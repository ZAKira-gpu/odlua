// Core Types for Propelo AI

export type ProposalStatus = "draft" | "sent" | "opened" | "accepted" | "rejected";

export type ProposalTone = "concise" | "persuasive" | "friendly" | "formal" | "custom";

export type FreelancePlatform = "upwork" | "fiverr" | "freelancer" | "linkedin" | "toptal" | "other";

export type SubscriptionPlan = "free" | "starter" | "pro" | "agency" | "lifetime";

export type UserRole = "user" | "admin";

// Firebase-specific types
export type PlanType = 'free' | 'pro' | 'ultimate';
export type SubscriptionStatus = 'pending' | 'active' | 'canceled' | 'past_due' | 'trialing';
export type FeedbackType = 'trial_review' | 'feature_request' | 'bug_report' | 'general';
export type BillingStatus = 'pending' | 'completed' | 'failed' | 'refunded';
export type AnalyticsEventType = 'proposal_generated' | 'proposal_sent' | 'proposal_opened' | 'proposal_accepted' | 'view' | 'scroll' | 'click' | 'share';

// User
export interface User {
  id: string;
  email: string;
  emailVerified: boolean;
  firstName?: string;
  lastName?: string;
  name?: string;
  image?: string;
  profileImage?: string;
  bio?: string;
  primarySpecialization?: string;
  yearsOfExperience?: number;
  preferredHourlyRate?: number;
  skills: string[];
  languages: string[];
  projects: UserProject[];
  createdAt: Date;
  updatedAt: Date;
  
  // Subscription
  subscriptionPlan: SubscriptionPlan;
  subscriptionStatus: SubscriptionStatus;
  subscriptionId?: string;
  currentPeriodEnd?: Date;
  
  // Usage
  proposalsUsed: number;
  proposalsLimit: number;
  
  // Settings
  preferredTone?: ProposalTone;
  customTone?: string;
  
  // Firebase compatibility fields
  plan?: PlanType;
  lastResetDate?: Date;
  billingCycleDay?: number;
  trialEndsAt?: Date;
  welcomeSentAt?: Date;
  reengageStages?: ReengageStages;
  preferences?: UserPreferences;
  analytics?: UserAnalytics;
  accounts?: Record<string, PlatformAccount>;
  platforms?: Record<string, PlatformStatus>;
}

export interface UserProject {
  id: string;
  title: string;
  description: string;
  technologies: string[];
  link?: string;
  image?: string;
}

// Proposal
export interface Proposal {
  id: string;
  userId: string;
  title: string;
  content: string;
  jobDescription: string;
  status: ProposalStatus;
  tone: ProposalTone;
  platform: FreelancePlatform;
  
  // AI Generated Sections
  sections: ProposalSection[];
  insights: JobInsight[];
  
  // Client Info
  clientName?: string;
  clientCompany?: string;
  jobBudget?: string;
  jobDeadline?: string;
  
  // Tracking
  shareUrl?: string;
  opened: boolean;
  openedAt?: Date;
  openCount: number;
  timeSpent?: number; // in seconds
  linkClicks: number;
  
  // Versioning
  version: number;
  previousVersionId?: string;
  
  // Ratings
  userRating?: number; // 1-5 stars
  
  createdAt: Date;
  updatedAt: Date;
}

export interface ProposalSection {
  id: string;
  type: SectionType;
  title: string;
  content: string;
  order: number;
  enabled: boolean;
}

export type SectionType =
  | "introduction"
  | "scope"
  | "timeline"
  | "deliverables"
  | "pricing"
  | "experience"
  | "faq"
  | "guarantee"
  | "cta"
  | "terms";

// Job Insights (Propelo's Job Insights)
// Add more types as needed
export type InsightType = 'pain_point' | 'requirement' | 'budget' | 'timeline' | 'risk' | 'opportunity';
export type InsightImportance = 'high' | 'medium' | 'low';

export interface JobInsight {
  id: string;
  type: InsightType;
  importance: InsightImportance;
  title: string;
  description: string;
  text?: string;
  icon?: string;
}

// ============================================
// Firebase-Specific Types (Enhanced for backwards compatibility)
// ============================================

export interface UserPreferences {
  theme: 'light' | 'dark';
  defaultPlatform?: string;
  defaultTone?: string;
  emailNotifications: boolean;
  proposalOpenAlerts: boolean;
  weeklyReports: boolean;
  marketingEmails: boolean;
  language: string;
  timezone: string;
  autoSave: boolean;
}

export interface UserAnalytics {
  totalProposals: number;
  totalViews: number;
  totalAccepted: number;
  winRate: number;
  lastUpdated: Date;
}

export interface ReengageStages {
  day3: boolean;
  day7: boolean;
  day14: boolean;
  day21: boolean;
  day30: boolean;
}

export interface PersonalData {
  name: string;
  professionalTitle: string;
  yearsExperience: string;
  portfolioUrl?: string;
  skills: string[];
  expertise: string;
  bio?: string;
  linkedin?: string;
  github?: string;
  updated_at: Date;
}

export interface ProposalAnalytics {
  opens: number;
  clicks: number;
  timeSpent: number;
  lastOpened?: Date;
}

export interface ProposalMetadata {
  aiModel?: string;
  processingTime?: number;
  tokenCount?: number;
}

export interface FirebaseProposal {
  id: string;
  userId: string;
  title: string;
  content: string; // Main proposal text
  jobDescription: string;
  platform: string;
  clientName?: string;
  clientType?: string;
  tone: string;
  tones?: string[]; // Deprecated, kept for backwards compat
  suggestedPrice?: string;
  suggestedTimeframe?: string;
  confidenceRating?: string;
  painPoint?: string;
  status: ProposalStatus;
  created_at: Date;
  updated_at: Date;
  sent_at?: Date;
  analytics: ProposalAnalytics;
  metadata?: ProposalMetadata;
}

export interface Draft {
  jobDescription: string;
  platform: string;
  clientType?: string;
  tone?: string;
  tones?: string[];
  additionalNotes?: string;
  language?: string;
  timestamp: Date;
  autoSaved: boolean;
}

export interface BillingHistory {
  id: string;
  date: Date;
  amount: number;
  currency: string;
  plan: string;
  status: BillingStatus;
  type: 'one-time' | 'recurring';
  subscriptionId?: string;
  invoiceUrl?: string;
  metadata?: Record<string, any>;
}

export interface AnalyticsEvent {
  id: string;
  type: 'proposal_generated' | 'proposal_sent' | 'proposal_opened' | 'proposal_accepted';
  proposalId?: string;
  timestamp: Date;
  metadata?: Record<string, any>;
  ipAddress?: string;
}

export interface Template {
  id: string;
  name: string;
  content: string;
  platform: string;
  tone: string;
  isFavorite: boolean;
  useCount: number;
  created_at: Date;
}

export interface Feedback {
  id: string;
  userId: string;
  type: FeedbackType;
  rating?: number;
  message: string;
  status: 'pending' | 'reviewed' | 'resolved';
  created_at: Date;
  metadata?: Record<string, any>;
}

export interface GlobalAnalytics {
  date: string; // 'YYYY-MM-DD'
  totalUsers: number;
  activeUsers: number;
  proposalsGenerated: number;
  byPlan: {
    free: number;
    pro: number;
    ultimate: number;
  };
  timestamp: Date;
}

export interface SystemConfig {
  defaultModel: string;
  maxTokens: number;
  temperature: number;
  updated_at: Date;
}

// Proposal Template
export interface ProposalTemplate {
  id: string;
  name: string;
  description: string;
  niche: string;
  tone: ProposalTone;
  sections: Omit<ProposalSection, "id">[];
  isDefault: boolean;
  userId?: string; // null for system templates
}

// Proposal Enhancer
export interface ProposalEnhancement {
  id: string;
  originalText: string;
  enhancedText: string;
  beforeRating: number;
  afterRating: number;
  improvements: Enhancement[];
  createdAt: Date;
}

export interface Enhancement {
  type: "clarity" | "persuasion" | "flow" | "grammar" | "professionalism";
  description: string;
  highlightedText: string;
  suggestion: string;
}

// CRM Client
export interface Client {
  id: string;
  userId: string;
  name: string;
  company?: string;
  email?: string;
  platform: FreelancePlatform;
  notes?: string;
  
  // Stats
  proposalsSent: number;
  proposalsAccepted: number;
  totalRevenue?: number;
  lastContact?: Date;
  
  createdAt: Date;
  updatedAt: Date;
}

// Snippets Library
export interface Snippet {
  id: string;
  userId: string;
  title: string;
  content: string;
  category: "pricing" | "timeline" | "faq" | "experience" | "cta" | "other";
  tags: string[];
  usageCount: number;
  createdAt: Date;
}

// Analytics
export interface ProposalAnalytics {
  proposalId: string;
  events: ProposalAnalyticsEvent[];
}

export interface ProposalAnalyticsEvent {
  id: string;
  type: "view" | "scroll" | "click" | "share";
  timestamp: Date;
  metadata?: Record<string, any>;
}

// Generation Request
export interface ProposalGenerationRequest {
  jobDescription: string;
  jobTitle: string;
  platform: FreelancePlatform;
  tone: ProposalTone;
  clientName?: string;
  budget?: string;
  deadline?: string;
  selectedSections: SectionType[];
  customInstructions?: string;
  useTemplate?: string; // template ID
}

// API Response Types
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export interface PaginatedResponse<T> {
  data: T[];
  total: number;
  page: number;
  pageSize: number;
  hasMore: boolean;
}

// Lemon Squeezy Types
export interface LemonSqueezyWebhook {
  meta: {
    event_name: string;
    custom_data?: Record<string, any>;
  };
  data: {
    id: string;
    type: string;
    attributes: Record<string, any>;
  };
}

// Constants
export const PLAN_LIMITS = {
  free: {
    proposals: 15,
    model: "gpt-4o-mini",
    features: ["basic_tones", "basic_analytics"],
  },
  starter: {
    proposals: 200,
    model: "gpt-4o-mini",
    features: ["all_tones", "analytics", "crm_lite", "snippets"],
  },
  pro: {
    proposals: 500,
    model: "gpt-4o",
    features: [
      "all_tones",
      "custom_tone",
      "advanced_analytics",
      "crm_lite",
      "snippets",
      "proposal_enhancer",
      "portfolio_links",
    ],
  },
  agency: {
    proposals: 1500,
    model: "gpt-4o",
    features: [
      "all_features",
      "team_seats",
      "priority_support",
      "advanced_analytics",
      "export",
    ],
  },
  lifetime: {
    proposals: 99999,
    model: "gpt-4o",
    features: ["all_features"],
  },
} as const;

export const TONES: Record<ProposalTone, { label: string; description: string }> = {
  concise: {
    label: "Concise",
    description: "Short, direct, and to the point",
  },
  persuasive: {
    label: "Persuasive",
    description: "Compelling and results-focused",
  },
  friendly: {
    label: "Friendly",
    description: "Warm, approachable, and conversational",
  },
  formal: {
    label: "Formal",
    description: "Professional and business-oriented",
  },
  custom: {
    label: "Custom",
    description: "Your personalized tone",
  },
};

export const NICHES = [
  "Web Development",
  "Mobile App Development",
  "UI/UX Design",
  "Graphic Design",
  "Content Writing",
  "Copywriting",
  "SEO & Marketing",
  "Video Editing",
  "Data Analysis",
  "Virtual Assistant",
  "Social Media Management",
  "eCommerce Development",
] as const;

// ============================================
// Account Scraping & Proposal Tracking Types
// ============================================

/**
 * Unified Platform Account Data
 * Scraped from user's profile on various platforms
 */
export interface PlatformAccount {
  platform: FreelancePlatform;
  userId: string; // Our internal user ID
  profileData: UpworkProfile | FiverrProfile | FreelancerProfile | LinkedInProfile;
  lastSynced: Date;
  syncStatus: 'success' | 'partial' | 'failed';
  syncErrors?: string[];
}

/**
 * Upwork Account Profile Data
 */
export interface UpworkProfile {
  platform: 'upwork';
  // Basic Info
  name?: string;
  displayName: string;
  username?: string;
  title: string;
  profileUrl?: string;
  location?: string;
  profileImage?: string;
  bio?: string;
  overview?: string;
  description?: string;
  
  // Professional Stats
  hourlyRate?: number;
  hourlyRateMin?: number;
  hourlyRateMax?: number;
  hourlyRateCurrency?: string;
  jobSuccessScore?: number; // 0-100
  totalEarnings?: number;
  totalJobs?: number;
  totalHours?: number;
  
  // Profile Completeness & Badges
  profileCompleteness?: number; // 0-100
  isVerified?: boolean;
  isTopRated?: boolean;
  isTopRatedPlus?: boolean;
  isRisingTalent?: boolean;
  isExpertVetted?: boolean;
  
  // Skills & Experience
  skills?: string[];
  categories?: string[];
  languages?: Array<{
    name: string;
    proficiency?: string;
  }>;
  
  // Portfolio
  portfolio?: Array<{
    title: string;
    description?: string;
    url?: string;
    imageUrl?: string;
    completedDate?: string;
    skills?: string[];
  }>;
  
  // Reviews & Ratings
  rating?: number; // 0-5
  reviewCount?: number;
  recentReviews?: Array<{
    rating?: number;
    comment?: string;
    clientName?: string;
    date?: string;
    jobTitle?: string;
  }>;
  
  // Education & Certifications
  education?: Array<{
    institution?: string;
    degree?: string;
    field?: string;
    year?: string;
  }>;
  certifications?: Array<{
    name?: string;
    issuer?: string;
    date?: string;
  }>;
  
  // Additional Info
  memberSince?: string;
  availability?: string;
  responseTime?: string;
  
  // Scraping Metadata
  scrapedAt?: Date | string;
  scrapedFrom?: string; // URL
}

/**
 * Fiverr Account Profile Data
 */
export interface FiverrProfile {
  platform: 'fiverr';
  // Basic Info
  username: string;
  displayName: string;
  profileUrl?: string;
  profileImage?: string;
  location?: string;
  
  // Seller Stats
  sellerLevel: 'new' | 'level_one' | 'level_two' | 'top_rated';
  rating?: number; // 0-5
  reviewCount?: number;
  totalOrders?: number;
  totalRevenue?: number;
  
  // Gigs
  activeGigs: number;
  gigCategories: string[];
  
  // Skills & Languages
  skills: string[];
  languages: Array<{
    name: string;
    proficiency: 'basic' | 'conversational' | 'fluent' | 'native';
  }>;
  
  // Response & Delivery
  responseTime?: string; // e.g., "1 hour"
  deliveryTime?: string; // e.g., "24 hours"
  
  // Professional Info
  bio?: string;
  memberSince?: string;
  
  // Certifications
  certifications?: string[];
  
  // Recent Reviews
  recentReviews?: Array<{
    rating: number;
    comment: string;
    buyerName: string;
    date: string;
    gigTitle: string;
  }>;
  
  // Scraping Metadata
  scrapedAt: Date;
  scrapedFrom: string;
}

/**
 * Freelancer Account Profile Data
 */
export interface FreelancerProfile {
  platform: 'freelancer';
  // Basic Info
  username: string;
  displayName: string;
  profileUrl?: string;
  profileImage?: string;
  location?: string;
  
  // Freelancer Stats
  rating?: number; // 0-5
  reviewCount?: number;
  completedProjects?: number;
  onTimeDelivery?: number; // percentage
  onBudgetDelivery?: number; // percentage
  repeatHireRate?: number; // percentage
  
  // Financial
  hourlyRate?: number;
  earnings?: number;
  
  // Skills & Expertise
  skills: string[];
  categories: string[];
  
  // Portfolio
  portfolio: Array<{
    title: string;
    description?: string;
    url?: string;
    imageUrl?: string;
  }>;
  
  // Professional Details
  bio?: string;
  tagline?: string;
  memberSince?: string;
  
  // Qualifications
  certifications?: Array<{
    name: string;
    issuer?: string;
    date?: string;
  }>;
  
  // Languages
  languages: Array<{
    name: string;
    proficiency: 'basic' | 'conversational' | 'fluent' | 'native';
  }>;
  
  // Scraping Metadata
  scrapedAt: Date;
  scrapedFrom: string;
}

/**
 * LinkedIn Account Profile Data
 */
export interface LinkedInProfile {
  platform: 'linkedin';
  // Basic Info
  name: string;
  headline: string;
  profileUrl?: string;
  profileImage?: string;
  location?: string;
  
  // Network
  connectionCount?: number;
  followerCount?: number;
  
  // Experience
  experience: Array<{
    title: string;
    company: string;
    location?: string;
    startDate?: string;
    endDate?: string;
    isCurrent: boolean;
    description?: string;
  }>;
  
  // Education
  education: Array<{
    school: string;
    degree?: string;
    fieldOfStudy?: string;
    startYear?: string;
    endYear?: string;
  }>;
  
  // Skills
  skills: Array<{
    name: string;
    endorsements?: number;
  }>;
  
  // Certifications
  certifications: Array<{
    name: string;
    issuer: string;
    issueDate?: string;
    credentialId?: string;
    credentialUrl?: string;
  }>;
  
  // Recommendations
  recommendations?: Array<{
    recommenderName: string;
    recommenderTitle: string;
    relationship: string;
    text: string;
    date?: string;
  }>;
  
  // About
  about?: string;
  
  // Languages
  languages?: string[];
  
  // Featured Content
  featuredContent?: Array<{
    type: 'article' | 'post' | 'document';
    title: string;
    url?: string;
    description?: string;
  }>;
  
  // Scraping Metadata
  scrapedAt: Date;
  scrapedFrom: string;
}

/**
 * Proposal Submission Tracking
 * Tracks proposals submitted on platforms
 */
export interface ProposalSubmission {
  id: string;
  userId: string;
  platform: FreelancePlatform;
  
  // Job Information
  jobId?: string; // Platform-specific job ID
  jobTitle: string;
  jobUrl?: string;
  clientName?: string;
  clientCompany?: string;
  jobPostedDate?: Date;
  
  // Proposal Details
  coverLetter: string;
  bidAmount?: number;
  currency?: string;
  proposedDuration?: string;
  attachments?: Array<{
    name: string;
    url?: string;
  }>;
  
  // Status Tracking
  status: ProposalSubmissionStatus;
  submittedAt: Date;
  viewedAt?: Date;
  respondedAt?: Date;
  hiredAt?: Date;
  
  // Client Activity
  clientViewed: boolean;
  clientLastSeen?: Date;
  interviewInvited: boolean;
  interviewScheduledFor?: Date;
  
  // Communication
  messages: Array<{
    from: 'client' | 'freelancer';
    text: string;
    sentAt: Date;
  }>;
  
  // Outcome
  outcomeType?: 'hired' | 'rejected' | 'no_response' | 'withdrawn' | 'archived';
  outcomeDate?: Date;
  outcomeNotes?: string;
  
  // Project Details (if hired)
  projectId?: string;
  projectStartDate?: Date;
  projectEndDate?: Date;
  finalAmount?: number;
  
  // Analytics
  responseTime?: number; // hours until client responded
  proposalRank?: number; // ranking among all proposals (if visible)
  totalProposals?: number; // total proposals on that job
  
  // AI-Generated Flag
  generatedByPropelo: boolean;
  propeloProposalId?: string;
  
  // Sync Metadata
  lastScraped: Date;
  scrapedFrom: string; // URL of proposals page
  syncStatus: 'active' | 'stale' | 'archived';
}

export type ProposalSubmissionStatus =
  | 'draft' // Not yet submitted
  | 'submitted' // Submitted, awaiting review
  | 'pending' // Submitted, pending
  | 'viewed' // Client viewed the proposal
  | 'shortlisted' // Client shortlisted
  | 'interviewing' // In interview/discussion phase
  | 'offer_received' // Client sent offer
  | 'accepted' // Hired/accepted
  | 'rejected' // Explicitly rejected by client
  | 'withdrawn' // Withdrawn by freelancer
  | 'archived' // Job closed/archived
  | 'no_response'; // No response from client

/**
 * Unified Account Sync Request
 * Sent from extension to web app API
 */
export interface AccountSyncRequest {
  userId: string;
  platform: FreelancePlatform;
  profileData: UpworkProfile | FiverrProfile | FreelancerProfile | LinkedInProfile;
  timestamp: Date;
}

/**
 * Proposal Tracking Batch Sync
 * Sent from extension to web app API
 */
export interface ProposalTrackingSync {
  userId: string;
  platform: FreelancePlatform;
  proposals: ProposalSubmission[];
  syncedAt: Date;
}

/**
 * Account Summary (for dashboard display)
 */
export interface AccountSummary {
  userId: string;
  platforms: {
    upwork?: {
      connected: boolean;
      lastSynced?: Date;
      profileCompleteness?: number;
      jobSuccessScore?: number;
      rating?: number;
      totalEarnings?: number;
    };
    fiverr?: {
      connected: boolean;
      lastSynced?: Date;
      sellerLevel?: string;
      rating?: number;
      totalOrders?: number;
    };
    freelancer?: {
      connected: boolean;
      lastSynced?: Date;
      rating?: number;
      completedProjects?: number;
    };
    linkedin?: {
      connected: boolean;
      lastSynced?: Date;
      connectionCount?: number;
    };
  };
  totalProposalsTracked: number;
  activeProposals: number;
  winRate?: number; // percentage of accepted proposals
  averageResponseTime?: number; // hours
  lastSyncedAt?: Date;
}

/**
 * Scraping Configuration
 * Stored in Chrome storage for extension settings
 */
export interface ScrapingConfig {
  enableAutoSync: boolean;
  syncInterval: number; // minutes
  platforms: {
    upwork: boolean;
    fiverr: boolean;
    freelancer: boolean;
    linkedin: boolean;
  };
  trackProposals: boolean;
  syncAccountData: boolean;
  notifyOnStatusChange: boolean;
}

// Platform connection status
export interface PlatformStatus {
  connected: boolean;
  lastSyncedAt?: Date;
  jobSuccessScore?: number;
  rating?: number;
  totalEarnings?: string;
}
