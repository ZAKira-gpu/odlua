import type { NormalizedJob } from '../types';
import type { FreelancerProfile } from '../../../types';

/**
 * ===== INLINE SCRAPER UTILITIES =====
 */

function sanitizeText(text: string): string {
  return text
    .replace(/<[^>]*>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function validateJobData(job: Partial<NormalizedJob>): job is NormalizedJob {
  return Boolean(
    job.jobTitle &&
    job.jobTitle.length > 3 &&
    job.description &&
    job.description.length > 50 &&
    job.platform &&
    job.url
  );
}

function getTextContent(selector: string): string | null {
  try {
    const element = document.querySelector(selector);
    return element ? sanitizeText(element.textContent || '') : null;
  } catch (error) {
    console.error(`Error getting text content for selector: ${selector}`, error);
    return null;
  }
}

function getMultipleTextContent(selector: string): string[] {
  try {
    const elements = document.querySelectorAll(selector);
    return Array.from(elements)
      .map(el => sanitizeText(el.textContent || ''))
      .filter(text => text.length > 0);
  } catch (error) {
    console.error(`Error getting multiple text content for selector: ${selector}`, error);
    return [];
  }
}

function waitForElement(selector: string, timeout = 5000): Promise<Element | null> {
  return new Promise((resolve) => {
    const element = document.querySelector(selector);
    if (element) {
      resolve(element);
      return;
    }

    const observer = new MutationObserver(() => {
      const element = document.querySelector(selector);
      if (element) {
        observer.disconnect();
        resolve(element);
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    setTimeout(() => {
      observer.disconnect();
      resolve(null);
    }, timeout);
  });
}

function logScrapingError(platform: string, error: Error, context?: any): void {
  console.error(`[Propelo] Scraping error on ${platform}:`, error);
  
  try {
    chrome.runtime.sendMessage({
      action: 'LOG_ERROR',
      data: {
        message: error.message,
        stack: error.stack,
        context: {
          platform,
          url: window.location.href,
          ...context
        },
        timestamp: Date.now()
      }
    });
  } catch (e) {
    console.error('[Propelo] Failed to log error:', e);
  }
}

/**
 * ===== FREELANCER SCRAPER =====
 */

/**
 * Safe text extractor with multiple fallback strategies
 */
function extractText(...selectors: string[]): string {
  for (const selector of selectors) {
    try {
      const elements = document.querySelectorAll(selector);
      for (const element of elements) {
        const text = element.textContent?.trim();
        if (text && text.length > 0) {
          return sanitizeText(text);
        }
      }
    } catch (e) {
      // Continue to next selector
    }
  }
  return '';
}

/**
 * Extract number from text with multiple pattern matching
 */
function extractNumber(text: string): number | undefined {
  if (!text) return undefined;
  
  // Remove currency symbols and common words
  const cleaned = text
    .replace(/[€£¥₹$]/g, '')
    .replace(/USD|EUR|GBP|AUD/gi, '')
    .replace(/per hour|\/hr|hour/gi, '')
    .replace(/,/g, '');
  
  // Try to find a number
  const match = cleaned.match(/(\d+\.?\d*)/);
  if (match) {
    const num = parseFloat(match[1]);
    return isNaN(num) ? undefined : num;
  }
  
  return undefined;
}

/**
 * Scrape Freelancer profile data with extensive fallbacks
 */
async function scrapeFreelancerProfile(): Promise<FreelancerProfile | null> {
  try {




    // Wait for profile content to load
    await new Promise(resolve => setTimeout(resolve, 2000));

    // Profile Name - 20+ selectors
    const profileName = extractText(
      // Common patterns
      'h1.FreelancerInfo-userName',
      '.PageUserProfileView h1',
      '.user-profile h1',
      '.freelancer-name',
      '.profile-header h1',
      'h1[data-freelancer-name]',
      '[data-user-name]',
      // Generic heading patterns
      'header h1',
      'main h1',
      '.profile h1',
      '.user h1',
      // Class name patterns
      '[class*="userName"] h1',
      '[class*="UserName"]',
      '[class*="freelancer-name"]',
      '[class*="profile-name"]',
      // Attribute patterns
      '[itemprop="name"]',
      '[data-qa="freelancer-name"]',
      '[data-test="freelancer-name"]',
      // Fallback to any h1
      'h1'
    );



    // Title/Tagline - 15+ selectors
    const title = extractText(
      '.FreelancerInfo-tagline',
      '.user-tagline',
      '.profile-tagline',
      '.freelancer-title',
      'h2.tagline',
      '.professional-title',
      '[data-tagline]',
      '[class*="tagline"]',
      '[class*="headline"]',
      '[class*="title"]',
      'h1 + p',
      'h1 + div',
      '.profile-header p',
      '.user-profile .subtitle',
      'main h2'
    );



    // Bio/Description - 15+ selectors
    const bio = extractText(
      '.FreelancerInfo-description',
      '.profile-description',
      '.about-me',
      '.user-description',
      '.freelancer-bio',
      '[data-description]',
      '[class*="description"]',
      '[class*="about"]',
      '[class*="bio"]',
      '.profile-summary',
      '[itemprop="description"]',
      'section[aria-label*="About"] p',
      'section[aria-label*="Description"] p',
      '.user-profile p',
      'main p'
    );



    // Location - 15+ selectors
    const location = extractText(
      '.FreelancerInfo-location',
      '.user-location',
      '.profile-location',
      '.location',
      '[data-location]',
      '[class*="location"]',
      '[itemprop="addressLocality"]',
      '[itemprop="location"]',
      '.address',
      '.country',
      'span[title*="Location"]',
      '[aria-label*="location"]',
      '.user-details .location',
      '.profile-details .location',
      'svg[class*="location"] + span'
    );



    // Hourly Rate - 15+ selectors
    const hourlyRateText = extractText(
      '.FreelancerInfo-hourlyRate',
      '.hourly-rate',
      '.rate',
      '.price',
      '[data-rate]',
      '[class*="hourly-rate"]',
      '[class*="HourlyRate"]',
      '[class*="rate"]',
      '[class*="price"]',
      '.cost',
      '.pricing',
      'span[title*="hour"]',
      'div[title*="rate"]',
      '.user-stats .rate',
      '.profile-stats .rate'
    );
    const hourlyRate = extractNumber(hourlyRateText);



    // Rating - 20+ selectors
    const ratingText = extractText(
      '.FreelancerInfo-rating',
      '.rating-value',
      '.star-rating',
      '[data-rating]',
      '[class*="rating"]',
      '[class*="Rating"]',
      '[itemprop="ratingValue"]',
      '.review-rating',
      '.stars',
      'span[title*="star"]',
      'div[title*="rating"]',
      '[aria-label*="rating"]',
      '[aria-label*="stars"]',
      '.user-rating',
      '.profile-rating',
      // Look near review counts
      '.reviews + span',
      '.review-count + span',
      // Generic patterns
      'svg[class*="star"] + span',
      '.rating-badge',
      '.score'
    );
    const rating = extractNumber(ratingText);



    // Review Count - 15+ selectors
    const reviewsText = extractText(
      '.FreelancerInfo-reviewCount',
      '.review-count',
      '.reviews-count',
      '.num-reviews',
      '[data-reviews]',
      '[class*="review-count"]',
      '[class*="reviewCount"]',
      '[class*="reviews"]',
      '[itemprop="reviewCount"]',
      '.total-reviews',
      'span[title*="review"]',
      '[aria-label*="review"]',
      '.user-reviews',
      '.profile-reviews',
      'a[href*="reviews"]'
    );
    const reviewCount = extractNumber(reviewsText);



    // Completed Projects - 15+ selectors
    const completedText = extractText(
      '.FreelancerInfo-completedProjects',
      '.completed-projects',
      '.projects-completed',
      '.total-projects',
      '[data-completed]',
      '[class*="completed"]',
      '[class*="projects"]',
      '.project-count',
      '.jobs-completed',
      'span[title*="completed"]',
      'span[title*="project"]',
      '[aria-label*="completed"]',
      '.user-stats .projects',
      '.profile-stats .projects',
      'strong'
    );
    const completedProjects = extractNumber(completedText);



    // Earnings - 15+ selectors
    const earningsText = extractText(
      '.FreelancerInfo-earnings',
      '.total-earnings',
      '.earnings',
      '.total-earned',
      '[data-earnings]',
      '[class*="earnings"]',
      '[class*="earned"]',
      '.revenue',
      '.income',
      'span[title*="earned"]',
      'span[title*="earning"]',
      '[aria-label*="earnings"]',
      '.user-stats .earnings',
      '.profile-stats .earnings',
      '.financial-stats'
    );
    const earnings = extractNumber(earningsText);



    // Member Since - 15+ selectors
    const memberSince = extractText(
      '.FreelancerInfo-memberSince',
      '.member-since',
      '.joined-date',
      '.registration-date',
      '[data-member-since]',
      '[class*="member-since"]',
      '[class*="memberSince"]',
      '[class*="joined"]',
      'time',
      'span[title*="member"]',
      'span[title*="joined"]',
      '[aria-label*="member since"]',
      '.user-details .date',
      '.profile-details .date',
      'small'
    );



    // Skills - Multiple selector strategies
    let skills: string[] = [];
    const skillSelectors = [
      '.FreelancerInfo-skills .skill',
      '.skills-list .skill',
      '.skill-tag',
      '.skill-badge',
      '[data-skill]',
      '[class*="skill"] a',
      '[class*="skill"] span',
      '[class*="skill"] li',
      'section[aria-label*="Skills"] a',
      'section[aria-label*="Skills"] span',
      '.user-skills a',
      '.profile-skills a',
      'a[href*="skills"]',
      '.badge',
      '.tag'
    ];

    for (const selector of skillSelectors) {
      const elements = document.querySelectorAll(selector);
      if (elements.length > 0) {
        skills = Array.from(elements)
          .map(el => sanitizeText(el.textContent || ''))
          .filter(s => s && s.length > 1 && s.length < 50);
        if (skills.length > 0) {

          break;
        }
      }
    }



    // Profile Picture - 15+ selectors
    let profileImage: string | undefined;
    const imageSelectors = [
      '.FreelancerInfo-avatar img',
      '.user-avatar img',
      '.profile-avatar img',
      '.avatar img',
      '[class*="avatar"] img',
      '[class*="Avatar"] img',
      '.profile-picture img',
      '.user-picture img',
      '[data-avatar] img',
      'img[alt*="profile"]',
      'img[alt*="avatar"]',
      'header img',
      '.profile-header img',
      '.user-header img',
      'main img'
    ];

    for (const selector of imageSelectors) {
      const img = document.querySelector(selector) as HTMLImageElement;
      if (img?.src && !img.src.includes('placeholder') && !img.src.includes('default')) {
        profileImage = img.src;
        break;
      }
    }



    // Construct profile data
    const profileData: FreelancerProfile = {
      platform: 'freelancer',
      username: extractProfileId() || 'unknown',
      displayName: profileName || 'Unknown User',
      profileUrl: window.location.href,
      profileImage,
      location: location || undefined,
      rating,
      reviewCount,
      completedProjects,
      hourlyRate,
      earnings,
      skills,
      categories: [],
      portfolio: [],
      bio: bio || undefined,
      tagline: title || undefined,
      memberSince: memberSince || undefined,
      certifications: [],
      languages: [],
      scrapedAt: new Date(),
      scrapedFrom: window.location.href
    };

    // Send to background for syncing
    try {
      chrome.runtime.sendMessage({
        action: 'SYNC_ACCOUNT_DATA',
        data: {
          platform: 'freelancer',
          profileData
        }
      });

    } catch (error) {
      console.error('[Propelo Freelancer Profile] ❌ Failed to send to background:', error);
    }

    return profileData;

  } catch (error) {
    console.error('[Propelo Freelancer Profile] ❌ Fatal error:', error);
    logScrapingError('freelancer-profile', error as Error, {
      url: window.location.href
    });
    return null;
  }
}

/**
 * Extract profile ID from URL
 */
function extractProfileId(): string {
  const match = window.location.pathname.match(/\/u\/([^/]+)/);
  return match ? match[1] : window.location.pathname.split('/').pop() || '';
}

/**
 * Detect if current page is a profile page
 */
function isProfilePage(): boolean {
  return window.location.pathname.includes('/u/') || 
         window.location.pathname.includes('/users/') ||
         document.querySelector('.user-profile, .freelancer-profile') !== null;
}

/**
 * Detect if current page is a project page
 */
function isProjectPage(): boolean {
  return window.location.pathname.includes('/projects/') ||
         document.querySelector('.PageProjectViewLogout-header, .project-title') !== null;
}

/**
 * Scrape job data from Freelancer project page
 */
function scrapeFreelancerJob(): NormalizedJob | null {
  try {


    // Job title - multiple possible selectors
    const jobTitle = 
      getTextContent('.PageProjectViewLogout-header h1') ||
      getTextContent('.project-title') ||
      getTextContent('h1[class*="project"]') ||
      getTextContent('.job-title') ||
      getTextContent('h1.title');

    // Job description
    const description = 
      getTextContent('.PageProjectViewLogout-description') ||
      getTextContent('.project-description') ||
      getTextContent('.description-text') ||
      getTextContent('[class*="description"]') ||
      getTextContent('.project-detail');

    // Budget
    const budget = 
      getTextContent('.PageProjectViewLogout-budget') ||
      getTextContent('.project-budget') ||
      getTextContent('.job-salary') ||
      getTextContent('[class*="budget"]') ||
      getTextContent('.price-range');

    // Skills
    let skills = 
      getMultipleTextContent('.PageProjectViewLogout-skills .Tag') ||
      getMultipleTextContent('.skill-tag') ||
      getMultipleTextContent('.project-skills .skill') ||
      getMultipleTextContent('[class*="skill"]') ||
      getMultipleTextContent('.tag-item');

    // Client information
    const clientName = 
      getTextContent('.employer-name') ||
      getTextContent('.client-name') ||
      getTextContent('[class*="employer"]');

    const clientRating = 
      getTextContent('.employer-rating') ||
      getTextContent('.client-rating') ||
      getTextContent('[class*="rating"]');

    const clientLocation = 
      getTextContent('.employer-location') ||
      getTextContent('.client-location') ||
      getTextContent('[class*="location"]');

    // Validation
    if (!jobTitle || !description) {

      return null;
    }

    const jobData: NormalizedJob = {
      jobTitle: jobTitle,
      description: description,
      budget: budget || undefined,
      skills: skills,
      clientInfo: {
        name: clientName || undefined,
        rating: clientRating ? parseFloat(clientRating) : undefined,
        location: clientLocation || undefined
      },
      platform: 'freelancer',
      url: window.location.href,
      scrapedAt: new Date().toISOString()
    };

    if (validateJobData(jobData)) {

      return jobData;
    }


    return null;

  } catch (error) {
    logScrapingError('freelancer', error as Error, {
      url: window.location.href
    });
    return null;
  }
}

/**
 * Initialize scraper when page loads
 */
async function initFreelancerScraper(): Promise<void> {


  // Check if it's a profile page
  if (isProfilePage()) {

    
    // Wait for profile content to load
    await waitForElement('.user-profile h1, .freelancer-name, .profile-header h1', 10000);
    
    // Give additional time for dynamic content
    setTimeout(async () => {
      const profileData = await scrapeFreelancerProfile();
      
      if (profileData) {
        // Store scraped data
        chrome.storage.local.set({ freelancerProfile: profileData });

      } else {

      }
    }, 2000);
    
    return;
  }

  // Check if it's a project page
  if (isProjectPage()) {

    
    // Wait for project content to load
    await waitForElement('.PageProjectViewLogout-header h1, .project-title, h1[class*="project"]', 10000);

    // Give additional time for dynamic content
    setTimeout(() => {
      const jobData = scrapeFreelancerJob();
      
      if (jobData) {
        // Store scraped data
        chrome.storage.local.set({ currentJob: jobData });
        

      } else {

      }
    }, 2000);
  }
}

/**
 * Listen for messages from popup
 */
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.action === 'GET_JOB_DATA') {
    chrome.storage.local.get(['currentJob'], (result) => {
      if (result.currentJob) {
        sendResponse(result.currentJob);
      } else {
        // Try to scrape if not already cached
        const jobData = scrapeFreelancerJob();
        if (jobData) {
          chrome.storage.local.set({ currentJob: jobData });
          sendResponse(jobData);
        } else {
          sendResponse(null);
        }
      }
    });
    return true; // Keep channel open for async response
  }
});

// Initialize scraper when page loads
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initFreelancerScraper);
} else {
  initFreelancerScraper();
}

// Re-scrape on URL changes (for SPA navigation)
let lastUrl = window.location.href;
new MutationObserver(() => {
  const currentUrl = window.location.href;
  if (currentUrl !== lastUrl) {
    lastUrl = currentUrl;

    initFreelancerScraper();
  }
}).observe(document.body, { childList: true, subtree: true });

export {};
