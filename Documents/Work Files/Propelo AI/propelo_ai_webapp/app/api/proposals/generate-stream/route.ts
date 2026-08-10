import { NextRequest } from "next/server";
import OpenAI from "openai";
import { proposalGenerationSchema } from "@/lib/validations";
import { db, collections, auth } from "@/lib/firebase-admin";
import { cookies } from "next/headers";
import { checkRateLimit, RATE_LIMITS, getRateLimitHeaders } from "@/lib/rate-limit";
import { sanitizeProposalInput } from "@/lib/sanitize";

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});

// Allowed origins for this API
const ALLOWED_ORIGINS = [
  process.env.NEXT_PUBLIC_APP_URL || "https://app.propeloai.com",
  "https://propeloai.com",
  "https://www.propeloai.com",
];

// Expert system prompt for high-conversion proposals
const SYSTEM_PROMPT = `You write Upwork proposals that win. Human, calm, smart, trustworthy.

CORE IDENTITY:
Thoughtful expert who cares about outcomes. Not desperate. Not an agency. A real person with opinions.

OPENING (First 2 lines):
- Hook emotionally, show you understand their problem
- Feel personal, not template
- If skippable, rewrite

EMOTIONAL SAFETY:
State explicitly: control, predictability, no surprises, no scope creep, no ghosting.
"I'll send daily updates" > implying you communicate well.

SOUND HUMAN:
BANNED: scalable, robust, cutting-edge, solutions, seamless, leverage, synergy
REQUIRED: Contractions, short sentences, conversational rhythm, slight imperfection.
If it sounds like a pitch deck, rewrite.

PRICING PSYCHOLOGY:
- Always anchor with low-risk entry: "Lean MVP" → "Serious MVP" → "Scale"
- Use ranges, not exact numbers (feels flexible, human)
- MVP = experiment, not marriage. Say: "proof version", "validation build", "pilot"
- Never drop large numbers without framing and phases
- Region-sensitive: MENA/emerging markets = lower risk tolerance, stronger need for testing
- Explain pricing in plain English: what they get, why phased, why it protects them
- Signal control: milestones, phase gates, no lock-in, no surprise costs
- Goal: get reply and start conversation, not maximize first deal

PRODUCT JUDGMENT:
Never list features. Include what NOT to build yet, what's risky, what usually goes wrong.
Sound like a builder with opinions.

MVP-FIRST:
Never sell full system first. Client must feel: "This person protects my money."

MICRO-DIFFERENTIATION:
1-2 lines showing identity—a belief, principle, or opinion. Not bragging.

HUMAN SIGNALS:
- One lived-experience hint
- One opinionated statement
- One line a real person would say out loud

LEADERSHIP ENERGY:
Never submissive or desperate. Calm expert. Grounded confidence.

END WITH REPLY TRIGGER:
Easy, personal, helpful question. Not salesy.
"Does that match what you had in mind?"

FORMAT:
150-250 words. Short paragraphs. Skimmable.

FINAL CHECK:
Would a founder with limited budget and high fear reply to this? If not, rewrite.`;

export async function POST(req: NextRequest) {
  try {
    // Origin validation
    const origin = req.headers.get("origin");
    const isExtension = req.headers.get("x-extension-request") === "true";
    
    if (origin && !ALLOWED_ORIGINS.includes(origin) && !isExtension) {
      console.warn("[Generate Stream API] Blocked request from invalid origin:", origin);
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Get user session from cookie
    const cookieStore = await cookies();
    const sessionCookie = cookieStore.get("session")?.value;

    const body = await req.json();
    const fallbackToken = body?._idToken;

    // Verify the session token
    let decodedToken: any = null;

    const tryVerify = async (token: string) => {
      try {
        return await auth.verifyIdToken(token);
      } catch {
        return null;
      }
    };

    // Try session cookie first
    if (sessionCookie) {
      decodedToken = await tryVerify(sessionCookie);
    }

    // Try Authorization header
    if (!decodedToken) {
      const authHeader = req.headers.get("authorization");
      if (authHeader?.startsWith("Bearer ")) {
        decodedToken = await tryVerify(authHeader.split(" ")[1]);
      }
    }

    // Try fallback token
    if (!decodedToken && fallbackToken) {
      decodedToken = await tryVerify(fallbackToken);
    }

    if (!decodedToken) {
      return new Response(
        JSON.stringify({ error: "Invalid session - Please sign in again" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
      );
    }

    const userId = decodedToken.uid;

    // Rate limiting check
    const rateLimitResult = await checkRateLimit(`proposal:${userId}`, RATE_LIMITS.proposalGenerate);
    if (!rateLimitResult.success) {
      return new Response(
        JSON.stringify({ error: `Rate limit exceeded. Try again in ${rateLimitResult.resetIn} seconds.` }),
        { 
          status: 429, 
          headers: { 
            "Content-Type": "application/json",
            ...getRateLimitHeaders(rateLimitResult, RATE_LIMITS.proposalGenerate)
          } 
        }
      );
    }
    // Validate the request
    const validatedData = proposalGenerationSchema.parse(body);

    // Sanitize text inputs to prevent XSS and injection attacks
    const sanitizedData = {
      ...validatedData,
      jobDescription: sanitizeProposalInput(validatedData.jobDescription, 15000),
      jobTitle: sanitizeProposalInput(validatedData.jobTitle, 500),
      customInstructions: validatedData.customInstructions ? sanitizeProposalInput(validatedData.customInstructions, 1000) : undefined,
    };

    // Get user data and check limits
    const userDoc = await db.collection(collections.users).doc(userId).get();
    const userData = userDoc.data();
    const proposalsUsed = userData?.proposalsUsed || 0;
    const proposalsLimit = userData?.proposalsLimit || 15;

    if (proposalsUsed >= proposalsLimit) {
      return new Response(
        JSON.stringify({ error: "Proposal limit reached. Please upgrade your plan." }),
        { status: 403, headers: { "Content-Type": "application/json" } }
      );
    }

    // Build prompt
    const skillsStr = userData?.skills?.slice(0, 5).join(", ") || "experienced professional";
    const userPrompt = `Write a ${sanitizedData.tone} proposal for this job:

Title: ${sanitizedData.jobTitle}
Description: ${sanitizedData.jobDescription.substring(0, 1000)}
Budget: ${sanitizedData.budget || "Not specified"}

About me: ${skillsStr}${userData?.bio ? `. ${userData.bio.substring(0, 150)}` : ""}
${sanitizedData.customInstructions ? `Additional notes: ${sanitizedData.customInstructions}` : ""}

Write the proposal now:`;

    // Create streaming response
    const stream = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: userPrompt },
      ],
      max_completion_tokens: 8000,
      stream: true,
    });

    // Create a TransformStream for SSE
    const encoder = new TextEncoder();
    let fullContent = "";

    const readable = new ReadableStream({
      async start(controller) {
        try {
          for await (const chunk of stream) {
            const content = chunk.choices[0]?.delta?.content || "";
            if (content) {
              fullContent += content;
              // Send SSE format
              controller.enqueue(encoder.encode(`data: ${JSON.stringify({ content, done: false })}\n\n`));
            }
          }

          // Save to database after stream completes
          const proposalData = {
            title: validatedData.jobTitle,
            content: fullContent,
            jobDescription: validatedData.jobDescription,
            status: "draft",
            tone: validatedData.tone,
            platform: validatedData.platform,
            createdAt: new Date(),
            updatedAt: new Date(),
          };

          const proposalRef = await db
            .collection(collections.users)
            .doc(userId)
            .collection("proposals")
            .add(proposalData);

          // Update proposal count
          await db.collection(collections.users).doc(userId).update({
            proposalsUsed: proposalsUsed + 1,
          });

          // Send completion signal with proposal ID
          controller.enqueue(
            encoder.encode(
              `data: ${JSON.stringify({ 
                content: "", 
                done: true, 
                proposalId: `${userId}_${proposalRef.id}`,
                fullContent 
              })}\n\n`
            )
          );
          controller.close();
        } catch (error: any) {
          controller.enqueue(
            encoder.encode(`data: ${JSON.stringify({ error: error.message, done: true })}\n\n`)
          );
          controller.close();
        }
      },
    });

    return new Response(readable, {
      headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        Connection: "keep-alive",
      },
    });
  } catch (error: any) {
    console.error("Streaming error:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to generate proposal" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
}
