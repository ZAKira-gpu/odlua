import { NextRequest, NextResponse } from "next/server";
import { lemonSqueezy } from "@/lib/lemonsqueezy";
import { db, collections } from "@/lib/firebase-admin";
import crypto from "crypto";

export async function POST(req: NextRequest) {
  try {
    // Verify webhook signature
    const body = await req.text();
    const signature = req.headers.get("x-signature") || "";
    const secret = process.env.LEMONSQUEEZY_WEBHOOK_SECRET || "";

    const isValid = lemonSqueezy.verifyWebhookSignature(body, signature, secret);

    if (!isValid) {
      console.error("Invalid webhook signature");
      return NextResponse.json({ error: "Invalid signature" }, { status: 401 });
    }

    const event = JSON.parse(body);
    const eventName = event.meta.event_name;
    const eventData = event.data.attributes;



    switch (eventName) {
      case "subscription_created":
      case "subscription_updated":
        await handleSubscriptionUpdate(eventData);
        break;

      case "subscription_cancelled":
        await handleSubscriptionCancelled(eventData);
        break;

      case "subscription_resumed":
        await handleSubscriptionResumed(eventData);
        break;

      case "subscription_expired":
        await handleSubscriptionExpired(eventData);
        break;

      case "order_created":
        await handleOrderCreated(eventData);
        break;

      default:

    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Webhook error:", error);
    return NextResponse.json(
      { error: "Webhook processing failed" },
      { status: 500 }
    );
  }
}

export async function handleSubscriptionUpdate(data: any) {
  const userId = data.custom_data?.user_id;
  if (!userId) {
    console.error("No user_id in webhook data");
    return;
  }

  const variantId = data.variant_id;
  const plan = getSubscriptionPlan(variantId);

  await db.collection(collections.users).doc(userId).update({
    subscriptionPlan: plan,
    subscriptionStatus: data.status,
    subscriptionId: data.id,
    currentPeriodEnd: new Date(data.renews_at),
    proposalsLimit: getPlanLimit(plan),
    updatedAt: new Date(),
  });


}

async function handleSubscriptionCancelled(data: any) {
  const userId = data.custom_data?.user_id;
  if (!userId) return;

  await db.collection(collections.users).doc(userId).update({
    subscriptionStatus: "canceled",
    updatedAt: new Date(),
  });


}

async function handleSubscriptionResumed(data: any) {
  const userId = data.custom_data?.user_id;
  if (!userId) return;

  await db.collection(collections.users).doc(userId).update({
    subscriptionStatus: "active",
    updatedAt: new Date(),
  });


}

async function handleSubscriptionExpired(data: any) {
  const userId = data.custom_data?.user_id;
  if (!userId) return;

  await db.collection(collections.users).doc(userId).update({
    subscriptionPlan: "free",
    subscriptionStatus: "canceled",
    subscriptionId: null,
    proposalsLimit: 15,
    updatedAt: new Date(),
  });


}

async function handleOrderCreated(data: any) {
  const userId = data.custom_data?.user_id;
  if (!userId) return;

  // Handle lifetime deal or one-time purchases
  const variantId = data.variant_id;

  if (variantId === process.env.LEMONSQUEEZY_LIFETIME_VARIANT_ID) {
    await db.collection(collections.users).doc(userId).update({
      subscriptionPlan: "lifetime",
      subscriptionStatus: "active",
      proposalsLimit: 99999,
      updatedAt: new Date(),
    });


  }
}

export function getSubscriptionPlan(variantId: string): string {
  // Map variant IDs to plan names
  const variantMap: Record<string, string> = {
    [process.env.LEMONSQUEEZY_STARTER_VARIANT_ID || ""]: "starter",
    [process.env.LEMONSQUEEZY_PRO_VARIANT_ID || ""]: "pro",
    [process.env.LEMONSQUEEZY_AGENCY_VARIANT_ID || ""]: "agency",
    [process.env.LEMONSQUEEZY_LIFETIME_VARIANT_ID || ""]: "lifetime",
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
