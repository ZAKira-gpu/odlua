/**
 * Production-Grade Profile Sync Service
 * 
 * This module handles all profile data synchronization between
 * the extension and the backend. It implements:
 * - Retry with exponential backoff
 * - State machine for sync status
 * - Idempotent operations
 * - Comprehensive error handling
 * - Observable logging
 */

import type { UpworkProfile } from '../types';

// ============================================
// TYPE DEFINITIONS
// ============================================

export type SyncStatus = 'idle' | 'pending' | 'syncing' | 'success' | 'error';

export interface SyncState {
  status: SyncStatus;
  lastSyncedAt: string | null;
  lastError: string | null;
  retryCount: number;
  version: number;
}

export interface SyncResult {
  success: boolean;
  error?: string;
  syncedAt?: string;
  version?: number;
}

export interface ProfileSyncRequest {
  userId: string;
  platform: 'upwork' | 'fiverr' | 'freelancer';
  profileData: UpworkProfile;
  timestamp: string;
  version: number;
  clientId: string; // Unique extension instance ID
}

export interface ProfileSyncResponse {
  success: boolean;
  message?: string;
  error?: string;
  syncedAt?: string;
  serverVersion?: number;
  canonicalProfile?: UpworkProfile;
}

// ============================================
// CONSTANTS
// ============================================

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://app.propeloai.com';
const MAX_RETRIES = 3;
const BASE_DELAY_MS = 1000;
const MAX_DELAY_MS = 30000;
const SYNC_TIMEOUT_MS = 30000;

// Generate a unique client ID for this extension instance
const getClientId = (): string => {
  const key = 'propelo_client_id';
  let clientId = localStorage.getItem(key);
  if (!clientId) {
    clientId = `ext_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    localStorage.setItem(key, clientId);
  }
  return clientId;
};

// ============================================
// SYNC STATE MANAGEMENT
// ============================================

const SYNC_STATE_KEY = 'propelo_sync_state';

export async function getSyncState(): Promise<SyncState> {
  const result = await chrome.storage.local.get([SYNC_STATE_KEY]);
  return result[SYNC_STATE_KEY] || {
    status: 'idle',
    lastSyncedAt: null,
    lastError: null,
    retryCount: 0,
    version: 0
  };
}

export async function setSyncState(state: Partial<SyncState>): Promise<void> {
  const current = await getSyncState();
  const newState = { ...current, ...state };
  await chrome.storage.local.set({ [SYNC_STATE_KEY]: newState });

}

// ============================================
// AUTH HELPERS
// ============================================

async function getAuthCredentials(): Promise<{ token: string; userId: string } | null> {
  const result = await chrome.storage.local.get(['authToken', 'userId']);

  if (!result.authToken || !result.userId) {
    console.error('[ProfileSync] Missing auth credentials:', {
      hasToken: !!result.authToken,
      hasUserId: !!result.userId
    });
    return null;
  }

  return {
    token: result.authToken,
    userId: result.userId
  };
}

// ============================================
// RETRY LOGIC
// ============================================

function calculateDelay(attempt: number): number {
  const delay = Math.min(BASE_DELAY_MS * Math.pow(2, attempt), MAX_DELAY_MS);
  // Add jitter (±25%)
  const jitter = delay * 0.25 * (Math.random() * 2 - 1);
  return Math.floor(delay + jitter);
}

async function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// ============================================
// MAIN SYNC FUNCTION
// ============================================

export async function syncProfileToBackend(
  profileData: UpworkProfile,
  platform: 'upwork' | 'fiverr' | 'freelancer' = 'upwork'
): Promise<SyncResult> {






  // Get current state
  const state = await getSyncState();

  // Prevent concurrent syncs
  if (state.status === 'syncing') {

    return { success: false, error: 'Sync already in progress' };
  }

  // Update state to pending
  await setSyncState({ status: 'pending', lastError: null });

  // Get auth credentials
  const auth = await getAuthCredentials();
  if (!auth) {
    const error = 'Not authenticated - please sign in to the web app first';
    await setSyncState({ status: 'error', lastError: error });
    return { success: false, error };
  }

  // Prepare request
  const newVersion = state.version + 1;
  const request: ProfileSyncRequest = {
    userId: auth.userId,
    platform,
    profileData,
    timestamp: new Date().toISOString(),
    version: newVersion,
    clientId: getClientId()
  };

  // Attempt sync with retries
  let lastError: string = 'Unknown error';

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      await setSyncState({ status: 'syncing', retryCount: attempt });



      const result = await executeSync(request, auth.token);

      if (result.success) {
        await setSyncState({
          status: 'success',
          lastSyncedAt: result.syncedAt || new Date().toISOString(),
          lastError: null,
          retryCount: 0,
          version: result.serverVersion || newVersion
        });

        // Store the canonical profile from server
        if (result.canonicalProfile) {
          await chrome.storage.local.set({
            upworkProfile: result.canonicalProfile,
            lastProfileSync: new Date().toISOString()
          });
        }


        return {
          success: true,
          syncedAt: result.syncedAt,
          version: result.serverVersion
        };
      } else {
        lastError = result.error || 'Sync failed';
        console.error(`[ProfileSync] Attempt ${attempt + 1} failed:`, lastError);
      }

    } catch (error: any) {
      lastError = error.message || 'Network error';
      console.error(`[ProfileSync] Attempt ${attempt + 1} exception:`, lastError);
    }

    // If not the last attempt, wait before retry
    if (attempt < MAX_RETRIES) {
      const delay = calculateDelay(attempt);

      await sleep(delay);
    }
  }

  // All attempts failed
  await setSyncState({
    status: 'error',
    lastError,
    retryCount: MAX_RETRIES
  });

  console.error('[ProfileSync] ❌ All sync attempts failed:', lastError);
  return { success: false, error: lastError };
}

// ============================================
// EXECUTE SINGLE SYNC ATTEMPT
// ============================================

async function executeSync(
  request: ProfileSyncRequest,
  token: string
): Promise<ProfileSyncResponse> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), SYNC_TIMEOUT_MS);

  try {


    const response = await fetch(`${API_BASE_URL}/api/account/sync`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
        'X-Client-ID': request.clientId,
        'X-Sync-Version': String(request.version)
      },
      body: JSON.stringify(request),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    const data = await response.json();




    if (!response.ok) {
      return {
        success: false,
        error: data.error || `HTTP ${response.status}: ${response.statusText}`
      };
    }

    return {
      success: true,
      message: data.message,
      syncedAt: data.syncedAt,
      serverVersion: data.version,
      canonicalProfile: data.profile
    };

  } catch (error: any) {
    clearTimeout(timeoutId);

    if (error.name === 'AbortError') {
      return { success: false, error: 'Request timeout' };
    }

    return { success: false, error: error.message };
  }
}

// ============================================
// CONVENIENCE FUNCTIONS
// ============================================

/**
 * Queue a profile sync - to be called from content scripts
 */
export async function queueProfileSync(profileData: UpworkProfile): Promise<void> {


  // Store locally first (optimistic)
  await chrome.storage.local.set({
    upworkProfile: profileData,
    upworkProfilePending: true
  });

  // Attempt sync
  const result = await syncProfileToBackend(profileData, 'upwork');

  // Clear pending flag
  await chrome.storage.local.set({ upworkProfilePending: false });

  // Broadcast result to popup
  chrome.runtime.sendMessage({
    action: 'PROFILE_SYNC_RESULT',
    data: result
  }).catch(() => {
    // Popup might not be open
  });
}

/**
 * Check if we have a pending sync that needs retry
 */
export async function checkPendingSync(): Promise<void> {
  const result = await chrome.storage.local.get(['upworkProfile', 'upworkProfilePending']);

  if (result.upworkProfilePending && result.upworkProfile) {

    await syncProfileToBackend(result.upworkProfile, 'upwork');
  }
}

/**
 * Force a manual sync (for debugging)
 */
export async function forceSync(): Promise<SyncResult> {
  const result = await chrome.storage.local.get(['upworkProfile']);

  if (!result.upworkProfile) {
    return { success: false, error: 'No profile data to sync' };
  }

  return syncProfileToBackend(result.upworkProfile, 'upwork');
}
