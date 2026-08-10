import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/firebase-admin";

export const dynamic = "force-dynamic";
export const revalidate = 0;

interface HealthStatus {
  status: "healthy" | "degraded" | "unhealthy";
  timestamp: string;
  version: string;
  uptime: number;
  checks: {
    database: CheckResult;
    environment: CheckResult;
  };
}

interface CheckResult {
  status: "pass" | "fail" | "warn";
  message?: string;
  latency?: number;
}

const startTime = Date.now();

/**
 * GET /api/health
 * Health check endpoint for load balancers, monitoring, and alerting
 */
export async function GET(req: NextRequest): Promise<NextResponse> {
  const checks: HealthStatus["checks"] = {
    database: { status: "pass" },
    environment: { status: "pass" },
  };

  let overallStatus: HealthStatus["status"] = "healthy";

  // Check database connectivity
  try {
    const dbStart = Date.now();
    await db.collection("_health").doc("ping").get();
    checks.database = {
      status: "pass",
      latency: Date.now() - dbStart,
    };
  } catch (error) {
    checks.database = {
      status: "fail",
      message: "Database connection failed",
    };
    overallStatus = "unhealthy";
  }

  // Check critical environment variables
  const requiredEnvVars = [
    "FIREBASE_PROJECT_ID",
    "FIREBASE_CLIENT_EMAIL", 
    "FIREBASE_PRIVATE_KEY",
    "OPENAI_API_KEY",
  ];

  const missingVars = requiredEnvVars.filter((v) => !process.env[v]);

  if (missingVars.length > 0) {
    checks.environment = {
      status: "fail",
      message: `Missing critical env vars: ${missingVars.length}`,
    };
    overallStatus = "unhealthy";
  }

  // Check optional but recommended variables
  const optionalVars = [
    "UPSTASH_REDIS_REST_URL",
    "BREVO_SMTP_USER",
  ];

  const missingOptional = optionalVars.filter((v) => !process.env[v]);

  if (missingOptional.length > 0 && checks.environment.status === "pass") {
    checks.environment = {
      status: "warn",
      message: `Optional services not configured: ${missingOptional.length}`,
    };
    if (overallStatus === "healthy") {
      overallStatus = "degraded";
    }
  }

  const response: HealthStatus = {
    status: overallStatus,
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || "1.0.0",
    uptime: Math.floor((Date.now() - startTime) / 1000),
    checks,
  };

  const statusCode = overallStatus === "unhealthy" ? 503 : 200;

  return NextResponse.json(response, {
    status: statusCode,
    headers: {
      "Cache-Control": "no-store, no-cache, must-revalidate",
    },
  });
}

/**
 * HEAD /api/health
 * Simple health check for load balancers that only check status code
 */
export async function HEAD(req: NextRequest): Promise<NextResponse> {
  try {
    await db.collection("_health").doc("ping").get();
    return new NextResponse(null, { status: 200 });
  } catch {
    return new NextResponse(null, { status: 503 });
  }
}
