import type { NormalizedJob } from '../types';

/**
 * Sanitize text by removing HTML tags and normalizing whitespace
 */
export function sanitizeText(text: string): string {
  return text
    .replace(/<[^>]*>/g, '') // Remove HTML tags
    .replace(/&nbsp;/g, ' ') // Replace &nbsp; with space
    .replace(/&amp;/g, '&') // Replace &amp; with &
    .replace(/&lt;/g, '<') // Replace &lt; with <
    .replace(/&gt;/g, '>') // Replace &gt; with >
    .replace(/&quot;/g, '"') // Replace &quot; with "
    .replace(/&#39;/g, "'") // Replace &#39; with '
    .replace(/\s+/g, ' ') // Normalize whitespace
    .trim();
}

/**
 * Validate that job data meets minimum requirements
 */
export function validateJobData(job: Partial<NormalizedJob>): job is NormalizedJob {
  return Boolean(
    job.jobTitle &&
    job.jobTitle.length > 3 &&
    job.description &&
    job.description.length > 50 &&
    job.platform &&
    job.url
  );
}

/**
 * Extract text content from an element
 */
export function getTextContent(selector: string): string | null {
  try {
    const element = document.querySelector(selector);
    return element ? sanitizeText(element.textContent || '') : null;
  } catch (error) {
    console.error(`Error getting text content for selector: ${selector}`, error);
    return null;
  }
}

/**
 * Extract text content from multiple elements
 */
export function getMultipleTextContent(selector: string): string[] {
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

/**
 * Wait for an element to appear in the DOM
 */
export function waitForElement(selector: string, timeout = 5000): Promise<Element | null> {
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

    // Timeout after specified duration
    setTimeout(() => {
      observer.disconnect();
      resolve(null);
    }, timeout);
  });
}

/**
 * Log scraping errors for debugging
 */
export function logScrapingError(platform: string, error: Error, context?: any): void {
  console.error(`[Propelo] Scraping error on ${platform}:`, error);
  
  // Send error to background script for storage
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
