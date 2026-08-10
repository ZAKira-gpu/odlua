
import type { UpworkProfile } from '../../../types';

/**
 * Robust Upwork Profile Scraper
 * Implements "surgical" selectors based on known DOM structures.
 */

// ============================================
// TYPES
// ============================================

interface ScrapeResult {
  success: boolean;
  data?: UpworkProfile;
  error?: string;
  logs: string[];
}

// ============================================
// HELPERS
// ============================================

function cleanText(text: string | null | undefined): string {
  if (!text) return '';
  return text
    .replace(/\s+/g, ' ') // Collapse whitespace
    .trim();
}

function parseCurrency(text: string): { amount: number; currency: string } | null {
  // "$15.00/hr" -> 15.00
  const match = text.match(/([$€£¥])?([\d,]+(\.\d{2})?)/);
  if (!match) return null;

  const symbol = match[1] || '$';
  const amount = parseFloat(match[2].replace(/,/g, ''));

  const currencyMap: Record<string, string> = {
    '$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    '¥': 'JPY'
  };

  return {
    amount,
    currency: currencyMap[symbol] || 'USD'
  };
}

// ============================================
// EXTRACTORS
// ============================================

function extractHourlyRate(root: Document): { hourlyRate: number; currency: string } | null {
  // Target: <div><h3 class="h5"><strong><span>$15.00/hr</span></strong></h3></div>
  const selectors = [
    'h3.h5 strong span', // Primary
    '[data-test="hourly-rate"]', // Testing attribute
    '.hourly-rate span', // Common class
    'div:has(> h3.h5) strong span', // Structural
    // Fallbacks
    '[data-qa="hourly-rate"]',
    '[data-qa="rate"]',
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
    'h3:has-text("$")'
  ];

  for (const selector of selectors) {
    try {
      const elements = root.querySelectorAll(selector);
      for (const el of Array.from(elements)) {
        const text = el.textContent || '';
        if (text.includes('/hr') || text.includes('hour')) {
          const parsed = parseCurrency(text);
          if (parsed) return { hourlyRate: parsed.amount, currency: parsed.currency };
        }
      }
    } catch (e) {
      // Ignore invalid selectors
    }
  }

  return null;
}

function extractTitle(root: Document): string | null {
  // Target: <h3 class="h4">Cross-Platform Mobile App Developer</h3>
  // This is tricky because h3.h4 might be used elsewhere.
  // We look for it in the profile header area usually.



  const selectors = [
    // Modern Upwork selectors (2024-2025)
    '[data-testid="FreelancerTitle"]',
    '[data-testid="freelancer-title"]',
    '[data-test="freelancer-title"]',
    '[data-qa="freelancer-title"]',
    '[data-ev-label="freelancer_title"]',

    // H2/H3 patterns
    'h2.h4',
    'h3.h4',
    'h2.h3',
    'h3.h3',

    // Card section patterns
    '.air3-card-section h2',
    '.air3-card-section h3',
    '.up-card-section h2',
    '.up-card-section h3',

    // Class-based
    '.title',
    '.freelancer-title',
    '.profile-title',
    '.headline',
    '.tagline',
    '.subtitle',
    '[itemprop="jobTitle"]',

    // After name patterns
    'h1 + h2',
    'h1 + h3',
    'h1 + p',
    'h1 ~ h2',
    'h1 ~ h3',

    // Container patterns
    '[class*="FreelancerTitle"]',
    '[class*="freelancerTitle"]',
    '[class*="profile-title"]',
    '[class*="ProfileTitle"]',
    '[class*="headline"]',
    '[class*="Headline"]',
    '[class*="tagline"]',
    '[class*="Tagline"]',

    // Flexible
    '.up-card h2',
    '.up-card h3',
    '.profile-header p',
    '.profile-header h2',
    '.profile-header h3',
    'header h2',
    'header h3',
    'header p',
    'main h2',
    'main h3',
    'span[class*="title"]',
    '.text-subtitle',

    // Fallback to any h2/h3 after the first section
    'section h2:first-of-type',
    'section h3:first-of-type',
    'h2:first-of-type',
    'h3:first-of-type'
  ];

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector);
      if (el) {
        const text = cleanText(el.textContent);
        // Heuristic: Titles are usually short (5-150 chars) and don't contain "Overview", "Upwork", etc.
        if (text && text.length > 3 && text.length < 150 &&
          !text.includes('Overview') &&
          !text.includes('Upwork') &&
          !text.includes('Work history') &&
          !text.includes('Portfolio')) {

          return text;
        }
      }
    } catch (e) {
      // Ignore invalid selectors
    }
  }


  return null;
}

function extractBio(root: Document): string | null {
  // Target: <div class="air3-line-clamp"><span class="text-body">...</span></div>
  const selectors = [
    '[data-test="description"]',
    '.air3-line-clamp span.text-body', // As per user spec
    '.air3-line-clamp-wrapper span',
    'p.text-body',
    // Fallbacks
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

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector);
      if (el) {
        // Preserve line breaks for bio
        return (el.textContent || '').trim();
      }
    } catch (e) {
      // Ignore invalid selectors
    }
  }

  return null;
}

function extractName(root: Document): string | null {
  // Log what we're looking for (helps debug)


  const selectors = [
    // Modern Upwork selectors (2024-2025)
    '[data-testid="FreelancerName"]',
    '[data-testid="freelancer-name"]',
    '[data-test="freelancer-name"]',
    '[data-qa="freelancer-name"]',
    '[data-ev-label="freelancer_name"]',

    // H1/H2 patterns
    'h1.h2',
    'h2.h1',
    'h1[itemprop="name"]',
    'h2[itemprop="name"]',

    // Class-based patterns
    '.identity-name',
    '.freelancer-name',
    '.profile-name',
    '.display-name',
    '.up-n-link',

    // Aria/accessibility
    '[aria-label*="freelancer"] h1',
    '[aria-label*="freelancer"] h2',
    '[role="heading"][aria-level="1"]',
    '[role="heading"][aria-level="2"]',

    // Container patterns
    '.profile-header h1',
    '.profile-header h2',
    '.up-card h1',
    '.up-card h2',
    'header h1',
    'header h2',
    'main h1',

    // New component-based selectors
    '[class*="FreelancerName"]',
    '[class*="freelancerName"]',
    '[class*="profile-name"]',
    '[class*="ProfileName"]',
    '[class*="IdentityName"]',
    '[class*="identity-name"]',
    '[class*="UserName"]',
    '[class*="userName"]',

    // Flexible matching
    'div[class*="name"] h1',
    'div[class*="name"] h2',
    'section[class*="profile"] h1',
    'section[class*="profile"] h2',

    // Last resort - any h1/h2 in main content
    'main section h1',
    'main section h2',
    '[role="main"] h1',
    '[role="main"] h2',

    // Ultimate fallback
    'h1:first-of-type',
    'h1',
    'h2:first-of-type'
  ];

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector);
      if (el) {
        const text = cleanText(el.textContent);
        // Validate it looks like a name (not too long, not empty)
        if (text && text.length > 1 && text.length < 100 && !text.includes('Upwork')) {

          return text;
        }
      }
    } catch (e) {
      // Ignore invalid selectors
    }
  }

  // Try getting from meta tags or structured data
  try {
    // Open Graph
    const ogTitle = root.querySelector('meta[property="og:title"]');
    if (ogTitle) {
      const content = ogTitle.getAttribute('content');
      if (content && content.includes(' - ')) {
        const name = content.split(' - ')[0].trim();
        if (name && name.length < 100) {

          return name;
        }
      }
    }

    // Document title fallback
    const title = document.title;
    if (title && title.includes(' | Upwork')) {
      const name = title.split(' | ')[0].trim();
      if (name && name.length < 100 && name !== 'Upwork') {

        return name;
      }
    }
  } catch (e) {

  }


  return null;
}

function extractLocation(root: Document): string | null {
  const selectors = [
    '[data-test="location"]',
    '[itemprop="addressLocality"]',
    '.location',
    // Fallbacks
    '[data-qa="location"]',
    '[data-qa="freelancer-location"]',
    '.freelancer-location',
    '[data-location]',
    '[class*="location"]',
    '[class*="Location"]',
    '[class*="geo"]',
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
  ];

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector);
      if (el) return cleanText(el.textContent);
    } catch (e) {
      // Ignore invalid selectors
    }
  }

  return null;
}

function extractStats(root: Document): { jobSuccessScore?: number; totalEarnings?: string; totalJobs?: number; totalHours?: number } {
  const stats: any = {};



  // Job Success Score - multiple patterns
  const jssSelectors = [
    '.job-success-score',
    '[data-test="job-success-score"]',
    '[data-testid="job-success-score"]',
    '[data-qa="job-success"]',
    '[class*="JobSuccess"]',
    '[class*="jobSuccess"]',
    '[class*="success-score"]',
    '.up-skill-wrapper',
    '[aria-label*="Job Success"]'
  ];

  for (const selector of jssSelectors) {
    try {
      const el = root.querySelector(selector);
      if (el) {
        const text = el.textContent || '';
        const match = text.match(/(\d+)\s*%/);
        if (match) {
          stats.jobSuccessScore = parseInt(match[1]);

          break;
        }
      }
    } catch (e) { }
  }

  // Also try to find JSS in any element containing percentage
  if (!stats.jobSuccessScore) {
    const allElements = root.querySelectorAll('*');
    for (const el of Array.from(allElements)) {
      const text = el.textContent || '';
      if (text.includes('Job Success') && text.includes('%')) {
        const match = text.match(/(\d+)\s*%/);
        if (match) {
          stats.jobSuccessScore = parseInt(match[1]);

          break;
        }
      }
    }
  }

  // Stats bar items (Earnings, Jobs, Hours)
  const statSelectors = [
    '.stat-amount',
    '[data-test="stat-amount"]',
    '[data-testid="stat-amount"]',
    '[class*="stat-amount"]',
    '[class*="StatAmount"]',
    '.up-stats span',
    '[class*="earnings"]',
    '[class*="Earnings"]'
  ];

  for (const selector of statSelectors) {
    try {
      const items = root.querySelectorAll(selector);
      items.forEach(item => {
        const value = cleanText(item.textContent);
        const parent = item.closest('[class*="stat"]') || item.parentElement;
        const label = cleanText(parent?.textContent?.replace(value, '') || '');

        if (label.toLowerCase().includes('earning') || value.includes('$') || value.includes('K+')) {
          stats.totalEarnings = value;

        }
        if (label.toLowerCase().includes('job') && !label.toLowerCase().includes('success')) {
          stats.totalJobs = parseInt(value.replace(/[,+K]/g, ''));

        }
        if (label.toLowerCase().includes('hour')) {
          stats.totalHours = parseInt(value.replace(/[,+K]/g, ''));

        }
      });
    } catch (e) { }
  }

  return stats;
}

function extractSkills(root: Document): string[] {
  const skills: string[] = [];
  const selectors = [
    '[data-test="skill"]',
    '.air3-token',
    '.skill-badge',
    // Fallbacks
    '[data-test="token"]',
    '[data-test="skill-item-stack"]',
    '[class*="skill"]',
    '[class*="token"]',
    '[class*="tag"]'
  ];

  for (const selector of selectors) {
    try {
      const elements = root.querySelectorAll(selector);
      if (elements.length > 0) {
        elements.forEach(el => {
          const text = cleanText(el.textContent);
          if (text) skills.push(text);
        });
        break; // Stop if we found a valid list
      }
    } catch (e) {
      // Ignore invalid selectors
    }
  }

  return skills;
}

function extractImage(root: Document): string | null {
  const selectors = [
    '[data-test="up-c-avatar"] img',
    '[data-testid="avatar"] img',
    '.up-avatar img',
    'img[alt*="Portrait"]',
    'img[alt*="profile"]',
    'img[alt*="Profile"]',
    '[class*="avatar"] img',
    '[class*="Avatar"] img',
    'header img',
    '.profile-header img'
  ];

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector) as HTMLImageElement;
      if (el && el.src && !el.src.includes('placeholder') && !el.src.includes('default')) {

        return el.src;
      }
    } catch (e) { }
  }

  return null;
}

// ============================================
// NEW EXTRACTORS
// ============================================

interface PortfolioItem {
  title: string;
  description?: string;
  url?: string;
  imageUrl?: string;
  completedDate?: string;
  skills?: string[];
}

async function extractPortfolio(root: Document): Promise<PortfolioItem[]> {
  const portfolio: PortfolioItem[] = [];
  const seenTitles = new Set<string>();



  // Find the portfolio section container
  // Based on HTML: div.portfolio-v2-editor-shelf or heading containing "Portfolio"
  let container: Element | null = root.querySelector('.portfolio-v2-editor-shelf');

  if (!container) {
    container = root.querySelector('[class*="portfolio-v2"]');
  }

  if (!container) {
    // Try finding by heading
    const headings = root.querySelectorAll('h2, h3, h4');
    for (const h of Array.from(headings)) {
      if (h.textContent?.trim().toLowerCase() === 'portfolio') {
        container = h.closest('.vue-portal-target') || h.closest('section') || h.parentElement;
        break;
      }
    }
  }

  if (!container) {

    return portfolio;
  }



  // Function to extract items from current page
  const extractCurrentPageItems = (): void => {
    // Based on HTML: each item is div.portfolio-v2-shelf-thumbnail
    const thumbnails = container!.querySelectorAll('.portfolio-v2-shelf-thumbnail');

    if (thumbnails.length === 0) {
      // Fallback selectors
      const gridItems = container!.querySelectorAll('.air3-grid-container > div[class*="span"]');
      gridItems.forEach((item) => {
        try {
          // Title is in <a> inside div.mt-3x
          const titleLink = item.querySelector('.mt-3x a, a.no-underline');
          const title = cleanText(titleLink?.textContent) || '';

          // Image is in .list-complete-item-custom-bg img
          const imgEl = item.querySelector('img') as HTMLImageElement | null;
          const imageUrl = imgEl?.src || '';

          if (title && !seenTitles.has(title)) {
            seenTitles.add(title);
            portfolio.push({ title, imageUrl });

          }
        } catch (e) {

        }
      });
      return;
    }

    thumbnails.forEach((thumbnail) => {
      try {
        // Title: inside div.mt-3x > a
        const titleLink = thumbnail.querySelector('.mt-3x a, a.no-underline, a.d-flex');
        const title = cleanText(titleLink?.textContent) || '';

        // Image: inside .list-complete-item-custom-bg img or just img
        const imgEl = thumbnail.querySelector('.list-complete-item-custom-bg img, img') as HTMLImageElement | null;
        let imageUrl = imgEl?.src || '';

        // Convert relative URLs to absolute
        if (imageUrl && !imageUrl.startsWith('http')) {
          imageUrl = `https://www.upwork.com${imageUrl}`;
        }

        if (title && !seenTitles.has(title)) {
          seenTitles.add(title);
          portfolio.push({ title, imageUrl });

        }
      } catch (e) {

      }
    });
  };

  // Extract first page
  extractCurrentPageItems();

  // Check for pagination and click through all pages
  const paginationNav = container.querySelector('.air3-pagination, [data-test="pagination"]');
  if (paginationNav) {


    let hasNextPage = true;
    let pageCount = 1;
    const maxPages = 10; // Safety limit

    while (hasNextPage && pageCount < maxPages) {
      // Find next page button
      const nextBtn = container.querySelector('[data-test="next-page"]:not(.is-disabled), [data-ev-label="pagination_next_page"]:not([disabled])') as HTMLButtonElement | null;

      if (nextBtn && !nextBtn.disabled && !nextBtn.classList.contains('is-disabled')) {

        nextBtn.click();
        pageCount++;

        // Wait for content to load
        await new Promise(resolve => setTimeout(resolve, 800));

        // Extract items from new page
        extractCurrentPageItems();
      } else {
        hasNextPage = false;
      }
    }


  }


  return portfolio;
}

function extractCategories(root: Document): string[] {
  const categories: string[] = [];



  // Find categories/specializations section
  const selectors = [
    '[data-test="categories"]',
    '[data-testid="categories"]',
    '[class*="categories"]',
    '[class*="Categories"]',
    '[class*="specialization"]',
    '[class*="Specialization"]',
    'nav.breadcrumbs a',
    '[class*="breadcrumb"] a'
  ];

  for (const selector of selectors) {
    try {
      const items = root.querySelectorAll(selector);
      items.forEach(item => {
        const text = cleanText(item.textContent);
        if (text && text.length > 2 && text.length < 100 &&
          !text.toLowerCase().includes('upwork') &&
          !text.toLowerCase().includes('home')) {
          categories.push(text);
        }
      });
      if (categories.length > 0) break;
    } catch (e) { }
  }


  return [...new Set(categories)]; // Remove duplicates
}

interface ReviewItem {
  rating?: number;
  comment: string;
  clientName?: string;
  date?: string;
  jobTitle?: string;
}

function extractReviews(root: Document): ReviewItem[] {
  const reviews: ReviewItem[] = [];



  // Find reviews/work history section
  const containerSelectors = [
    '[data-test="work-history"]',
    '[data-testid="work-history"]',
    '[class*="work-history"]',
    '[class*="WorkHistory"]',
    '[class*="reviews"]',
    '[class*="Reviews"]',
    'section[aria-label*="review"]',
    'section[aria-label*="work history"]'
  ];

  let container: Element | null = null;
  for (const selector of containerSelectors) {
    try {
      container = root.querySelector(selector);
      if (container) break;
    } catch (e) { }
  }

  if (!container) {
    const headings = root.querySelectorAll('h2, h3');
    for (const h of Array.from(headings)) {
      const text = h.textContent?.toLowerCase() || '';
      if (text.includes('work history') || text.includes('review')) {
        container = h.closest('section') || h.parentElement;
        break;
      }
    }
  }

  if (!container) {

    return reviews;
  }

  // Find review items
  const itemSelectors = [
    '[data-test="job"]',
    '[data-testid="job"]',
    '[class*="job-item"]',
    '[class*="JobItem"]',
    '[class*="review-item"]',
    'article',
    '.up-card'
  ];

  let items: NodeListOf<Element> | null = null;
  for (const selector of itemSelectors) {
    try {
      items = container.querySelectorAll(selector);
      if (items.length > 0) break;
    } catch (e) { }
  }

  items?.forEach(item => {
    try {
      const review: ReviewItem = { comment: '' };

      // Extract job title
      const titleEl = item.querySelector('h4, h5, [class*="title"], [class*="Title"], strong');
      if (titleEl) review.jobTitle = cleanText(titleEl.textContent);

      // Extract rating (stars)
      const ratingEl = item.querySelector('[class*="rating"], [class*="Rating"], [class*="star"]');
      if (ratingEl) {
        const ratingText = ratingEl.getAttribute('aria-label') || ratingEl.textContent || '';
        const match = ratingText.match(/([\d.]+)/);
        if (match) review.rating = parseFloat(match[1]);
      }

      // Extract comment/feedback
      const commentEl = item.querySelector('p, [class*="feedback"], [class*="comment"], blockquote');
      if (commentEl) review.comment = cleanText(commentEl.textContent);

      // Extract date
      const dateEl = item.querySelector('time, [class*="date"], [class*="Date"], small');
      if (dateEl) review.date = cleanText(dateEl.textContent);

      if (review.jobTitle || review.comment) {
        reviews.push(review);
      }
    } catch (e) { }
  });


  return reviews.slice(0, 10); // Limit to 10 recent reviews
}

interface BadgeInfo {
  isTopRated: boolean;
  isRisingTalent: boolean;
  isVerified: boolean;
  isTopRatedPlus: boolean;
  isExpertVetted: boolean;
}

function extractBadges(root: Document): BadgeInfo {
  const badges: BadgeInfo = {
    isTopRated: false,
    isRisingTalent: false,
    isVerified: false,
    isTopRatedPlus: false,
    isExpertVetted: false
  };



  // Check all text content for badge indicators
  const bodyText = root.body?.textContent?.toLowerCase() || '';

  // Check for specific badge elements and text patterns
  const badgeSelectors = [
    '[data-test="badge"]',
    '[data-testid="badge"]',
    '[class*="badge"]',
    '[class*="Badge"]',
    '[class*="talent-badge"]',
    '.up-badge',
    'svg[aria-label]'
  ];

  for (const selector of badgeSelectors) {
    try {
      const elements = root.querySelectorAll(selector);
      elements.forEach(el => {
        const text = (el.textContent || el.getAttribute('aria-label') || '').toLowerCase();

        if (text.includes('top rated plus') || text.includes('top-rated plus')) {
          badges.isTopRatedPlus = true;
          badges.isTopRated = true;
        } else if (text.includes('top rated') || text.includes('top-rated')) {
          badges.isTopRated = true;
        }

        if (text.includes('rising talent')) {
          badges.isRisingTalent = true;
        }

        if (text.includes('verified') || text.includes('identity verified')) {
          badges.isVerified = true;
        }

        if (text.includes('expert-vetted') || text.includes('expert vetted')) {
          badges.isExpertVetted = true;
        }
      });
    } catch (e) { }
  }

  // Also check body text for badges
  if (bodyText.includes('top rated plus') || bodyText.includes('top-rated plus')) {
    badges.isTopRatedPlus = true;
    badges.isTopRated = true;
  } else if (bodyText.includes('top rated') || bodyText.includes('top-rated')) {
    badges.isTopRated = true;
  }

  if (bodyText.includes('rising talent')) {
    badges.isRisingTalent = true;
  }


  return badges;
}

function extractMemberSince(root: Document): string | null {


  // Look for member since text
  const patterns = [
    /member since[:\s]+([a-z]+\s+\d{4})/i,
    /joined[:\s]+([a-z]+\s+\d{4})/i,
    /since[:\s]+([a-z]+\s+\d{4})/i
  ];

  const bodyText = root.body?.textContent || '';

  for (const pattern of patterns) {
    const match = bodyText.match(pattern);
    if (match) {

      return match[1];
    }
  }

  // Try specific selectors
  const selectors = [
    '[data-test="member-since"]',
    '[class*="member-since"]',
    '[class*="memberSince"]',
    'time'
  ];

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector);
      if (el) {
        const text = cleanText(el.textContent);
        if (text && text.match(/\d{4}/)) {

          return text;
        }
      }
    } catch (e) { }
  }

  return null;
}

function extractAvailability(root: Document): string | null {


  const selectors = [
    '[data-test="availability"]',
    '[data-testid="availability"]',
    '[class*="availability"]',
    '[class*="Availability"]',
    '[aria-label*="availability"]'
  ];

  for (const selector of selectors) {
    try {
      const el = root.querySelector(selector);
      if (el) {
        const text = cleanText(el.textContent);
        if (text) {

          return text;
        }
      }
    } catch (e) { }
  }

  // Check for availability text patterns
  const bodyText = root.body?.textContent || '';
  const patterns = [
    /available[:\s]+(full[- ]?time|part[- ]?time|hourly|as needed)/i,
    /(more than \d+ hrs\/week)/i,
    /(less than \d+ hrs\/week)/i,
    /(\d+\+?\s*hrs?\/week)/i
  ];

  for (const pattern of patterns) {
    const match = bodyText.match(pattern);
    if (match) {

      return match[1];
    }
  }

  return null;
}

function extractEducation(root: Document): Array<{ institution?: string; degree?: string; field?: string; year?: string }> {
  const education: Array<{ institution?: string; degree?: string; field?: string; year?: string }> = [];



  // Find education section
  let container: Element | null = null;
  const headings = root.querySelectorAll('h2, h3, h4');
  for (const h of Array.from(headings)) {
    if (h.textContent?.toLowerCase().includes('education')) {
      container = h.closest('section') || h.parentElement;
      break;
    }
  }

  if (!container) {
    container = root.querySelector('[data-test="education"], [class*="education"], [class*="Education"]');
  }

  if (!container) return education;

  // Extract education items
  const items = container.querySelectorAll('li, article, [class*="item"], .up-card');
  items.forEach(item => {
    try {
      const edu: { institution?: string; degree?: string; field?: string; year?: string } = {};

      // Institution name (usually in strong/bold or heading)
      const instEl = item.querySelector('h4, h5, strong, b, [class*="name"], [class*="institution"]');
      if (instEl) edu.institution = cleanText(instEl.textContent);

      // Degree/field
      const degreeEl = item.querySelector('p, [class*="degree"], [class*="field"]');
      if (degreeEl) {
        const text = cleanText(degreeEl.textContent);
        if (text && text !== edu.institution) {
          edu.degree = text;
        }
      }

      // Year
      const yearEl = item.querySelector('time, [class*="year"], [class*="date"], small');
      if (yearEl) {
        const yearMatch = yearEl.textContent?.match(/\d{4}/);
        if (yearMatch) edu.year = yearMatch[0];
      }

      if (edu.institution || edu.degree) {
        education.push(edu);

      }
    } catch (e) { }
  });

  return education;
}

function extractCertifications(root: Document): Array<{ name?: string; issuer?: string; date?: string }> {
  const certifications: Array<{ name?: string; issuer?: string; date?: string }> = [];



  // Find certifications section
  let container: Element | null = null;
  const headings = root.querySelectorAll('h2, h3, h4');
  for (const h of Array.from(headings)) {
    const text = h.textContent?.toLowerCase() || '';
    if (text.includes('certification') || text.includes('credential')) {
      container = h.closest('section') || h.parentElement;
      break;
    }
  }

  if (!container) {
    container = root.querySelector('[data-test="certifications"], [class*="certification"], [class*="Certification"]');
  }

  if (!container) return certifications;

  // Extract certification items
  const items = container.querySelectorAll('li, article, [class*="item"], .up-card');
  items.forEach(item => {
    try {
      const cert: { name?: string; issuer?: string; date?: string } = {};

      // Certification name
      const nameEl = item.querySelector('h4, h5, strong, b, [class*="name"], [class*="title"]');
      if (nameEl) cert.name = cleanText(nameEl.textContent);

      // Issuer
      const issuerEl = item.querySelector('p, [class*="issuer"], [class*="provider"]');
      if (issuerEl) {
        const text = cleanText(issuerEl.textContent);
        if (text && text !== cert.name) {
          cert.issuer = text;
        }
      }

      // Date
      const dateEl = item.querySelector('time, [class*="date"], small');
      if (dateEl) cert.date = cleanText(dateEl.textContent);

      if (cert.name) {
        certifications.push(cert);

      }
    } catch (e) { }
  });

  return certifications;
}

// ============================================
// MAIN SCRAPER
// ============================================

export async function scrapeProfileFromDOM(): Promise<ScrapeResult> {
  const logs: string[] = [];
  const log = (msg: string) => {
    logs.push(`[Scraper] ${msg}`);

  };

  log('Starting comprehensive profile scrape...');
  log(`URL: ${window.location.href}`);

  try {
    // 1. Verify we are on a profile page
    if (!window.location.href.includes('/freelancers/')) {
      return { success: false, error: 'Not a freelancer profile page', logs };
    }

    log('Page appears to be a freelancer profile');

    // 2. Extract all data
    log('--- Extracting basic info ---');
    const name = extractName(document);
    const title = extractTitle(document);
    const bio = extractBio(document);
    const rateData = extractHourlyRate(document);
    const location = extractLocation(document);
    const image = extractImage(document);

    log('--- Extracting stats ---');
    const stats = extractStats(document);

    log('--- Extracting skills ---');
    const skills = extractSkills(document);

    log('--- Extracting badges ---');
    const badges = extractBadges(document);

    log('--- Extracting portfolio (with pagination) ---');
    const portfolio = await extractPortfolio(document);

    log('--- Extracting categories ---');
    const categories = extractCategories(document);

    log('--- Extracting reviews ---');
    const reviews = extractReviews(document);

    log('--- Extracting additional info ---');
    const memberSince = extractMemberSince(document);
    const availability = extractAvailability(document);
    const education = extractEducation(document);
    const certifications = extractCertifications(document);

    // 3. Log summary
    log('=== EXTRACTION SUMMARY ===');
    log(`Name: ${name || 'NOT FOUND'}`);
    log(`Title: ${title || 'NOT FOUND'}`);
    log(`Location: ${location || 'NOT FOUND'}`);
    log(`Hourly Rate: ${rateData?.hourlyRate || 'NOT FOUND'}`);
    log(`Job Success: ${stats.jobSuccessScore || 'NOT FOUND'}%`);
    log(`Total Jobs: ${stats.totalJobs || 'NOT FOUND'}`);
    log(`Total Hours: ${stats.totalHours || 'NOT FOUND'}`);
    log(`Skills: ${skills?.length || 0} items`);
    log(`Portfolio: ${portfolio?.length || 0} items`);
    log(`Categories: ${categories?.length || 0} items`);
    log(`Reviews: ${reviews?.length || 0} items`);
    log(`Education: ${education?.length || 0} items`);
    log(`Certifications: ${certifications?.length || 0} items`);
    log(`Badges: TopRated=${badges.isTopRated}, Rising=${badges.isRisingTalent}, Verified=${badges.isVerified}`);
    log(`Member Since: ${memberSince || 'NOT FOUND'}`);
    log(`Availability: ${availability || 'NOT FOUND'}`);
    log(`Bio: ${bio ? bio.substring(0, 50) + '...' : 'NOT FOUND'}`);
    log('========================');

    // 4. Validate - only name is truly required
    if (!name) {
      log('DEBUG: Document title = ' + document.title);
      log('DEBUG: H1 count = ' + document.querySelectorAll('h1').length);
      log('DEBUG: H2 count = ' + document.querySelectorAll('h2').length);
      const firstH1 = document.querySelector('h1');
      if (firstH1) log('DEBUG: First H1 = ' + cleanText(firstH1.textContent));

      return { success: false, error: 'Could not find profile name', logs };
    }

    // 5. Construct comprehensive Profile Object
    const profile: UpworkProfile = {
      platform: 'upwork',

      // Basic Info
      name: name,
      displayName: name,
      title: title || 'Freelancer',
      bio: bio || '',
      overview: bio || '',
      description: bio || '',
      location: location || '',
      profileImage: image || '',
      profileUrl: window.location.href,

      // Rates
      hourlyRate: rateData?.hourlyRate,
      hourlyRateCurrency: rateData?.currency,

      // Stats
      jobSuccessScore: stats.jobSuccessScore,
      totalEarnings: stats.totalEarnings ? parseFloat(stats.totalEarnings.replace(/[$,K+]/g, '')) : undefined,
      totalJobs: stats.totalJobs,
      totalHours: stats.totalHours,

      // Badges
      isTopRated: badges.isTopRated,
      isTopRatedPlus: badges.isTopRatedPlus,
      isRisingTalent: badges.isRisingTalent,
      isVerified: badges.isVerified,
      isExpertVetted: badges.isExpertVetted,

      // Skills & Experience
      skills: skills,
      categories: categories,

      // Portfolio
      portfolio: portfolio,

      // Reviews
      recentReviews: reviews,
      rating: reviews.length > 0 ? reviews.reduce((sum, r) => sum + (r.rating || 0), 0) / reviews.filter(r => r.rating).length : undefined,
      reviewCount: reviews.length,

      // Education & Certifications
      education: education,
      certifications: certifications,

      // Additional Info
      memberSince: memberSince || '',
      availability: availability || '',

      // Metadata
      scrapedAt: new Date().toISOString(),
      scrapedFrom: window.location.href
    };

    log('Profile object constructed successfully with ' + Object.keys(profile).length + ' fields');
    return { success: true, data: profile, logs };

  } catch (e: any) {
    log(`Exception: ${e.message}`);
    console.error('[Scraper] Exception:', e);
    return { success: false, error: e.message, logs };
  }
}
