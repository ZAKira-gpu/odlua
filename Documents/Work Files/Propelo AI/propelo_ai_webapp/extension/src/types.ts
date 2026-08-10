/**
 * Propelo Extension Types
 * Core type definitions for the Chrome extension
 */

// ===== JOB DATA TYPES =====

export interface ClientInfo {
  name?: string;
  country?: string;
  location?: string;
  paymentVerified?: boolean;
  rating?: number;
  reviewCount?: number;
  totalSpent?: string;
  hireRate?: number;
  jobsPosted?: number;
  memberSince?: string;
}

export interface NormalizedJob {
  jobTitle: string;
  description: string;
  budget?: string;
  skills: string[];
  clientInfo?: ClientInfo;
  platform: 'upwork' | 'fiverr' | 'freelancer' | 'linkedin';
  url: string;
  scrapedAt: string;
  // Optional fields for different platforms
  duration?: string;
  experienceLevel?: string;
  projectType?: string;
  proposals?: number;
  connects?: number;
  isHourly?: boolean;
  hourlyRange?: string;
  fixedPrice?: string;
}

// ===== PROPOSAL TYPES =====

export interface ProposalSection {
  type: 'introduction' | 'scope' | 'timeline' | 'deliverables' | 'pricing' | 'experience' | 'faq' | 'guarantee' | 'cta' | 'terms';
  title: string;
  content: string;
}

export interface ProposalInsight {
  id: string;
  type: 'pain_point' | 'opportunity' | 'risk' | 'suggestion';
  title: string;
  description: string;
  importance: 'high' | 'medium' | 'low';
}

export interface ProposalResponse {
  proposalId?: string;
  proposal: string;
  suggestions: string[];
  confidence: number;
  sections?: ProposalSection[];
  insights?: ProposalInsight[];
  error?: string;
}

export interface SavedProposal {
  id: string;
  jobTitle: string;
  proposal: string;
  platform: string;
  createdAt: string;
  jobUrl?: string;
}

// ===== MESSAGE TYPES =====

export type ChromeMessageAction = 
  | 'PING'
  | 'SCRAPE_JOB'
  | 'GET_JOB_DATA'
  | 'LOG_ERROR'
  | 'AUTH_STATE_CHANGED'
  | 'SYNC_ACCOUNT_DATA'
  | 'SYNC_PROPOSALS'
  | 'AUTO_SCRAPE_PROFILE'
  | 'SCRAPING_STATUS'
  | 'GENERATE_PROPOSAL'
  | 'SCRAPE_START'
  | 'SCRAPE_STEP'
  | 'SCRAPE_COMPLETE'
  | 'SCRAPE_ERROR'
  | 'SCRAPE_STATE_CHANGED';

export interface ChromeMessage {
  action: ChromeMessageAction;
  type?: string; // For legacy support
  data?: any;
  payload?: any;
}

export interface ChromeMessageResponse {
  success?: boolean;
  error?: string;
  data?: any;
  message?: string;
}

// ===== PROFILE TYPES =====

export interface UpworkProfile {
  displayName: string;
  title?: string;
  hourlyRate?: number;
  location?: string;
  jobSuccessScore?: number;
  totalEarnings?: string;
  totalJobs?: number;
  totalHours?: number;
  rating?: number;
  reviewCount?: number;
  bio?: string;
  skills?: string[];
  portfolio?: PortfolioItem[];
  profileUrl?: string;
  profileImage?: string;
  memberSince?: string;
  responseTime?: string;
  availability?: string;
  categories?: string[];
  languages?: string[];
  topRated?: boolean;
  risingTalent?: boolean;
  scrapedAt?: string;
}

export interface PortfolioItem {
  title: string;
  description?: string;
  image?: string;
  url?: string;
  skills?: string[];
  completedDate?: string;
}

export interface FiverrProfile {
  displayName: string;
  sellerLevel?: string;
  rating?: number;
  reviewCount?: number;
  totalOrders?: number;
  location?: string;
  bio?: string;
  skills?: string[];
  languages?: string[];
  responseTime?: string;
  profileImage?: string;
  memberSince?: string;
  scrapedAt?: string;
}

export interface FreelancerProfile {
  displayName: string;
  title?: string;
  hourlyRate?: number;
  rating?: number;
  reviewCount?: number;
  completedProjects?: number;
  location?: string;
  bio?: string;
  skills?: string[];
  earnings?: string;
  profileImage?: string;
  memberSince?: string;
  scrapedAt?: string;
}

// ===== STORAGE TYPES =====

export interface ExtensionStorage {
  // Auth
  authToken?: string;
  userId?: string;
  userEmail?: string;
  lastAuthSync?: number;
  
  // Settings
  consent?: boolean;
  localMode?: boolean;
  syncEnabled?: boolean;
  
  // Current job
  currentJob?: NormalizedJob;
  
  // Profiles
  upworkProfile?: UpworkProfile;
  upworkProfileUrl?: string;
  fiverrProfile?: FiverrProfile;
  freelancerProfile?: FreelancerProfile;
  
  // Proposals
  upworkProposals?: ProposalSubmission[];
  savedProposals?: SavedProposal[];
  
  // Sync
  lastSync?: string;
  lastSyncResults?: SyncResults;
  
  // Errors
  errors?: ErrorLog[];
}

export interface SyncResults {
  upwork: { profile: boolean; proposals: boolean };
  fiverr: { profile: boolean };
  freelancer: { profile: boolean };
}

export interface ErrorLog {
  type: string;
  message: string;
  stack?: string;
  context?: any;
  timestamp: number;
}

// ===== PROPOSAL TRACKING TYPES =====

export interface ProposalSubmission {
  id?: string;
  jobTitle: string;
  jobUrl: string;
  proposalText: string;
  submittedAt: string;
  platform: 'upwork' | 'fiverr' | 'freelancer' | 'linkedin';
  status?: 'submitted' | 'viewed' | 'responded' | 'hired' | 'rejected';
  clientName?: string;
  bidAmount?: string;
  connects?: number;
}

// ===== ACCOUNT SYNC TYPES =====

export interface AccountSyncRequest {
  userId: string;
  platform: 'upwork' | 'fiverr' | 'freelancer' | 'linkedin';
  profileData: UpworkProfile | FiverrProfile | FreelancerProfile;
  timestamp: string;
}

export interface AccountSyncResponse {
  success: boolean;
  message?: string;
  syncedAt?: string;
  error?: string;
}

// ===== TEMPLATE TYPES =====

export interface ProposalTemplate {
  id: string;
  name: string;
  category: string;
  tone: 'professional' | 'friendly' | 'persuasive' | 'formal';
  sections: string[];
  previewText: string;
  usageCount?: number;
}

// ===== SETTINGS TYPES =====

export interface ExtensionSettings {
  autoScrape: boolean;
  defaultTone: 'professional' | 'friendly' | 'persuasive' | 'formal';
  defaultLength: 'short' | 'medium' | 'long';
  notifications: boolean;
  syncInterval: number; // minutes
  debugMode: boolean;
}

// ===== API REQUEST/RESPONSE TYPES =====

export interface GenerateProposalRequest {
  jobTitle: string;
  jobDescription: string;
  platform: string;
  tone?: string;
  selectedSections?: string[];
  clientName?: string;
  budget?: string;
  _idToken?: string;
}

export interface GenerateProposalResponse {
  success: boolean;
  data?: {
    id: string;
    content: string;
    sections: ProposalSection[];
    insights: ProposalInsight[];
  };
  error?: string;
}

// ===== SCRAPING STATE MACHINE TYPES =====

export type ScrapeState = 
  | 'idle' 
  | 'opening' 
  | 'scraping' 
  | 'validating' 
  | 'syncing' 
  | 'complete' 
  | 'error' 
  | 'cancelled';

export type ScrapeStep = 
  | 'opening_profile'
  | 'extracting_name'
  | 'extracting_title'
  | 'extracting_bio'
  | 'extracting_rate'
  | 'extracting_location'
  | 'extracting_skills'
  | 'extracting_stats'
  | 'extracting_portfolio'
  | 'validating_data'
  | 'syncing_to_backend';

export interface ScrapingProgress {
  step: ScrapeStep;
  progress: number; // 0-100
  message: string;
  startedAt: number;
}

export interface ScrapeStateData {
  state: ScrapeState;
  progress: number; // 0-100
  currentStep?: ScrapingProgress;
  steps: ScrapingProgress[];
  profileData?: any;
  error?: string;
  errorStep?: ScrapeStep;
  canRetry?: boolean;
  duration?: number;
  startedAt?: number;
  completedAt?: number;
}

export interface ScrapeMessage {
  action: string;
  data?: any;
}

export interface TabInfo {
  tabId: number;
  windowId: number;
  profileUrl: string;
  createdAt: number;
}
