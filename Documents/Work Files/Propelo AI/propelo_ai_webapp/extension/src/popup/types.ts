// Tab types
export type TabType = 'generate' | 'history' | 'settings';

// Tone types
export type ToneType = 'professional' | 'friendly' | 'confident' | 'direct' | 'enthusiastic';

// User data from auth
export interface UserData {
  email: string;
  name?: string;
  firstName?: string;
  photoURL?: string;
  plan?: 'free' | 'pro';
  profileImage?: string;
  accounts?: Record<string, any>;
}

// Job data extracted from page
export interface JobData {
  title: string;
  description: string;
  budget?: string;
  skills?: string[];
  clientInfo?: {
    name?: string;
    rating?: string;
    spent?: string;
    location?: string;
    hireRate?: string;
    jobsPosted?: string;
    paymentVerified?: boolean;
  };
  url?: string;
  platform?: string;
  duration?: string;
  experienceLevel?: string;
  projectType?: string;
}

// History item
export interface HistoryItem {
  id: string;
  jobTitle: string;
  proposal: string;
  timestamp: number;
  platform?: string;
  tone?: string;
  language?: string;
}

// Template configuration
export interface Template {
  id: string;
  name: string;
  tone: string;
  style: string;
  icon?: string;
}

// Generation options
export interface GenerationOptions {
  tone: ToneType;
  language: string;
  selectedSections: string[];
  customInstructions?: string;
  includePortfolio?: boolean;
}

// Available languages
export const LANGUAGES = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'es', name: 'Spanish', flag: '🇪🇸' },
  { code: 'fr', name: 'French', flag: '🇫🇷' },
  { code: 'de', name: 'German', flag: '🇩🇪' },
  { code: 'it', name: 'Italian', flag: '🇮🇹' },
  { code: 'pt', name: 'Portuguese', flag: '🇵🇹' },
  { code: 'ar', name: 'Arabic', flag: '🇸🇦' },
  { code: 'zh', name: 'Chinese', flag: '🇨🇳' },
];

// Available tones
export const TONES: { id: ToneType; name: string; icon: string; description: string }[] = [
  { id: 'professional', name: 'Professional', icon: '💼', description: 'Formal and business-like' },
  { id: 'friendly', name: 'Friendly', icon: '👋', description: 'Warm and approachable' },
  { id: 'confident', name: 'Confident', icon: '🎯', description: 'Bold and assertive' },
  { id: 'direct', name: 'Direct', icon: '⚡', description: 'Concise and to the point' },
  { id: 'enthusiastic', name: 'Enthusiastic', icon: '🚀', description: 'Energetic and excited' },
];

// Available sections
export const SECTIONS = [
  { id: 'introduction', name: 'Introduction', description: 'Opening and greeting' },
  { id: 'approach', name: 'Approach', description: 'How you\'ll tackle the project' },
  { id: 'experience', name: 'Experience', description: 'Relevant background' },
  { id: 'timeline', name: 'Timeline', description: 'Project schedule' },
  { id: 'deliverables', name: 'Deliverables', description: 'What you\'ll provide' },
  { id: 'pricing', name: 'Pricing', description: 'Cost breakdown' },
  { id: 'cta', name: 'Call to Action', description: 'Closing and next steps' },
  { id: 'questions', name: 'Questions', description: 'Clarifying questions' },
];

// Platform configurations
export const PLATFORMS = {
  upwork: { 
    name: 'Upwork', 
    gradient: 'from-emerald-500 to-green-500',
    bg: 'bg-emerald-50',
    border: 'border-emerald-200',
    icon: '💼' 
  },
  freelancer: { 
    name: 'Freelancer', 
    gradient: 'from-cyan-500 to-blue-500',
    bg: 'bg-cyan-50',
    border: 'border-cyan-200',
    icon: '🌐' 
  },
  fiverr: { 
    name: 'Fiverr', 
    gradient: 'from-green-500 to-emerald-500',
    bg: 'bg-green-50',
    border: 'border-green-200',
    icon: '⭐' 
  },
  other: { 
    name: 'Other', 
    gradient: 'from-violet-500 to-purple-500',
    bg: 'bg-violet-50',
    border: 'border-violet-200',
    icon: '📋' 
  },
};
