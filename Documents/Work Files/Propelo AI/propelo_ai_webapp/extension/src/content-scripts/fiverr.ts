import type { NormalizedJob } from '../types';
import type { FiverrProfile } from '../../../types';

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
 * ===== FIVERR SCRAPER =====
 */

/**
 * Scrape job data from Fiverr gig/buyer request page
 */
function scrapeFiverrJob(): NormalizedJob | null {
  try {


    // Job title - gig title or request title
    const jobTitle = 
      getTextContent('.gig-title') ||
      getTextContent('.page-title') ||
      getTextContent('h1[class*="title"]') ||
      getTextContent('.main-title');

    // Job description
    const description = 
      getTextContent('.description-content') ||
      getTextContent('.gig-desc') ||
      getTextContent('.description-wrapper') ||
      getTextContent('[class*="description"]') ||
      getTextContent('.questions-container');

    // Budget/Price
    const budget = 
      getTextContent('.price-wrapper') ||
      getTextContent('.package-price') ||
      getTextContent('[class*="price"]') ||
      getTextContent('.budget-amount');

    // Skills/Tags
    let skills = 
      getMultipleTextContent('.tags-wrapper .tag') ||
      getMultipleTextContent('.tag-item') ||
      getMultipleTextContent('[class*="tag"]') ||
      getMultipleTextContent('.skill-tag');

    // Seller/Client information
    const clientName = 
      getTextContent('.seller-profile .username') ||
      getTextContent('.buyer-name') ||
      getTextContent('[class*="username"]');

    const clientRating = getTextContent('.rating-score') || getTextContent('.seller-rating');
    const clientLocation = getTextContent('.seller-location') || getTextContent('[class*="location"]');

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
      platform: 'fiverr',
      url: window.location.href,
      scrapedAt: new Date().toISOString()
    };

    if (validateJobData(jobData)) {

      return jobData;
    }


    return null;

  } catch (error) {
    logScrapingError('fiverr', error as Error, {
      url: window.location.href
    });
    return null;
  }
}

/**
 * Initialize scraper when page loads
 */
async function initFiverrScraper(): Promise<void> {


  // Wait for gig content to load
  await waitForElement('.gig-title, .page-title, h1[class*="title"]', 10000);

  // Give additional time for dynamic content
  setTimeout(() => {
    const jobData = scrapeFiverrJob();
    
    if (jobData) {
      // Store scraped data
      chrome.storage.local.set({ currentJob: jobData });
      

    } else {

    }
  }, 2000);
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
        const jobData = scrapeFiverrJob();
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
  document.addEventListener('DOMContentLoaded', initFiverrScraper);
} else {
  initFiverrScraper();
}

// Re-scrape on URL changes (for SPA navigation)
let lastUrl = window.location.href;
new MutationObserver(() => {
  const currentUrl = window.location.href;
  if (currentUrl !== lastUrl) {
    lastUrl = currentUrl;

    
    // Check if we're on profile page
    if (currentUrl.includes('/users/') || currentUrl.includes('/sellers/')) {

      scrapeAndSyncFiverrProfile();
    } else {
      // Regular gig/job page
      initFiverrScraper();
    }
  }
}).observe(document.body, { childList: true, subtree: true });

/**
 * ===== FIVERR PROFILE SCRAPER =====
 * Scrapes comprehensive profile data from Fiverr seller profiles
 */
async function scrapeFiverrProfile(): Promise<FiverrProfile | null> {
  try {



    // Wait for profile content to load
    await waitForElement('.seller-card, .user-profile-info, [data-profile-card]', 10000);

    // Basic Info
    const username = getTextContent('[data-username]') ||
                    getTextContent('.username') ||
                    getTextContent('.seller-name') || 
                    '';
    
    const displayName = getTextContent('.seller-card .display-name') ||
                       getTextContent('.user-profile-name') ||
                       username;
    
    const profileImage = document.querySelector('.user-profile-image img')?.getAttribute('src') ||
                        document.querySelector('.seller-avatar img')?.getAttribute('src') || 
                        '';

    const location = getTextContent('.location') ||
                    getTextContent('[data-location]') ||
                    getTextContent('.user-stats-desc:contains("From")') ||
                    '';

    // Seller Level
    let sellerLevel: FiverrProfile['sellerLevel'] = 'new';
    const levelText = document.body.textContent?.toLowerCase() || '';
    if (levelText.includes('top rated')) sellerLevel = 'top_rated';
    else if (levelText.includes('level 2') || levelText.includes('level two')) sellerLevel = 'level_two';
    else if (levelText.includes('level 1') || levelText.includes('level one')) sellerLevel = 'level_one';

    // Stats
    const ratingText = getTextContent('.rating-score') ||
                       getTextContent('[data-rating]') ||
                       getTextContent('.seller-stats .rating') ||
                       '';
    const rating = ratingText ? parseFloat(ratingText.replace(/[^0-9.]/g, '')) : undefined;

    const reviewCountText = getTextContent('.reviews-count') ||
                           getTextContent('[data-reviews]') ||
                           getTextContent('.total-rating-breakdown') ||
                           '';
    const reviewCount = reviewCountText ? parseInt(reviewCountText.replace(/[^0-9]/g, '')) : undefined;

    const ordersText = getTextContent('[data-orders]') ||
                      getTextContent('.total-orders') ||
                      '';
    const totalOrders = ordersText ? parseInt(ordersText.replace(/[^0-9]/g, '')) : undefined;

    // Gigs
    const gigElements = document.querySelectorAll('[data-gig-card], .gig-card, .seller-gig');
    const activeGigs = gigElements.length;

    const gigCategories = Array.from(new Set(
      getMultipleTextContent('[data-gig-category], .gig-category, .category-tag')
    ));

    // Skills
    const skills = getMultipleTextContent('[data-skill], .skill-tag, .profile-skills .tag');

    // Languages
    const languageElements = document.querySelectorAll('[data-language], .language-item');
    const languages = Array.from(languageElements).map(el => {
      const name = el.querySelector('[data-language-name]')?.textContent?.trim() ||
                   el.textContent?.split('-')[0]?.trim() || '';
      const proficiency = el.querySelector('[data-language-level]')?.textContent?.trim().toLowerCase() ||
                         el.textContent?.split('-')[1]?.trim().toLowerCase() || 
                         'conversational';
      return {
        name,
        proficiency: proficiency as 'basic' | 'conversational' | 'fluent' | 'native'
      };
    }).filter(lang => lang.name);

    // Response & Delivery Times
    const responseTime = getTextContent('[data-response-time]') ||
                         getTextContent('.response-time') ||
                         '';
    
    const deliveryTime = getTextContent('[data-delivery-time]') ||
                         getTextContent('.delivery-time') ||
                         '';

    // Bio/Description
    const bio = getTextContent('.description-content') ||
                getTextContent('[data-description]') ||
                getTextContent('.seller-description') ||
                '';

    // Member Since
    const memberSince = getTextContent('[data-member-since]') ||
                        getTextContent('.member-since') ||
                        '';

    // Certifications
    const certifications = getMultipleTextContent('[data-certification], .certification-badge, .achievement-badge');

    // Recent Reviews
    const reviewElements = document.querySelectorAll('[data-review-card], .review-item, .review-card');
    const recentReviews = Array.from(reviewElements).slice(0, 5).map(el => {
      const ratingEl = el.querySelector('[data-review-rating]')?.textContent?.trim() || '0';
      const rating = parseFloat(ratingEl.replace(/[^0-9.]/g, ''));
      const comment = el.querySelector('[data-review-comment]')?.textContent?.trim() || 
                     el.querySelector('.review-description')?.textContent?.trim() || '';
      const buyerName = el.querySelector('[data-buyer-name]')?.textContent?.trim() ||
                       el.querySelector('.reviewer-name')?.textContent?.trim() || '';
      const date = el.querySelector('[data-review-date]')?.textContent?.trim() || '';
      const gigTitle = el.querySelector('[data-gig-title]')?.textContent?.trim() || '';
      return { rating, comment, buyerName, date, gigTitle };
    }).filter(review => review.comment);

    const profileData: FiverrProfile = {
      platform: 'fiverr',
      username,
      displayName,
      profileImage,
      location,
      profileUrl: window.location.href,
      
      sellerLevel,
      rating,
      reviewCount,
      totalOrders,
      
      activeGigs,
      gigCategories,
      
      skills,
      languages,
      
      responseTime,
      deliveryTime,
      
      bio,
      memberSince,
      certifications,
      recentReviews,
      
      scrapedAt: new Date(),
      scrapedFrom: window.location.href
    };







    return profileData;

  } catch (error) {
    console.error('[Propelo Fiverr Profile] ❌ Scraping error:', error);
    logScrapingError('fiverr-profile', error as Error, { url: window.location.href });
    return null;
  }
}

/**
 * Scrape and sync Fiverr profile data to web app
 */
async function scrapeAndSyncFiverrProfile(): Promise<void> {

  
  const profileData = await scrapeFiverrProfile();
  
  if (profileData) {
    // Store in Chrome storage
    chrome.storage.local.set({ 
      fiverrProfile: profileData,
      lastProfileSync: new Date().toISOString()
    });

    // Send to background script for API sync
    chrome.runtime.sendMessage({
      action: 'SYNC_ACCOUNT_DATA',
      data: {
        platform: 'fiverr',
        profileData
      }
    });


  }
}

// Check page type on load
if (window.location.href.includes('/users/') || window.location.href.includes('/sellers/')) {

  scrapeAndSyncFiverrProfile();
}

export {};
