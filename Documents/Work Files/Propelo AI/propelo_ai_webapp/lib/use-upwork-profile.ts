"use client";
import * as React from "react";
import { auth } from "./firebase";
/**
 * Upwork Profile Data Hook
 * 
 * This hook is the SINGLE SOURCE OF TRUTH for Upwork profile data in the web app.
 * It fetches data DIRECTLY from the backend API, NOT from auth context.
 * 
 * Usage:
 *   const { profile, connected, loading, error, refresh } = useUpworkProfile();
 * 
 * States:
 *   - loading: true → Fetching data
 *   - error: string → Fetch failed
 *   - connected: false, profile: null → Not connected
 *   - connected: true, profile: {...} → Connected with data
 */
// ============================================
// TYPE DEFINITIONS
// ============================================
export interface UpworkProfile {
  // Identity
  platform: string;
  displayName: string;
  username?: string;
  title?: string;
  profileUrl?: string;
  location?: string;
  profileImage?: string;
  // Rates
  hourlyRate?: string | number;
  hourlyRateMin?: number;
  hourlyRateMax?: number;
  // Stats
  jobSuccessScore?: number;
  totalEarnings?: string;
  totalJobs?: number;
  totalHours?: number;
  // Badges
  profileCompleteness?: number;
  isVerified?: boolean;
  isTopRated?: boolean;
  isRisingTalent?: boolean;
  // Skills & Categories
  skills?: string[];
  categories?: string[];
  languages?: Array<{ name: string; proficiency?: string }>;
  // Bio
  description?: string;
  overview?: string;
  // Work History
  workHistory?: Array<{
    title?: string;
    client?: string;
    feedback?: string;
    rating?: number;
    startDate?: string;
    endDate?: string;
  }>;
  // Portfolio
  portfolio?: Array<{
    title?: string;
    description?: string;
    imageUrl?: string;
    projectUrl?: string;
  }>;
  // Education & Certifications
  education?: Array<{
    institution?: string;
    degree?: string;
    field?: string;
    year?: string;
  }>;
  certifications?: Array<{
    name?: string;
    issuer?: string;
    date?: string;
  }>;
  // Metadata
  syncedAt?: string;
  scrapedAt?: string;
  syncVersion?: number;
  clientId?: string;
}
export interface UpworkProfileState {
  connected: boolean;
  profile: UpworkProfile | null;
  lastSynced: string | null;
  syncStatus: 'success' | 'partial' | 'failed' | null;
  loading: boolean;
  error: string | null;
}
interface UseUpworkProfileOptions {
  /** Enable polling for real-time updates */
  enablePolling?: boolean;
  /** Polling interval in milliseconds (default: 5000) */
  pollingInterval?: number;
}
// ============================================
// HOOK IMPLEMENTATION
// ============================================
export function useUpworkProfile(options: UseUpworkProfileOptions = {}) {
  const { enablePolling = false, pollingInterval = 5000 } = options;
  const [state, setState] = React.useState<UpworkProfileState>({
    connected: false,
    profile: null,
    lastSynced: null,
    syncStatus: null,
    loading: true,
    error: null,
  });
  const fetchProfile = React.useCallback(async () => {
    setState(prev => ({ ...prev, loading: true, error: null }));
    try {
      // Get current user's ID token
      const user = auth.currentUser;
      if (!user) {
        setState({
          connected: false,
          profile: null,
          lastSynced: null,
          syncStatus: null,
          loading: false,
          error: 'Not authenticated',
        });
        return;
      }
      const token = await user.getIdToken();
      // Fetch from canonical API endpoint
      const response = await fetch('/api/account/upwork', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      });
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      const data = await response.json();
      setState({
        connected: data.connected,
        profile: data.profile,
        lastSynced: data.lastSynced,
        syncStatus: data.syncStatus,
        loading: false,
        error: data.error || null,
      });
    } catch (error: any) {
      console.error('[useUpworkProfile] Fetch error:', error);
      setState(prev => ({
        ...prev,
        loading: false,
        error: error.message || 'Failed to fetch Upwork profile',
      }));
    }
  }, []);
  // Fetch on mount
  React.useEffect(() => {
    fetchProfile();
  }, [fetchProfile]);
  // Listen for auth state changes
  React.useEffect(() => {
    const unsubscribe = auth.onAuthStateChanged((user) => {
      if (user) {
        fetchProfile();
      } else {
        setState({
          connected: false,
          profile: null,
          lastSynced: null,
          syncStatus: null,
          loading: false,
          error: null,
        });
      }
    });
    return () => unsubscribe();
  }, [fetchProfile]);
  // Polling for real-time updates (when enabled)
  React.useEffect(() => {
    if (!enablePolling) return;
    const interval = setInterval(() => {
      // Only poll if window is focused
      if (document.hasFocus()) {
        fetchProfile();
      }
    }, pollingInterval);
    return () => clearInterval(interval);
  }, [enablePolling, pollingInterval, fetchProfile]);
  // Refresh when window regains focus (for catching extension syncs)
  React.useEffect(() => {
    const handleFocus = () => {
      fetchProfile();
    };
    window.addEventListener('focus', handleFocus);
    return () => window.removeEventListener('focus', handleFocus);
  }, [fetchProfile]);
  return {
    ...state,
    refresh: fetchProfile,
  };
}
// ============================================
// EXPORT FOR DIRECT IMPORT
// ============================================
export default useUpworkProfile;
