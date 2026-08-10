import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/firebase-admin';
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders, getClientIdentifier } from '@/lib/rate-limit';

// Note: This endpoint is intentionally unauthenticated to allow tracking from shared proposals
// Rate limiting is applied to prevent abuse
export async function POST(request: NextRequest) {
  try {
    // Rate limit by IP to prevent abuse
    const clientId = getClientIdentifier(request);
    const rateLimitResult = await checkRateLimit(clientId, RATE_LIMITS.analytics, "analytics-track-detail");
    
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: 'Too many requests' },
        { 
          status: 429,
          headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.analytics)
        }
      );
    }

    const body = await request.json();
    const { proposalId, eventType, metadata } = body;

    if (!proposalId || !eventType) {
      return NextResponse.json(
        { error: 'Missing required fields' },
        { status: 400 }
      );
    }

    // Parse composite proposalId (userId_proposalId)
    const parts = proposalId.split('_');
    if (parts.length !== 2) {
      return NextResponse.json(
        { error: 'Invalid proposal ID format' },
        { status: 400 }
      );
    }
    
    const [userId, actualProposalId] = parts;

    const proposalRef = db
      .collection('users')
      .doc(userId)
      .collection('proposals')
      .doc(actualProposalId);

    // Create analytics event in proposal's analytics subcollection
    await proposalRef.collection('analytics').add({
      eventType,
      timestamp: new Date(),
      metadata: metadata || {},
      createdAt: new Date()
    });

    // Update proposal document with summary stats
    const proposalDoc = await proposalRef.get();

    if (proposalDoc.exists) {
      const currentData = proposalDoc.data();
      const updates: any = {
        lastViewedAt: new Date()
      };

      switch (eventType) {
        case 'view':
          updates.totalViews = (currentData?.totalViews || 0) + 1;
          
          // Update views by date
          const today = new Date().toISOString().split('T')[0];
          const viewsByDate = currentData?.viewsByDate || {};
          viewsByDate[today] = (viewsByDate[today] || 0) + 1;
          updates.viewsByDate = viewsByDate;
          break;

        case 'time_spent':
          const totalTime = currentData?.totalTimeSpent || 0;
          const viewCount = currentData?.totalViews || 1;
          updates.totalTimeSpent = totalTime + (metadata?.duration || 0);
          updates.averageTimeSpent = updates.totalTimeSpent / viewCount;
          break;

        case 'scroll_depth':
          const currentMax = currentData?.maxScrollDepth || 0;
          if (metadata?.scrollPercentage && metadata.scrollPercentage > currentMax) {
            updates.maxScrollDepth = metadata.scrollPercentage;
          }
          break;

        case 'link_click':
          updates.linkClicks = (currentData?.linkClicks || 0) + 1;
          break;

        case 'copy':
          updates.copyCount = (currentData?.copyCount || 0) + 1;
          break;
      }

      await proposalRef.update(updates);
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('[Analytics Track] Error:', error);
    return NextResponse.json(
      { error: 'Failed to track event' },
      { status: 500 }
    );
  }
}

// Get analytics for a specific proposal
export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const proposalId = searchParams.get('proposalId');

    if (!proposalId) {
      return NextResponse.json(
        { error: 'Proposal ID required' },
        { status: 400 }
      );
    }

    // Parse composite proposalId
    const parts = proposalId.split('_');
    if (parts.length !== 2) {
      return NextResponse.json(
        { error: 'Invalid proposal ID format' },
        { status: 400 }
      );
    }
    
    const [userId, actualProposalId] = parts;

    const proposalDoc = await db
      .collection('users')
      .doc(userId)
      .collection('proposals')
      .doc(actualProposalId)
      .get();

    if (!proposalDoc.exists) {
      return NextResponse.json({
        proposalId,
        totalViews: 0,
        uniqueViews: 0,
        averageTimeSpent: 0,
        maxScrollDepth: 0,
        linkClicks: 0,
        copyCount: 0,
        viewsByDate: {}
      });
    }

    const data = proposalDoc.data();
    return NextResponse.json({
      proposalId,
      totalViews: data?.totalViews || 0,
      uniqueViews: data?.uniqueViews || 0,
      averageTimeSpent: data?.averageTimeSpent || 0,
      maxScrollDepth: data?.maxScrollDepth || 0,
      linkClicks: data?.linkClicks || 0,
      copyCount: data?.copyCount || 0,
      viewsByDate: data?.viewsByDate || {},
      lastViewedAt: data?.lastViewedAt
    });
  } catch (error) {
    console.error('[Analytics Get] Error:', error);
    return NextResponse.json(
      { error: 'Failed to get analytics' },
      { status: 500 }
    );
  }
}
