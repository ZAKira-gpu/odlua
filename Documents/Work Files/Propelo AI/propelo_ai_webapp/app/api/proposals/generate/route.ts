import { NextRequest, NextResponse } from "next/server";
import { generateProposal } from "@/lib/openai";
import { proposalGenerationSchema } from "@/lib/validations";
import { db, collections, addDocument, auth } from "@/lib/firebase-admin";
import { cookies } from "next/headers";
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders } from "@/lib/rate-limit";
import { validateOrigin } from "@/lib/csrf";
import { sanitizeProposalInput } from "@/lib/sanitize";

// Allowed origins for this API
const ALLOWED_ORIGINS = [
  process.env.NEXT_PUBLIC_APP_URL || "https://app.propeloai.com",
  "https://propeloai.com",
  "https://www.propeloai.com",
  // Chrome extension can also call this API
];

export async function POST(req: NextRequest) {
  try {
    // Origin validation (allow same-origin requests and extension)
    const origin = req.headers.get("origin");
    const isExtension = req.headers.get("x-extension-request") === "true";
    
    if (origin && !ALLOWED_ORIGINS.includes(origin) && !isExtension) {
      console.warn("[Generate API] Blocked request from invalid origin:", origin);
      return NextResponse.json(
        { error: "Forbidden" },
        { status: 403 }
      );
    }

    // Get user session from cookie
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get("session")?.value;
    
    // Note: we don't immediately reject when no session cookie is present --
    // we allow a fallback token via Authorization header or request body.

    // Parse request body early so we can accept an optional idToken fallback
    const body = await req.json();
    const fallbackToken = body?._idToken;

    // Verify the session token
    let decodedToken: any = null;
    let verificationError: any = null;

    const tryVerify = async (token: string) => {
      try {
        return await auth.verifyIdToken(token);
      } catch (err) {
        throw err;
      }
    };

    if (sessionCookie) {
      try {
        decodedToken = await tryVerify(sessionCookie);
      } catch (err) {
        verificationError = err;

      }
    } else {

    }

    // If cookie verification failed or cookie missing, try Authorization header
    if (!decodedToken) {
      const authHeader = req.headers.get("authorization");
      if (authHeader?.startsWith("Bearer ")) {
        const token = authHeader.split(" ")[1];
        try {
          decodedToken = await tryVerify(token);
        } catch (err) {
          verificationError = verificationError || err;

        }
      } else {

      }
    }

    // If still not verified, try fallback token provided in request body (field: _idToken)
    if (!decodedToken && fallbackToken) {
      try {
        decodedToken = await tryVerify(fallbackToken);
      } catch (err) {
        verificationError = verificationError || err;

      }
    }

    if (!decodedToken) {
      // Log a short hint for debugging (no sensitive token values).
      console.error("Invalid session - no valid token found for request to /api/proposals/generate", {
        cookiePresent: !!sessionCookie,
        verificationError: verificationError ? (verificationError.message || String(verificationError)) : null,
      });

      return NextResponse.json(
        { error: "Invalid session - Please sign in again" },
        { status: 401 }
      );
    }

    const userId = decodedToken.uid;

    // Rate limiting check
    const rateLimitResult = await checkRateLimit(`proposal:${userId}`, RATE_LIMITS.proposalGenerate);
    if (!rateLimitResult.success) {
      return NextResponse.json(
        { error: `Rate limit exceeded. Try again in ${rateLimitResult.resetIn} seconds.` },
        { 
          status: 429,
          headers: getRateLimitHeaders(rateLimitResult, RATE_LIMITS.proposalGenerate)
        }
      );
    }

    // Validate the request payload now that the user is authenticated
    const validatedData = proposalGenerationSchema.parse(body);

    // Sanitize text inputs to prevent XSS and injection attacks
    const sanitizedData = {
      ...validatedData,
      jobDescription: sanitizeProposalInput(validatedData.jobDescription, 15000),
      jobTitle: sanitizeProposalInput(validatedData.jobTitle, 500),
      clientName: validatedData.clientName ? sanitizeProposalInput(validatedData.clientName, 200) : undefined,
    };

    // Get user context from database
    const userDoc = await db.collection(collections.users).doc(userId).get();
    const userData = userDoc.data();

    // Check proposal limits
    const proposalsUsed = userData?.proposalsUsed || 0;
    const proposalsLimit = userData?.proposalsLimit || 15;

    if (proposalsUsed >= proposalsLimit) {
      return NextResponse.json(
        { error: "Proposal limit reached. Please upgrade your plan." },
        { status: 403 }
      );
    }

    // Generate proposal using OpenAI (now returns enhanced output)
    const proposalOutput = await generateProposal(
      sanitizedData as any,
      {
        skills: userData?.skills || [],
        experience: userData?.bio,
        projects: userData?.projects || [],
        preferredTone: userData?.preferredTone,
        portfolio: userData?.portfolio || [],
        testimonials: userData?.testimonials || [],
        nicheExpertise: userData?.nicheExpertise || [],
      }
    );

    // Create full proposal content from sections or use generated proposal
    const content = proposalOutput.proposal || 
      proposalOutput.sections.map((s) => `${s.title}\n\n${s.content}`).join("\n\n---\n\n");

    // Save proposal to user's proposals subcollection
    const proposalData: any = {
      title: proposalOutput.title || sanitizedData.jobTitle,
      content,
      jobDescription: sanitizedData.jobDescription,
      status: "draft",
      tone: validatedData.tone,
      platform: validatedData.platform,
      sections: proposalOutput.sections,
      insights: proposalOutput.insights,
      
      // Enhanced fields
      suggestedPrice: proposalOutput.suggested_price,
      suggestedTimeframe: proposalOutput.suggested_timeframe,
      confidenceRating: proposalOutput.confidence_rating,
      painPoint: proposalOutput.pain_point,
      howToUsePainPoint: proposalOutput.how_to_use_pain_point,
      detectedLanguage: proposalOutput.detected_language,
      proposalQualityScore: proposalOutput.proposal_quality_score,
      ctaVariation: proposalOutput.cta_variation,
      
      // Tracking
      opened: false,
      openCount: 0,
      linkClicks: 0,
      version: 1,
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    // Only add optional fields if they have values (Firestore doesn't accept undefined)
    if (validatedData.clientName) {
      proposalData.clientName = validatedData.clientName;
    }
    if (validatedData.budget) {
      proposalData.jobBudget = validatedData.budget;
    }
    if (validatedData.deadline) {
      proposalData.jobDeadline = validatedData.deadline;
    }

    // Save to user's proposals subcollection
    const proposalRef = await db
      .collection(collections.users)
      .doc(userId)
      .collection('proposals')
      .add(proposalData);

    // Update user's proposal count
    await db.collection(collections.users).doc(userId).update({
      proposalsUsed: proposalsUsed + 1,
    });

    return NextResponse.json({
      success: true,
      data: {
        id: `${userId}_${proposalRef.id}`, // Composite ID
        ...proposalData,
      },
    });
  } catch (error: any) {
    console.error("Error generating proposal:", error);

    if (error.name === "ZodError") {
      return NextResponse.json(
        { error: "Invalid input", details: error.errors },
        { status: 400 }
      );
    }

    return NextResponse.json(
      { error: error.message || "Failed to generate proposal" },
      { status: 500 }
    );
  }
}
