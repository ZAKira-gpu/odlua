import { NextRequest, NextResponse } from 'next/server';
import { db, auth, collections } from '@/lib/firebase-admin';
import { cookies } from 'next/headers';

/**
 * API endpoint to receive profile data from Chrome extension
 * POST /api/account/receive-profile
 */
export async function POST(request: NextRequest) {
  try {
    // Get session from cookie
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get('session')?.value;
    
    // Try to verify session
    let userId: string | null = null;
    
    if (sessionCookie) {
      try {
        const decodedToken = await auth.verifyIdToken(sessionCookie);
        userId = decodedToken.uid;
      } catch (error) {

      }
    }
    
    // Try Authorization header as fallback
    if (!userId) {
      const authHeader = request.headers.get('authorization');
      if (authHeader?.startsWith('Bearer ')) {
        try {
          const token = authHeader.split(' ')[1];
          const decodedToken = await auth.verifyIdToken(token);
          userId = decodedToken.uid;
        } catch (error) {

        }
      }
    }
    
    if (!userId) {
      return NextResponse.json(
        { error: 'Unauthorized - Please log in' },
        { status: 401 }
      );
    }

    const body = await request.json();
    const { platform, profileData } = body;

    if (!platform || !profileData) {
      return NextResponse.json(
        { error: 'Missing required fields: platform and profileData' },
        { status: 400 }
      );
    }

    // Validate platform
    const validPlatforms = ['upwork', 'fiverr', 'freelancer'];
    if (!validPlatforms.includes(platform)) {
      return NextResponse.json(
        { error: `Invalid platform. Must be one of: ${validPlatforms.join(', ')}` },
        { status: 400 }
      );
    }

    // Store in Firestore - use SAME structure as /api/account/sync
    const userRef = db.collection(collections.users).doc(userId);
    const now = new Date();
    
    // Normalize profile data
    const normalizedProfile = {
      ...profileData,
      platform,
      syncedAt: now.toISOString(),
      scrapedAt: profileData.scrapedAt || now.toISOString()
    };

    // Use NESTED structure to match /api/account/sync
    // This ensures consistency across all sync endpoints
    await userRef.set(
      {
        accounts: {
          [platform]: {
            platform,
            connected: true,
            userId,
            profileData: normalizedProfile,  // NESTED - consistent with /api/account/sync
            lastSynced: now,
            syncStatus: 'success',
            syncErrors: []
          }
        },
        platforms: {
          [platform]: {
            connected: true,
            lastSynced: now,
            displayName: profileData.displayName || profileData.name || null,
            jobSuccessScore: profileData.jobSuccessScore || null,
            hourlyRate: profileData.hourlyRate || null,
            profileImage: profileData.profileImage || null
          }
        },
        lastAccountSync: now.toISOString(),
        updatedAt: now
      },
      { merge: true }
    );

    // Return summary
    return NextResponse.json({
      success: true,
      message: `${platform} profile data saved successfully`,
      summary: {
        platform,
        name: profileData.displayName || profileData.username || 'Unknown',
        profileUrl: profileData.profileUrl,
        itemsCollected: {
          skills: profileData.skills?.length || 0,
          portfolio: profileData.portfolio?.length || 0,
          languages: profileData.languages?.length || 0
        }
      }
    });

  } catch (error) {
    console.error('[API] Error receiving profile data:', error);
    
    return NextResponse.json(
      { 
        error: 'Failed to save profile data',
        details: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}

/**
 * GET endpoint to retrieve stored profile data
 * GET /api/account/receive-profile?platform=upwork
 */
export async function GET(request: NextRequest) {
  try {
    // Get session from cookie
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get('session')?.value;
    
    if (!sessionCookie) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }
    
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(sessionCookie);
    } catch (error) {
      return NextResponse.json(
        { error: 'Invalid session' },
        { status: 401 }
      );
    }
    
    const userId = decodedToken.uid;

    const platform = request.nextUrl.searchParams.get('platform');
    
    if (!platform) {
      return NextResponse.json(
        { error: 'Platform parameter required' },
        { status: 400 }
      );
    }

    // Get from Firestore
    const userDoc = await db.collection(collections.users).doc(userId).get();
    
    if (!userDoc.exists) {
      return NextResponse.json(
        { error: 'User not found' },
        { status: 404 }
      );
    }

    const userData = userDoc.data();
    const accountData = userData?.accounts?.[platform];

    if (!accountData) {
      return NextResponse.json(
        { error: `No ${platform} account data found` },
        { status: 404 }
      );
    }

    return NextResponse.json({
      success: true,
      platform,
      data: accountData
    });

  } catch (error) {
    console.error('[API] Error retrieving profile data:', error);
    
    return NextResponse.json(
      { error: 'Failed to retrieve profile data' },
      { status: 500 }
    );
  }
}
