import { NextRequest, NextResponse } from "next/server";
import { db, collections } from "@/lib/firebase-admin";
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders, getClientIdentifier } from "@/lib/rate-limit";

// Track proposal view
// Note: This endpoint is intentionally unauthenticated to allow tracking from shared proposals
// Rate limiting is applied to prevent abuse
export async function POST(req: NextRequest) {
  try {
    // Rate limit by IP to prevent abuse
    const clientId = getClientIdentifier(req);
    const rateLimitResult = await checkRateLimit(clientId, RATE_LIMITS.analytics, "analytics-track");
    
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: "Too many requests" },
        { 
          status: 429,
          headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.analytics)
        }
      );
    }

    const body = await req.json();
    const { proposalId, eventType, metadata } = body;

    if (!proposalId) {
      return NextResponse.json({ error: "Proposal ID required" }, { status: 400 });
    }

    // Parse composite proposalId (userId_proposalId)
    const parts = proposalId.split('_');
    if (parts.length !== 2) {
      return NextResponse.json({ error: "Invalid proposal ID format" }, { status: 400 });
    }
    
    const [userId, actualProposalId] = parts;

    const proposalRef = db
      .collection(collections.users)
      .doc(userId)
      .collection('proposals')
      .doc(actualProposalId);
      
    const proposalDoc = await proposalRef.get();

    if (!proposalDoc.exists) {
      return NextResponse.json({ error: "Proposal not found" }, { status: 404 });
    }

    // Update proposal analytics
    const updates: any = {};

    switch (eventType) {
      case "view":
        if (!proposalDoc.data()?.opened) {
          updates.opened = true;
          updates.openedAt = new Date();
        }
        updates.openCount = (proposalDoc.data()?.openCount || 0) + 1;
        break;

      case "click":
        updates.linkClicks = (proposalDoc.data()?.linkClicks || 0) + 1;
        break;

      case "time_spent":
        updates.timeSpent = metadata.timeSpent;
        break;
    }

    if (Object.keys(updates).length > 0) {
      await proposalRef.update(updates);
    }

    // Store detailed analytics event in proposal subcollection
    await proposalRef.collection('analytics').add({
      type: eventType,
      timestamp: new Date(),
      metadata: metadata || {},
    });

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Error tracking analytics:", error);
    return NextResponse.json(
      { error: "Failed to track analytics" },
      { status: 500 }
    );
  }
}

// GET analytics for user or specific proposal
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const proposalId = searchParams.get("proposalId");
    const timeRange = searchParams.get("timeRange") || "30d";
    
    // Get user session from cookie
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
      // Try Authorization header as fallback
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

    const userId = decodedToken.uid;

    // If proposalId is provided, return single proposal analytics
    if (proposalId) {
      // Parse composite proposalId
      const parts = proposalId.split('_');
      if (parts.length !== 2) {
        return NextResponse.json({ error: "Invalid proposal ID format" }, { status: 400 });
      }
      
      const [proposalUserId, actualProposalId] = parts;
      
      // Verify ownership
      if (proposalUserId !== userId) {
        return NextResponse.json({ error: "Unauthorized" }, { status: 403 });
      }

      const proposalDoc = await db
        .collection(collections.users)
        .doc(userId)
        .collection('proposals')
        .doc(actualProposalId)
        .get();
      
      if (!proposalDoc.exists) {
        return NextResponse.json({ error: "Proposal not found" }, { status: 404 });
      }

      // Get analytics events from proposal subcollection
      const eventsSnapshot = await proposalDoc.ref
        .collection('analytics')
        .orderBy("timestamp", "desc")
        .limit(100)
        .get();

      const events = eventsSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      return NextResponse.json({
        success: true,
        data: {
          proposal: proposalDoc.data(),
          events,
        },
      });
    }

    // Otherwise, return user analytics overview
    // Calculate date range
    const now = new Date();
    let startDate = new Date();
    
    switch (timeRange) {
      case "7d":
        startDate.setDate(now.getDate() - 7);
        break;
      case "30d":
        startDate.setDate(now.getDate() - 30);
        break;
      case "90d":
        startDate.setDate(now.getDate() - 90);
        break;
      case "1y":
        startDate.setFullYear(now.getFullYear() - 1);
        break;
      default:
        startDate.setDate(now.getDate() - 30);
    }

    // Fetch all user proposals in time range from user subcollection
    const proposalsSnapshot = await db
      .collection(collections.users)
      .doc(userId)
      .collection('proposals')
      .where("createdAt", ">=", startDate)
      .get();

    const proposals = proposalsSnapshot.docs.map((doc) => ({
      id: `${userId}_${doc.id}`,
      ...doc.data(),
    }));

    // Calculate analytics
    const totalProposals = proposals.length;
    const totalViews = proposals.reduce((sum, p: any) => sum + (p.openCount || 0), 0);
    const totalClicks = proposals.reduce((sum, p: any) => sum + (p.linkClicks || 0), 0);
    
    // Calculate accepted proposals
    const acceptedProposals = proposals.filter((p: any) => p.status === "accepted").length;
    const winRate = totalProposals > 0 ? (acceptedProposals / totalProposals) * 100 : 0;

    // Calculate average time spent (mock for now)
    const avgTimeSpent = "2m 34s";

    // Group by month for trends
    const monthlyData = new Map<string, { proposals: number; accepted: number }>();
    proposals.forEach((proposal: any) => {
      const date = proposal.createdAt?.toDate?.() || new Date(proposal.createdAt);
      const monthKey = date.toLocaleDateString("en-US", { month: "short" });
      
      const existing = monthlyData.get(monthKey) || { proposals: 0, accepted: 0 };
      existing.proposals += 1;
      if (proposal.status === "accepted") {
        existing.accepted += 1;
      }
      monthlyData.set(monthKey, existing);
    });

    const proposalTrends = Array.from(monthlyData.entries()).map(([month, data]) => ({
      month,
      ...data,
    }));

    // Status distribution
    const statusCounts = proposals.reduce((acc: any, p: any) => {
      const status = p.status || "draft";
      acc[status] = (acc[status] || 0) + 1;
      return acc;
    }, {});

    const statusDistribution = [
      { name: "Accepted", value: statusCounts.accepted || 0, color: "#10B981" },
      { name: "Opened", value: statusCounts.opened || 0, color: "#3B82F6" },
      { name: "Sent", value: statusCounts.sent || 0, color: "#F59E0B" },
      { name: "Draft", value: statusCounts.draft || 0, color: "#6B7280" },
      { name: "Rejected", value: statusCounts.rejected || 0, color: "#EF4444" },
    ].filter((item) => item.value > 0);

    // Platform performance
    const platformStats = proposals.reduce((acc: any, p: any) => {
      const platform = p.platform || "other";
      if (!acc[platform]) {
        acc[platform] = { proposals: 0, accepted: 0, views: 0 };
      }
      acc[platform].proposals += 1;
      acc[platform].views += p.openCount || 0;
      if (p.status === "accepted") {
        acc[platform].accepted += 1;
      }
      return acc;
    }, {});

    const platformPerformance = Object.entries(platformStats).map(([platform, stats]: [string, any]) => ({
      platform: platform.charAt(0).toUpperCase() + platform.slice(1),
      proposals: stats.proposals,
      accepted: stats.accepted,
      views: stats.views,
      rate: stats.proposals > 0 ? Math.round((stats.accepted / stats.proposals) * 100) : 0,
    })).sort((a, b) => b.proposals - a.proposals);

    // Calculate conversion rate (views to accepted)
    const conversionRate = totalViews > 0 ? ((acceptedProposals / totalViews) * 100).toFixed(1) : "0.0";

    return NextResponse.json({
      success: true,
      data: {
        stats: {
          totalViews,
          totalClicks,
          avgTimeSpent,
          conversionRate: `${conversionRate}%`,
          totalProposals,
          acceptedProposals,
          winRate: winRate.toFixed(1),
        },
        proposalTrends,
        statusDistribution,
        platformPerformance,
      },
    });
  } catch (error: any) {
    console.error("Error fetching analytics:", error);
    return NextResponse.json(
      { error: "Failed to fetch analytics" },
      { status: 500 }
    );
  }
}
