// App-wide configuration constants

export const APP_CONFIG = {
  name: "Propelo AI",
  description: "From writing to winning, AI supercharges freelancing",
  url: process.env.NEXT_PUBLIC_APP_URL || "https://app.propeloai.com",
  version: "1.0.0",
} as const;

export const COLORS = {
  background: '#FFFEFB',
  primary: '#0EA5E9',
  secondary: '#0369A1',
  text: '#334155',
  white: '#FFFFFF',
} as const;

// Proposal tones
export const TONES = [
  'Professional',
  'Friendly',
  'Casual',
  'Formal',
  'Confident',
  'Humble',
  'Enthusiastic',
] as const;

// Client types
export const CLIENT_TYPES = [
  'Startup',
  'Corporate',
  'Agency',
  'Small Business',
  'Individual',
  'Non-Profit',
] as const;

export const ROUTES = {
  home: "/",
  dashboard: "/dashboard",
  generator: "/dashboard/generator",
  history: "/dashboard/history",
  analytics: "/dashboard/analytics",
  clients: "/dashboard/clients",
  snippets: "/dashboard/snippets",
  profile: "/dashboard/profile",
  settings: "/dashboard/settings",
  subscription: "/dashboard/subscription",
  enhancer: "/dashboard/enhancer",
  auth: {
    signIn: "/auth/signin",
    signUp: "/auth/signup",
    verify: "/auth/verify",
    forgotPassword: "/auth/forgot-password",
  },
  api: {
    proposals: "/api/proposals",
    generate: "/api/proposals/generate",
    enhance: "/api/proposals/enhance",
    analytics: "/api/analytics",
    webhooks: "/api/webhooks",
    auth: "/api/auth",
  },
} as const;

export const SECTION_TYPES = [
  { value: "introduction", label: "Introduction", description: "Personal greeting and connection" },
  { value: "scope", label: "Scope", description: "Project understanding and approach" },
  { value: "timeline", label: "Timeline", description: "Delivery schedule and milestones" },
  { value: "deliverables", label: "Deliverables", description: "What you'll provide" },
  { value: "pricing", label: "Pricing", description: "Budget breakdown" },
  { value: "experience", label: "Experience", description: "Relevant past work" },
  { value: "faq", label: "FAQ", description: "Common questions answered" },
  { value: "guarantee", label: "Guarantee", description: "Risk reversal" },
  { value: "cta", label: "Call to Action", description: "Next steps" },
  { value: "terms", label: "Terms", description: "Legal and payment terms" },
] as const;

export const DEFAULT_SECTIONS: Array<{ type: string; enabled: boolean }> = [
  { type: "introduction", enabled: true },
  { type: "scope", enabled: true },
  { type: "experience", enabled: true },
  { type: "timeline", enabled: true },
  { type: "deliverables", enabled: true },
  { type: "pricing", enabled: false },
  { type: "cta", enabled: true },
];

export const PLATFORMS = [
  { value: "upwork", label: "Upwork", icon: "briefcase" },
  { value: "fiverr", label: "Fiverr", icon: "zap" },
  { value: "freelancer", label: "Freelancer", icon: "user" },
  { value: "toptal", label: "Toptal", icon: "star" },
  { value: "other", label: "Other", icon: "more-horizontal" },
] as const;

export const PRICING_PLANS = {
  free: {
    name: "Free",
    price: 0,
    interval: "forever",
    features: [
      "15 free proposals (Trial)",
      "Smart AI Model",
      "All tones",
      "Basic dashboard",
    ],
  },
  starter: {
    name: "Pro Closer",
    price: 12,
    originalPrice: 19, // Kept for UI strikethrough effect if desired, or can be removed
    firstWeekPrice: 6.99,
    interval: "month",
    popular: true,
    features: [
      "200 proposals/month",
      "Smart AI Model",
      "All tones",
      "Open/click stats",
      "Proposal enhancer (Before/After)",
      "Portfolio links",
      "Priority support",
    ],
  },
  pro: {
    name: "Agency Elite",
    price: 19.99,
    interval: "month",
    features: [
      "500 proposals/month",
      "Smartest AI Model (More human-like)",
      "Custom tone memory",
      "Pain point detection & Client type",
      "Advanced analytics + export",
      "Proposal enhancer",
      "Priority support",
    ],
  },
} as const;

export const RATE_LIMITS = {
  proposalGeneration: {
    free: { requests: 15, window: "lifetime" },
    starter: { requests: 200, window: "30d" },
    pro: { requests: 500, window: "30d" },
  },
  apiCalls: {
    free: { requests: 100, window: "1h" },
    starter: { requests: 500, window: "1h" },
    pro: { requests: 2000, window: "1h" },
  },
} as const;

export const ERROR_MESSAGES = {
  generic: "Something went wrong. Please try again.",
  unauthorized: "You must be signed in to access this.",
  limitReached: "You've reached your proposal limit. Upgrade to continue.",
  invalidInput: "Please check your input and try again.",
  networkError: "Network error. Please check your connection.",
  proposalFailed: "Proposal generation failed. Retry?",
} as const;

export const SUCCESS_MESSAGES = {
  proposalGenerated: "Proposal generated successfully!",
  proposalSaved: "Proposal saved!",
  proposalDeleted: "Proposal deleted.",
  profileUpdated: "Profile updated successfully!",
  settingsSaved: "Settings saved!",
} as const;
