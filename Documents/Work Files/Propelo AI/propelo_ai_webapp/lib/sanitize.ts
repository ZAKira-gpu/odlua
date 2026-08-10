/**
 * Input Sanitization Utilities
 * Protects against XSS, SQL injection, and other input-based attacks
 */

// Characters that could be used in XSS attacks
const XSS_PATTERNS = [
  /<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi,
  /<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi,
  /javascript:/gi,
  /on\w+\s*=/gi,
  /<\s*embed/gi,
  /<\s*object/gi,
  /<\s*link/gi,
  /<\s*meta/gi,
  /data:\s*text\/html/gi,
  /vbscript:/gi,
];

// SQL injection patterns
const SQL_PATTERNS = [
  /(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|FETCH|DECLARE|TRUNCATE)\b)/gi,
  /(--|;|\/\*|\*\/|@@|@)/g,
  /(\b(OR|AND)\b\s+\d+\s*=\s*\d+)/gi,
  /(\b(OR|AND)\b\s+'\w*'\s*=\s*'\w*')/gi,
];

/**
 * Sanitize a string by removing potentially dangerous content
 */
export function sanitizeString(input: string): string {
  if (typeof input !== "string") {
    return "";
  }
  
  let sanitized = input;
  
  // Remove XSS patterns
  for (const pattern of XSS_PATTERNS) {
    sanitized = sanitized.replace(pattern, "");
  }
  
  // HTML encode special characters
  sanitized = sanitized
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#x27;");
  
  return sanitized.trim();
}

/**
 * Sanitize input for display (allows some HTML but removes dangerous elements)
 */
export function sanitizeForDisplay(input: string): string {
  if (typeof input !== "string") {
    return "";
  }
  
  let sanitized = input;
  
  // Remove script and iframe tags
  for (const pattern of XSS_PATTERNS) {
    sanitized = sanitized.replace(pattern, "");
  }
  
  return sanitized.trim();
}

/**
 * Check if string contains SQL injection attempts
 */
export function containsSqlInjection(input: string): boolean {
  if (typeof input !== "string") {
    return false;
  }
  
  for (const pattern of SQL_PATTERNS) {
    if (pattern.test(input)) {
      return true;
    }
  }
  
  return false;
}

/**
 * Validate and sanitize email address
 */
export function sanitizeEmail(email: string): string | null {
  if (typeof email !== "string") {
    return null;
  }
  
  const trimmed = email.toLowerCase().trim();
  const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
  
  if (!emailRegex.test(trimmed)) {
    return null;
  }
  
  // Additional check for dangerous characters
  if (trimmed.includes("<") || trimmed.includes(">") || trimmed.includes("'")) {
    return null;
  }
  
  return trimmed;
}

/**
 * Sanitize URL
 */
export function sanitizeUrl(url: string): string | null {
  if (typeof url !== "string") {
    return null;
  }
  
  const trimmed = url.trim();
  
  // Only allow http and https protocols
  if (!trimmed.startsWith("http://") && !trimmed.startsWith("https://")) {
    return null;
  }
  
  // Check for javascript: or data: in URL
  if (/javascript:|data:|vbscript:/i.test(trimmed)) {
    return null;
  }
  
  try {
    const parsed = new URL(trimmed);
    return parsed.toString();
  } catch {
    return null;
  }
}

/**
 * Sanitize an object's string values recursively
 */
export function sanitizeObject<T extends Record<string, unknown>>(obj: T): T {
  const sanitized: Record<string, unknown> = {};
  
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === "string") {
      sanitized[key] = sanitizeString(value);
    } else if (Array.isArray(value)) {
      sanitized[key] = value.map((item) =>
        typeof item === "string" ? sanitizeString(item) : item
      );
    } else if (value !== null && typeof value === "object") {
      sanitized[key] = sanitizeObject(value as Record<string, unknown>);
    } else {
      sanitized[key] = value;
    }
  }
  
  return sanitized as T;
}

/**
 * Validate that a string only contains allowed characters
 */
export function isAlphanumeric(input: string, allowedChars: string = ""): boolean {
  if (typeof input !== "string") {
    return false;
  }
  
  const pattern = new RegExp(`^[a-zA-Z0-9${allowedChars.replace(/[-[\]{}()*+?.,\\^$|#\s]/g, "\\$&")}]+$`);
  return pattern.test(input);
}

/**
 * Truncate string to max length
 */
export function truncateString(input: string, maxLength: number): string {
  if (typeof input !== "string") {
    return "";
  }
  
  if (input.length <= maxLength) {
    return input;
  }
  
  return input.substring(0, maxLength);
}

/**
 * Sanitize proposal/job description input
 * Less strict than general sanitization to allow legitimate content
 */
export function sanitizeProposalInput(input: string, maxLength: number = 10000): string {
  if (typeof input !== "string") {
    return "";
  }
  
  // Remove script tags and event handlers but keep most content
  let sanitized = input
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, "")
    .replace(/on\w+\s*=/gi, "")
    .replace(/javascript:/gi, "");
  
  // Truncate to max length
  return truncateString(sanitized, maxLength);
}
