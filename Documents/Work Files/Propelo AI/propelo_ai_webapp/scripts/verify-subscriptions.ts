
import { config } from 'dotenv';
import { resolve } from 'path';

// Load .env.local
config({ path: resolve(process.cwd(), '.env.local') });

// Mock imports if needed, or import directly using relative paths
// We need to match the logic from app/api/webhooks/lemonsqueezy/route.ts
// Since we can't easily import the route file in standalone (it has "next/server" imports), 
// we will COPY the logic here to verify the Environment Variables + IO.

import { initializeApp, getApps, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

// --- Firebase Init (Copied from lib/firebase-admin.ts to ensure standalone works) ---
const apps = getApps();
let db: FirebaseFirestore.Firestore;

if (!apps.length) {
  const serviceAccount = {
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
  };
  
  // Basic validation
  if (!serviceAccount.privateKey) {
      console.error("❌ FIREBASE_PRIVATE_KEY is missing in .env.local");
      process.exit(1);
  }

  initializeApp({
    credential: cert(serviceAccount),
  });
}
db = getFirestore();
// --------------------------------------------------------------------------

async function main() {
    console.log("🚀 Starting Subscription Verification...");

    // 1. Validate Env Vars
    const starterId = process.env.LEMONSQUEEZY_STARTER_VARIANT_ID;
    const proId = process.env.LEMONSQUEEZY_PRO_VARIANT_ID;

    if (!starterId) {
        console.error("❌ LEMONSQUEEZY_STARTER_VARIANT_ID is missing!");
        
        // Debugging: Check for NEXT_PUBLIC version
        const publicStarterId = process.env.NEXT_PUBLIC_LEMONSQUEEZY_STARTER_VARIANT_ID;
        if (publicStarterId) {
             console.log(`⚠️  Found NEXT_PUBLIC_LEMONSQUEEZY_STARTER_VARIANT_ID: ${publicStarterId}`);
             console.log("👉 ACTION: You need to map NEXT_PUBLIC_ vars to server vars, or update code to use NEXT_PUBLIC_ vars.");
        } else {
             console.log("❌ NEXT_PUBLIC_LEMONSQUEEZY_STARTER_VARIANT_ID is ALSO missing.");
        }
        
        console.log("Available LEMON keys:", Object.keys(process.env).filter(k => k.includes('LEMON')));
        process.exit(1);
    }
    console.log(`✅ Found Starter Variant ID: ${starterId}`);

    // 2. Logic to test (Copy of getSubscriptionPlan)
    function getSubscriptionPlan(variantId: string): string {
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

    const mapResult = getSubscriptionPlan(starterId);
    if (mapResult !== 'starter') {
        console.error(`❌ Mapping Failed! ID '${starterId}' mapped to '${mapResult}'`);
        process.exit(1);
    }
    console.log(`✅ Variant ID Maps Correctly to: ${mapResult}`);
    console.log(`✅ Plan Limit for ${mapResult}: ${getPlanLimit(mapResult)}`);

    // 3. Simulate DB Update
    const userId = "test_script_user_" + Date.now();
    console.log(`📝 Creating test user: ${userId}`);
    
    // Create initial user
    await db.collection("users").doc(userId).set({
        firstName: "Test Script",
        subscriptionPlan: "free",
        proposalsLimit: 15,
        updatedAt: new Date()
    });

    // Simulate Webhook Update Logic
    const plan = getSubscriptionPlan(starterId);
    const limit = getPlanLimit(plan);
    
    console.log(`🔄 Simulating upgrade to ${plan}...`);
    
    await db.collection("users").doc(userId).update({
        subscriptionPlan: plan,
        subscriptionStatus: "active",
        subscriptionId: "sim_sub_123",
        currentPeriodEnd: new Date(),
        proposalsLimit: limit,
        updatedAt: new Date(),
    });

    // 4. Verify
    const updatedDoc = await db.collection("users").doc(userId).get();
    const data = updatedDoc.data();

    if (data?.subscriptionPlan === 'starter' && data?.proposalsLimit === 200) {
        console.log("✅ SUCCESS: User document updated correctly in Firestore!");
    } else {
        console.error("❌ FAILURE: Firestore document mismatch:", data);
        process.exit(1);
    }

    // Cleanup
    console.log("🧹 Cleaning up test user...");
    await db.collection("users").doc(userId).delete();
    console.log("✨ Done.");
}

main().catch(console.error);
