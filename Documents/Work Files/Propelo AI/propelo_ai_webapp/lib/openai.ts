import OpenAI from "openai";
import { ProposalGenerationRequest, ProposalSection, JobInsight } from "@/types";
const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY,
});
// ============================================
// EXPERT UPWORK PROPOSAL SYSTEM
// High-conversion, human, trust-building proposals
// ============================================

// EXPERT SYSTEM PROMPT - Upwork conversion specialist
const SYSTEM_PROMPT_FAST = `You write Upwork proposals that win. Human, calm, smart, trustworthy.

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
// SPEED-OPTIMIZED USER PROMPT BUILDER
function buildOptimizedPrompt(
  request: ProposalGenerationRequest,
  userContext?: {
    skills?: string[];
    experience?: string;
    projects?: any[];
    preferredTone?: string;
    portfolio?: any[];
    testimonials?: string[];
    nicheExpertise?: string[];
  }
): string {
  const skillsStr = userContext?.skills?.slice(0, 5).join(", ") || "experienced professional";
  return `Write a ${request.tone} proposal for this job:

Title: ${request.jobTitle}
Description: ${request.jobDescription.substring(0, 1000)}
Budget: ${request.budget || "Not specified"}

About me: ${skillsStr}${userContext?.experience ? `. ${userContext.experience.substring(0, 150)}` : ""}
${request.customInstructions ? `Additional notes: ${request.customInstructions}` : ""}

Write the proposal now:`;
}
// Enhanced proposal output interface
interface EnhancedProposalOutput {
  sections: ProposalSection[];
  insights: JobInsight[];
  title: string;
  proposal: string;
  suggested_price: string;
  suggested_timeframe: string;
  confidence_rating: string;
  pain_point: string;
  how_to_use_pain_point: string;
  detected_language: string;
  proposal_quality_score: number;
  cta_variation: string;
}
export async function generateProposal(
  request: ProposalGenerationRequest,
  userContext?: {
    skills?: string[];
    experience?: string;
    projects?: any[];
    preferredTone?: string;
    portfolio?: any[];
    testimonials?: string[];
    nicheExpertise?: string[];
  }
): Promise<EnhancedProposalOutput> {
  try {
    const userPrompt = buildOptimizedPrompt(request, userContext);
    const completion = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      messages: [
        { role: "system", content: SYSTEM_PROMPT_FAST },
        { role: "user", content: userPrompt },
      ],
      max_completion_tokens: 8000,
    });
    
    // Try to get content from various possible locations
    const choice = completion.choices?.[0];
    let response = choice?.message?.content;
    
    // Some models might put content elsewhere
    if (!response && (choice as any)?.text) {
      response = (choice as any).text;
    }
    if (!response && (completion as any)?.content) {
      response = (completion as any).content;
    }
    
    const finishReason = choice?.finish_reason;
    
    if (!response || response.trim() === "") {
      // Log the full structure to understand what we got
      console.error("Empty content. Full choice:", JSON.stringify(choice, null, 2));
      throw new Error(`Empty response from OpenAI. finish_reason: ${finishReason}, choices: ${completion.choices?.length || 0}`);
    }
    
    // Use plain text response directly (no JSON parsing needed)
    return {
      sections: [],
      insights: [],
      title: request.jobTitle,
      proposal: response.trim(),
      suggested_price: "Contact for quote",
      suggested_timeframe: "To be discussed",
      confidence_rating: "medium",
      pain_point: "Addressed in proposal",
      how_to_use_pain_point: "N/A",
      detected_language: "en",
      proposal_quality_score: 80,
      cta_variation: "Standard",
    };
  } catch (error: any) {
    console.error("Error generating proposal:", error);
    // Build detailed error for debugging
    const errorMessage = error?.message || "Unknown error";
    const errorCode = error?.code || error?.status || "";
    const errorType = error?.type || error?.name || "";
    
    // Construct debug-friendly error
    let debugError = `[OpenAI] ${errorMessage}`;
    if (errorCode) debugError += ` (code: ${errorCode})`;
    if (errorType) debugError += ` [${errorType}]`;
    
    throw new Error(debugError);
  }
}
// ============================================
// SPEED-OPTIMIZED PROPOSAL ENHANCER
// ============================================
export async function enhanceProposal(originalText: string, instructions?: string): Promise<{
  enhancedText: string;
  beforeRating: number;
  afterRating: number;
  improvements: Array<{
    type: string;
    description: string;
    highlightedText: string;
    suggestion: string;
  }>;
}> {
  try {
    // Use custom instructions if provided, otherwise use default improvements
    const improvementInstructions = instructions 
      ? `SPECIFIC REQUEST: ${instructions}`
      : `IMPROVE IT BY:
1. Add powerful HOOK if missing (show you understand their pain)
2. Make it sound human, not corporate
3. Add specifics and social proof
4. Create a natural, low-friction CTA
5. Fix any grammar or clarity issues`;

    const enhancerPrompt = `Improve this Upwork proposal for maximum conversion.

ORIGINAL:
${originalText.substring(0, 2000)}

${improvementInstructions}

Write the improved proposal now:`;

    const completion = await openai.chat.completions.create({
      model: process.env.OPENAI_MODEL || "gpt-4o-mini",
      messages: [
        { role: "system", content: "You improve Upwork proposals to be more human, persuasive, and trustworthy. Output only the improved proposal text, nothing else." },
        { role: "user", content: enhancerPrompt },
      ],
      max_completion_tokens: 4000,
    });
    
    const response = completion.choices?.[0]?.message?.content;
    if (!response || response.trim() === "") {
      throw new Error("No response from OpenAI");
    }
    
    // Return plain text response
    return {
      enhancedText: response.trim(),
      beforeRating: 6,
      afterRating: 8,
      improvements: [{ type: "overall", description: "Improved for conversion", highlightedText: "", suggestion: "More human and persuasive" }],
    };
  } catch (error) {
    console.error("Error enhancing proposal:", error);
    throw new Error("Failed to enhance proposal. Please try again.");
  }
}
// ============================================
// FAST JOB BRIEF PARSER
// Pre-analyze before proposal generation
// ============================================
export async function parseClientBrief(jobDescription: string): Promise<{
  painPoints: string[];
  requirements: string[];
  budget?: string;
  deadline?: string;
  techStack: string[];
  risks: string[];
  detectedLanguage: string;
  clientType: string;
  urgencyLevel: string;
}> {
  try {
    const parserPrompt = `FAST EXTRACT from job post:
${jobDescription.substring(0, 2000)}
JSON:
{
  "painPoints": ["max 3 key problems"],
  "requirements": ["max 5 key requirements"],
  "budget": "budget if mentioned or null",
  "deadline": "deadline if mentioned or null",
  "techStack": ["technologies mentioned"],
  "risks": ["red flags max 2"],
  "detectedLanguage": "language code",
  "clientType": "startup|enterprise|agency|individual|nonprofit",
  "urgencyLevel": "high|medium|low"
}`;
    const completion = await openai.chat.completions.create({
      model: "gpt-4o-mini", // Always use mini for parsing (speed)
      messages: [
        { role: "system", content: "Fast job analyzer. Extract only essentials." },
        { role: "user", content: parserPrompt },
      ],
      temperature: 0.2, // Low for consistency
      max_tokens: 500, // Minimal for speed
      response_format: { type: "json_object" },
    });
    const response = completion.choices[0]?.message?.content;
    if (!response) {
      throw new Error("No response from OpenAI");
    }
    return JSON.parse(response);
  } catch (error) {
    console.error("Error parsing brief:", error);
    throw new Error("Failed to parse job brief.");
  }
}
// ============================================
// HOOK GENERATOR (Standalone for caching)
// ============================================
export async function generateHook(
  painPoint: string,
  platform: string,
  tone: string
): Promise<string> {
  const hookPrompt = `Generate 1 killer hook (2-3 sentences) for freelance proposal.
Pain Point: ${painPoint}
Platform: ${platform}
Tone: ${tone}
Rules:
- Mirror the pain immediately
- Be specific, not generic
- Create curiosity or bold claim
- No phone/email
Return JSON: {"hook": "string"}`;
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: hookPrompt }],
    temperature: 0.8,
    max_tokens: 150,
    response_format: { type: "json_object" },
  });
  const response = completion.choices[0]?.message?.content;
  const parsed = JSON.parse(response || '{"hook":""}');
  return parsed.hook;
}
// ============================================
// CTA GENERATOR (Standalone for variations)
// ============================================
export async function generateCTA(
  platform: string,
  tone: string,
  language: string = "en"
): Promise<string> {
  const ctaPrompt = `Generate 1 action-driven CTA for freelance proposal.
Platform: ${platform}
Tone: ${tone}
Language: ${language}
Rules:
- Compel immediate response
- No phone/email
- Create urgency without being pushy
- Match language if not English
Return JSON: {"cta": "string"}`;
  const completion = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: ctaPrompt }],
    temperature: 0.7,
    max_tokens: 100,
    response_format: { type: "json_object" },
  });
  const response = completion.choices[0]?.message?.content;
  const parsed = JSON.parse(response || '{"cta":""}');
  return parsed.cta;
}
export default {
  generateProposal,
  enhanceProposal,
  parseClientBrief,
  generateHook,
  generateCTA,
};
