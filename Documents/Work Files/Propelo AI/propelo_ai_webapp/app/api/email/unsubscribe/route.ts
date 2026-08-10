import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/firebase-admin';
import { createHmac } from 'crypto';

// Get the secret for signing tokens
function getUnsubscribeSecret(): string {
  const secret = process.env.UNSUBSCRIBE_SECRET || process.env.CSRF_SECRET || process.env.NEXTAUTH_SECRET;
  if (!secret && process.env.NODE_ENV === 'production') {
    throw new Error('UNSUBSCRIBE_SECRET, CSRF_SECRET, or NEXTAUTH_SECRET must be set in production');
  }
  return secret || 'dev-unsubscribe-secret';
}

/**
 * Generate a secure unsubscribe token
 * Uses HMAC-SHA256 for security
 */
export function generateUnsubscribeToken(email: string): string {
  const secret = getUnsubscribeSecret();
  const hmac = createHmac('sha256', secret);
  hmac.update(email.toLowerCase());
  return hmac.digest('hex');
}

/**
 * Verify an unsubscribe token
 */
function verifyUnsubscribeToken(email: string, token: string): boolean {
  const expectedToken = generateUnsubscribeToken(email);
  // Constant-time comparison to prevent timing attacks
  if (token.length !== expectedToken.length) return false;
  let result = 0;
  for (let i = 0; i < token.length; i++) {
    result |= token.charCodeAt(i) ^ expectedToken.charCodeAt(i);
  }
  return result === 0;
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const token = searchParams.get('token');
    const email = searchParams.get('email');

    if (!token || !email) {
      return NextResponse.redirect(
        new URL('/unsubscribe-error?reason=invalid', request.url)
      );
    }

    // Verify HMAC-signed token
    if (!verifyUnsubscribeToken(email, token)) {
      return NextResponse.redirect(
        new URL('/unsubscribe-error?reason=invalid-token', request.url)
      );
    }

    // Find user by email and update preferences
    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      return NextResponse.redirect(
        new URL('/unsubscribe-error?reason=not-found', request.url)
      );
    }

    const userDoc = usersSnapshot.docs[0];
    await userDoc.ref.update({
      emailNotifications: false,
      unsubscribedAt: new Date(),
    });

    // Redirect to success page
    return NextResponse.redirect(
      new URL('/unsubscribe-success', request.url)
    );
  } catch (error) {
    console.error('Unsubscribe error:', error);
    return NextResponse.redirect(
      new URL('/unsubscribe-error?reason=server-error', request.url)
    );
  }
}

// POST endpoint for API-based unsubscribe
export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json();

    if (!email) {
      return NextResponse.json(
        { error: 'Email is required' },
        { status: 400 }
      );
    }

    const usersSnapshot = await db
      .collection('users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      // Don't reveal if email exists or not
      return NextResponse.json({ success: true });
    }

    const userDoc = usersSnapshot.docs[0];
    await userDoc.ref.update({
      emailNotifications: false,
      unsubscribedAt: new Date(),
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Unsubscribe API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
