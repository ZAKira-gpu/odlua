import { NextRequest, NextResponse } from "next/server";
import { db, auth, collections } from "@/lib/firebase-admin";

/**
 * Canonical Upwork Profile API
 * 
 * GET /api/account/upwork
 * 
 * Returns the CURRENT state of the user's Upwork profile from Firestore.
 * This is the SINGLE SOURCE OF TRUTH for the web app.
 * 
 * Response:
 * {
 *   connected: boolean,
 *   profile: UpworkProfile | null,
 *   lastSynced: string | null,
 *   syncStatus: 'success' | 'partial' | 'failed' | null
 * }
 */

// ============================================
// TYPE DEFINITIONS
// ============================================

interface UpworkProfileResponse {
  connected: boolean;
  profile: Record<string, any> | null;
  lastSynced: string | null;
  syncStatus: 'success' | 'partial' | 'failed' | null;
  error?: string;
}

// ============================================
// MAIN HANDLER
// ============================================

export async function GET(req: NextRequest): Promise<NextResponse<UpworkProfileResponse>> {
  const requestId = `get_upwork_${Date.now()}`;
  




  
  try {
    // ----------------------------------------
    // 1. AUTHENTICATE
    // ----------------------------------------
    const authHeader = req.headers.get('authorization');
    
    if (!authHeader?.startsWith('Bearer ')) {
      console.error(`[Upwork API] [${requestId}] Missing or invalid auth header`);
      return NextResponse.json({
        connected: false,
        profile: null,
        lastSynced: null,
        syncStatus: null,
        error: 'Authentication required'
      }, { status: 401 });
    }
    
    const token = authHeader.substring(7);
    
    let userId: string;
    try {
      const decodedToken = await auth.verifyIdToken(token);
      userId = decodedToken.uid;

    } catch (authError) {
      console.error(`[Upwork API] [${requestId}] Token verification failed:`, authError);
      return NextResponse.json({
        connected: false,
        profile: null,
        lastSynced: null,
        syncStatus: null,
        error: 'Invalid authentication token'
      }, { status: 401 });
    }
    
    // ----------------------------------------
    // 2. FETCH FROM FIRESTORE
    // ----------------------------------------
    const userRef = db.collection(collections.users).doc(userId);
    const userDoc = await userRef.get();
    
    if (!userDoc.exists) {

      return NextResponse.json({
        connected: false,
        profile: null,
        lastSynced: null,
        syncStatus: null
      });
    }
    
    const userData = userDoc.data();
    const upworkAccount = userData?.accounts?.upwork;
    
    // ----------------------------------------
    // 3. BUILD RESPONSE
    // ----------------------------------------
    if (!upworkAccount) {

      return NextResponse.json({
        connected: false,
        profile: null,
        lastSynced: null,
        syncStatus: null
      });
    }
    
    // Extract profile data - handle both nested and flat structures
    let profileData = upworkAccount.profileData || null;
    
    // If profileData is null but we have other fields, it might be flat structure
    if (!profileData && upworkAccount.displayName) {
      // Legacy flat structure - reconstruct
      const { platform, connected, userId: uid, lastSynced, syncStatus, syncVersion, syncErrors, ...rest } = upworkAccount;
      profileData = rest;
    }
    
    // Format lastSynced
    let lastSyncedStr: string | null = null;
    if (upworkAccount.lastSynced) {
      if (upworkAccount.lastSynced.toDate) {
        lastSyncedStr = upworkAccount.lastSynced.toDate().toISOString();
      } else if (typeof upworkAccount.lastSynced === 'string') {
        lastSyncedStr = upworkAccount.lastSynced;
      } else if (upworkAccount.lastSynced instanceof Date) {
        lastSyncedStr = upworkAccount.lastSynced.toISOString();
      }
    }
    
    const response: UpworkProfileResponse = {
      connected: upworkAccount.connected === true,
      profile: profileData,
      lastSynced: lastSyncedStr,
      syncStatus: upworkAccount.syncStatus || null
    };
    
    return NextResponse.json(response);
    
  } catch (error: any) {
    console.error(`[Upwork API] [${requestId}] Unexpected error:`, error);
    return NextResponse.json({
      connected: false,
      profile: null,
      lastSynced: null,
      syncStatus: null,
      error: 'Internal server error'
    }, { status: 500 });
  }
}
