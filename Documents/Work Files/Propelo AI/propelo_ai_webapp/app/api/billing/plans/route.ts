import { NextRequest, NextResponse } from "next/server";

// LemonSqueezy Variant IDs - kept server-side only
const VARIANT_IDS = {
  starter: process.env.LEMONSQUEEZY_STARTER_VARIANT_ID || "1160539",
  pro: process.env.LEMONSQUEEZY_PRO_VARIANT_ID || "1160834",
};

// Plan configuration with variant IDs securely served from backend
const PLANS_CONFIG = [
  {
    id: "free",
    name: "Free Trial",
    price: 0,
    period: "",
    description: "Try Propelo AI risk-free",
    features: [
      "15 proposals total",
      "Basic AI Model",
      "Standard Tones",
      "7-day history",
    ],
    limitations: [
      "No proposal enhancer",
      "No analytics",
    ],
    popular: false,
    variantId: null,
    color: "slate",
  },
  {
    id: "starter",
    name: "Pro Closer",
    price: 6.99,
    originalPrice: 12,
    period: "/mo",
    description: "For serious freelancers who want to win",
    features: [
      "200 proposals/month",
      "Smart AI Model",
      "All Professional Tones",
      "Open/click tracking",
      "Proposal Enhancer",
      "30-day history",
      "Email Support",
    ],
    popular: true,
    variantId: VARIANT_IDS.starter,
    color: "blue",
  },
  {
    id: "pro",
    name: "Agency Elite",
    price: 19.99,
    originalPrice: 49,
    period: "/mo",
    description: "Scale your agency operations",
    features: [
      "500 proposals/month",
      "Smartest AI Model (GPT-4)",
      "Custom Tone Memory",
      "Advanced Analytics + Export",
      "Pain point detection",
      "Client type analysis",
      "Priority Support",
      "Unlimited history",
    ],
    popular: false,
    variantId: VARIANT_IDS.pro,
    color: "purple",
  },
];

export async function GET(request: NextRequest) {
  try {
    // Return plans without exposing internal configuration details
    // The variant IDs are needed for checkout but this is still safer
    // than embedding them in client-side code
    return NextResponse.json({
      success: true,
      plans: PLANS_CONFIG,
    });
  } catch (error) {
    console.error("[Plans API] Error fetching plans:", error);
    return NextResponse.json(
      { success: false, error: "Failed to fetch plans" },
      { status: 500 }
    );
  }
}
