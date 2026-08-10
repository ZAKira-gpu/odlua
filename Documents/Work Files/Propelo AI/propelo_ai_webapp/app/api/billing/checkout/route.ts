import { NextRequest, NextResponse } from "next/server";
import { lemonSqueezy } from "@/lib/lemonsqueezy";
import { auth } from "@/lib/firebase-admin";
import { cookies } from "next/headers";
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders } from "@/lib/rate-limit";

// Allowed origins
const ALLOWED_ORIGINS = [
  process.env.NEXT_PUBLIC_APP_URL || "https://app.propeloai.com",
  "https://propeloai.com",
  "https://www.propeloai.com",
];

export async function POST(req: NextRequest) {
    try {
        // Origin validation
        const origin = req.headers.get("origin");
        if (origin && !ALLOWED_ORIGINS.includes(origin)) {
            return NextResponse.json({ error: "Forbidden" }, { status: 403 });
        }

        // 1. Authenticate User
        const cookieStore = await cookies();
        const sessionCookie = cookieStore.get("session")?.value;

        if (!sessionCookie) {
            return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
        }

        const decodedToken = await auth.verifyIdToken(sessionCookie);
        const userId = decodedToken.uid;
        const userEmail = decodedToken.email;

        if (!userId || !userEmail) {
            return NextResponse.json({ error: "Invalid user data" }, { status: 400 });
        }

        // Rate limiting check
        const rateLimitResult = await checkRateLimit(`billing:${userId}`, RATE_LIMITS.billing);
        if (!rateLimitResult.success) {
            return NextResponse.json(
                { error: `Rate limit exceeded. Try again in ${rateLimitResult.resetIn} seconds.` },
                { 
                    status: 429,
                    headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.billing)
                }
            );
        }

        // 2. Parse Request
        const body = await req.json();
        const { variantId, redirectUrl } = body;

        if (!variantId) {
            return NextResponse.json({ error: "Variant ID is required" }, { status: 400 });
        }

        // 3. Create Checkout
        // We pass userId in custom_data so the webhook can link the subscription to the user
        // We pass email to pre-fill the checkout form
        // We pass redirectUrl to send users back to the app after checkout
        const successRedirectUrl = redirectUrl || `${process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'}/dashboard/subscription?success=true`;
        
        const response = await lemonSqueezy.createCheckout({
            variantId,
            email: userEmail,
            customData: {
                user_id: userId,
            },
            redirectUrl: successRedirectUrl,
        });

        const checkoutUrl = response.data?.attributes?.url;

        if (!checkoutUrl) {
            console.error("Lemon Squeezy response missing URL:", response);
            return NextResponse.json({ error: "Failed to generate checkout URL" }, { status: 500 });
        }

        // 4. Return URL
        return NextResponse.json({ url: checkoutUrl });

    } catch (error: any) {
        console.error("Checkout API Error:", error);
        return NextResponse.json(
            { error: error.message || "Internal Server Error" },
            { status: 500 }
        );
    }
}
