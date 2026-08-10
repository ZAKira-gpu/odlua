import { NextRequest, NextResponse } from "next/server";
import { auth } from "@/lib/firebase-admin";
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders, getClientIdentifier } from "@/lib/rate-limit";

/**
 * POST /api/auth/session
 * Sets an HttpOnly session cookie after verifying the Firebase ID token
 * This is more secure than setting cookies client-side
 */
export async function POST(request: NextRequest) {
  try {
    // Rate limit by IP since user might not be identified yet
    const clientId = getClientIdentifier(request);
    const rateLimitResult = await checkRateLimit(clientId, RATE_LIMITS.auth, "auth-session");
    
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: "Too many requests. Please try again later." },
        { 
          status: 429,
          headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.auth)
        }
      );
    }

    const body = await request.json();
    const { idToken } = body;

    if (!idToken || typeof idToken !== "string") {
      return NextResponse.json(
        { error: "Missing or invalid ID token" },
        { status: 400 }
      );
    }

    // Verify the ID token with Firebase Admin
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(idToken);
    } catch (error) {
      console.error("[Session] Token verification failed:", error);
      return NextResponse.json(
        { error: "Invalid or expired token" },
        { status: 401 }
      );
    }

    // Create session cookie (7 days expiry)
    const expiresIn = 60 * 60 * 24 * 7; // 7 days in seconds
    const expiresAt = new Date(Date.now() + expiresIn * 1000);

    // Create response with HttpOnly cookie
    const response = NextResponse.json({
      success: true,
      userId: decodedToken.uid,
      email: decodedToken.email,
      expiresAt: expiresAt.toISOString(),
    });

    // Set HttpOnly, Secure cookie
    const isProduction = process.env.NODE_ENV === "production";
    
    response.cookies.set("session", idToken, {
      httpOnly: true,
      secure: isProduction,
      sameSite: "strict",
      path: "/",
      maxAge: expiresIn,
    });

    return response;
  } catch (error) {
    console.error("[Session] Error setting session:", error);
    return NextResponse.json(
      { error: "Failed to create session" },
      { status: 500 }
    );
  }
}

/**
 * DELETE /api/auth/session
 * Clears the session cookie (logout)
 */
export async function DELETE(request: NextRequest) {
  const response = NextResponse.json({ success: true });
  
  // Clear the session cookie
  response.cookies.set("session", "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "strict",
    path: "/",
    maxAge: 0, // Expire immediately
  });

  return response;
}

/**
 * GET /api/auth/session
 * Validates the current session and returns user info
 */
export async function GET(request: NextRequest) {
  try {
    const sessionCookie = request.cookies.get("session")?.value;

    if (!sessionCookie) {
      return NextResponse.json(
        { authenticated: false },
        { status: 401 }
      );
    }

    // Verify the session token
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(sessionCookie);
    } catch (error) {
      // Token is invalid or expired
      const response = NextResponse.json(
        { authenticated: false, error: "Session expired" },
        { status: 401 }
      );
      
      // Clear invalid cookie
      response.cookies.set("session", "", {
        httpOnly: true,
        secure: process.env.NODE_ENV === "production",
        sameSite: "strict",
        path: "/",
        maxAge: 0,
      });
      
      return response;
    }

    return NextResponse.json({
      authenticated: true,
      userId: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified,
    });
  } catch (error) {
    console.error("[Session] Error validating session:", error);
    return NextResponse.json(
      { authenticated: false, error: "Session validation failed" },
      { status: 500 }
    );
  }
}
