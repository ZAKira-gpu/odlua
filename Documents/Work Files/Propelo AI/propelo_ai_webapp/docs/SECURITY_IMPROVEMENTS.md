# Security Improvements - Propelo AI

## Summary

This document outlines all security hardening measures implemented for Propelo AI.

---

## 1. Frontend Data Protection

### Firebase Configuration
- **Before**: Firebase config was hardcoded directly in `lib/firebase.ts`
- **After**: Moved to environment variables (`NEXT_PUBLIC_FIREBASE_*`)
- **Why**: Prevents accidental exposure in source code, allows different configs per environment

### LemonSqueezy Variant IDs
- **Before**: Exposed as `NEXT_PUBLIC_LEMONSQUEEZY_*` in frontend
- **After**: Moved to backend-only env vars (`LEMONSQUEEZY_*`)
- **Implementation**: Created `/api/billing/plans` endpoint to serve plan data securely
- **Why**: Reduces attack surface by keeping billing config server-side

---

## 2. Security Headers (Middleware)

Added comprehensive security headers to all responses:

```
X-Frame-Options: DENY                    # Prevents clickjacking
X-Content-Type-Options: nosniff          # Prevents MIME sniffing
X-XSS-Protection: 1; mode=block          # XSS protection for older browsers
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
Content-Security-Policy: [comprehensive policy]
Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
```

**CSP Policy Includes:**
- Restricted script sources
- Limited connection sources
- Frame ancestor restrictions
- Form action restrictions
- Upgrade insecure requests

---

## 3. CSRF Protection (`lib/csrf.ts`)

New CSRF protection module with:
- `generateCsrfToken()` - Creates signed, time-limited tokens
- `validateCsrfToken()` - Validates token signature and expiry
- `verifyCsrfFromRequest()` - Extracts and validates tokens from requests
- `validateOrigin()` - Validates request origin/referer

**Token Features:**
- HMAC-SHA256 signed
- 1-hour expiry
- Base64 encoded

---

## 4. Input Sanitization (`lib/sanitize.ts`)

Comprehensive input sanitization utilities:

| Function | Purpose |
|----------|---------|
| `sanitizeString()` | Removes XSS patterns, HTML encodes |
| `sanitizeForDisplay()` | Removes dangerous tags, allows some HTML |
| `containsSqlInjection()` | Detects SQL injection patterns |
| `sanitizeEmail()` | Validates and sanitizes email format |
| `sanitizeUrl()` | Validates URL protocols, removes dangerous schemes |
| `sanitizeObject()` | Recursively sanitizes object string values |
| `sanitizeProposalInput()` | Proposal-specific sanitization |

**Protected Against:**
- XSS (script injection, event handlers, javascript: URLs)
- SQL injection patterns
- Data URL exploits
- Malformed input

---

## 5. Rate Limiting (`lib/rate-limit.ts`)

In-memory rate limiting with configurable limits:

| Endpoint | Limit |
|----------|-------|
| Proposal Generation | 10 requests/minute |
| Proposal Enhancement | 20 requests/minute |
| Billing Operations | 5 requests/minute |

**Features:**
- Per-user rate limiting
- Automatic cleanup of expired entries
- Standard rate limit headers in responses
- Graceful degradation

---

## 6. Origin Validation

All mutation API endpoints validate request origin:

```typescript
const ALLOWED_ORIGINS = [
  "https://app.propeloai.com",
  "https://propeloai.com",
  "https://www.propeloai.com",
];
```

**Protected Routes:**
- `/api/proposals/generate`
- `/api/proposals/generate-stream`
- `/api/proposals/enhance`
- `/api/billing/checkout`
- `/api/billing/cancel`

---

## 7. Secure Cookie Settings

Session cookies now use:
- `SameSite=Strict` - Prevents CSRF via cookies
- `Secure` flag - HTTPS only in production
- 7-day max age
- Path restricted to `/`

---

## 8. API Route Security

All API routes now include:
- ✅ Authentication verification (Firebase ID tokens)
- ✅ Rate limiting
- ✅ Origin validation
- ✅ Input sanitization
- ✅ Proper error handling without sensitive data exposure

---

## Files Modified

| File | Changes |
|------|---------|
| `lib/firebase.ts` | Firebase config from env vars |
| `middleware.ts` | Security headers |
| `lib/csrf.ts` | New CSRF module |
| `lib/sanitize.ts` | New sanitization module |
| `lib/rate-limit.ts` | Rate limiting (existing) |
| `lib/auth-context.tsx` | Secure cookie settings |
| `app/api/billing/plans/route.ts` | New secure plans endpoint |
| `app/api/proposals/generate/route.ts` | Origin validation, sanitization |
| `app/api/proposals/generate-stream/route.ts` | Origin validation, sanitization |
| `app/api/proposals/enhance/route.ts` | Origin validation, sanitization |
| `app/api/billing/checkout/route.ts` | Origin validation, rate limiting |
| `app/api/billing/cancel/route.ts` | Origin validation, rate limiting |
| `app/dashboard/subscription/page.tsx` | Fetch plans from API |
| `.env.local` | Reorganized env vars |

---

## Environment Variables

### Required (Server-Side Only)
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`
- `OPENAI_API_KEY`
- `LEMONSQUEEZY_API_KEY`
- `LEMONSQUEEZY_STORE_ID`
- `LEMONSQUEEZY_WEBHOOK_SECRET`
- `LEMONSQUEEZY_STARTER_VARIANT_ID`
- `LEMONSQUEEZY_PRO_VARIANT_ID`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET`
- `NEXTAUTH_SECRET`

### Public (Client-Side)
- `NEXT_PUBLIC_APP_URL`
- `NEXT_PUBLIC_APP_NAME`
- `NEXT_PUBLIC_FIREBASE_API_KEY`
- `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`
- `NEXT_PUBLIC_FIREBASE_PROJECT_ID`
- `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`
- `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`
- `NEXT_PUBLIC_FIREBASE_APP_ID`
- `NEXT_PUBLIC_FIREBASE_MEASUREMENT_ID`
- `NEXT_PUBLIC_ENABLE_GOOGLE_AUTH`
- `NEXT_PUBLIC_ENABLE_PAYMENTS`
- `NEXT_PUBLIC_LEMONSQUEEZY_CHECKOUT_URL`

---

## Testing Recommendations

1. **Security Headers**: Use https://securityheaders.com to verify
2. **CSP**: Test all features work correctly with CSP enabled
3. **Rate Limiting**: Test that limits are enforced correctly
4. **Origin Validation**: Test API calls from unauthorized origins are blocked
5. **Input Sanitization**: Test with various XSS and injection payloads

---

## Production Checklist

- [ ] Update `NEXTAUTH_SECRET` to a strong random value
- [ ] Verify all Firebase security rules are production-ready
- [ ] Enable HTTPS only in production
- [ ] Set up proper monitoring for rate limit violations
- [ ] Configure error reporting (Sentry or similar)
- [ ] Review and test all API endpoints
- [ ] Verify webhook signature validation works correctly
