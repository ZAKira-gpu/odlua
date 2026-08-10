import { NextRequest, NextResponse } from 'next/server';
import { auth, db } from '@/lib/firebase-admin';

export async function POST(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    
    // Verify Firebase token
    const decodedToken = await auth.verifyIdToken(token);
    const userId = decodedToken.uid;

    const { platform, profileData } = await request.json();

    if (!platform || !profileData) {
      return NextResponse.json(
        { error: 'Missing platform or profileData' },
        { status: 400 }
      );
    }

    // Store profile data in Firestore
    const profileRef = db
      .collection('users')
      .doc(userId)
      .collection('connectedAccounts')
      .doc(platform);

    await profileRef.set({
      platform,
      profileData,
      lastSynced: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    }, { merge: true });

    // Also update user's main document
    await db.collection('users').doc(userId).set({
      connectedAccounts: {
        [platform]: {
          connected: true,
          lastSynced: new Date().toISOString(),
          displayName: profileData.displayName,
          profileUrl: profileData.profileUrl
        }
      },
      updatedAt: new Date().toISOString()
    }, { merge: true });



    return NextResponse.json({
      success: true,
      message: `${platform} profile synced successfully`,
      data: {
        platform,
        lastSynced: new Date().toISOString()
      }
    });

  } catch (error) {
    console.error('[Account Connect] Error:', error);
    
    return NextResponse.json(
      { 
        error: 'Failed to sync profile',
        details: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}

export async function GET(request: NextRequest) {
  try {
    const authHeader = request.headers.get('authorization');
    
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const token = authHeader.substring(7);
    const decodedToken = await auth.verifyIdToken(token);
    const userId = decodedToken.uid;

    // Get all connected accounts
    const accountsSnapshot = await db
      .collection('users')
      .doc(userId)
      .collection('connectedAccounts')
      .get();

    const accounts: any = {};
    
    accountsSnapshot.forEach(doc => {
      accounts[doc.id] = doc.data();
    });

    return NextResponse.json({
      success: true,
      accounts
    });

  } catch (error) {
    console.error('[Account Connect] Error fetching accounts:', error);
    
    return NextResponse.json(
      { 
        error: 'Failed to fetch accounts',
        details: error instanceof Error ? error.message : 'Unknown error'
      },
      { status: 500 }
    );
  }
}
