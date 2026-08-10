/**
 * Scraper Events Handler
 * 
 * This content script listens for explicit SCRAPE_START messages
 * and coordinates step-by-step scraping with real-time progress reporting.
 * 
 * Used ONLY in temporary tabs opened by the background script.
 */

import type { ScrapeStep, ScrapingProgress } from '../types';
import { scrapeProfileFromDOM } from './profile-scraper';

// ============================================
// STATE
// ============================================

let isScraping = false;
let currentSteps: ScrapingProgress[] = [];

const STEPS_ORDER: ScrapeStep[] = [
  'opening_profile',
  'extracting_name',
  'extracting_title',
  'extracting_bio',
  'extracting_rate',
  'extracting_location',
  'extracting_skills',
  'extracting_stats',
  'extracting_portfolio',
  'validating_data',
  'syncing_to_backend',
];

const STEP_MESSAGES: Record<ScrapeStep, string> = {
  'opening_profile': 'Opening your Upwork profile…',
  'extracting_name': 'Collecting your name…',
  'extracting_title': 'Collecting your headline…',
  'extracting_bio': 'Collecting your overview…',
  'extracting_rate': 'Collecting your hourly rate…',
  'extracting_location': 'Collecting your location…',
  'extracting_skills': 'Collecting your skills…',
  'extracting_stats': 'Collecting your job success score…',
  'extracting_portfolio': 'Collecting your portfolio…',
  'validating_data': 'Validating collected data…',
  'syncing_to_backend': 'Syncing with Propelo…',
};

// ============================================
// STEP REPORTING
// ============================================

/**
 * Report a step completion to the background script
 */
function reportStep(step: ScrapeStep, progress: number): void {
  const stepData: ScrapingProgress = {
    step,
    progress,
    message: STEP_MESSAGES[step],
    startedAt: Date.now(),
  };
  
  currentSteps.push(stepData);
  
  // Send to background script (which forwards to popup)
  chrome.runtime.sendMessage({
    action: 'SCRAPE_STEP',
    data: {
      step,
      progress,
      message: STEP_MESSAGES[step],
    }
  }).catch(() => {
    // Ignore errors if background script isn't listening
  });
  

}

// ============================================
// MAIN SCRAPING ORCHESTRATOR
// ============================================

/**
 * Execute the full scraping workflow with step-by-step reporting
 */
async function executeScrapingFlow(): Promise<any> {
  const startTime = Date.now(); // Track actual start time for duration
  



  
  if (isScraping) {

    return { success: false, error: 'Already scraping' };
  }
  
  isScraping = true;
  currentSteps = [];
  
  try {
    // Step 1: Opening profile
    reportStep('opening_profile', 0);
    
    // Wait for page to be fully loaded
    await waitForProfilePage(5000);
    reportStep('opening_profile', 20);
    
    // Step 2-9: Extract data sections (async for portfolio pagination)

    const result = await scrapeProfileFromDOM();
    
    if (!result.success) {
      throw new Error(`Scrape failed: ${result.error}`);
    }
    
    const profileData = result.data;
    
    // Report extraction progress
    reportStep('extracting_name', 25);
    reportStep('extracting_title', 35);
    reportStep('extracting_bio', 45);
    reportStep('extracting_rate', 55);
    reportStep('extracting_location', 65);
    reportStep('extracting_skills', 75);
    reportStep('extracting_stats', 85);
    reportStep('extracting_portfolio', 90);
    
    // Step 10: Validate data
    reportStep('validating_data', 95);
    validateProfileData(profileData);
    
    // Data is valid, ready for sync
    reportStep('syncing_to_backend', 98);
    
    // Store in local storage for background to pick up
    chrome.storage.local.set({
      upworkProfile: profileData,
      upworkProfilePending: true,
      lastProfileScrape: new Date().toISOString()
    });
    
    // Emit SCRAPE_COMPLETE to background
    chrome.runtime.sendMessage({
      action: 'SCRAPE_COMPLETE',
      data: {
        profileData,
        duration: Date.now() - startTime, // FIXED: Actual elapsed time
        stepsCompleted: currentSteps.length,
      }
    }).catch(() => {});
    
    reportStep('syncing_to_backend', 100);
    

    return { success: true, profileData };
    
  } catch (error: any) {
    console.error('[Scraper] ❌ Scraping error:', error);
    
    const errorMessage = error.message || 'Unknown error';
    const failedStep = identifyFailedStep(error);
    
    chrome.runtime.sendMessage({
      action: 'SCRAPE_ERROR',
      data: {
        error: errorMessage,
        step: failedStep,
        canRetry: isRetryable(error),
      }
    }).catch(() => {});
    
    throw error;
    
  } finally {
    isScraping = false;
  }
}

// ============================================
// HELPERS
// ============================================

/**
 * Wait for profile page to be loaded
 */
async function waitForProfilePage(timeoutMs: number): Promise<void> {
  const startTime = Date.now();
  



  
  // Wait for document to be fully loaded first
  if (document.readyState !== 'complete') {

    await new Promise(resolve => {
      window.addEventListener('load', resolve, { once: true });
      // Also set a backup timeout
      setTimeout(resolve, 3000);
    });
  }
  
  // Extra wait for dynamic content (React/Angular hydration)
  await new Promise(resolve => setTimeout(resolve, 1500));
  
  while (Date.now() - startTime < timeoutMs) {
    // Look for any profile-specific elements with expanded selectors
    const profileElements = document.querySelectorAll(
      '[data-test="freelancer-name"], [data-testid="FreelancerName"], h1, h2, .profile-header, [class*="profile"], [class*="Profile"], [class*="freelancer"], [class*="Freelancer"]'
    );
    
    if (profileElements.length > 0) {

      // Give a bit more time for all content to render
      await new Promise(resolve => setTimeout(resolve, 500));
      return;
    }
    
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  


}

/**
 * Validate that required fields are present
 * PRODUCTION REQUIREMENT: Block sync if critical data is missing
 */
function validateProfileData(data: any): void {
  const errors: string[] = [];
  
  // CRITICAL: Must have name/displayName
  if (!data.displayName && !data.name) {
    errors.push('name');
  }
  
  // HIGH IMPORTANCE: These should be present but don't block sync
  const warnings: string[] = [];
  if (!data.title) warnings.push('title');
  if (!data.hourlyRate && data.hourlyRate !== 0) warnings.push('hourlyRate');
  if (!data.bio && !data.description && !data.overview) warnings.push('description');
  if (!data.profileUrl && !data.scrapedFrom) warnings.push('profileUrl');
  
  // Log warnings but don't block
  if (warnings.length > 0) {

  }
  
  // CRITICAL: Block if required fields missing
  if (errors.length > 0) {
    throw new Error(`Missing required fields: ${errors.join(', ')}`);
  }
  
  // Additional validation: Ensure data isn't empty placeholders
  const name = data.displayName || data.name;
  if (name && (name.length < 2 || name === 'undefined' || name === 'null')) {
    throw new Error('Invalid name value detected');
  }
  

}

/**
 * Identify which step failed
 */
function identifyFailedStep(error: any): ScrapeStep {
  const message = error.message || '';
  
  if (message.includes('name')) return 'extracting_name';
  if (message.includes('title')) return 'extracting_title';
  if (message.includes('rate')) return 'extracting_rate';
  if (message.includes('validation')) return 'validating_data';
  
  return 'opening_profile';
}

/**
 * Check if error is retryable
 */
function isRetryable(error: any): boolean {
  const message = error.message || '';
  return !message.includes('required fields');
}

// ============================================
// MESSAGE LISTENER
// ============================================

/**
 * Listen for SCRAPE_START messages from background script
 */
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message.action === 'SCRAPE_START') {

    
    // Execute scraping flow asynchronously
    executeScrapingFlow()
      .then(() => {
        sendResponse({ success: true });
      })
      .catch((error) => {
        sendResponse({ success: false, error: error.message });
      });
    
    // Keep the channel open for async response
    return true;
  }
  
  // Also support explicit SCRAPE_PROFILE for backwards compatibility
  if (message.type === 'SCRAPE_PROFILE') {

    
    executeScrapingFlow()
      .then((result) => {
        if (result.profileData) {
          sendResponse({ success: true, profile: result.profileData });
        } else {
          sendResponse({ success: false, error: 'No profile data extracted' });
        }
      })
      .catch((error) => {
        sendResponse({ success: false, error: error.message });
      });
    
    return true;
  }
});



export {};
