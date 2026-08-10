import { NextRequest, NextResponse } from "next/server";
import { auth, db, collections } from "@/lib/firebase-admin";
import { sendWelcomeEmail } from "@/lib/email/send-welcome";

export async function POST(req: NextRequest) {
  try {
    const { token } = await req.json();

    if (!token) {
      return NextResponse.json({ error: "Missing token" }, { status: 400 });
    }

    // Verify the ID token
    const decodedToken = await auth.verifyIdToken(token);
    const userId = decodedToken.uid;
    const email = decodedToken.email;
    const name = decodedToken.name || "";
    const [firstName = "", lastName = ""] = name.split(" ");
    const picture = decodedToken.picture || "";

    // Check if user document already exists
    const userRef = db.collection(collections.users).doc(userId);
    const userDoc = await userRef.get();

    if (userDoc.exists) {
        // User exists, we can optionally sync some fields if needed
        // But crucially, we DO NOT reset their plan or limits
        return NextResponse.json({ 
            success: true, 
            status: "existing",
            message: "User already exists" 
        });
    }

    // User does not exist, create with safe defaults
    const now = new Date();
    const trialEndsAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000); // 7 days

    const newUser = {
      email,
      firstName,
      lastName,
      profileImage: picture,
      createdAt: now,
      updatedAt: now,
      
      // CRITICAL: Server-authoritative defaults
      subscriptionPlan: "free",
      subscriptionStatus: "active", // Active free tier
      plan: "free",
      proposalsUsed: 0,
      proposalsLimit: 15, // Default limit
      
      // Default preferences
      preferences: {
        theme: "light",
        emailNotifications: true,
        proposalOpenAlerts: true,
        weeklyReports: false,
        marketingEmails: false,
        language: "en",
        timezone: "UTC",
        autoSave: true,
      },
      analytics: {
        totalProposals: 0,
        totalViews: 0,
        totalAccepted: 0,
        winRate: 0,
        lastUpdated: now,
      },
      reengageStages: {
          day3: false,
          day7: false,
          day14: false,
          day21: false,
          day30: false,
      }
    };

    await userRef.set(newUser);

    // Send welcome email (non-blocking)
    const displayName = firstName || email?.split('@')[0] || 'there';
    sendWelcomeEmail(email!, displayName).catch((err) => {
      console.error('Failed to send welcome email:', err);
    });

    return NextResponse.json({ 
        success: true, 
        status: "created",
        data: { id: userId, ...newUser }
    });

  } catch (error: any) {
    console.error("Error syncing user:", error);
    return NextResponse.json(
      { error: "Failed to sync user" },
      { status: 500 }
    );
  }
}
