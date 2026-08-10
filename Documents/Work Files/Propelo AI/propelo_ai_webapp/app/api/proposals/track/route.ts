import { NextRequest, NextResponse } from "next/server";
import { db, collections } from "@/lib/firebase-admin";
import type { ProposalTrackingSync, ProposalSubmission } from "@/types";

/**
 * POST /api/proposals/track
 * Track proposal submissions from extension
 */
export async function POST(req: NextRequest) {
  try {
    const body: ProposalTrackingSync = await req.json();
    const { userId, platform, proposals, syncedAt } = body;

    if (!userId || !platform || !proposals || !Array.isArray(proposals)) {
      return NextResponse.json(
        { error: "Missing required fields: userId, platform, or proposals array" },
        { status: 400 }
      );
    }

    // Verify user session
    const cookieStore = await (await import("next/headers")).cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    
    if (!sessionCookie) {
      return NextResponse.json(
        { error: "Unauthorized - Please sign in" },
        { status: 401 }
      );
    }

    // Verify the session token
    let decodedToken;
    try {
      const { auth } = await import("@/lib/firebase-admin");
      decodedToken = await auth.verifyIdToken(sessionCookie);
    } catch (error) {
      const authHeader = req.headers.get("authorization");
      if (authHeader?.startsWith("Bearer ")) {
        const token = authHeader.split(" ")[1];
        const { auth } = await import("@/lib/firebase-admin");
        decodedToken = await auth.verifyIdToken(token);
      } else {
        return NextResponse.json(
          { error: "Invalid session - Please sign in again" },
          { status: 401 }
        );
      }
    }

    // Verify user ID matches
    if (decodedToken.uid !== userId) {
      return NextResponse.json(
        { error: "Unauthorized - User ID mismatch" },
        { status: 403 }
      );
    }

    // Batch write proposals
    const batch = db.batch();
    const proposalRefs: any[] = [];
    let newProposals = 0;
    let updatedProposals = 0;

    for (const proposal of proposals) {
      const proposalRef = db
        .collection(collections.users)
        .doc(userId)
        .collection('proposalTracking')
        .doc(proposal.id);

      // Check if proposal exists
      const existingDoc = await proposalRef.get();
      
      if (existingDoc.exists) {
        // Update existing proposal
        batch.update(proposalRef, {
          ...proposal,
          userId,
          updatedAt: new Date(),
          lastScraped: new Date()
        });
        updatedProposals++;
      } else {
        // Create new proposal
        batch.set(proposalRef, {
          ...proposal,
          userId,
          createdAt: new Date(),
          updatedAt: new Date(),
          lastScraped: new Date()
        });
        newProposals++;
      }

      proposalRefs.push(proposalRef);
    }

    // Commit batch
    await batch.commit();

    // Update user's proposal tracking summary
    const userRef = db.collection(collections.users).doc(userId);
    const userDoc = await userRef.get();
    const userData = userDoc.data();

    // Calculate stats
    const allProposalsSnapshot = await db
      .collection(collections.users)
      .doc(userId)
      .collection('proposalTracking')
      .get();

    const totalProposals = allProposalsSnapshot.size;
    const activeProposals = allProposalsSnapshot.docs.filter(
      doc => ['submitted', 'viewed', 'interviewing', 'shortlisted'].includes(doc.data().status)
    ).length;

    const acceptedProposals = allProposalsSnapshot.docs.filter(
      doc => doc.data().status === 'accepted'
    ).length;

    const winRate = totalProposals > 0 ? ((acceptedProposals / totalProposals) * 100).toFixed(1) : '0';

    // Calculate average response time
    const responseTimes = allProposalsSnapshot.docs
      .map(doc => doc.data().responseTime)
      .filter(time => time !== undefined && time !== null);
    
    const averageResponseTime = responseTimes.length > 0
      ? responseTimes.reduce((sum, time) => sum + time, 0) / responseTimes.length
      : undefined;

    // Update user summary
    await userRef.update({
      'proposalTracking.totalProposals': totalProposals,
      'proposalTracking.activeProposals': activeProposals,
      'proposalTracking.acceptedProposals': acceptedProposals,
      'proposalTracking.winRate': parseFloat(winRate),
      'proposalTracking.averageResponseTime': averageResponseTime,
      'proposalTracking.lastSyncedAt': new Date(),
      [`proposalTracking.platforms.${platform}`]: proposals.length,
      updatedAt: new Date()
    });




    return NextResponse.json({
      success: true,
      message: `Successfully tracked ${proposals.length} proposals`,
      summary: {
        totalSynced: proposals.length,
        newProposals,
        updatedProposals,
        totalProposals,
        activeProposals,
        winRate: `${winRate}%`
      },
      syncedAt: new Date().toISOString()
    });

  } catch (error: any) {
    console.error("[Proposal Tracking] Error:", error);
    return NextResponse.json(
      { error: "Failed to track proposals", details: error.message },
      { status: 500 }
    );
  }
}

/**
 * GET /api/proposals/track?platform=upwork&status=active
 * Retrieve tracked proposals with optional filters
 */
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const platform = searchParams.get("platform");
    const status = searchParams.get("status");
    const limit = parseInt(searchParams.get("limit") || "50");
    const offset = parseInt(searchParams.get("offset") || "0");

    // Verify user session
    const cookieStore = await (await import("next/headers")).cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    
    if (!sessionCookie) {
      return NextResponse.json(
        { error: "Unauthorized - Please sign in" },
        { status: 401 }
      );
    }

    const { auth } = await import("@/lib/firebase-admin");
    const decodedToken = await auth.verifyIdToken(sessionCookie);
    const userId = decodedToken.uid;

    // Build query
    let query: any = db
      .collection(collections.users)
      .doc(userId)
      .collection('proposalTracking')
      .orderBy('submittedAt', 'desc');

    // Apply filters
    if (platform) {
      query = query.where('platform', '==', platform);
    }

    if (status) {
      query = query.where('status', '==', status);
    }

    // Execute query
    const snapshot = await query.limit(limit).offset(offset).get();

    const proposals: ProposalSubmission[] = [];
    snapshot.forEach((doc: any) => {
      proposals.push({
        id: doc.id,
        ...doc.data()
      } as ProposalSubmission);
    });

    // Get total count
    const totalSnapshot = await db
      .collection(collections.users)
      .doc(userId)
      .collection('proposalTracking')
      .get();

    return NextResponse.json({
      success: true,
      data: proposals,
      pagination: {
        total: totalSnapshot.size,
        limit,
        offset,
        hasMore: offset + limit < totalSnapshot.size
      }
    });

  } catch (error: any) {
    console.error("[Proposal Tracking] Get Error:", error);
    return NextResponse.json(
      { error: "Failed to retrieve proposals", details: error.message },
      { status: 500 }
    );
  }
}

/**
 * PATCH /api/proposals/track
 * Update a specific proposal's status or details
 */
export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const { proposalId, updates } = body;

    if (!proposalId || !updates) {
      return NextResponse.json(
        { error: "Missing required fields: proposalId or updates" },
        { status: 400 }
      );
    }

    // Verify user session
    const cookieStore = await (await import("next/headers")).cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    
    if (!sessionCookie) {
      return NextResponse.json(
        { error: "Unauthorized - Please sign in" },
        { status: 401 }
      );
    }

    const { auth } = await import("@/lib/firebase-admin");
    const decodedToken = await auth.verifyIdToken(sessionCookie);
    const userId = decodedToken.uid;

    // Update proposal
    const proposalRef = db
      .collection(collections.users)
      .doc(userId)
      .collection('proposalTracking')
      .doc(proposalId);

    const proposalDoc = await proposalRef.get();
    if (!proposalDoc.exists) {
      return NextResponse.json(
        { error: "Proposal not found" },
        { status: 404 }
      );
    }

    await proposalRef.update({
      ...updates,
      updatedAt: new Date()
    });



    return NextResponse.json({
      success: true,
      message: "Proposal updated successfully",
      proposalId
    });

  } catch (error: any) {
    console.error("[Proposal Tracking] Update Error:", error);
    return NextResponse.json(
      { error: "Failed to update proposal", details: error.message },
      { status: 500 }
    );
  }
}
