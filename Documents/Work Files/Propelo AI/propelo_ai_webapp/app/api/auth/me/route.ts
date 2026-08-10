import { NextResponse } from 'next/server';
import { db, auth } from '@/lib/firebase-admin';

export async function GET(request: Request) {
  try {
    // Get token from Authorization header
    const authHeader = request.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
    
    const token = authHeader.substring(7);
    
    // Verify the token
    const decodedToken = await auth.verifyIdToken(token);
    const uid = decodedToken.uid;
    
    // Get user data from Firestore
    const userDoc = await db.collection('users').doc(uid).get();
    
    if (!userDoc.exists) {
      return NextResponse.json({ error: 'User not found' }, { status: 404 });
    }
    
    const userData = userDoc.data();
    
    // Return user data for the extension
    return NextResponse.json({
      uid,
      email: userData?.email || decodedToken.email,
      firstName: userData?.firstName || '',
      lastName: userData?.lastName || '',
      profileImage: userData?.profileImage || '',
      plan: userData?.subscription?.plan || 'free',
      proposalsUsed: userData?.proposalsUsed || 0,
      proposalsLimit: userData?.proposalsLimit || (userData?.subscription?.plan === 'pro' ? 100 : 10),
    });
  } catch (error) {
    console.error('Auth me error:', error);
    return NextResponse.json({ error: 'Invalid token' }, { status: 401 });
  }
}
