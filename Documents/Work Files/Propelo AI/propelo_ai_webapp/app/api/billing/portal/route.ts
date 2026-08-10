import { NextRequest, NextResponse } from "next/server";
import { auth, db, collections } from "@/lib/firebase-admin";
import { cookies } from "next/headers";

export async function POST(req: NextRequest) {
    try {
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

        // 2. Get user's subscription info from Firestore
        const userDoc = await db.collection(collections.users).doc(userId).get();
        const userData = userDoc.data();

        if (!userData?.subscriptionId) {
            return NextResponse.json(
                { error: "No active subscription found" },
                { status: 404 }
            );
        }

        // 3. Get the customer portal URL from Lemon Squeezy
        // Lemon Squeezy provides a customer portal URL in subscription data
        const subscriptionId = userData.subscriptionId;
        
        const lemonSqueezyApiKey = process.env.LEMONSQUEEZY_API_KEY;
        if (!lemonSqueezyApiKey) {
            return NextResponse.json(
                { error: "Payment configuration error" },
                { status: 500 }
            );
        }

        // Fetch subscription details to get the customer portal URL
        const response = await fetch(
            `https://api.lemonsqueezy.com/v1/subscriptions/${subscriptionId}`,
            {
                headers: {
                    "Authorization": `Bearer ${lemonSqueezyApiKey}`,
                    "Accept": "application/vnd.api+json",
                },
            }
        );

        if (!response.ok) {
            console.error("Lemon Squeezy API error:", await response.text());
            return NextResponse.json(
                { error: "Failed to fetch subscription details" },
                { status: 500 }
            );
        }

        const subscriptionData = await response.json();
        const portalUrl = subscriptionData.data?.attributes?.urls?.customer_portal;

        if (!portalUrl) {
            // Fallback: Provide Lemon Squeezy account page
            return NextResponse.json({
                url: null,
                message: "Please check your email for subscription management options.",
            });
        }

        return NextResponse.json({ url: portalUrl });

    } catch (error: any) {
        console.error("Portal API Error:", error);
        return NextResponse.json(
            { error: error.message || "Internal Server Error" },
            { status: 500 }
        );
    }
}
