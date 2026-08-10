import { NextRequest, NextResponse } from "next/server";
import { enhanceProposal } from "@/lib/openai";
import { proposalEnhancementSchema } from "@/lib/validations";
import { addDocument, collections, auth } from "@/lib/firebase-admin";
import { cookies } from "next/headers";
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders } from "@/lib/rate-limit";
import { sanitizeProposalInput } from "@/lib/sanitize";

// Allowed origins for this API
const ALLOWED_ORIGINS = [
  process.env.NEXT_PUBLIC_APP_URL || "https://app.propeloai.com",
  "https://propeloai.com",
  "https://www.propeloai.com",
];

export async function POST(req: NextRequest) {
  try {
    // Origin validation
    const origin = req.headers.get("origin");
    const isExtension = req.headers.get("x-extension-request") === "true";
    
    if (origin && !ALLOWED_ORIGINS.includes(origin) && !isExtension) {
      console.warn("[Enhance API] Blocked request from invalid origin:", origin);
      return NextResponse.json(
        { error: "Forbidden" },
        { status: 403 }
      );
    }

    // Get user session from cookie or Authorization header
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    const authHeader = req.headers.get("authorization");
    const bearerToken = authHeader?.startsWith("Bearer ") ? authHeader.split(" ")[1] : null;
    
    const tokenToVerify = sessionCookie || bearerToken;
    
    if (!tokenToVerify) {
      return NextResponse.json(
        { error: "Unauthorized - Please sign in" },
        { status: 401 }
      );
    }

    // Verify the session token
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(tokenToVerify);
    } catch (error) {
      return NextResponse.json(
        { error: "Invalid session - Please sign in again" },
        { status: 401 }
      );
    }

    const userId = decodedToken.uid;

    // Rate limiting check
    const rateLimitResult = await checkRateLimit(`enhance:${userId}`, RATE_LIMITS.proposalEnhance);
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: `Rate limit exceeded. Try again in ${rateLimitResult.resetIn} seconds.` },
        { 
          status: 429,
          headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.proposalEnhance)
        }
      );
    }

    const body = await req.json();
    const validatedData = proposalEnhancementSchema.parse(body);

    // Accept either originalText or proposal field and sanitize
    const proposalText = sanitizeProposalInput(
      validatedData.originalText || (validatedData as any).proposal,
      15000
    );
    const instructions = (body as any).instructions 
      ? sanitizeProposalInput((body as any).instructions, 1000)
      : undefined;

    // Enhance the proposal with optional instructions
    const enhancement = await enhanceProposal(proposalText, instructions);

    // Save enhancement to database
    const enhancementData = {
      userId,
      originalText: proposalText,
      enhancedText: enhancement.enhancedText,
      beforeRating: enhancement.beforeRating,
      afterRating: enhancement.afterRating,
      improvements: enhancement.improvements,
      createdAt: new Date(),
    };

    const enhancementId = await addDocument(collections.enhancements, enhancementData);

    return NextResponse.json({
      success: true,
      data: {
        id: enhancementId,
        ...enhancement,
      },
    });
  } catch (error: any) {
    console.error("Error enhancing proposal:", error);

    if (error.name === "ZodError") {
      return NextResponse.json(
        { error: "Invalid input", details: error.errors },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { error: error.message || "Failed to enhance proposal" },
      { status: 500 }
    );
  }
}
