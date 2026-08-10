import { NextRequest } from "next/server";
import { randomBytes, createHmac, timingSafeEqual } from "crypto";

// CSRF token secret - MUST be configured in production
function getCsrfSecret(): string {
  const secret = process.env.CSRF_SECRET || process.env.NEXTAUTH_SECRET;
  
  if (!secret) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(
        "CRITICAL: CSRF_SECRET or NEXTAUTH_SECRET must be configured in production. " +
        "Generate one with: openssl rand -hex 32"
      );
    }
    // Allow fallback in development only
    console.warn("[CSRF] ⚠️ Using default secret - NOT safe for production");
    return "dev-csrf-secret-not-for-production";
  }
  
  // Warn if secret is too short
  if (secret.length < 32) {
    console.warn("[CSRF] ⚠️ CSRF_SECRET is less than 32 characters - consider using a longer secret");
  }
  
  return secret;
}

const CSRF_TOKEN_EXPIRY = 60 * 60 * 1000; // 1 hour in milliseconds

/**
 * Generate a CSRF token with embedded timestamp
 */
export function generateCsrfToken(): string {
  const secret = getCsrfSecret();
  const timestamp = Date.now().toString();
  const randomPart = randomBytes(16).toString("hex");
  const data = `${timestamp}:${randomPart}`;
  
  const hmac = createHmac("sha256", secret);
  hmac.update(data);
  const signature = hmac.digest("hex");
  
  // Return base64-encoded token with data and signature
  const token = Buffer.from(`${data}:${signature}`).toString("base64");
  return token;
}

/**
 * Validate a CSRF token using constant-time comparison
 */
export function validateCsrfToken(token: string): boolean {
  try {
    const secret = getCsrfSecret();
    const decoded = Buffer.from(token, "base64").toString("utf-8");
    const parts = decoded.split(":");
    
    if (parts.length !== 3) {
      return false;
    }
    
    const [timestamp, randomPart, signature] = parts;
    const data = `${timestamp}:${randomPart}`;
    
    // Verify signature with timing-safe comparison
    const hmac = createHmac("sha256", secret);
    hmac.update(data);
    const expectedSignature = hmac.digest("hex");
    
    // Use timing-safe comparison to prevent timing attacks
    const signatureBuffer = Buffer.from(signature, "hex");
    const expectedBuffer = Buffer.from(expectedSignature, "hex");
    
    if (signatureBuffer.length !== expectedBuffer.length) {
      return false;
    }
    
    if (!timingSafeEqual(signatureBuffer, expectedBuffer)) {
      return false;
    }
    
    // Check expiry
    const tokenTime = parseInt(timestamp, 10);
    if (isNaN(tokenTime) || Date.now() - tokenTime > CSRF_TOKEN_EXPIRY) {
      return false;
    }
    
    return true;
  } catch {
    return false;
  }
}

/**
 * Extract and validate CSRF token from request
 */
export function verifyCsrfFromRequest(request: NextRequest): boolean {
  // Check header first (preferred for API calls)
  const headerToken = request.headers.get("x-csrf-token");
  if (headerToken && validateCsrfToken(headerToken)) {
    return true;
  }
  
  // Check cookie as fallback
  const cookieToken = request.cookies.get("csrf-token")?.value;
  if (cookieToken && validateCsrfToken(cookieToken)) {
    return true;
  }
  
  return false;
}

/**
 * Check if request origin is allowed
 */
export function validateOrigin(request: NextRequest): boolean {
  const origin = request.headers.get("origin");
  const referer = request.headers.get("referer");
  
  const allowedOrigins = [
    process.env.NEXT_PUBLIC_APP_URL || "https://app.propeloai.com",
    "https://propeloai.com",
    "https://www.propeloai.com",
  ];
  
  // In development, allow localhost
  if (process.env.NODE_ENV === "development") {
    allowedOrigins.push("http://localhost:3000");
  }
  
  // Check origin header
  if (origin && allowedOrigins.includes(origin)) {
    return true;
  }
  
  // Check referer as fallback
  if (referer) {
    try {
      const refererUrl = new URL(referer);
      if (allowedOrigins.includes(refererUrl.origin)) {
        return true;
      }
    } catch {
      return false;
    }
  }
  
  // For same-origin requests without Origin header (like GET requests)
  // We allow them but mutation APIs should check more strictly
  return false;
}
