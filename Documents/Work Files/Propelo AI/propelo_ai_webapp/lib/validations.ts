import { z } from "zod";

// Validation schemas using Zod

export const proposalGenerationSchema = z.object({
  jobTitle: z.string().min(3, "Job title must be at least 3 characters"),
  jobDescription: z.string().min(50, "Job description must be at least 50 characters"),
  platform: z.enum(["upwork", "fiverr", "freelancer", "linkedin", "toptal", "other"]),
  // Allow any non-empty string for tone to match UI-defined tone options
  tone: z.string().min(1, "Please select a tone"),
  clientName: z.string().optional(),
  clientType: z.enum(["startup", "enterprise", "agency", "individual", "nonprofit"]).optional(),
  budget: z.string().optional(),
  deadline: z.string().optional(),
  selectedSections: z.array(z.string()).min(1, "Select at least one section"),
  customInstructions: z.string().optional(),
  useTemplate: z.string().optional(),
  // Enhanced inputs for better proposals
  proposalEnhancements: z.array(z.string()).optional(), // e.g., ["add_urgency", "include_guarantee"]
  jobPostLanguage: z.string().optional(), // e.g., "en", "es", "fr"
  additionalNotes: z.string().optional(),
});

export const proposalEnhancementSchema = z.object({
  originalText: z.string().min(50, "Proposal must be at least 50 characters").optional(),
  proposal: z.string().min(50, "Proposal must be at least 50 characters").optional(),
}).refine(data => data.originalText || data.proposal, {
  message: "Either originalText or proposal is required",
});

export const userProfileSchema = z.object({
  firstName: z.string().min(2, "First name must be at least 2 characters"),
  lastName: z.string().min(2, "Last name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
  primarySpecialization: z.string().optional(),
  bio: z.string().max(500, "Bio must be less than 500 characters").optional(),
  yearsOfExperience: z.number().min(0).max(50).optional(),
  preferredHourlyRate: z.number().min(0).optional(),
  skills: z.array(z.string()).max(20, "Maximum 20 skills allowed"),
  languages: z.array(z.string()),
  projects: z.array(
    z.object({
      title: z.string(),
      description: z.string(),
      technologies: z.array(z.string()),
      link: z.string().url().optional(),
    })
  ).optional(),
});

export const clientSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  company: z.string().optional(),
  email: z.string().email("Invalid email address").optional(),
  platform: z.enum(["upwork", "fiverr", "freelancer", "toptal", "other"]),
  notes: z.string().optional(),
});

export const snippetSchema = z.object({
  title: z.string().min(3, "Title must be at least 3 characters"),
  content: z.string().min(10, "Content must be at least 10 characters"),
  category: z.enum(["pricing", "timeline", "faq", "experience", "cta", "other"]),
  tags: z.array(z.string()).optional(),
});

export const signUpSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
  firstName: z.string().min(2, "First name must be at least 2 characters"),
  lastName: z.string().min(2, "Last name must be at least 2 characters"),
});

export const signInSchema = z.object({
  email: z.string().email("Invalid email address"),
  password: z.string().min(8, "Password must be at least 8 characters"),
});

export const forgotPasswordSchema = z.object({
  email: z.string().email("Invalid email address"),
});

export const resetPasswordSchema = z.object({
  password: z.string().min(8, "Password must be at least 8 characters"),
  confirmPassword: z.string().min(8, "Password must be at least 8 characters"),
}).refine((data) => data.password === data.confirmPassword, {
  message: "Passwords don't match",
  path: ["confirmPassword"],
});

// Type inference from schemas
export type ProposalGenerationInput = z.infer<typeof proposalGenerationSchema>;
export type ProposalEnhancementInput = z.infer<typeof proposalEnhancementSchema>;
export type UserProfileInput = z.infer<typeof userProfileSchema>;
export type ClientInput = z.infer<typeof clientSchema>;
export type SnippetInput = z.infer<typeof snippetSchema>;
export type SignUpInput = z.infer<typeof signUpSchema>;
export type SignInInput = z.infer<typeof signInSchema>;
export type ForgotPasswordInput = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordInput = z.infer<typeof resetPasswordSchema>;
