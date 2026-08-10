/**
 * Extension Configuration
 * 
 * Centralized configuration for API endpoints and webapp URLs.
 * Uses Vite environment variables for production deployments.
 */

// Base URL for the web application
export const WEBAPP_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://app.propeloai.com';

// API endpoint for backend calls
export const API_BASE_URL = WEBAPP_BASE_URL;

// URLs for navigation
export const URLS = {
  dashboard: `${WEBAPP_BASE_URL}/dashboard`,
  signin: `${WEBAPP_BASE_URL}/auth/signin`,
  signup: `${WEBAPP_BASE_URL}/auth/signup`,
  profile: `${WEBAPP_BASE_URL}/dashboard/profile`,
  settings: `${WEBAPP_BASE_URL}/dashboard/settings`,
  generator: `${WEBAPP_BASE_URL}/dashboard/generator`,
} as const;

// Allowed origins for external messages (webapp domains)
export const ALLOWED_ORIGINS = [
  'https://app.propeloai.com',
  'https://propeloai.com',
] as const;

// Helper to open a webapp page in a new tab
export function openWebAppPage(path: string): void {
  const url = path.startsWith('/') ? `${WEBAPP_BASE_URL}${path}` : path;
  chrome.tabs.create({ url });
}
