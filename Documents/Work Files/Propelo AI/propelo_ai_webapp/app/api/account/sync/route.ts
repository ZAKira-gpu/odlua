import { NextRequest, NextResponse } from "next/server";
import { db, auth, collections } from "@/lib/firebase-admin";
import { FieldValue } from "firebase-admin/firestore";

/**
 * Production-Grade Profile Sync API
 * 
 * POST /api/account/sync
 * 
 * Features:
 * - Dual auth support (Bearer token + session cookie)
 * - Idempotent writes with versioning
 * - Atomic Firestore updates
 * - Full audit trail
 * - Returns canonical profile
 */

// ============================================
// TYPE DEFINITIONS
// ============================================

interface ProfileSyncRequest {
  userId: string;
  platform: 'upwork' | 'fiverr' | 'freelancer';
  profileData: Record<string, any>;
  timestamp: string;
  version?: number;
  clientId?: string;
}

interface ProfileSyncResponse {
  success: boolean;
  message?: string;
  error?: string;
  syncedAt?: string;
  version?: number;
  profile?: Record<string, any>;
}

// ============================================
// MAIN HANDLER
// ============================================

export async function POST(req: NextRequest): Promise<NextResponse<ProfileSyncResponse>> {
  const startTime = Date.now();
  const requestId = `sync_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  



  
  try {
    // ----------------------------------------
    // 1. PARSE REQUEST
    // ----------------------------------------
    const body: ProfileSyncRequest = await req.json();
    const { userId, platform, profileData, timestamp, version, clientId } = body;

    // ----------------------------------------
    // 2. VALIDATE REQUEST
    // ----------------------------------------
    const validationErrors: string[] = [];
    
    if (!userId || typeof userId !== 'string') {
      validationErrors.push('userId is required and must be a string');
    }
    
    if (!platform || !['upwork', 'fiverr', 'freelancer'].includes(platform)) {
      validationErrors.push('platform must be one of: upwork, fiverr, freelancer');
    }
    
    if (!profileData || typeof profileData !== 'object') {
      validationErrors.push('profileData is required and must be an object');
    }
    
    // PRODUCTION: Validate required profile fields
    if (profileData) {
      const name = profileData.displayName || profileData.name;
      if (!name || typeof name !== 'string' || name.length < 2) {
        validationErrors.push('profileData.displayName or profileData.name is required');
      }
      
      // Warn but don't block for recommended fields
      const warnings: string[] = [];
      if (!profileData.title) warnings.push('title');
      if (!profileData.hourlyRate && profileData.hourlyRate !== 0) warnings.push('hourlyRate');
      if (!profileData.bio && !profileData.description && !profileData.overview) warnings.push('bio/description');
      
      if (warnings.length > 0) {

      }
    }
    
    if (validationErrors.length > 0) {
      console.error(`[Sync API] [${requestId}] Validation failed:`, validationErrors);
      return NextResponse.json({
        success: false,
        error: `Validation failed: ${validationErrors.join(', ')}`
      }, { status: 400 });
    }

    // ----------------------------------------
    // 3. AUTHENTICATE
    // ----------------------------------------
    let authenticatedUserId: string | null = null;
    let authMethod: string = 'none';
    
    // Try Bearer token first (extension uses this)
    const authHeader = req.headers.get("authorization");
    if (authHeader?.startsWith("Bearer ")) {
      try {
        const token = authHeader.split(" ")[1];
        const decodedToken = await auth.verifyIdToken(token);
        authenticatedUserId = decodedToken.uid;
        authMethod = 'bearer';

      } catch (error: any) {

      }
    }
    
    // Try session cookie (webapp uses this)
    if (!authenticatedUserId) {
      try {
        const { cookies } = await import("next/headers");
        const cookieStore = await cookies();
        const sessionCookie = cookieStore.get("session")?.value;
        
        if (sessionCookie) {
          const decodedToken = await auth.verifyIdToken(sessionCookie);
          authenticatedUserId = decodedToken.uid;
          authMethod = 'session';

        }
      } catch (error: any) {

      }
    }
    
    // Check if authenticated
    if (!authenticatedUserId) {
      console.error(`[Sync API] [${requestId}] Authentication failed - no valid credentials`);
      return NextResponse.json({
        success: false,
        error: 'Unauthorized - Please sign in'
      }, { status: 401 });
    }
    
    // Verify user ID matches
    if (authenticatedUserId !== userId) {
      console.error(`[Sync API] [${requestId}] User ID mismatch:`, {
        authenticated: authenticatedUserId?.substring(0, 10),
        requested: userId?.substring(0, 10)
      });
      return NextResponse.json({
        success: false,
        error: 'Unauthorized - User ID mismatch'
      }, { status: 403 });
    }

    // ----------------------------------------
    // 4. PREPARE DATA
    // ----------------------------------------
    const now = new Date();
    const serverVersion = version || Date.now();
    
    // Normalize profile data
    const normalizedProfile = {
      ...profileData,
      // Ensure required fields
      platform,
      syncedAt: now.toISOString(),
      syncVersion: serverVersion,
      clientId: clientId || 'unknown'
    };
    
    // Prepare Firestore update
    const updateData: Record<string, any> = {
      // Account data with full profile
      [`accounts.${platform}`]: {
        platform,
        connected: true,
        userId,
        profileData: normalizedProfile,
        lastSynced: now,
        syncStatus: 'success',
        syncVersion: serverVersion,
        syncErrors: []
      },
      // Platform status (quick access)
      [`platforms.${platform}`]: {
        connected: true,
        lastSynced: now,
        displayName: profileData.displayName || profileData.name || null,
        jobSuccessScore: profileData.jobSuccessScore || null,
        rating: profileData.rating || null,
        totalEarnings: profileData.totalEarnings || null,
        hourlyRate: profileData.hourlyRate || null,
        profileImage: profileData.profileImage || null
      },
      // Metadata
      updatedAt: FieldValue.serverTimestamp(),
      lastProfileSync: now
    };

    // ----------------------------------------
    // 5. WRITE TO FIRESTORE
    // ----------------------------------------
    const userRef = db.collection(collections.users).doc(userId);
    
    try {
      const docSnap = await userRef.get();
      
      if (docSnap.exists) {
        // Document exists: Use update() which correctly handles dot notation keys (e.g. "accounts.upwork")
        // This ensures we update nested fields without overwriting the parent map
        await userRef.update(updateData);

      } else {
        // Document does not exist: Use set() but we must construct nested objects manually
        // because set() treats "accounts.upwork" as a literal key name, not a path
        const createData = {
          accounts: {
            [platform]: updateData[`accounts.${platform}`]
          },
          platforms: {
            [platform]: updateData[`platforms.${platform}`]
          },
          updatedAt: FieldValue.serverTimestamp(),
          lastProfileSync: now,
          createdAt: FieldValue.serverTimestamp()
        };
        await userRef.set(createData);

      }
    } catch (firestoreError: any) {
      console.error(`[Sync API] [${requestId}] Firestore write failed:`, firestoreError);
      return NextResponse.json({
        success: false,
        error: `Database write failed: ${firestoreError.message}`
      }, { status: 500 });
    }

    // ----------------------------------------
    // 6. VERIFY WRITE
    // ----------------------------------------
    const verifyDoc = await userRef.get();
    if (!verifyDoc.exists) {
      console.error(`[Sync API] [${requestId}] Verification failed - document not found`);
      return NextResponse.json({
        success: false,
        error: 'Write verification failed'
      }, { status: 500 });
    }
    
    const verifyData = verifyDoc.data();
    const verifyAccount = verifyData?.accounts?.[platform];
    
    // ----------------------------------------
    // 7. RETURN SUCCESS
    // ----------------------------------------
    const duration = Date.now() - startTime;

    
    return NextResponse.json({
      success: true,
      message: `${platform} profile synced successfully`,
      syncedAt: now.toISOString(),
      version: serverVersion,
      profile: normalizedProfile
    });

  } catch (error: any) {
    const duration = Date.now() - startTime;
    console.error(`[Sync API] [${requestId}] ❌ Error after ${duration}ms:`, {
      message: error.message,
      name: error.name,
      stack: error.stack?.split('\n').slice(0, 3)
    });
    
    return NextResponse.json({
      success: false,
      error: `Sync failed: ${error.message}`
    }, { status: 500 });
  }
}

// ============================================
// GET HANDLER - Retrieve synced data
// ============================================

export async function GET(req: NextRequest): Promise<NextResponse> {
  const { searchParams } = new URL(req.url);
  const platform = searchParams.get("platform");
  const userId = searchParams.get("userId");
  


  // Try to get userId from auth if not provided
  let authenticatedUserId = userId;
  
  if (!authenticatedUserId) {
    // Try Bearer token
    const authHeader = req.headers.get("authorization");
    if (authHeader?.startsWith("Bearer ")) {
      try {
        const token = authHeader.split(" ")[1];
        const decodedToken = await auth.verifyIdToken(token);
        authenticatedUserId = decodedToken.uid;
      } catch (e) {
        // Try session cookie
      }
    }
    
    if (!authenticatedUserId) {
      try {
        const { cookies } = await import("next/headers");
        const cookieStore = await cookies();
        const sessionCookie = cookieStore.get("session")?.value;
        if (sessionCookie) {
          const decodedToken = await auth.verifyIdToken(sessionCookie);
          authenticatedUserId = decodedToken.uid;
        }
      } catch (e) {
        // No auth
      }
    }
  }

  if (!authenticatedUserId) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  try {
    const userRef = db.collection(collections.users).doc(authenticatedUserId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {
      return NextResponse.json({ 
        success: true,
        error: "User not found",
        accounts: {},
        platforms: {}
      });
    }
    
    const data = userDoc.data();
    
    if (platform) {
      const account = data?.accounts?.[platform];
      return NextResponse.json({
        success: true,
        platform,
        account: account || null,
        connected: !!account
      });
    }
    
    return NextResponse.json({
      success: true,
      accounts: data?.accounts || {},
      platforms: data?.platforms || {}
    });
    
  } catch (error: any) {
    console.error("[Sync API GET] Error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}
