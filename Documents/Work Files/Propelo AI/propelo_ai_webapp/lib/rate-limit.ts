/**
 * Production-ready rate limiter with Upstash Redis
 * Falls back to in-memory store if Redis is unavailable
 */

import { Ratelimit } from "@upstash/ratelimit";
import { Redis } from "@upstash/redis";
import { NextRequest, NextResponse } from "next/server";

// ============================================
// Types
// ============================================

export interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
}

export interface RateLimitResult {
  success: boolean;
  remaining: number;
  resetIn: number;
}

// ============================================
// In-Memory Fallback (for when Redis unavailable)
// ============================================

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

const memoryStore = new Map<string, RateLimitEntry>();

// Clean up expired entries every 5 minutes
if (typeof setInterval !== "undefined") {
  setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of memoryStore.entries()) {
      if (entry.resetTime < now) {
        memoryStore.delete(key);
      }
    }
  }, 5 * 60 * 1000);
}

function checkMemoryRateLimit(
  identifier: string,
  config: RateLimitConfig
): RateLimitResult {
  const now = Date.now();
  const entry = memoryStore.get(identifier);

  if (!entry || entry.resetTime < now) {
    memoryStore.set(identifier, {
      count: 1,
      resetTime: now + config.windowMs,
    });
    return {
      success: true,
      remaining: config.maxRequests - 1,
      resetIn: Math.ceil(config.windowMs / 1000),
    };
  }

  entry.count++;

  if (entry.count > config.maxRequests) {
    return {
      success: false,
      remaining: 0,
      resetIn: Math.ceil((entry.resetTime - now) / 1000),
    };
  }

  return {
    success: true,
    remaining: config.maxRequests - entry.count,
    resetIn: Math.ceil((entry.resetTime - now) / 1000),
  };
}

// ============================================
// Upstash Redis Rate Limiter
// ============================================

let redis: Redis | null = null;
let isRedisAvailable = false;
let redisCheckDone = false;

// Initialize Redis connection
function initRedis(): Redis | null {
  if (redisCheckDone) return redis;

  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;

  if (url && token) {
    try {
      redis = new Redis({ url, token });
      isRedisAvailable = true;
      console.log("[Rate Limit] ✅ Upstash Redis connected");
    } catch (error) {
      console.warn("[Rate Limit] ⚠️ Failed to connect to Redis, using memory fallback:", error);
      isRedisAvailable = false;
    }
  } else {
    if (process.env.NODE_ENV === "production") {
      console.warn("[Rate Limit] ⚠️ Redis not configured in production - rate limiting will be per-instance only");
    }
    isRedisAvailable = false;
  }

  redisCheckDone = true;
  return redis;
}

// Cache for Ratelimit instances
const rateLimiters = new Map<string, Ratelimit>();

function getUpstashRateLimiter(name: string, config: RateLimitConfig): Ratelimit | null {
  const redisClient = initRedis();
  if (!redisClient || !isRedisAvailable) return null;

  const key = `${name}-${config.maxRequests}-${config.windowMs}`;
  
  if (!rateLimiters.has(key)) {
    const windowSeconds = Math.ceil(config.windowMs / 1000);
    rateLimiters.set(
      key,
      new Ratelimit({
        redis: redisClient,
        limiter: Ratelimit.slidingWindow(config.maxRequests, `${windowSeconds} s`),
        analytics: true,
        prefix: `propelo:ratelimit:${name}`,
      })
    );
  }

  return rateLimiters.get(key)!;
}

// ============================================
// Main Rate Limit Function
// ============================================

/**
 * Check if a request is rate limited
 * Uses Upstash Redis in production, falls back to in-memory if unavailable
 */
export async function checkRateLimit(
  identifier: string,
  config: RateLimitConfig,
  name: string = "default"
): Promise<RateLimitResult> {
  // Try Upstash first
  const limiter = getUpstashRateLimiter(name, config);

  if (limiter) {
    try {
      const result = await limiter.limit(identifier);
      return {
        success: result.success,
        remaining: result.remaining,
        resetIn: Math.ceil((result.reset - Date.now()) / 1000),
      };
    } catch (error) {
      console.error("[Rate Limit] Redis error, falling back to memory:", error);
      // Fall through to memory fallback
    }
  }

  // Memory fallback
  return checkMemoryRateLimit(`${name}:${identifier}`, config);
}

/**
 * Synchronous rate limit check (memory only)
 * Use when async is not possible
 */
export function checkRateLimitSync(
  identifier: string,
  config: RateLimitConfig,
  name: string = "default"
): RateLimitResult {
  return checkMemoryRateLimit(`${name}:${identifier}`, config);
}

// ============================================
// Pre-configured Rate Limits
// ============================================

export const RATE_LIMITS = {
  // Proposal generation: 10 requests per minute (expensive OpenAI calls)
  proposalGenerate: {
    maxRequests: 10,
    windowMs: 60 * 1000,
  },
  // Proposal enhancement: 20 requests per minute
  proposalEnhance: {
    maxRequests: 20,
    windowMs: 60 * 1000,
  },
  // Billing: 5 requests per minute
  billing: {
    maxRequests: 5,
    windowMs: 60 * 1000,
  },
  // Auth: 10 requests per minute
  auth: {
    maxRequests: 10,
    windowMs: 60 * 1000,
  },
  // Email: 5 requests per minute (prevent spam)
  email: {
    maxRequests: 5,
    windowMs: 60 * 1000,
  },
  // Analytics: 30 requests per minute
  analytics: {
    maxRequests: 30,
    windowMs: 60 * 1000,
  },
  // General API: 60 requests per minute
  general: {
    maxRequests: 60,
    windowMs: 60 * 1000,
  },
} as const;

// ============================================
// Response Headers Helper
// ============================================

export function getRateLimitHeaders(result: RateLimitResult, config: RateLimitConfig) {
  return {
    "X-RateLimit-Limit": config.maxRequests.toString(),
    "X-RateLimit-Remaining": result.remaining.toString(),
    "X-RateLimit-Reset": result.resetIn.toString(),
  };
}

// ============================================
// Middleware Helper
// ============================================

/**
 * Rate limit middleware helper
 * Returns null if allowed, or a 429 response if rate limited
 */
export async function rateLimitMiddleware(
  request: NextRequest,
  identifier: string,
  config: RateLimitConfig,
  name: string = "default"
): Promise<NextResponse | null> {
  const result = await checkRateLimit(identifier, config, name);

  if (!result.success) {
    return NextResponse.json(
      {
        error: "Too many requests",
        message: `Rate limit exceeded. Please try again in ${result.resetIn} seconds.`,
        retryAfter: result.resetIn,
      },
      {
        status: 429,
        headers: {
          ...getRateLimitHeaders(result, config),
          "Retry-After": result.resetIn.toString(),
        },
      }
    );
  }

  return null;
}

/**
 * Get client identifier from request
 * Uses user ID if authenticated, falls back to IP
 */
export function getClientIdentifier(request: NextRequest, userId?: string): string {
  if (userId) return `user:${userId}`;
  
  // Try various headers for real IP
  const forwarded = request.headers.get("x-forwarded-for");
  const realIp = request.headers.get("x-real-ip");
  const ip = forwarded?.split(",")[0]?.trim() || realIp || "anonymous";
  
  return `ip:${ip}`;
}
