import { NextRequest, NextResponse } from "next/server";
import { auth, db, collections } from "@/lib/firebase-admin";
import { cookies } from "next/headers";

// This endpoint syncs the user's subscription status from Lemon Squeezy
// Useful when webhooks can't reach localhost during development
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
        const userEmail = decodedToken.email;

        if (!userId || !userEmail) {

            return NextResponse.json({ error: "Invalid user data" }, { status: 400 });
        }



        // 2. Check Lemon Squeezy for subscriptions by email
        const lemonSqueezyApiKey = process.env.LEMONSQUEEZY_API_KEY;
        if (!lemonSqueezyApiKey) {

            return NextResponse.json(
                { error: "Payment configuration error" },
                { status: 500 }
            );
        }

        // Find subscriptions directly by user email (more reliable than customer lookup)
        const subscriptionsResponse = await fetch(
            `https://api.lemonsqueezy.com/v1/subscriptions?filter[user_email]=${encodeURIComponent(userEmail)}&filter[status]=active`,
            {
                headers: {
                    "Authorization": `Bearer ${lemonSqueezyApiKey}`,
                    "Accept": "application/vnd.api+json",
                },
            }
        );

        if (!subscriptionsResponse.ok) {
            const errorText = await subscriptionsResponse.text();
            console.error("[Sync] Failed to fetch subscriptions:", errorText);
            return NextResponse.json(
                { error: "Failed to fetch subscription details" },
                { status: 500 }
            );
        }

        const subscriptionsData = await subscriptionsResponse.json();

        
        const activeSubscription = subscriptionsData.data?.[0];

        if (!activeSubscription) {

            // No active subscription - update user to free plan
            await db.collection(collections.users).doc(userId).update({
                subscriptionPlan: "free",
                subscriptionStatus: "inactive",
                subscriptionId: null,
                proposalsLimit: 15,
                updatedAt: new Date(),
            });

            return NextResponse.json({ 
                synced: true, 
                subscription: null,
                plan: "free",
                message: "No active subscription found"
            });
        }

        // 3. Map variant ID to plan name
        const variantId = activeSubscription.attributes.variant_id.toString();
        const plan = getSubscriptionPlan(variantId);
        const proposalsLimit = getPlanLimit(plan);



        // 4. Update Firestore with subscription info
        await db.collection(collections.users).doc(userId).update({
            subscriptionPlan: plan,
            subscriptionStatus: activeSubscription.attributes.status,
            subscriptionId: activeSubscription.id,
            currentPeriodEnd: new Date(activeSubscription.attributes.renews_at),
            proposalsLimit: proposalsLimit,
            lemonSqueezyCustomerId: activeSubscription.attributes.customer_id.toString(),
            updatedAt: new Date(),
        });



        return NextResponse.json({
            synced: true,
            subscription: {
                id: activeSubscription.id,
                plan: plan,
                status: activeSubscription.attributes.status,
                productName: activeSubscription.attributes.product_name,
                renewsAt: activeSubscription.attributes.renews_at,
            },
            proposalsLimit: proposalsLimit,
            message: `Subscription synced successfully: ${plan} plan`
        });

    } catch (error: any) {
        console.error("[Sync] API Error:", error);
        return NextResponse.json(
            { error: error.message || "Internal Server Error" },
            { status: 500 }
        );
    }
}

function getSubscriptionPlan(variantId: string): string {
    const variantMap: Record<string, string> = {
        // Hardcoded variant IDs for your store
        "1160539": "starter",
        "1160834": "pro",
        // Also check env vars
        [process.env.NEXT_PUBLIC_LEMONSQUEEZY_STARTER_VARIANT_ID || ""]: "starter",
        [process.env.NEXT_PUBLIC_LEMONSQUEEZY_PRO_VARIANT_ID || ""]: "pro",
        [process.env.LEMONSQUEEZY_STARTER_VARIANT_ID || ""]: "starter",
        [process.env.LEMONSQUEEZY_PRO_VARIANT_ID || ""]: "pro",
    };

    return variantMap[variantId] || "free";
}

function getPlanLimit(plan: string): number {
    const limits: Record<string, number> = {
        free: 15,
        starter: 200,
        pro: 500,
        agency: 1500,
        lifetime: 99999,
    };

    return limits[plan] || 15;
}
