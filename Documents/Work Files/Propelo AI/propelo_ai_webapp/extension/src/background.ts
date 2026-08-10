import type { NormalizedJob, ChromeMessage, ProposalResponse, ScrapeStateData, TabInfo } from './types';

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://app.propeloai.com';

// ============================================
// SCRAPING STATE MACHINE
// ============================================

interface ScrapeStateManager {
  state: ScrapeStateData;
  tabInfo?: TabInfo;
  /** CRITICAL: Explicit flag that MUST be true for scraping to proceed */
  scrapeRequested: boolean;
  /** Timestamp of last scrape request (for debouncing) */
  lastRequestTime: number;
}

const scrapeStateMachine: ScrapeStateManager = {
  state: {
    state: 'idle',
    progress: 0,
    steps: [],
  },
  scrapeRequested: false,
  lastRequestTime: 0
};

/** GUARD: Check if scraping is explicitly allowed */
function isScrapeAllowed(): boolean {
  return scrapeStateMachine.scrapeRequested === true;
}

/** Reset scrape flag after completion or failure */
function resetScrapeFlag(): void {
  scrapeStateMachine.scrapeRequested = false;

}

/**
 * Update scraping state and broadcast to popup
 */
function setScrapeState(newState: Partial<ScrapeStateData>): void {
  scrapeStateMachine.state = {
    ...scrapeStateMachine.state,
    ...newState,
  };



  // Broadcast to all popups
  chrome.runtime.sendMessage({
    action: 'SCRAPE_STATE_CHANGED',
    data: scrapeStateMachine.state
  }).catch(() => { });
}

/**
 * Open a temporary tab for scraping
 */
async function openTemporaryTab(profileUrl: string): Promise<number> {


  // Validate URL before creating tab
  if (!profileUrl || !profileUrl.startsWith('http')) {
    throw new Error('Invalid profile URL');
  }

  let tab: chrome.tabs.Tab;

  try {
    tab = await chrome.tabs.create({
      url: profileUrl,
      active: false, // Open in background
      pinned: false,
    });
  } catch (createError: any) {
    console.error('[Background] Tab creation failed:', createError);
    throw new Error(`Failed to open profile page: ${createError.message || 'Unknown error'}`);
  }

  if (!tab.id) {
    throw new Error('Tab was created but has no ID');
  }

  // Wait for tab to be ready with timeout
  const TIMEOUT_MS = 30000;
  const startTime = Date.now();

  await new Promise((resolve, reject) => {
    const checkReady = async () => {
      // Check timeout
      if (Date.now() - startTime > TIMEOUT_MS) {
        reject(new Error('Timeout waiting for profile page to load'));
        return;
      }

      try {
        const updatedTab = await chrome.tabs.get(tab.id!);
        if (updatedTab.status === 'complete') {
          resolve(true);
        } else {
          setTimeout(checkReady, 200);
        }
      } catch (getError) {
        // Tab might have been closed
        reject(new Error('Tab was closed before it finished loading'));
      }
    };
    checkReady();
  });



  // Store tab info
  scrapeStateMachine.tabInfo = {
    tabId: tab.id,
    windowId: tab.windowId || 0,
    profileUrl,
    createdAt: Date.now(),
  };

  return tab.id;
}

/**
 * Close the temporary tab
 */
async function closeTemporaryTab(): Promise<void> {
  if (!scrapeStateMachine.tabInfo?.tabId) return;

  try {
    await chrome.tabs.remove(scrapeStateMachine.tabInfo.tabId);

  } catch (error) {

  }

  scrapeStateMachine.tabInfo = undefined;
}

// ============================================
// SYNC STATE MANAGEMENT (inline for background script)
// ============================================

interface SyncState {
  status: 'idle' | 'pending' | 'syncing' | 'success' | 'error';
  lastSyncedAt: string | null;
  lastError: string | null;
  retryCount: number;
}

const SYNC_STATE_KEY = 'propelo_sync_state';

async function getSyncState(): Promise<SyncState> {
  const result = await chrome.storage.local.get([SYNC_STATE_KEY]);
  return result[SYNC_STATE_KEY] || {
    status: 'idle',
    lastSyncedAt: null,
    lastError: null,
    retryCount: 0
  };
}

async function setSyncState(state: Partial<SyncState>): Promise<void> {
  const current = await getSyncState();
  const newState = { ...current, ...state };
  await chrome.storage.local.set({ [SYNC_STATE_KEY]: newState });

}

// Message routing between content scripts and popup
chrome.runtime.onMessage.addListener((message: ChromeMessage, _sender, sendResponse) => {
  // Ping check for extension detection
  if (message.action === 'PING') {
    sendResponse({ success: true, message: 'Extension is running' });
    return true;
  }

  if (message.action === 'SCRAPE_JOB') {
    handleJobScrape(message.data)
      .then(sendResponse)
      .catch(error => sendResponse({ error: error.message }));
    return true; // Keep channel open for async response
  }

  if (message.action === 'LOG_ERROR') {
    logError(message.data);
    sendResponse({ success: true });
    return true;
  }

  if (message.action === 'AUTH_STATE_CHANGED') {

    // Broadcast to all tabs/popups that auth state changed
    chrome.runtime.sendMessage({ action: 'AUTH_STATE_CHANGED' }).catch(() => {
      // Ignore if no receivers
    });
    sendResponse({ success: true });
    return true;
  }

  // Handle account data sync
  if (message.action === 'SYNC_ACCOUNT_DATA') {
    handleAccountSync(message.data)
      .then(sendResponse)
      .catch(error => sendResponse({ error: error.message }));
    return true;
  }

  // Handle proposal tracking sync
  if (message.action === 'SYNC_PROPOSALS') {
    handleProposalSync(message.data)
      .then(sendResponse)
      .catch(error => sendResponse({ error: error.message }));
    return true;
  }

  // NEW: Handle scraping progress step
  if (message.action === 'SCRAPE_STEP') {

    setScrapeState({
      progress: message.data?.progress || 0,
      currentStep: {
        step: message.data?.step,
        progress: message.data?.progress || 0,
        message: message.data?.message,
        startedAt: Date.now(),
      }
    });
    sendResponse({ ok: true });
    return true;
  }

  // NEW: Handle scraping completion
  if (message.action === 'SCRAPE_COMPLETE') {


    setScrapeState({
      state: 'syncing',
      progress: 95,
    });

    handleScrapingComplete(message.data)
      .then(() => {
        // Sync successful - update to complete state
        setScrapeState({
          state: 'complete',
          progress: 100,
          completedAt: Date.now(),
        });

        // Close the temporary tab
        closeTemporaryTab();

        // CRITICAL: Reset scrape flag
        resetScrapeFlag();

        sendResponse({ success: true });
      })
      .catch(error => {
        setScrapeState({
          state: 'error',
          error: error.message,
          canRetry: true,
        });

        // Close the temporary tab even on error
        closeTemporaryTab();

        // CRITICAL: Reset scrape flag on error
        resetScrapeFlag();

        sendResponse({ success: false, error: error.message });
      });
    return true;
  }

  // NEW: Handle scraping error
  if (message.action === 'SCRAPE_ERROR') {
    console.error('[Background] Scrape error:', message.data?.error);
    setScrapeState({
      state: 'error',
      error: message.data?.error,
      errorStep: message.data?.step,
      canRetry: message.data?.canRetry !== false,
    });

    // Close temp tab on error
    closeTemporaryTab();

    // CRITICAL: Reset scrape flag on error
    resetScrapeFlag();

    sendResponse({ ok: true });
    return true;
  }

  // NEW: Handle explicit scrape start from popup
  if (message.action === 'SCRAPE_START') {

    handleScrapeStart(message.data || {})
      .then(sendResponse)
      .catch(error => {
        sendResponse({ success: false, error: error.message });
      });
    return true;
  }

  // Handle auto-scrape trigger from webapp
  if (message.action === 'AUTO_SCRAPE_PROFILE') {
    handleAutoScrapeProfile(message.data)
      .then(sendResponse)
      .catch(error => sendResponse({ error: error.message }));
    return true;
  }

  // Handle scraping status updates (for popup UI)
  if (message.action === 'SCRAPING_STATUS') {
    // Broadcast to popup
    chrome.runtime.sendMessage(message).catch(() => { });
    sendResponse({ success: true });
    return true;
  }
});

// Helper: fetch with timeout
async function fetchWithTimeout(url: string, options: RequestInit = {}, timeoutMs = 15000): Promise<Response> {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { ...options, signal: controller.signal });
    return res;
  } finally {
    clearTimeout(id);
  }
}

// Helper: basic retry with exponential backoff
async function fetchWithRetry(url: string, options: RequestInit, retries = 1, baseDelayMs = 500): Promise<Response> {
  let attempt = 0;
  // Always enforce a timeout per attempt
  const doAttempt = () => fetchWithTimeout(url, options, 15000);
  while (true) {
    try {
      const res = await doAttempt();
      return res;
    } catch (err) {
      if (attempt >= retries) throw err;
      const delay = baseDelayMs * Math.pow(2, attempt);
      await new Promise((r) => setTimeout(r, delay));
      attempt += 1;
    }
  }
}

async function handleJobScrape(jobData: NormalizedJob): Promise<ProposalResponse> {
  try {


    // 1. Normalize data
    const normalized = normalizeJobData(jobData);

    // 2. Get Firebase auth token
    const token = await getAuthToken();

    if (!token) {
      throw new Error('User not authenticated. Please sign in to Propelo first.');
    }



    // 3. Transform job data to match API format
    const requestBody: any = {
      jobTitle: normalized.jobTitle,
      jobDescription: normalized.description,
      platform: normalized.platform,
      tone: 'professional', // Default tone
      selectedSections: ['introduction', 'qualifications', 'approach', 'callToAction'], // Required sections
      _idToken: token // Fallback token for API
    };

    // Only add optional fields if they have values
    if (normalized.clientInfo?.name) {
      requestBody.clientName = normalized.clientInfo.name;
    }

    if (normalized.budget) {
      requestBody.budget = normalized.budget;
    }



    // 4. Send to Next.js API


    const response = await fetchWithRetry(`${API_BASE_URL}/api/proposals/generate`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(requestBody)
    });



    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || `API returned ${response.status}`);
    }

    const result = await response.json();


    // Transform API response to match ProposalResponse interface
    // Ensure insights are converted to strings
    const suggestions = Array.isArray(result.data.insights)
      ? result.data.insights.map((insight: any) => {
        if (typeof insight === 'string') return insight;
        if (typeof insight === 'object' && insight !== null) {
          // Extract text from insight object (e.g., {id, type, title, description, importance})
          return insight.title || insight.description || insight.text || String(insight);
        }
        return String(insight);
      })
      : [];

    return {
      proposalId: result.data.id,
      proposal: result.data.content,
      suggestions,
      confidence: 0.85
    };
  } catch (error: any) {
    const errorMsg = error.message || 'Unknown error during job processing';
    console.error('[Propelo Background] ❌ Error:', error);
    logError({
      type: 'job_scrape_error',
      message: errorMsg,
      jobTitle: jobData.jobTitle,
      timestamp: Date.now()
    });
    throw error;
  }
}

/**
 * Handle scraping completion - sends data to backend API
 */
async function handleScrapingComplete(data: any): Promise<any> {


  if (!data?.profileData) {
    throw new Error('No profile data provided');
  }

  // Get auth credentials
  const token = await getAuthToken();
  const storageData = await chrome.storage.local.get(['userId']);
  const userId = storageData.userId;

  if (!token) {
    throw new Error('Not authenticated - sign in to web app first');
  }

  if (!userId) {
    throw new Error('User ID not found - sign in to web app first');
  }

  // Send to backend API for sync
  const profileData = data.profileData;

  return handleAccountSync({
    platform: 'upwork',
    profileData,
    timestamp: new Date().toISOString(),
    version: Date.now(),
    clientId: `ext_${chrome.runtime.id}`
  });
}

/**
 * Handle account data sync from content scripts
 * Production-grade implementation with retry, state tracking, and error handling
 */
async function handleAccountSync(data: any): Promise<any> {
  const MAX_RETRIES = 3;
  const BASE_DELAY = 1000;







  // Check if already syncing
  const currentState = await getSyncState();
  if (currentState.status === 'syncing') {

    return { success: false, error: 'Sync already in progress' };
  }

  await setSyncState({ status: 'pending', lastError: null });

  try {
    // Get auth credentials
    const token = await getAuthToken();
    const storageData = await chrome.storage.local.get(['userId']);
    const userId = storageData.userId;



    if (!token) {
      const error = 'Not authenticated - sign in to web app first';
      await setSyncState({ status: 'error', lastError: error });
      return { success: false, error };
    }

    if (!userId) {
      const error = 'User ID not found - sign in to web app first';
      await setSyncState({ status: 'error', lastError: error });
      return { success: false, error };
    }

    // Prepare request
    const syncRequest = {
      userId,
      platform: data.platform,
      profileData: data.profileData,
      timestamp: new Date().toISOString(),
      version: Date.now(),
      clientId: `ext_${chrome.runtime.id}`
    };

    // Attempt with retries
    let lastError = 'Unknown error';

    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        await setSyncState({ status: 'syncing', retryCount: attempt });




        const response = await fetchWithTimeout(
          `${API_BASE_URL}/api/account/sync`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${token}`,
              'X-Client-ID': syncRequest.clientId
            },
            body: JSON.stringify(syncRequest)
          },
          30000
        );

        const result = await response.json();



        // Handle 401 - auth expired
        if (response.status === 401) {
          console.error('[Background Sync] Auth expired (401)');
          await setSyncState({ status: 'error', lastError: 'Session expired. Please sign in again.' });

          // Broadcast auth expired to popup
          chrome.runtime.sendMessage({
            action: 'AUTH_EXPIRED',
            data: { error: 'Session expired. Please sign in again.' }
          }).catch(() => { });

          return {
            success: false,
            error: 'Session expired. Please sign in again.',
            authExpired: true
          };
        }

        if (response.ok && result.success) {
          await setSyncState({
            status: 'success',
            lastSyncedAt: new Date().toISOString(),
            lastError: null,
            retryCount: 0
          });

          // Broadcast success to popup
          chrome.runtime.sendMessage({
            action: 'PROFILE_SYNC_RESULT',
            data: { success: true, syncedAt: result.syncedAt }
          }).catch(() => { });


          return { success: true, ...result };
        }

        lastError = result.error || `HTTP ${response.status}`;
        console.error(`[Background Sync] Attempt ${attempt + 1} failed:`, lastError);

      } catch (fetchError: any) {
        lastError = fetchError.message || 'Network error';
        console.error(`[Background Sync] Attempt ${attempt + 1} exception:`, lastError);
      }

      // Wait before retry (except on last attempt)
      if (attempt < MAX_RETRIES) {
        const delay = BASE_DELAY * Math.pow(2, attempt);

        await new Promise(r => setTimeout(r, delay));
      }
    }

    // All retries failed
    await setSyncState({ status: 'error', lastError, retryCount: MAX_RETRIES });

    // Broadcast failure to popup
    chrome.runtime.sendMessage({
      action: 'PROFILE_SYNC_RESULT',
      data: { success: false, error: lastError }
    }).catch(() => { });

    console.error('[Background Sync] ❌ All attempts failed:', lastError);
    logError({
      type: 'sync_failed',
      platform: data.platform,
      error: lastError,
      retries: MAX_RETRIES,
      timestamp: Date.now()
    });
    return { success: false, error: lastError };

  } catch (error: any) {
    const errorMsg = error.message || 'Unexpected error';
    await setSyncState({ status: 'error', lastError: errorMsg });
    console.error('[Background Sync] ❌ Exception:', errorMsg);
    return { success: false, error: errorMsg };
  }
}

/**
 * Handle proposal tracking sync from content scripts
 */
async function handleProposalSync(data: any): Promise<any> {
  try {


    // Get auth token
    const token = await getAuthToken();
    if (!token) {
      throw new Error('User not authenticated');
    }

    // Get user ID from storage
    const storageData = await chrome.storage.local.get(['userId']);
    const userId = storageData.userId;

    if (!userId) {
      throw new Error('User ID not found');
    }

    // Add userId to each proposal
    const proposalsWithUserId = data.proposals.map((p: any) => ({
      ...p,
      userId
    }));

    // Prepare sync request
    const syncRequest = {
      userId,
      platform: data.platform,
      proposals: proposalsWithUserId,
      syncedAt: new Date().toISOString()
    };



    // Send to API
    const response = await fetchWithRetry(
      `${API_BASE_URL}/api/proposals/track`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`
        },
        body: JSON.stringify(syncRequest)
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to sync proposals');
    }

    const result = await response.json();


    return { success: true, ...result };

  } catch (error: any) {
    console.error('[Propelo Background] Proposal sync error:', error);
    return { error: error.message };
  }
}

/**
 * Periodic sync for account data and proposals
 * Runs every 30 minutes
 */
function setupPeriodicSync() {
  const SYNC_INTERVAL = 30 * 60 * 1000; // 30 minutes

  setInterval(async () => {


    try {
      // Check if user is authenticated
      const token = await getAuthToken();
      if (!token) {

        return;
      }

      // Get stored account data
      const storage = await chrome.storage.local.get([
        'upworkProfile',
        'fiverrProfile',
        'freelancerProfile',
        'upworkProposals'
      ]);

      const syncResults = {
        upwork: { profile: false, proposals: false },
        fiverr: { profile: false },
        freelancer: { profile: false }
      };

      // Sync Upwork data if available
      if (storage.upworkProfile) {
        try {
          await handleAccountSync({
            platform: 'upwork',
            profileData: storage.upworkProfile
          });
          syncResults.upwork.profile = true;

        } catch (error) {
          console.error('[Propelo Background] ❌ Failed to sync Upwork profile:', error);
        }
      }

      if (storage.upworkProposals && storage.upworkProposals.length > 0) {
        try {
          await handleProposalSync({
            platform: 'upwork',
            proposals: storage.upworkProposals
          });
          syncResults.upwork.proposals = true;

        } catch (error) {
          console.error('[Propelo Background] ❌ Failed to sync Upwork proposals:', error);
        }
      }

      // Sync Fiverr data if available
      if (storage.fiverrProfile) {
        try {
          await handleAccountSync({
            platform: 'fiverr',
            profileData: storage.fiverrProfile
          });
          syncResults.fiverr.profile = true;

        } catch (error) {
          console.error('[Propelo Background] ❌ Failed to sync Fiverr profile:', error);
        }
      }

      // Sync Freelancer data if available
      if (storage.freelancerProfile) {
        try {
          await handleAccountSync({
            platform: 'freelancer',
            profileData: storage.freelancerProfile
          });
          syncResults.freelancer.profile = true;

        } catch (error) {
          console.error('[Propelo Background] ❌ Failed to sync Freelancer profile:', error);
        }
      }



      // Store last sync timestamp
      await chrome.storage.local.set({
        lastSync: new Date().toISOString(),
        lastSyncResults: syncResults
      });

    } catch (error) {
      console.error('[Propelo Background] Periodic sync error:', error);
      logError({
        type: 'periodic_sync_error',
        message: error instanceof Error ? error.message : String(error),
        timestamp: Date.now()
      });
    }
  }, SYNC_INTERVAL);


}

function normalizeJobData(jobData: NormalizedJob): NormalizedJob {
  return {
    jobTitle: jobData.jobTitle.trim(),
    description: jobData.description.trim(),
    budget: jobData.budget?.trim(),
    skills: jobData.skills.filter(s => s && s.trim()).map(s => s.trim()),
    clientInfo: jobData.clientInfo,
    platform: jobData.platform,
    url: jobData.url,
    scrapedAt: jobData.scrapedAt || new Date().toISOString()
  };
}

async function getAuthToken(): Promise<string | null> {
  return new Promise((resolve) => {
    chrome.storage.local.get(['authToken'], (result) => {
      resolve(result.authToken || null);
    });
  });
}

function logError(errorData: any): void {
  console.error('Extension error:', errorData);

  // Store error locally for debugging
  chrome.storage.local.get(['errors'], (result) => {
    const errors = result.errors || [];
    errors.push({
      ...errorData,
      timestamp: Date.now()
    });

    // Keep only last 50 errors
    if (errors.length > 50) {
      errors.shift();
    }

    chrome.storage.local.set({ errors });
  });
}

/**
 * NEW: Handle explicit SCRAPE_START from popup/web app
 * Opens temporary tab, triggers scraping, waits for completion
 */
async function handleScrapeStart(data: { profileUrl?: string }): Promise<any> {


  // CRITICAL: Double-click / duplicate request protection
  const now = Date.now();
  const DEBOUNCE_MS = 3000; // 3 second debounce
  if (now - scrapeStateMachine.lastRequestTime < DEBOUNCE_MS) {

    return { success: false, error: 'Please wait before trying again' };
  }

  // CRITICAL: Check if already scraping
  if (scrapeStateMachine.state.state === 'scraping' ||
    scrapeStateMachine.state.state === 'syncing' ||
    scrapeStateMachine.state.state === 'opening') {

    return { success: false, error: 'Scrape already in progress' };
  }

  // SET EXPLICIT FLAG
  scrapeStateMachine.scrapeRequested = true;
  scrapeStateMachine.lastRequestTime = now;


  // Get profile URL
  let profileUrl = data.profileUrl;

  if (!profileUrl) {
    // Try to auto-detect profile URL
    const stored = await chrome.storage.local.get(['upworkProfileUrl']);
    profileUrl = stored.upworkProfileUrl;
  }

  if (!profileUrl) {
    throw new Error('No profile URL provided and none stored');
  }

  // Set state to opening
  setScrapeState({
    state: 'opening',
    progress: 5,
    startedAt: Date.now(),
    steps: [],
  });

  try {
    // Open temporary tab
    const tabId = await openTemporaryTab(profileUrl);

    setScrapeState({
      state: 'scraping',
      progress: 10,
    });

    // Give content script a moment to initialize
    await new Promise(resolve => setTimeout(resolve, 500));

    // Send SCRAPE_START message to the content script in the tab


    try {
      const response = await chrome.tabs.sendMessage(tabId, {
        action: 'SCRAPE_START',
        data: { profileUrl }
      });


    } catch (msgError: any) {
      console.error('[Background] Failed to send message to tab:', msgError);
      // Content script might not be ready yet, try again after a delay
      await new Promise(resolve => setTimeout(resolve, 1000));

      const retryResponse = await chrome.tabs.sendMessage(tabId, {
        action: 'SCRAPE_START',
        data: { profileUrl }
      });

    }

    // Return tab info to popup
    return {
      success: true,
      tabId,
      message: 'Scraping started in background tab'
    };

  } catch (error: any) {
    console.error('[Background] SCRAPE_START error:', error);

    setScrapeState({
      state: 'error',
      error: error.message,
      canRetry: true,
    });

    // CRITICAL: Reset scrape flag on error
    resetScrapeFlag();

    await closeTemporaryTab();
    throw error;
  }
}

/**
 * Handle auto-scrape profile request from webapp
 * Opens Upwork, navigates to profile, triggers scraping
 */
async function handleAutoScrapeProfile(data: { platform: string }): Promise<{ success: boolean; message?: string }> {
  try {


    if (data.platform !== 'upwork') {
      return { success: false, message: 'Only Upwork is supported currently' };
    }

    // Step 1: Open or find Upwork tab
    const upworkUrl = 'https://www.upwork.com/ab/account-security/login';

    // Check if Upwork is already open
    const tabs = await chrome.tabs.query({ url: '*://*.upwork.com/*' });

    let targetTab: chrome.tabs.Tab;

    if (tabs.length > 0) {
      // Use existing tab
      targetTab = tabs[0];


      // Activate the tab
      if (targetTab.id) {
        await chrome.tabs.update(targetTab.id, { active: true });
        await chrome.windows.update(targetTab.windowId!, { focused: true });
      }
    } else {
      // Create new tab

      targetTab = await chrome.tabs.create({
        url: upworkUrl,
        active: true
      });
    }

    // Wait for tab to load
    await new Promise(resolve => setTimeout(resolve, 3000));

    // Step 2: Check if user is logged in by looking for profile URL
    if (targetTab.id) {
      const tab = await chrome.tabs.get(targetTab.id);

      if (tab.url?.includes('/login') || tab.url?.includes('/register')) {
        // User needs to log in


        // Send message to notify popup
        chrome.runtime.sendMessage({
          action: 'SCRAPING_STATUS',
          status: 'login',
          message: 'Please log in to Upwork...'
        }).catch(() => { });

        // Wait for login (poll for URL change)
        let loginAttempts = 0;
        const maxAttempts = 60; // 2 minutes max

        while (loginAttempts < maxAttempts) {
          await new Promise(resolve => setTimeout(resolve, 2000));
          const currentTab = await chrome.tabs.get(targetTab.id);

          if (!currentTab.url?.includes('/login') && !currentTab.url?.includes('/register')) {

            break;
          }

          loginAttempts++;
        }

        if (loginAttempts >= maxAttempts) {
          return { success: false, message: 'Login timeout - please try again' };
        }
      }

      // Step 3: Navigate to user's profile


      chrome.runtime.sendMessage({
        action: 'SCRAPING_STATUS',
        status: 'navigating',
        message: 'Navigating to your profile...'
      }).catch(() => { });

      // Get user's profile URL from storage or use settings page to find it
      const profileUrl = await getUpworkProfileUrl(targetTab.id);

      if (profileUrl) {
        await chrome.tabs.update(targetTab.id, { url: profileUrl });
      } else {
        // Navigate to settings to find profile URL
        await chrome.tabs.update(targetTab.id, { url: 'https://www.upwork.com/freelancers/settings/contactInfo' });
      }

      // Wait for navigation
      await new Promise(resolve => setTimeout(resolve, 5000));

      // Step 4: Trigger scraping via message to content script


      chrome.runtime.sendMessage({
        action: 'SCRAPING_STATUS',
        status: 'profile',
        message: 'Collecting profile info...'
      }).catch(() => { });

      // The content script will automatically scrape when it detects a profile page
      // We just need to wait for the data

      // Wait for scraping to complete (poll storage)
      let scrapeAttempts = 0;
      const maxScrapeAttempts = 30; // 1 minute max
      let profileData = null;

      while (scrapeAttempts < maxScrapeAttempts) {
        await new Promise(resolve => setTimeout(resolve, 2000));

        const storage = await chrome.storage.local.get(['upworkProfile']);
        if (storage.upworkProfile && storage.upworkProfile.scrapedAt) {
          const scrapedTime = new Date(storage.upworkProfile.scrapedAt).getTime();
          const now = Date.now();

          // Check if scraped within last 2 minutes
          if (now - scrapedTime < 120000) {
            profileData = storage.upworkProfile;

            break;
          }
        }

        scrapeAttempts++;
      }

      if (!profileData) {
        return { success: false, message: 'Profile scraping timeout - please try again' };
      }

      // Step 5: Send success message
      chrome.runtime.sendMessage({
        action: 'SCRAPING_STATUS',
        status: 'complete',
        message: 'Data collection complete!',
        data: {
          name: profileData.displayName,
          title: profileData.title,
          rate: profileData.hourlyRate,
          jss: profileData.jobSuccessScore,
          portfolioCount: profileData.portfolio?.length || 0
        }
      }).catch(() => { });



      return {
        success: true,
        message: 'Profile data collected successfully!'
      };
    }

    return { success: false, message: 'Failed to open Upwork tab' };

  } catch (error) {
    console.error('[Propelo Background] Auto-scrape error:', error);
    return {
      success: false,
      message: error instanceof Error ? error.message : 'Unknown error'
    };
  }
}

/**
 * Try to get user's Upwork profile URL
 */
async function getUpworkProfileUrl(tabId: number): Promise<string | null> {
  try {
    // Try to get from storage first
    const storage = await chrome.storage.local.get(['upworkProfileUrl', 'upworkProfile']);

    if (storage.upworkProfileUrl) {
      return storage.upworkProfileUrl;
    }

    if (storage.upworkProfile?.profileUrl) {
      return storage.upworkProfile.profileUrl;
    }

    // If not in storage, we'll need to navigate to settings to find it
    // This is handled in the main flow
    return null;

  } catch (error) {
    console.error('[Propelo Background] Error getting profile URL:', error);
    return null;
  }
}

// Listen for extension installation
chrome.runtime.onInstalled.addListener(() => {


  // Set default settings
  chrome.storage.local.set({
    consent: false,
    localMode: false,
    syncEnabled: true
  });

  // Start periodic sync
  setupPeriodicSync();
});

// Listen for external messages (from webapp)
chrome.runtime.onMessageExternal.addListener((message, sender, sendResponse) => {


  // Only allow messages from our webapp domain
  const allowedOrigins = [
    'https://app.propeloai.com',
    'https://propeloai.com',
    'https://www.propeloai.com'
  ];

  const senderOrigin = sender.url ? new URL(sender.url).origin : '';
  if (!allowedOrigins.includes(senderOrigin)) {

    sendResponse({ error: 'Unauthorized origin' });
    return false;
  }

  // Handle messages based on action
  if (message.action === 'PING') {
    sendResponse({ success: true, message: 'Extension is running' });
    return true;
  }

  if (message.action === 'AUTO_SCRAPE_PROFILE') {
    handleAutoScrapeProfile(message.data)
      .then(sendResponse)
      .catch(error => sendResponse({ error: error.message }));
    return true;
  }

  sendResponse({ error: 'Unknown action' });
  return false;
});

export { };
