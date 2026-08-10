// Analytics event types
export interface AnalyticsEvent {
  id: string;
  proposalId: string;
  eventType: 'view' | 'time_spent' | 'scroll_depth' | 'link_click' | 'copy';
  timestamp: Date;
  metadata?: {
    duration?: number; // milliseconds
    scrollPercentage?: number;
    linkUrl?: string;
    userAgent?: string;
    referrer?: string;
  };
}

// Proposal analytics summary
export interface ProposalAnalytics {
  proposalId: string;
  totalViews: number;
  uniqueViews: number;
  averageTimeSpent: number; // seconds
  maxScrollDepth: number; // percentage
  linkClicks: number;
  copyCount: number;
  viewsByDate: Record<string, number>; // YYYY-MM-DD -> count
  lastViewedAt?: Date;
  createdAt: Date;
}

// User analytics summary
export interface UserAnalytics {
  userId: string;
  totalProposals: number;
  totalViews: number;
  totalAccepted: number;
  winRate: number; // percentage
  averageViewsPerProposal: number;
  topPerformingProposal?: {
    id: string;
    title: string;
    views: number;
  };
  platformStats: {
    platform: string;
    proposals: number;
    winRate: number;
  }[];
  monthlyStats: {
    month: string; // YYYY-MM
    proposals: number;
    accepted: number;
    views: number;
  }[];
}
