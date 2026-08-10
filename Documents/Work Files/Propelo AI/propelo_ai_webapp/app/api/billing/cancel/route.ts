import { NextRequest, NextResponse } from "next/server";
import { auth, db, collections } from "@/lib/firebase-admin";
import { cookies } from "next/headers";
import { lemonSqueezy } from "@/lib/lemonsqueezy";
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

        if (!userId) {
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

        // 2. Get user's subscription info from Firestore
        const userDoc = await db.collection(collections.users).doc(userId).get();
        const userData = userDoc.data();

        if (!userData?.subscriptionId) {
            return NextResponse.json(
                { error: "No active subscription found" },
                { status: 404 }
            );
        }

        const subscriptionId = userData.subscriptionId;

        // 3. Cancel subscription via Lemon Squeezy API
        const result = await lemonSqueezy.cancelSubscription(subscriptionId);

        // 4. Update Firestore to reflect cancellation
        await db.collection(collections.users).doc(userId).update({
            subscriptionStatus: "canceled",
            updatedAt: new Date().toISOString(),
        });

        return NextResponse.json({ 
            success: true,
            message: "Subscription cancelled successfully. You'll have access until the end of your billing period.",
            subscription: result.data,
        });

    } catch (error: any) {
        console.error("Cancel Subscription API Error:", error);
        return NextResponse.json(
            { error: error.message || "Failed to cancel subscription" },
            { status: 500 }
        );
    }
}
