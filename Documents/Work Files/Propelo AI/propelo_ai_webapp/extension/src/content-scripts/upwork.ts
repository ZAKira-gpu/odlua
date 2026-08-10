import type { NormalizedJob } from '../types';
import type { UpworkProfile, ProposalSubmission } from '../../../types';
import { scrapeProfileFromDOM } from './profile-scraper';
import './scraper-events'; // Import the new scraper events handler

/**
 * ===== INLINE SCRAPER UTILITIES =====
 * These are inlined to avoid ES module import issues in Chrome content scripts
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
 * ===== UPWORK SCRAPER =====
 */
function scrapeUpworkJob(): NormalizedJob | null {
  try {


    
    // Debug: Log page structure
    const allHeadings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');

    // Try ALL possible selectors for job title
    const titleSelectors = [
      '[data-test="job-title"]',
      'h2.job-title',
      '.air3-heading-2',
      'h4[class*="job-title"]',
      'h2.h4',
      'h2[class*="heading"]',
      'h4[class*="heading"]',
      '.up-card-section h2',
      '.up-card-section h4',
      'article h2',
      'article h4',
      'main h2',
      'main h4'
    ];

    let jobTitle = null;
    for (const selector of titleSelectors) {
      jobTitle = getTextContent(selector);
      if (jobTitle && jobTitle.length > 5) {

        break;
      }
    }

    // Fallback: Try to get the largest heading text
    if (!jobTitle || jobTitle.length < 5) {

      const headings = Array.from(document.querySelectorAll('h1, h2, h3, h4'));
      const sortedByLength = headings
        .map(h => sanitizeText(h.textContent || ''))
        .filter(text => text.length > 10 && text.length < 200)
        .sort((a, b) => b.length - a.length);
      
      if (sortedByLength.length > 0) {
        jobTitle = sortedByLength[0];

      }
    }
    


    // Try ALL possible selectors for description
    const descriptionSelectors = [
      '[data-test="job-description"]',
      '[data-test="Description"]',
      '[data-qa="description"]',
      '.description',
      '[class*="description"]',
      '[class*="Description"]',
      '.up-card-section [class*="text"]',
      'section.air3-card-section',
      'article p',
      'main p',
      '[data-test="job-details"] p'
    ];

    let description = null;
    for (const selector of descriptionSelectors) {
      description = getTextContent(selector);
      if (description && description.length > 100) {

        break;
      }
    }

    // Fallback: Get all paragraphs and combine
    if (!description || description.length < 100) {

      const paragraphs = Array.from(document.querySelectorAll('p'))
        .map(p => sanitizeText(p.textContent || ''))
        .filter(text => text.length > 50);
      
      if (paragraphs.length > 0) {
        description = paragraphs.slice(0, 3).join(' '); // Take first 3 paragraphs

      }
    }
    


    // Budget information - try multiple selectors
    const budgetSelectors = [
      '[data-test="budget"]',
      '[data-test="Budget"]',
      '[data-test="is-fixed-price"]',
      '[data-test="is-hourly-price"]',
      '.budget',
      '[class*="budget"]',
      '[class*="price"]'
    ];

    let budget = null;
    for (const selector of budgetSelectors) {
      budget = getTextContent(selector);
      if (budget) break;
    }
    


    // Skills - try multiple selectors
    const skillsSelectors = [
      '[data-test="token"]',
      '[data-test="skill-item-stack"]',
      '.air3-token',
      '[class*="skill"]',
      '[class*="token"]',
      '[class*="tag"]'
    ];

    let skills: string[] = [];
    for (const selector of skillsSelectors) {
      skills = getMultipleTextContent(selector);
      if (skills.length > 0) {

        break;
      }
    }
    


    // Client information
    const clientName = getTextContent('[data-test="client-name"]');
    const clientRating = getTextContent('[data-test="client-rating"]');
    const clientLocation = getTextContent('[data-test="client-location"]');

    // More lenient validation - just need title OR description
    if (!jobTitle && !description) {


      return null;
    }

    // If we only have one, make it usable
    if (!jobTitle && description) {
      // Use first 100 chars of description as title
      jobTitle = description.substring(0, 100) + '...';

    }

    if (!description && jobTitle) {
      // Use title as description (better than nothing)
      description = jobTitle;

    }

    const jobData: NormalizedJob = {
      jobTitle: jobTitle!,
      description: description!,
      budget: budget || undefined,
      skills: skills,
      clientInfo: {
        name: clientName || undefined,
        rating: clientRating ? parseFloat(clientRating) : undefined,
        location: clientLocation || undefined
      },
      platform: 'upwork',
      url: window.location.href,
      scrapedAt: new Date().toISOString()
    };





    
    return jobData;

  } catch (error) {
    console.error('[Propelo Upwork] ❌ Scraping error:', error);
    logScrapingError('upwork', error as Error, {
      url: window.location.href
    });
    return null;
  }
}

/**
 * Initialize scraper when page loads
 * 
 * DISABLED: Job scraping no longer auto-runs on page load.
 * This is kept for backwards compatibility but should not be called.
 * Jobs are now scraped ONLY when explicitly requested via message.
 */
async function initUpworkScraper(): Promise<void> {
  // AUTO-SCRAPING DISABLED - see comment above
  return;
}

/**
 * Listen for messages from popup
 */
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {

  
  if (message.action === 'PING') {
    sendResponse({ success: true });
    return true;
  }

  if (message.action === 'GET_JOB_DATA') {

    
    // First check if we have cached data
    chrome.storage.local.get(['currentJob'], (result) => {
      if (result.currentJob && result.currentJob.url === window.location.href) {

        sendResponse(result.currentJob);
      } else {
        // Try to scrape fresh

        const jobData = scrapeUpworkJob();
        
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
  
  // Handle profile scrape request from popup
  if (message.type === 'SCRAPE_PROFILE') {

    
    // Check if we're on a profile page
    const url = window.location.href;
    if (!url.includes('/freelancers/~') && !url.includes('/ab/profiles/')) {

      sendResponse({ success: false, error: 'Not on a profile page' });
      return true;
    }
    
    // Scrape the profile
    try {
      scrapeAndSyncProfile().then(() => {
        // Check if profile was saved
        chrome.storage.local.get(['upworkProfile'], (result) => {
          if (result.upworkProfile) {

            sendResponse({ success: true, profile: result.upworkProfile });
          } else {

            sendResponse({ success: false, error: 'No profile data found' });
          }
        });
      }).catch((err) => {
        console.error('[Propelo Upwork] ❌ Profile scrape error:', err);
        sendResponse({ success: false, error: err.message });
      });
    } catch (err: any) {
      console.error('[Propelo Upwork] ❌ Profile scrape exception:', err);
      sendResponse({ success: false, error: err.message });
    }
    
    return true; // Keep channel open for async response
  }
  
  return false;
});

// AUTO-SCRAPING DISABLED
// Job scraping no longer auto-runs on page load.
// It is now ONLY triggered by explicit user action via the popup or background script.
// Previously this section triggered auto-scraping:
// if (document.readyState === 'loading') {
//   document.addEventListener('DOMContentLoaded', initUpworkScraper);
// } else {
//   initUpworkScraper();
// }

// URL change detection - also disabled for job scraping
// CRITICAL: NO auto-scraping on ANY page - all scraping is explicit only
let lastUrl = window.location.href;
new MutationObserver(() => {
  const currentUrl = window.location.href;
  if (currentUrl !== lastUrl) {
    lastUrl = currentUrl;

    
    // AUTO-SCRAPING DISABLED FOR ALL PAGES
    // Previously this triggered scrapeAndSyncProposals() on proposals pages
    // Now ALL scraping must be explicitly triggered by user action
    
    // REMOVED: Auto-scrape on proposals page
    // if (currentUrl.includes('/proposals') || currentUrl.includes('/nx/proposals')) {

    //   scrapeAndSyncProposals();
    // }
  }
}).observe(document.body, { childList: true, subtree: true });

/**
 * ===== UPWORK PROFILE SCRAPER =====
 * Scrapes comprehensive profile data from Upwork profile pages
 */

/**
 * Advanced Portfolio Scraper with MAXIMUM Lazy-Load Support
 * Handles infinite scroll, multiple layouts, comprehensive data extraction
 * Performs aggressive scrolling and button clicking to load ALL items
 */
async function scrapePortfolioItems(): Promise<Array<{
  title: string;
  description: string;
  url: string;
  imageUrl: string;
  skills?: string[];
  category?: string;
  completionDate?: string;
  projectUrl?: string;
}>> {
  try {



    
    // Notify extension popup about collection
    chrome.runtime.sendMessage({
      action: 'SCRAPING_STATUS',
      status: 'portfolio',
      message: 'Collecting portfolio info...'
    }).catch(() => {});
    
    // STEP 1: Analyze page structure

    const bodyText = document.body.textContent || '';
    const hasPortfolioText = bodyText.toLowerCase().includes('portfolio') || 
                             bodyText.toLowerCase().includes('work samples') ||
                             bodyText.toLowerCase().includes('project');

    
    const allSections = document.querySelectorAll('section, [role="region"], div[class*="section"], div[class*="Section"]');

    
    // STEP 2: Find portfolio section with 50+ selectors
    const portfolioSelectors = [
      // Modern Upwork data attributes
      '[data-test="portfolio-section"]',
      '[data-test*="portfolio"]',
      '[data-qa="portfolio"]',
      '[data-qa="portfolio-section"]',
      '[data-qa*="portfolio"]',
      '[data-cy="portfolio"]',
      '[data-cy*="portfolio"]',
      
      // ID patterns
      '#portfolio',
      '#portfolio-section',
      '#work-samples',
      '#projects',
      '[id*="portfolio"]',
      '[id*="Portfolio"]',
      
      // Semantic/Aria
      'section[aria-label*="Portfolio" i]',
      'section[aria-label*="Work" i]',
      'section[aria-label*="Project" i]',
      'section[aria-label*="Sample" i]',
      '[role="region"][aria-label*="portfolio" i]',
      
      // Class patterns
      '.portfolio-section',
      '.portfolio-container',
      '.work-samples',
      '.project-section',
      '[class*="portfolio-section"]',
      '[class*="portfolioSection"]',
      '[class*="PortfolioSection"]',
      '[class*="portfolio_section"]',
      '[class*="portfolio"]',
      '[class*="Portfolio"]',
      '[class*="work-samples"]',
      '[class*="workSamples"]',
      '[class*="WorkSamples"]',
      
      // Layout patterns
      'div[class*="Portfolio"]',
      'section[class*="portfolio"]',
      'div[data-ev-label*="portfolio"]',
      'section[data-section="portfolio"]',
      'div[data-section="portfolio"]',
      
      // Generic containers
      'main section',
      '.up-card-section',
      '.fe-portfolio',
      'section.section'
    ];
    
    let portfolioSection: Element | null = null;
    let usedSelector = '';
    
    for (const selector of portfolioSelectors) {
      try {
        const element = document.querySelector(selector);
        if (element) {
          const text = element.textContent?.toLowerCase() || '';
          // Verify it actually contains portfolio content
          if (text.includes('portfolio') || text.includes('work') || text.includes('project')) {

            portfolioSection = element;
            usedSelector = selector;
            break;
          }
        }
      } catch (e) {
        continue;
      }
    }
    
    // STEP 3: Text-based search if selectors fail
    if (!portfolioSection) {

      Array.from(allSections).forEach((section, index) => {
        const headings = section.querySelectorAll('h1, h2, h3, h4, h5, h6');
        const headingText = Array.from(headings)
          .map(h => h.textContent?.toLowerCase() || '')
          .join(' ');
        
        if (headingText.includes('portfolio') || 
            headingText.includes('work samples') || 
            headingText.includes('projects') ||
            headingText.includes('my work')) {

          portfolioSection = section;
          usedSelector = `text: "${headingText.substring(0, 30)}..."`;
          return;
        }
      });
    }
    
    if (!portfolioSection) {


      Array.from(allSections).slice(0, 5).forEach((section, i) => {
        const heading = section.querySelector('h1, h2, h3, h4, h5, h6');

      });
      return [];
    }


    
    // STEP 4: AGGRESSIVE scrolling and clicking

    portfolioSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
    await new Promise(resolve => setTimeout(resolve, 2000));

    // STEP 5: Find and click ALL possible expansion buttons (multiple rounds)
    const buttonPatterns = [
      // Data attributes
      'button[data-test*="view"]',
      'button[data-test*="show"]',
      'button[data-test*="more"]',
      'button[data-test*="all"]',
      'button[data-qa*="view"]',
      'button[data-qa*="show"]',
      'button[data-qa*="more"]',
      'a[data-test*="portfolio"]',
      'a[data-qa*="portfolio"]',
      
      // Classes
      'button[class*="view-all"]',
      'button[class*="viewAll"]',
      'button[class*="ViewAll"]',
      'button[class*="show-more"]',
      'button[class*="showMore"]',
      'button[class*="ShowMore"]',
      'button[class*="load-more"]',
      'button[class*="loadMore"]',
      'a[class*="view-all"]',
      'a[class*="show-all"]',
      
      // Generic buttons
      'button',
      'a[role="button"]',
      '.up-btn',
      '.btn'
    ];
    

    let clickedButtons = 0;
    
    for (const pattern of buttonPatterns) {
      const buttons = portfolioSection.querySelectorAll(pattern);
      for (const button of Array.from(buttons)) {
        const buttonText = button.textContent?.toLowerCase() || '';
        const ariaLabel = button.getAttribute('aria-label')?.toLowerCase() || '';
        
        if (buttonText.includes('view all') ||
            buttonText.includes('show all') ||
            buttonText.includes('see all') ||
            buttonText.includes('view more') ||
            buttonText.includes('show more') ||
            buttonText.includes('load more') ||
            buttonText.includes('more projects') ||
            ariaLabel.includes('view') ||
            ariaLabel.includes('show') ||
            ariaLabel.includes('more')) {
          

          (button as HTMLElement).click();
          clickedButtons++;
          await new Promise(resolve => setTimeout(resolve, 2000));
        }
      }
    }
    

    
    // STEP 5.5: Handle pagination (NEW - for portfolio items across multiple pages)

    const paginationSelectors = [
      '[data-test="next-page"]',
      'button[data-ev-label="pagination_next_page"]',
      '.air3-pagination button[aria-label*="Next"]',
      'button[aria-label*="Next page"]',
      'button.air3-pagination-btn-control:not(.is-disabled)'
    ];
    
    // STEP 6: Quick scroll to section (removed slow infinite scroll)

    portfolioSection.scrollIntoView({ behavior: 'instant', block: 'start' });
    await new Promise(resolve => setTimeout(resolve, 300)); // Reduced from 3000ms

    // STEP 7: Find portfolio items with 60+ selectors
    const itemSelectors = [
      // NEW: Upwork's actual portfolio structure (2024+)
      '.air3-grid-container > div.span-6',
      '.air3-grid-container > div.span-md-4',
      '.air3-grid-container > div[class*="span"]',
      'div.portfolio-v2-shelf-thumbnail',
      '[class*="portfolio-v2"] [class*="thumbnail"]',
      
      // Data attributes (most specific)
      '[data-test="portfolio-item"]',
      '[data-test*="portfolio"]',
      '[data-qa="portfolio-item"]',
      '[data-qa*="portfolio"]',
      '[data-cy="portfolio-item"]',
      '[data-cy*="portfolio"]',
      '[data-ev-label="portfolio_item"]',
      '[data-ev-label*="portfolio"]',
      'article[data-ev-sublocation*="portfolio"]',
      'div[data-test*="project"]',
      'div[data-qa*="project"]',
      
      // Class patterns (high priority)
      '.portfolio-item',
      '.portfolio-card',
      '.portfolio-project',
      '.work-sample',
      '.project-item',
      '.project-card',
      '[class*="portfolio-item"]',
      '[class*="portfolioItem"]',
      '[class*="PortfolioItem"]',
      '[class*="portfolio_item"]',
      '[class*="portfolio-card"]',
      '[class*="portfolioCard"]',
      '[class*="PortfolioCard"]',
      '[class*="work-sample"]',
      '[class*="workSample"]',
      '[class*="WorkSample"]',
      '[class*="project-item"]',
      '[class*="projectItem"]',
      '[class*="ProjectItem"]',
      '[class*="project-card"]',
      '[class*="projectCard"]',
      '[class*="ProjectCard"]',
      '.work-item',
      '.project-card',
      '.portfolio-card',
      
      // Specific portfolio structures
      '[data-cy="portfolio-item"]',
      'article[class*="portfolio"]',
      'div[class*="PortfolioItem"]',
      'div[class*="portfolioItem"]',
      'div[class*="portfolio-item"]',
      
      // List items in portfolio context (more specific)
      'ul[class*="portfolio"] > li',
      'div[class*="portfolio"] > ul > li',
      'section[class*="portfolio"] li[class*="item"]',
      'li[class*="portfolio"]',
      
      // Generic (last resort)
      '[data-ev-label*="work"]',
      'article',
      '.card',
      // Only use generic 'li' if within portfolio section and has image
      'li:has(img[src*="portfolio"])',
      'li:has(img[src*="project"])',
      'li:has(a[href*="portfolio"])'
    ];

    // STEP 7: Pagination loop to collect items from all pages
    let allPortfolioElements: Element[] = [];
    let usedItemSelector = '';
    let currentPage = 1;
    const maxPages = 10; // Safety limit
    const seenTitles = new Set<string>(); // Track unique items by title
    let consecutiveDuplicatePages = 0; // Stop if we see same items multiple times
    
    try {
      while (currentPage <= maxPages) {

        
        // Find items on current page
        let pageElements: Element[] = [];
        
        for (const selector of itemSelectors) {
          try {
            const elements = Array.from(portfolioSection.querySelectorAll(selector));
            if (elements.length > 0) {

              
              // Filter out elements that are clearly not portfolio items
              const filtered = elements.filter(el => {
                const text = el.textContent?.trim() || '';
                const hasText = text.length > 20;
                const hasImage = el.querySelector('img') !== null;
                const hasLink = el.querySelector('a') !== null;
                
                // EXCLUDE pagination and navigation elements
                const isPagination = text.toLowerCase().includes('pagination') || 
                                    text.toLowerCase().includes('current page') ||
                                    (text.toLowerCase().includes('page') && text.length < 100);
                const isNavigation = text.toLowerCase().includes('go to') && text.length < 50;
                const isButton = el.tagName.toLowerCase() === 'button';
                const hasOnlyPaginationText = /^(current\s+page|go\s+to|page\s+\d+|next|previous|first|last)/i.test(text);
                
                // Must have real content (text or image) and not be navigation
                const isValidItem = (hasText || hasImage || hasLink) && 
                                  !isPagination && 
                                  !isNavigation && 
                                  !isButton &&
                                  !hasOnlyPaginationText;
                
                return isValidItem;
              });
              
              if (filtered.length > 0) {

                pageElements = filtered;
                if (!usedItemSelector) usedItemSelector = selector;
                break;
              }
            }
          } catch (selectorError) {
            // Skip invalid selectors

            continue;
          }
        }
        
        // Check for duplicates by title
        let newItemsFound = 0;
        for (const el of pageElements) {
          // Extract title to check uniqueness
          const titleEl = el.querySelector('a') || el.querySelector('[class*="title"]') || el;
          const itemTitle = titleEl.textContent?.trim() || '';
          
          if (itemTitle && !seenTitles.has(itemTitle)) {
            seenTitles.add(itemTitle);
            allPortfolioElements.push(el);
            newItemsFound++;
          }
        }
        

        
        // If no new items found, increment duplicate counter
        if (newItemsFound === 0) {
          consecutiveDuplicatePages++;

          
          // Stop if we've seen 2 consecutive duplicate pages
          if (consecutiveDuplicatePages >= 2) {

            break;
          }
        } else {
          consecutiveDuplicatePages = 0; // Reset counter
        }
        
        // Try to find and click "Next" button

        let nextButton: HTMLElement | null = null;
        
        for (const selector of paginationSelectors) {
          try {
            const button = portfolioSection.querySelector(selector) as HTMLElement;
            if (button && !button.hasAttribute('disabled') && button.getAttribute('aria-disabled') !== 'true') {
              nextButton = button;

              break;
            }
          } catch (paginationError) {
            // Skip invalid pagination selectors
            continue;
          }
        }
        
        if (nextButton) {

          nextButton.click();
          currentPage++;
          
          // Reduced wait time (500ms instead of 3500ms)
          await new Promise(resolve => setTimeout(resolve, 500));
        } else {

          break;
        }
      }
    } catch (paginationLoopError) {
      console.error('[Portfolio] ⚠️ Error during pagination, using collected items so far:', paginationLoopError);
      // Continue with whatever items we collected
    }
    
    const portfolioElements = allPortfolioElements;

    if (portfolioElements.length === 0) {


      
      // Log the full structure for debugging

      Array.from(portfolioSection.children).forEach((child, i) => {
        const text = child.textContent?.substring(0, 100).replace(/\n/g, ' ').trim() || '';


        
        // Check if child has any meaningful content
        const hasImages = child.querySelectorAll('img').length;
        const hasLinks = child.querySelectorAll('a[href*="portfolio"]').length;

      });
      




      
      return [];
    }




    // Log first few items for debugging
    portfolioElements.slice(0, 3).forEach((el, i) => {
      const preview = el.textContent?.trim().substring(0, 80).replace(/\n/g, ' ') || '';

    });

    const portfolioItems = [];

    for (const [index, element] of portfolioElements.entries()) {
      try {
        // Title - multiple strategies (ENHANCED)
        const titleSelectors = [
          '[data-test="portfolio-title"]',
          '[data-qa="title"]',
          'h3',
          'h4',
          'h5',
          '.title',
          '.project-title',
          '.work-title',
          '[class*="title"]',
          '[class*="Title"]',
          'a strong',
          'a span',
          'a',
          'strong',
          'span.h4',
          'span.h5',
          'div[class*="name"]'
        ];

        let title = '';
        for (const sel of titleSelectors) {
          const el = element.querySelector(sel);
          if (el?.textContent?.trim()) {
            const text = sanitizeText(el.textContent);
            if (text.length > 2 && text.length < 200) {
              title = text;
              break;
            }
          }
        }
        
        // If still no title, try getting first meaningful text from element
        if (!title) {
          const allText = element.textContent?.trim() || '';
          const lines = allText.split('\n').map(l => l.trim()).filter(l => l.length > 3 && l.length < 200);
          if (lines.length > 0) {
            title = sanitizeText(lines[0]);
          }
        }

        // Description - multiple strategies
        const descriptionSelectors = [
          '[data-test="portfolio-description"]',
          '[data-qa="description"]',
          'p',
          '.description',
          '.project-description',
          '.work-description',
          '[class*="description"]',
          '.excerpt'
        ];

        let description = '';
        for (const sel of descriptionSelectors) {
          const el = element.querySelector(sel);
          if (el?.textContent?.trim() && el.textContent.trim().length > 20) {
            description = sanitizeText(el.textContent);
            break;
          }
        }

        // If no description in child, try parent description
        if (!description) {
          const parentText = element.textContent || '';
          const lines = parentText.split('\n').filter(l => l.trim().length > 30);
          if (lines.length > 0) {
            description = sanitizeText(lines[0]);
          }
        }

        // URL - link to portfolio item detail page
        const linkElement = element.querySelector('a[href]') as HTMLAnchorElement;
        let url = linkElement?.href || '';
        
        // Make relative URLs absolute
        if (url && url.startsWith('/')) {
          url = `https://www.upwork.com${url}`;
        }

        // Image - multiple strategies
        const imageSelectors = [
          'img[data-test="portfolio-image"]',
          'img[data-qa="portfolio-image"]',
          'img[class*="portfolio"]',
          'img[class*="project"]',
          'img[class*="thumbnail"]',
          'img[src*="upwork"]',
          'img'
        ];

        let imageUrl = '';
        for (const sel of imageSelectors) {
          const img = element.querySelector(sel) as HTMLImageElement;
          if (img?.src && !img.src.includes('placeholder') && !img.src.includes('default')) {
            imageUrl = img.src;
            break;
          }
        }

        // Extract skills/technologies used
        const skillElements = element.querySelectorAll('[data-test="skill"], .skill-tag, .tag, [class*="skill"]');
        const skills = Array.from(skillElements)
          .map(el => sanitizeText(el.textContent || ''))
          .filter(skill => skill.length > 0 && skill.length < 50);

        // Extract category
        const categoryElement = element.querySelector('[data-test="category"], .category, [class*="category"]');
        const category = categoryElement ? sanitizeText(categoryElement.textContent || '') : '';

        // Extract completion date
        const dateElement = element.querySelector('[data-test="date"], .date, time, [class*="date"]');
        const completionDate = dateElement ? sanitizeText(dateElement.textContent || '') : '';

        // Extract project URL (external link if available)
        const projectLinkElement = element.querySelector('a[href^="http"]:not([href*="upwork.com"])') as HTMLAnchorElement;
        const projectUrl = projectLinkElement?.href || '';

        // Only add if we have at least a title OR url OR image
        if (title || url || imageUrl) {
          portfolioItems.push({
            title: title || 'Untitled Project',
            description: description.substring(0, 500), // Limit description length
            url,
            imageUrl,
            skills: skills.length > 0 ? skills : undefined,
            category: category || undefined,
            completionDate: completionDate || undefined,
            projectUrl: projectUrl || undefined
          });


        } else {

        }

      } catch (itemError) {

        // Continue with next item
      }
    }


    
    // Log summary with actual titles
    if (portfolioItems.length > 0) {






      portfolioItems.forEach((item, i) => {

        if (item.description) {

        }
        if (item.imageUrl) {

        }
        if (item.skills && item.skills.length > 0) {

        }
      });
    } else {





    }

    return portfolioItems;

  } catch (error) {
    console.error('[Portfolio] Scraping error:', error);
    return [];
  }
}

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
 * Extract array of text from elements
 */
function extractTextArray(...selectors: string[]): string[] {
  for (const selector of selectors) {
    try {
      const elements = document.querySelectorAll(selector);
      if (elements.length > 0) {
        const texts = Array.from(elements)
          .map(el => sanitizeText(el.textContent || ''))
          .filter(t => t && t.length > 0);
        if (texts.length > 0) return texts;
      }
    } catch (e) {
      // Continue
    }
  }
  return [];
}

/**
 * Scrape Upwork profile with extensive fallbacks
 */
async function scrapeUpworkProfile(): Promise<UpworkProfile | null> {
  try {




    // Wait for profile content to load
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Display Name - 30+ selectors
    const displayName = extractText(
      // Modern Upwork patterns
      '[data-test="freelancer-name"]',
      'h1[data-qa="fl-name"]',
      '[data-qa="freelancer-name"]',
      'h1.up-n-link',
      'h1[data-cy="freelancer-name"]',
      // Common patterns
      '.freelancer-name',
      '.profile-name',
      '.display-name',
      '[data-name]',
      '[class*="FreelancerName"]',
      '[class*="freelancerName"]',
      '[class*="profile-name"]',
      '[class*="ProfileName"]',
      // Header patterns
      'header h1',
      'main h1',
      '.profile-header h1',
      '.up-card h1',
      'section h1',
      // Semantic
      '[itemprop="name"]',
      '[aria-label*="name"]',
      // Layout patterns
      'div[class*="name"] h1',
      'div[data-section="name"] h1',
      '.fe-profile h1',
      '.profile-top h1',
      // Generic fallbacks
      'h1.h1',
      'h1.title',
      'h1:first-of-type',
      'h1'
    );



    // Title - 25+ selectors
    const title = extractText(
      '[data-test="freelancer-title"]',
      '[data-qa="title"]',
      '[data-qa="freelancer-title"]',
      '.title',
      '.freelancer-title',
      '.profile-title',
      '[data-title]',
      '[class*="title"]',
      '[class*="Title"]',
      '[class*="headline"]',
      '[class*="tagline"]',
      'h1 + p',
      'h1 + div',
      'h2.subtitle',
      'h2',
      '[itemprop="jobTitle"]',
      '[aria-label*="title"]',
      '.up-card h2',
      '.profile-header p',
      'header p',
      'main h2',
      '.fe-profile h2',
      'div[class*="title"] p',
      'span[class*="title"]',
      '.text-subtitle'
    );



    // Location - 25+ selectors
    const location = extractText(
      '[data-test="location"]',
      '[data-qa="location"]',
      '[data-qa="freelancer-location"]',
      '.location',
      '.freelancer-location',
      '[data-location]',
      '[class*="location"]',
      '[class*="Location"]',
      '[class*="geo"]',
      '[itemprop="addressLocality"]',
      '[itemprop="location"]',
      '[aria-label*="location"]',
      'svg[data-test="location-icon"] ~ span',
      'svg[class*="location"] ~ span',
      'i[class*="location"] ~ span',
      '.up-icon-location ~ span',
      '.fe-location',
      'span[class*="location"]',
      'div[class*="location"] span',
      '.profile-location',
      '.text-muted span',
      'small',
      'span.text-light'
    );



    // Hourly Rate - 30+ selectors
    const hourlyRateText = extractText(
      '[data-test="hourly-rate"]',
      '[data-qa="hourly-rate"]',
      '[data-qa="rate"]',
      '.hourly-rate',
      '.freelancer-rate',
      '.rate',
      '[data-rate]',
      '[class*="hourly-rate"]',
      '[class*="HourlyRate"]',
      '[class*="rate"]',
      '[class*="Rate"]',
      '[class*="price"]',
      '[class*="Price"]',
      '.pricing',
      '.cost',
      'span[title*="hour"]',
      'div[title*="rate"]',
      'strong:has-text("$")',
      'span:has-text("/hr")',
      'div:has-text("per hour")',
      '.profile-rate',
      '.fe-rate',
      '[aria-label*="rate"]',
      'h3:has-text("$")',
      'h4:has-text("$")',
      '.up-card strong',
      '.stats strong',
      'strong'
    );
    const hourlyRate = extractNumber(hourlyRateText);



    // Job Success Score - 35+ selectors (enhanced)
    const jobSuccessText = extractText(
      '[data-test="job-success"]',
      '[data-qa="job-success"]',
      '[data-qa="jss"]',
      '.job-success',
      '.jss',
      '[data-jss]',
      '[class*="job-success"]',
      '[class*="JobSuccess"]',
      '[class*="jss"]',
      '[class*="JSS"]',
      'span[title*="Job Success"]',
      'div[title*="Success"]',
      '[aria-label*="success"]',
      '.success-score',
      '.profile-success',
      '.fe-jss',
      // New Upwork layout patterns
      '[data-ev-label*="job_success"]',
      'div[class*="stats"] span',
      'div[class*="Stats"] span',
      'section span:has-text("%")',
      'strong',
      'span.h4',
      'span.text-bold',
      'div.text-center strong',
      'div[class*="stat"] strong',
      'div[class*="Stat"] strong',
      // Try finding by context (near "Job Success" text)
      'dt:has-text("Job Success") + dd',
      'label:has-text("Job Success") + span',
      'div:has-text("Job Success") strong',
      'div:has-text("Job Success") span'
    );
    const jobSuccessScore = extractNumber(jobSuccessText);



    // Total Earnings - 35+ selectors (enhanced)
    const earningsText = extractText(
      '[data-test="total-earnings"]',
      '[data-qa="earnings"]',
      '[data-qa="total-earned"]',
      '.total-earnings',
      '.earnings',
      '[data-earnings]',
      '[class*="earnings"]',
      '[class*="Earnings"]',
      '[class*="earned"]',
      'span[title*="earned"]',
      'div[title*="earnings"]',
      '[aria-label*="earnings"]',
      '.profile-earnings',
      '.fe-earnings',
      '.revenue',
      // New patterns
      '[data-ev-label*="earnings"]',
      'div[class*="stat"] strong',
      'div[class*="Stat"] strong',
      'dt:has-text("earned") + dd',
      'dt:has-text("Total Earned") + dd',
      'label:has-text("earned") + span',
      'div:has-text("earned") strong',
      'div:has-text("Total Earned") span',
      'span.h4',
      'span.text-bold'
    );
    const totalEarnings = extractNumber(earningsText);



    // Total Jobs - 30+ selectors (enhanced)
    const jobsText = extractText(
      '[data-test="total-jobs"]',
      '[data-qa="jobs-count"]',
      '[data-qa="total-jobs"]',
      '.total-jobs',
      '.jobs-count',
      '[data-jobs]',
      '[class*="total-jobs"]',
      '[class*="jobsCount"]',
      'span[title*="jobs"]',
      'div[title*="jobs"]',
      '[aria-label*="jobs"]',
      '.profile-jobs',
      '.fe-jobs',
      '.jobs-completed',
      // New patterns
      '[data-ev-label*="jobs"]',
      'dt:has-text("Jobs") + dd',
      'dt:has-text("Total Jobs") + dd',
      'label:has-text("jobs") + span',
      'div:has-text("jobs") strong',
      'div[class*="stat"] strong',
      'span.h4',
      'span.text-bold'
    );
    const totalJobs = extractNumber(jobsText);



    // Total Hours - 30+ selectors (enhanced)
    const hoursText = extractText(
      '[data-test="total-hours"]',
      '[data-qa="hours"]',
      '[data-qa="total-hours"]',
      '.total-hours',
      '.hours',
      '[data-hours]',
      '[class*="hours"]',
      '[class*="Hours"]',
      'span[title*="hours"]',
      'div[title*="hours"]',
      '[aria-label*="hours"]',
      '.profile-hours',
      '.fe-hours',
      '.hours-worked',
      // New patterns
      '[data-ev-label*="hours"]',
      'dt:has-text("hours") + dd',
      'dt:has-text("Total Hours") + dd',
      'label:has-text("hours") + span',
      'div:has-text("hours") strong',
      'div[class*="stat"] strong',
      'span.h4',
      'span.text-bold'
    );
    const totalHours = extractNumber(hoursText);



    // Badge Detection - Top Rated
    const isTopRated = !!(
      document.querySelector('[data-test="top-rated-badge"]') ||
      document.querySelector('[data-qa="top-rated"]') ||
      document.querySelector('[class*="top-rated"]') ||
      document.querySelector('[class*="TopRated"]') ||
      document.querySelector('[aria-label*="Top Rated"]') ||
      Array.from(document.querySelectorAll('.badge, .up-badge, [class*="badge"]'))
        .some(el => el.textContent?.toLowerCase().includes('top rated'))
    );



    // Badge Detection - Rising Talent
    const isRisingTalent = !!(
      document.querySelector('[data-test="rising-talent-badge"]') ||
      document.querySelector('[data-qa="rising-talent"]') ||
      document.querySelector('[class*="rising-talent"]') ||
      document.querySelector('[class*="RisingTalent"]') ||
      document.querySelector('[aria-label*="Rising Talent"]') ||
      Array.from(document.querySelectorAll('.badge, .up-badge, [class*="badge"]'))
        .some(el => el.textContent?.toLowerCase().includes('rising talent'))
    );



    // Skills - Multiple selector strategies with filtering
    let skills: string[] = [];
    const skillSelectors = [
      '[data-test="skill"]',
      '[data-qa="skill-name"]',
      '[data-qa="skill"]',
      '.skill-badge',
      '.skill',
      '[data-skill]',
      '[class*="skill"] a',
      '[class*="skill"] span',
      '[class*="Skill"]',
      'section[data-section="skills"] a',
      'section[data-section="skills"] span',
      'section[aria-label*="Skills"] a',
      'section[aria-label*="Skill"] a',
      '[itemprop="skills"] a',
      '.up-badge',
      '.badge',
      '.tag'
    ];

    for (const selector of skillSelectors) {
      const elements = document.querySelectorAll(selector);
      if (elements.length > 0) {
        const extracted = Array.from(elements)
          .map(el => sanitizeText(el.textContent || ''))
          .filter(text => {
            // Filter out invalid skills
            const lower = text.toLowerCase();
            return text.length > 1 && 
                   text.length < 50 && // Skills are usually short
                   !lower.includes('wikipedia') && 
                   !lower.includes('http') &&
                   !lower.includes('www.') &&
                   !lower.includes('assessment') &&
                   !lower.includes('take test') &&
                   !lower.includes('view all') &&
                   !lower.includes('show') &&
                   !text.match(/^\d+$/) && // Not just numbers
                   !text.includes('•'); // Not bullet points
          })
          .filter((text, index, self) => self.indexOf(text) === index); // Remove duplicates
        
        if (extracted.length > 0) {
          skills = extracted;

          break;
        }
      }
    }



    // Categories - enhanced
    const categories = extractTextArray(
      '[data-test="category"]',
      '[data-qa="category"]',
      '.category',
      '[data-category]',
      '[class*="category"]',
      '[class*="Category"]',
      'a[href*="category"]',
      'section[data-section="categories"] a',
      'section[aria-label*="Categories"] a',
      'div[class*="categories"] a',
      'div[class*="Categories"] a',
      // Try breadcrumbs or tags
      '.breadcrumb a',
      '.tag',
      '.badge:not(.skill-badge)'
    );



    // Languages - Extract with proficiency (enhanced)
    let languages: Array<{
      name: string;
      proficiency: 'basic' | 'conversational' | 'fluent' | 'native';
    }> = [];

    try {
      const langSelectors = [
        '[data-test="language"]',
        '[data-qa="language"]',
        '.language',
        '[class*="language"]',
        '[class*="Language"]',
        'section[data-section="languages"] li',
        'section[aria-label*="Languages"] li',
        'section[aria-label*="Language"] li',
        'div[class*="languages"] li',
        'div[class*="Languages"] li'
      ];

      for (const selector of langSelectors) {
        const elements = document.querySelectorAll(selector);
        if (elements.length > 0) {
          languages = Array.from(elements).map(el => {
            const name = sanitizeText(
              el.querySelector('[data-test="language-name"]')?.textContent ||
              el.querySelector('.language-name')?.textContent ||
              el.querySelector('strong')?.textContent ||
              el.querySelector('span')?.textContent ||
              el.textContent ||
              ''
            );
            
            const profText = sanitizeText(
              el.querySelector('[data-test="language-proficiency"]')?.textContent ||
              el.querySelector('.proficiency')?.textContent ||
              el.textContent ||
              ''
            ).toLowerCase();
            
            let proficiency: 'basic' | 'conversational' | 'fluent' | 'native' = 'conversational';
            if (profText.includes('basic')) proficiency = 'basic';
            else if (profText.includes('fluent')) proficiency = 'fluent';
            else if (profText.includes('native')) proficiency = 'native';
            
            return { name, proficiency };
          }).filter(lang => lang.name && lang.name.length > 1);
          
          if (languages.length > 0) break;
        }
      }
    } catch (e) {
      console.error('[Propelo Upwork Profile] Error extracting languages:', e);
    }



    // Portfolio - Advanced scraping

    const portfolio = await scrapePortfolioItems();


    // Rating - 30+ selectors (enhanced)
    const ratingText = extractText(
      '[data-test="rating"]',
      '[data-qa="rating"]',
      '.rating',
      '[data-rating]',
      '[class*="rating"]',
      '[class*="Rating"]',
      '[itemprop="ratingValue"]',
      'span[title*="rating"]',
      '[aria-label*="rating"]',
      'span[class*="star"]',
      '.stars',
      '.review-rating',
      // New patterns
      '[data-ev-label*="rating"]',
      'div[class*="rating"] strong',
      'div[class*="Rating"] strong',
      'div[class*="reviews"] strong',
      'span.h4',
      'span.text-bold',
      'dt:has-text("rating") + dd',
      'label:has-text("rating") + span'
    );
    const rating = extractNumber(ratingText);



    // Review Count - 30+ selectors (enhanced)
    const reviewCountText = extractText(
      '[data-test="review-count"]',
      '[data-qa="reviews"]',
      '[data-qa="review-count"]',
      '.review-count',
      '.reviews-count',
      '[data-reviews]',
      '[class*="review-count"]',
      '[class*="reviewCount"]',
      'span[title*="review"]',
      '[aria-label*="reviews"]',
      'a[href*="reviews"]',
      '.total-reviews',
      // New patterns
      '[data-ev-label*="reviews"]',
      'div[class*="reviews"] strong',
      'div[class*="Reviews"] strong',
      'dt:has-text("reviews") + dd',
      'label:has-text("reviews") + span',
      'span.h6',
      'small'
    );
    const reviewCount = extractNumber(reviewCountText);



    // Bio/Overview - 25+ selectors
    const bio = extractText(
      '[data-test="overview"]',
      '[data-qa="description"]',
      '[data-qa="overview"]',
      '.bio',
      '.overview',
      '.description',
      '.profile-description',
      '[data-bio]',
      '[class*="overview"]',
      '[class*="Overview"]',
      '[class*="description"]',
      '[class*="bio"]',
      'section[data-section="overview"] p',
      'section[aria-label*="Overview"] p',
      '[itemprop="description"]',
      '.fe-overview',
      '.profile-summary',
      'main p',
      '.up-card p',
      'p.text-body'
    );



    // Member Since - 30+ selectors (enhanced)
    const memberSince = extractText(
      '[data-test="member-since"]',
      '[data-qa="member-since"]',
      '[data-qa="joined"]',
      '.member-since',
      '.joined-date',
      '[data-joined]',
      '[class*="member-since"]',
      '[class*="memberSince"]',
      '[class*="joined"]',
      'span[title*="member"]',
      'span[title*="joined"]',
      '[aria-label*="member since"]',
      'time',
      '.join-date',
      // New patterns
      '[data-ev-label*="member"]',
      'dt:has-text("Member") + dd',
      'dt:has-text("member since") + dd',
      'label:has-text("member") + span',
      'div:has-text("Member since") span',
      'small:not(:empty)',
      'span.text-muted:not(:empty)',
      'span.text-light:not(:empty)'
    ).replace('|', '').trim();



    // Response Time - 15+ selectors
    const responseTime = extractText(
      '[data-test="response-time"]',
      '[data-qa="response-time"]',
      '.response-time',
      '[data-response]',
      '[class*="response-time"]',
      '[class*="responseTime"]',
      'span[title*="response"]',
      '[aria-label*="response"]',
      '.response-rate'
    );



    // Profile Image - 25+ selectors
    let profileImage: string | undefined;
    const imageSelectors = [
      '[data-test="profile-image"]',
      '[data-qa="profile-photo"]',
      'img[alt*="profile"]',
      'img[alt*="photo"]',
      '.profile-image img',
      '.profile-photo img',
      '.avatar img',
      '[class*="avatar"] img',
      '[class*="Avatar"] img',
      '[class*="profile-image"] img',
      '[class*="ProfileImage"] img',
      'header img',
      '.up-avatar img',
      '.fe-avatar img',
      'img[itemprop="image"]',
      '[aria-label*="profile picture"] img',
      'button img',
      '.up-card img',
      'main img',
      'img'
    ];

    for (const selector of imageSelectors) {
      const img = document.querySelector(selector) as HTMLImageElement;
      if (img?.src && img.src.startsWith('http') && !img.src.includes('default') && !img.src.includes('placeholder')) {
        profileImage = img.src;

        break;
      }
    }



    // Construct profile data
    const profileData: UpworkProfile = {
      platform: 'upwork',
      displayName: displayName || 'Unknown User',
      username: undefined,
      title: title || undefined,
      profileUrl: window.location.href,
      location: location || undefined,
      profileImage: profileImage || undefined,
      
      hourlyRate,
      hourlyRateMin: undefined,
      hourlyRateMax: undefined,
      jobSuccessScore,
      totalEarnings,
      totalJobs,
      totalHours,
      
      profileCompleteness: undefined,
      isVerified: true,
      isTopRated,
      isRisingTalent,
      
      skills,
      categories,
      languages,
      
      portfolio,
      
      rating,
      reviewCount,
      recentReviews: [],
      
      bio: bio || undefined,
      memberSince: memberSince || undefined,
      availability: undefined,
      responseTime: responseTime || undefined,
      
      scrapedAt: new Date(),
      scrapedFrom: window.location.href
    };    
    // Log collected data details
    if (portfolio.length > 0) {

      portfolio.forEach((item, i) => {

      });
    }
    
    if (skills.length > 0) {

    }

    // Send to background for syncing
    try {
      chrome.runtime.sendMessage({
        action: 'SYNC_ACCOUNT_DATA',
        data: {
          platform: 'upwork',
          profileData
        }
      });

    } catch (error) {
      console.error('[Propelo Upwork Profile] ❌ Failed to send to background:', error);
    }

    return profileData;

  } catch (error) {
    console.error('[Propelo Upwork Profile] ❌ Fatal error:', error);
    logScrapingError('upwork-profile', error as Error, {
      url: window.location.href
    });
    return null;
  }
}

async function scrapeUpworkProfile_OLD(): Promise<UpworkProfile | null> {
  try {



    // Wait for profile content to load
    await waitForElement('[data-test="freelancer-profile"]', 10000);

    // Basic Info
    const displayName = getTextContent('[data-test="freelancer-name"]') || 
                       getTextContent('h1[data-qa="fl-name"]') ||
                       getTextContent('h1.display-name') || 
                       '';
    
    const title = getTextContent('[data-test="freelancer-title"]') ||
                 getTextContent('[data-qa="title"]') ||
                 getTextContent('.title') || 
                 '';
    
    const location = getTextContent('[data-test="location"]') ||
                    getTextContent('[data-qa="location"]') ||
                    '';
    
    const profileImage = document.querySelector('[data-test="profile-image"]')?.getAttribute('src') ||
                        document.querySelector('img[alt*="profile"]')?.getAttribute('src') ||
                        '';

    // Professional Stats
    const hourlyRateText = getTextContent('[data-test="hourly-rate"]') ||
                           getTextContent('[data-qa="hourly-rate"]') ||
                           getTextContent('.hourly-rate') || 
                           '';
    const hourlyRate = hourlyRateText ? parseFloat(hourlyRateText.replace(/[^0-9.]/g, '')) : undefined;

    const jobSuccessText = getTextContent('[data-test="job-success"]') ||
                          getTextContent('[data-qa="job-success"]') ||
                          '';
    const jobSuccessScore = jobSuccessText ? parseFloat(jobSuccessText.replace(/[^0-9.]/g, '')) : undefined;

    const totalEarningsText = getTextContent('[data-test="total-earnings"]') ||
                             getTextContent('[data-qa="earnings"]') ||
                             '';
    const totalEarnings = totalEarningsText ? parseFloat(totalEarningsText.replace(/[^0-9.]/g, '')) : undefined;

    const totalJobsText = getTextContent('[data-test="total-jobs"]') ||
                         getTextContent('[data-qa="jobs-count"]') ||
                         '';
    const totalJobs = totalJobsText ? parseInt(totalJobsText.replace(/[^0-9]/g, '')) : undefined;

    const totalHoursText = getTextContent('[data-test="total-hours"]') ||
                          getTextContent('[data-qa="hours"]') ||
                          '';
    const totalHours = totalHoursText ? parseInt(totalHoursText.replace(/[^0-9]/g, '')) : undefined;

    // Profile Status
    const isTopRated = !!document.querySelector('[data-test="top-rated-badge"]') ||
                       !!document.querySelector('[data-qa="top-rated"]') ||
                       document.body.textContent?.includes('Top Rated') || false;
    
    const isRisingTalent = !!document.querySelector('[data-test="rising-talent-badge"]') ||
                           !!document.querySelector('[data-qa="rising-talent"]') ||
                           document.body.textContent?.includes('Rising Talent') || false;

    // Skills
    const skills = getMultipleTextContent('[data-test="skill"]') ||
                   getMultipleTextContent('[data-qa="skill-name"]') ||
                   getMultipleTextContent('.skill-badge') ||
                   [];

    // Categories
    const categories = getMultipleTextContent('[data-test="category"]') ||
                      getMultipleTextContent('[data-qa="category"]') ||
                      [];

    // Languages
    const languageElements = document.querySelectorAll('[data-test="language"]');
    const languages = Array.from(languageElements).map(el => {
      const name = el.querySelector('[data-test="language-name"]')?.textContent?.trim() || '';
      const proficiency = el.querySelector('[data-test="language-proficiency"]')?.textContent?.trim().toLowerCase() || 'conversational';
      return {
        name,
        proficiency: proficiency as 'basic' | 'conversational' | 'fluent' | 'native'
      };
    }).filter(lang => lang.name);

    // Portfolio - Advanced scraping with scroll and lazy-load handling

    const portfolio = await scrapePortfolioItems();


    // Rating & Reviews
    const ratingText = getTextContent('[data-test="rating"]') ||
                       getTextContent('[data-qa="rating"]') ||
                       '';
    const rating = ratingText ? parseFloat(ratingText.replace(/[^0-9.]/g, '')) : undefined;

    const reviewCountText = getTextContent('[data-test="review-count"]') ||
                           getTextContent('[data-qa="reviews"]') ||
                           '';
    const reviewCount = reviewCountText ? parseInt(reviewCountText.replace(/[^0-9]/g, '')) : undefined;

    // Recent Reviews
    const reviewElements = document.querySelectorAll('[data-test="review-item"]');
    const recentReviews = Array.from(reviewElements).slice(0, 5).map(el => {
      const ratingEl = el.querySelector('[data-test="review-rating"]')?.textContent?.trim() || '0';
      const rating = parseFloat(ratingEl.replace(/[^0-9.]/g, ''));
      const comment = el.querySelector('[data-test="review-comment"]')?.textContent?.trim() || '';
      const clientName = el.querySelector('[data-test="client-name"]')?.textContent?.trim() || '';
      const date = el.querySelector('[data-test="review-date"]')?.textContent?.trim() || '';
      const jobTitle = el.querySelector('[data-test="job-title"]')?.textContent?.trim() || '';
      return { rating, comment, clientName, date, jobTitle };
    }).filter(review => review.comment);

    // Bio/Overview
    const bio = getTextContent('[data-test="overview"]') ||
                getTextContent('[data-qa="description"]') ||
                getTextContent('.bio') ||
                '';

    // Member Since
    const memberSince = getTextContent('[data-test="member-since"]') ||
                        getTextContent('[data-qa="member-since"]') ||
                        '';

    // Response Time
    const responseTime = getTextContent('[data-test="response-time"]') ||
                         getTextContent('[data-qa="response-time"]') ||
                         '';

    const profileData: UpworkProfile = {
      platform: 'upwork',
      displayName,
      title,
      location,
      profileImage,
      profileUrl: window.location.href,
      
      hourlyRate,
      jobSuccessScore,
      totalEarnings,
      totalJobs,
      totalHours,
      
      isVerified: true, // Assume verified if we can see profile
      isTopRated,
      isRisingTalent,
      
      skills,
      categories,
      languages,
      portfolio,
      
      rating,
      reviewCount,
      recentReviews,
      
      bio,
      memberSince,
      responseTime,
      
      scrapedAt: new Date(),
      scrapedFrom: window.location.href
    };







    return profileData;

  } catch (error) {
    console.error('[Propelo Upwork Profile] ❌ Scraping error:', error);
    logScrapingError('upwork-profile', error as Error, { url: window.location.href });
    return null;
  }
}

/**
 * ===== UPWORK PROPOSAL TRACKER =====
 * Scrapes submitted proposals from Upwork's "My Proposals" page
 */
async function scrapeUpworkProposals(): Promise<ProposalSubmission[]> {
  try {



    // Wait for proposals to load
    await waitForElement('[data-test="proposal-item"]', 10000);

    const proposalElements = document.querySelectorAll('[data-test="proposal-item"], .proposal-item, [class*="proposal-card"]');


    const proposals: ProposalSubmission[] = [];

    for (const element of Array.from(proposalElements)) {
      try {
        // Job Info
        const jobTitle = element.querySelector('[data-test="job-title"]')?.textContent?.trim() ||
                        element.querySelector('.job-title')?.textContent?.trim() || 
                        '';
        
        const jobUrl = element.querySelector('[data-test="job-link"]')?.getAttribute('href') ||
                       element.querySelector('a[href*="/jobs/"]')?.getAttribute('href') ||
                       '';
        
        const clientName = element.querySelector('[data-test="client-name"]')?.textContent?.trim() || '';

        // Proposal Details
        const coverLetter = element.querySelector('[data-test="cover-letter"]')?.textContent?.trim() ||
                           element.querySelector('.cover-letter')?.textContent?.trim() ||
                           '';
        
        const bidAmountText = element.querySelector('[data-test="bid-amount"]')?.textContent?.trim() ||
                             element.querySelector('.bid-amount')?.textContent?.trim() ||
                             '';
        const bidAmount = bidAmountText ? parseFloat(bidAmountText.replace(/[^0-9.]/g, '')) : undefined;

        // Status
        let status: ProposalSubmission['status'] = 'submitted';
        const statusText = element.querySelector('[data-test="proposal-status"]')?.textContent?.trim().toLowerCase() || '';
        
        if (statusText.includes('hired') || statusText.includes('accepted')) {
          status = 'accepted';
        } else if (statusText.includes('interview')) {
          status = 'interviewing';
        } else if (statusText.includes('archived') || statusText.includes('closed')) {
          status = 'archived';
        } else if (statusText.includes('withdrawn')) {
          status = 'withdrawn';
        } else if (statusText.includes('active') || statusText.includes('submitted')) {
          status = 'submitted';
        }

        // Dates
        const submittedText = element.querySelector('[data-test="submitted-date"]')?.textContent?.trim() || '';
        const submittedAt = submittedText ? new Date(submittedText) : new Date();

        // Client Activity
        const clientViewed = element.textContent?.includes('Viewed by client') || 
                            element.textContent?.includes('Client viewed') ||
                            false;

        const interviewInvited = element.textContent?.includes('Interview invited') ||
                                element.textContent?.includes('Invited to interview') ||
                                false;

        // Generate unique ID
        const proposalId = `upwork-${jobTitle.replace(/\s+/g, '-').toLowerCase()}-${submittedAt.getTime()}`;

        const proposal: ProposalSubmission = {
          id: proposalId,
          userId: '', // Will be set by background script
          platform: 'upwork',
          
          jobTitle,
          jobUrl: jobUrl ? `https://www.upwork.com${jobUrl}` : undefined,
          clientName,
          
          coverLetter,
          bidAmount,
          currency: 'USD',
          
          status,
          submittedAt,
          
          clientViewed,
          interviewInvited,
          
          messages: [],
          
          generatedByPropelo: false, // Can be updated if we match with our generated proposals
          
          lastScraped: new Date(),
          scrapedFrom: window.location.href,
          syncStatus: 'active'
        };

        if (jobTitle) { // Only add if we have at least a job title
          proposals.push(proposal);
        }

      } catch (error) {
        console.error('[Propelo Upwork Proposals] Error scraping individual proposal:', error);
      }
    }


    return proposals;

  } catch (error) {
    console.error('[Propelo Upwork Proposals] ❌ Scraping error:', error);
    logScrapingError('upwork-proposals', error as Error, { url: window.location.href });
    return [];
  }
}

/**
 * Scrape and sync profile data to web app
 * Production-grade implementation with proper error handling
 */
async function scrapeAndSyncProfile(): Promise<void> {



  
  try {
    // Use the new robust scraper (now async for portfolio pagination)
    const result = await scrapeProfileFromDOM();
    
    if (!result.success || !result.data) {
      console.error('[Propelo Upwork] ❌ Scrape failed:', result.error);

      throw new Error(result.error || 'Scrape failed');
    }
    
    const profileData = result.data;
    


    // Store in Chrome storage immediately (optimistic)
    await chrome.storage.local.set({ 
      upworkProfile: profileData,
      upworkProfilePending: true,
      lastProfileScrape: new Date().toISOString()
    });


    // Send to background script for API sync

    
    const response = await chrome.runtime.sendMessage({
      action: 'SYNC_ACCOUNT_DATA',
      data: {
        platform: 'upwork',
        profileData
      }
    });
    

    
    if (response?.success) {

      await chrome.storage.local.set({ 
        upworkProfilePending: false,
        lastProfileSync: new Date().toISOString()
      });
    } else {
      console.error('[Propelo Upwork] ❌ Sync failed:', response?.error);
      // Keep pending flag true for retry
    }
    
  } catch (error: any) {
    console.error('[Propelo Upwork] ❌ Profile sync error:', error.message);
    throw error; // Re-throw so caller knows it failed
  }
}

/**
 * Scrape and sync proposals data to web app
 */
async function scrapeAndSyncProposals(): Promise<void> {

  
  const proposals = await scrapeUpworkProposals();
  
  if (proposals.length > 0) {
    // Store in Chrome storage
    chrome.storage.local.set({ 
      upworkProposals: proposals,
      lastProposalsSync: new Date().toISOString()
    });

    // Send to background script for API sync
    chrome.runtime.sendMessage({
      action: 'SYNC_PROPOSALS',
      data: {
        platform: 'upwork',
        proposals
      }
    });


  }
}

// Check page type on load
const currentUrl = window.location.href;

const isProposalsPage = 
  currentUrl.includes('/proposals') || 
  currentUrl.includes('/nx/proposals');

if (isProposalsPage) {

  scrapeAndSyncProposals();
}

export {};
