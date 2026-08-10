/**
 * Page Context Detection Utility
 * 
 * Detects what type of Upwork page the user is currently viewing
 * Uses both URL patterns and DOM structure for accuracy
 */

export type PageContextType = 
  | 'freelancer-profile'  // User's own or other freelancer profile
  | 'job-posting'         // Job posting page
  | 'client-profile'      // Client profile (ignore)
  | 'proposals'           // Proposals page
  | 'other';              // Unknown/other page

export interface PageContext {
  type: PageContextType;
  url: string;
  platform: 'upwork' | 'fiverr' | 'freelancer' | 'other';
  isOwnProfile: boolean;  // True if viewing own profile
  confidence: 'high' | 'medium' | 'low';
  metadata?: {
    profileId?: string;
    jobId?: string;
    title?: string;
  };
}

/**
 * Detect page context from current tab
 */
export async function detectPageContext(): Promise<PageContext> {
  try {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    if (!tab.url || !tab.id) {
      return createContext('other', '', 'other', false, 'low');
    }

    const url = tab.url;
    
    // Determine platform
    const platform = getPlatform(url);
    
    if (platform === 'other') {
      return createContext('other', url, 'other', false, 'low');
    }

    // Execute DOM-based detection on the page
    const domContext = await detectFromDOM(tab.id, url);
    
    return {
      ...domContext,
      url,
      platform,
    };
  } catch (error) {
    console.error('[PageContext] Detection error:', error);
    return createContext('other', '', 'other', false, 'low');
  }
}

/**
 * Get platform from URL
 */
function getPlatform(url: string): 'upwork' | 'fiverr' | 'freelancer' | 'other' {
  if (url.includes('upwork.com')) return 'upwork';
  if (url.includes('fiverr.com')) return 'fiverr';
  if (url.includes('freelancer.com')) return 'freelancer';
  return 'other';
}

/**
 * Detect context using DOM inspection
 */
async function detectFromDOM(tabId: number, url: string): Promise<Omit<PageContext, 'url' | 'platform'>> {
  try {
    const results = await chrome.scripting.executeScript({
      target: { tabId },
      func: detectContextFromPage,
      args: [url],
    });

    if (results?.[0]?.result) {
      return results[0].result;
    }
  } catch (error) {
    console.error('[PageContext] DOM detection failed:', error);
  }

  // Fallback to URL-only detection
  return detectFromURLOnly(url);
}

/**
 * This function runs in the context of the web page
 */
function detectContextFromPage(url: string): Omit<PageContext, 'url' | 'platform'> {
  // Upwork URL patterns
  const isFreelancerProfile = /\/freelancers\/~[a-zA-Z0-9]+/.test(url);
  const isJobPage = /\/(jobs|job)\//.test(url) || 
                    /\/freelance-jobs\//.test(url) ||
                    /\/ab\/proposals\/job\//.test(url);
  const isProposalsPage = /\/proposals/.test(url) || /\/nx\/proposals/.test(url);
  const isClientProfile = /\/client\//.test(url) || /\/clients\//.test(url);
  
  // DOM-based checks for higher confidence
  let domType: PageContextType = 'other';
  let confidence: 'high' | 'medium' | 'low' = 'low';
  let isOwnProfile = false;
  let metadata: { profileId?: string; jobId?: string; title?: string } = {};

  // Check for freelancer profile page
  if (isFreelancerProfile) {
    // Look for profile-specific DOM elements
    const hasProfileHeader = !!(
      document.querySelector('[data-test="freelancer-name"]') ||
      document.querySelector('[data-qa="freelancer-name"]') ||
      document.querySelector('h1.up-n-link') ||
      document.querySelector('.profile-name') ||
      document.querySelector('[class*="FreelancerName"]')
    );
    
    const hasSkillsSection = !!(
      document.querySelector('[data-test="skill"]') ||
      document.querySelector('[data-qa="skill-name"]') ||
      document.querySelector('.skill-badge')
    );
    
    const hasHourlyRate = !!(
      document.querySelector('[data-test="hourly-rate"]') ||
      document.querySelector('[data-qa="hourly-rate"]') ||
      document.querySelector('[class*="hourly-rate"]')
    );

    if (hasProfileHeader || hasSkillsSection || hasHourlyRate) {
      domType = 'freelancer-profile';
      confidence = 'high';
      
      // Extract profile ID from URL
      const profileMatch = url.match(/\/freelancers\/~([a-zA-Z0-9]+)/);
      if (profileMatch) {
        metadata.profileId = profileMatch[1];
      }
      
      // Check if this is the user's own profile (look for edit button)
      isOwnProfile = !!(
        document.querySelector('[data-test="edit-profile"]') ||
        document.querySelector('button[aria-label*="Edit"]') ||
        document.querySelector('a[href*="/settings/"]') ||
        document.querySelector('[class*="edit-profile"]')
      );
    } else {
      domType = 'freelancer-profile';
      confidence = 'medium';
    }
  }
  
  // Check for job posting page
  else if (isJobPage) {
    const hasJobTitle = !!(
      document.querySelector('[data-test="job-title"]') ||
      document.querySelector('h1') ||
      document.querySelector('.job-title')
    );
    
    const hasJobDescription = !!(
      document.querySelector('[data-test="job-description"]') ||
      document.querySelector('.job-description') ||
      document.querySelector('[class*="JobDescription"]')
    );
    
    const hasApplyButton = !!(
      document.querySelector('[data-test="apply-button"]') ||
      document.querySelector('button[aria-label*="Apply"]') ||
      document.querySelector('button[class*="apply"]') ||
      document.querySelector('a[href*="apply"]')
    );

    if (hasJobTitle || hasJobDescription || hasApplyButton) {
      domType = 'job-posting';
      confidence = 'high';
      
      // Extract job title
      const titleEl = document.querySelector('[data-test="job-title"], h1');
      if (titleEl) {
        metadata.title = titleEl.textContent?.trim();
      }
    } else {
      domType = 'job-posting';
      confidence = 'medium';
    }
  }
  
  // Check for proposals page
  else if (isProposalsPage) {
    domType = 'proposals';
    confidence = 'medium';
  }
  
  // Check for client profile
  else if (isClientProfile) {
    domType = 'client-profile';
    confidence = 'medium';
  }

  return {
    type: domType,
    isOwnProfile,
    confidence,
    metadata,
  };
}

/**
 * Fallback URL-only detection
 */
function detectFromURLOnly(url: string): Omit<PageContext, 'url' | 'platform'> {
  if (/\/freelancers\/~[a-zA-Z0-9]+/.test(url)) {
    return { type: 'freelancer-profile', isOwnProfile: false, confidence: 'low' };
  }
  if (/\/(jobs|job)\//.test(url) || /\/freelance-jobs\//.test(url)) {
    return { type: 'job-posting', isOwnProfile: false, confidence: 'low' };
  }
  if (/\/proposals/.test(url)) {
    return { type: 'proposals', isOwnProfile: false, confidence: 'low' };
  }
  if (/\/client\//.test(url)) {
    return { type: 'client-profile', isOwnProfile: false, confidence: 'low' };
  }
  return { type: 'other', isOwnProfile: false, confidence: 'low' };
}

/**
 * Helper to create context object
 */
function createContext(
  type: PageContextType,
  url: string,
  platform: 'upwork' | 'fiverr' | 'freelancer' | 'other',
  isOwnProfile: boolean,
  confidence: 'high' | 'medium' | 'low',
  metadata?: PageContext['metadata']
): PageContext {
  return { type, url, platform, isOwnProfile, confidence, metadata };
}
