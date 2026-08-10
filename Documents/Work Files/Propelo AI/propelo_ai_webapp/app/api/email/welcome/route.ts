import { NextRequest, NextResponse } from 'next/server';
import { sendEmail } from '@/lib/email';
import { getWelcomeEmailTemplate } from '@/lib/email/templates';
import { auth } from '@/lib/firebase-admin';
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders, getClientIdentifier } from '@/lib/rate-limit';

/**
 * POST /api/email/welcome
 * Sends welcome email - requires authentication to prevent abuse
 */
export async function POST(request: NextRequest) {
  try {
    // Check for internal API key (for server-to-server calls)
    const internalKey = request.headers.get('x-internal-api-key');
    const isInternalCall = internalKey === process.env.INTERNAL_API_KEY;

    // If not internal, require Firebase auth
    let userId: string | undefined;
    
    if (!isInternalCall) {
      const authHeader = request.headers.get('authorization');
      if (!authHeader?.startsWith('Bearer ')) {
        return NextResponse.json(
          { error: 'Authentication required' },
          { status: 401 }
        );
      }

      try {
        const token = authHeader.split('Bearer ')[1];
        const decodedToken = await auth.verifyIdToken(token);
        userId = decodedToken.uid;
      } catch (error) {
        return NextResponse.json(
          { error: 'Invalid or expired token' },
          { status: 401 }
        );
      }
    }

    // Rate limiting
    const clientId = getClientIdentifier(request, userId);
    const rateLimitResult = await checkRateLimit(clientId, RATE_LIMITS.email, "email-welcome");
    
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: 'Too many requests. Please try again later.' },
        { 
          status: 429,
          headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.email)
        }
      );
    }

    const body = await request.json();
    const { email, name } = body;

    if (!email || !name) {
      return NextResponse.json(
        { error: 'Email and name are required' },
        { status: 400 }
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return NextResponse.json(
        { error: 'Invalid email format' },
        { status: 400 }
      );
    }

    const result = await sendEmail({
      to: email,
      subject: 'Welcome to Propelo! 🎉',
      html: getWelcomeEmailTemplate(name),
    });

    if (!result.success) {
      console.error('Failed to send welcome email:', result.error);
      return NextResponse.json(
        { error: 'Failed to send email' },
        { status: 500 }
      );
    }

    return NextResponse.json({ 
      success: true, 
      messageId: result.messageId 
    });
  } catch (error) {
    console.error('Welcome email API error:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
