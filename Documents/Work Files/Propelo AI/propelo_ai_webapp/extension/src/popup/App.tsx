import { useState, useEffect, useCallback } from 'react';
import './styles.css';
import type { UserData, JobData, HistoryItem, TabType, Template, ToneType } from './types';
import type { ScrapeStateData } from '../types';
import { Header } from './components/Header';
import { BottomNav } from './components/BottomNav';
import { JobCard } from './components/JobCard';
import { ProposalView } from './components/ProposalView';
import { HistoryList } from './components/HistoryList';
import { SettingsView } from './components/SettingsView';
import { OnboardingScreen } from './components/OnboardingScreen';
import { ProfileDetectedView } from './components/ProfileDetectedView';
import { ScrapeModal } from './components/ScrapeModal';
import { detectPageContext, PageContext } from './utils/pageContext';
import { LANGUAGES, TONES, SECTIONS } from './types';
import { URLS, API_BASE_URL } from '../config';
import logoImg from '../assets/logo-banner.png';
import logoIcon from '../assets/logo-icon.png';

const DEFAULT_TEMPLATES: Template[] = [
  { id: '1', name: 'Professional', tone: 'professional', style: 'formal' },
  { id: '2', name: 'Friendly', tone: 'friendly', style: 'casual' },
  { id: '3', name: 'Direct', tone: 'direct', style: 'concise' },
  { id: '4', name: 'Enthusiastic', tone: 'enthusiastic', style: 'energetic' },
];

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [user, setUser] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<TabType>('generate');
  
  // Onboarding state - shown only on first launch after auth
  const [showOnboarding, setShowOnboarding] = useState(false);
  const [hasUpworkConnected, setHasUpworkConnected] = useState(false);
  
  const [jobData, setJobData] = useState<JobData | null>(null);
  const [isDetecting, setIsDetecting] = useState(false);
  const [proposal, setProposal] = useState('');
  const [isGenerating, setIsGenerating] = useState(false);
  const [error, setError] = useState<string | null>(null);
  
  const [selectedTone, setSelectedTone] = useState<ToneType>(TONES[0].id);
  const [selectedLanguage, setSelectedLanguage] = useState(LANGUAGES[0].code);
  const [selectedSections, setSelectedSections] = useState(SECTIONS.slice(0, 5).map(s => s.id));
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [customInstructions, setCustomInstructions] = useState('');
  
  const [history, setHistory] = useState<HistoryItem[]>([]);
  
  const [defaultTemplateId, setDefaultTemplateId] = useState('1');
  const [defaultTone, setDefaultTone] = useState<ToneType>(TONES[0].id);
  const [defaultLanguage, setDefaultLanguage] = useState(LANGUAGES[0].code);
  
  // Page context detection state
  const [pageContext, setPageContext] = useState<PageContext | null>(null);
  const [showProfilePrompt, setShowProfilePrompt] = useState(false);
  const [profileScrapedThisSession, setProfileScrapedThisSession] = useState(false);

  // NEW: Scraping state
  const [scrapeState, setScrapeState] = useState<ScrapeStateData>({
    state: 'idle',
    progress: 0,
    steps: [],
  });
  const [showScrapeModal, setShowScrapeModal] = useState(false);

  useEffect(() => {
    checkAuth();
    loadHistory();
    loadSettings();
    detectCurrentPageContext();
    
    // Listen for messages from background
    const handleBackgroundMessage = (message: any) => {
      // Scrape state changes
      if (message.action === 'SCRAPE_STATE_CHANGED') {

        setScrapeState(message.data);
        setShowScrapeModal(true);
        
        // If scraping completed successfully, update connected state
        if (message.data.state === 'complete') {
          setHasUpworkConnected(true);
          setProfileScrapedThisSession(true);
        }
      }
      
      // Auth expired
      if (message.action === 'AUTH_EXPIRED') {

        setError('Your session has expired. Please sign in again.');
        setIsAuthenticated(false);
        setUser(null);
        setShowScrapeModal(false);
      }
    };
    
    chrome.runtime.onMessage.addListener(handleBackgroundMessage);
    
    return () => {
      chrome.runtime.onMessage.removeListener(handleBackgroundMessage);
    };
  }, []);
  
  useEffect(() => {
    // Only auto-detect jobs if authenticated, not in onboarding, and not already detecting
    if (isAuthenticated && !loading && !showOnboarding && !jobData && !isDetecting) {
      detectJob();
    }
  }, [isAuthenticated, loading, showOnboarding]);

  const checkAuth = async () => {
    try {
      const result = await chrome.storage.local.get([
        'authToken', 
        'userData', 
        'onboardingCompleted',  // Has user completed or skipped onboarding?
        'upworkProfile'         // Has Upwork profile been scraped?
      ]);
      
      if (result.authToken && result.userData) {
        setUser(result.userData);
        setIsAuthenticated(true);
        
        // Check if Upwork is connected
        const hasUpwork = !!(result.upworkProfile);
        setHasUpworkConnected(hasUpwork);
        
        // Show onboarding ONLY if:
        // 1. User has never completed onboarding
        // 2. Upwork profile is not already scraped
        if (!result.onboardingCompleted && !hasUpwork) {
          setShowOnboarding(true);
        }
      }
    } catch (err) {
      console.error('Auth check failed:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadHistory = async () => {
    try {
      const result = await chrome.storage.local.get(['proposalHistory']);
      if (result.proposalHistory) setHistory(result.proposalHistory);
    } catch (err) {
      console.error('Failed to load history:', err);
    }
  };

  const loadSettings = async () => {
    try {
      const result = await chrome.storage.local.get(['defaultTone', 'defaultLanguage', 'defaultTemplateId']);
      if (result.defaultTone) {
        setDefaultTone(result.defaultTone);
        setSelectedTone(result.defaultTone);
      }
      if (result.defaultLanguage) {
        setDefaultLanguage(result.defaultLanguage);
        setSelectedLanguage(result.defaultLanguage);
      }
      if (result.defaultTemplateId) setDefaultTemplateId(result.defaultTemplateId);
    } catch (err) {
      console.error('Failed to load settings:', err);
    }
  };

  /**
   * NEW: Start scraping via background script (with temporary tab)
   */
  const startScraping = async (profileUrl?: string): Promise<void> => {

    
    setShowScrapeModal(true);
    setScrapeState({
      state: 'opening',
      progress: 0,
      startedAt: Date.now(),
      steps: [],
    });
    
    try {
      const response = await chrome.runtime.sendMessage({
        action: 'SCRAPE_START',
        data: { profileUrl }
      });
      
      if (!response?.success) {
        throw new Error(response?.error || 'Failed to start scraping');
      }
      

      
    } catch (error: any) {
      console.error('[Popup] Scrape start error:', error);
      setScrapeState(prev => ({
        ...prev,
        state: 'error',
        error: error.message,
        canRetry: true,
      }));
    }
  };

  /**
   * Retry scraping
   */
  const retryScraping = async (): Promise<void> => {

    const storedUrl = await chrome.storage.local.get(['upworkProfileUrl']);
    await startScraping(storedUrl.upworkProfileUrl);
  };

  /**
   * Cancel scraping
   */
  const cancelScraping = async (): Promise<void> => {

    
    // Close the temporary tab
    // (background will handle this on SCRAPE_ERROR)
    
    setShowScrapeModal(false);
    setScrapeState({
      state: 'idle',
      progress: 0,
      steps: [],
    });
  };

  /**
   * Trigger Upwork profile scraping with a specific profile URL (LEGACY)
   */
  const triggerUpworkScrape = async (profileUrl: string): Promise<void> => {

    
    // Store the URL for future use
    await chrome.storage.local.set({ upworkProfileUrl: profileUrl });
    
    // Use the new scraping flow
    await startScraping(profileUrl);
  };

  /**
   * Handle onboarding consent - user wants to collect Upwork data
   */
  const handleOnboardingConsent = async (profileUrl: string) => {
    try {
      await triggerUpworkScrape(profileUrl);
      
      // Mark onboarding as completed
      await chrome.storage.local.set({ onboardingCompleted: true });
      setShowOnboarding(false);
    } catch (err) {
      console.error('[Onboarding] Consent flow failed:', err);
      throw err; // Let OnboardingScreen handle the error display
    }
  };

  /**
   * Handle onboarding skip - user wants to skip for now
   */
  const handleOnboardingSkip = async () => {

    
    // Mark onboarding as completed (skipped)
    await chrome.storage.local.set({ onboardingCompleted: true });
    setShowOnboarding(false);
  };

  /**
   * Detect the current page context (profile, job, or unknown)
   */
  const detectCurrentPageContext = async () => {
    try {
      const context = await detectPageContext();
      setPageContext(context);
      

      
      // If on a profile page and user is authenticated, show profile prompt
      // But only if they haven't already scraped in this session
      if (context.type === 'freelancer-profile' && !profileScrapedThisSession) {
        // Check if this profile is already scraped
        const result = await chrome.storage.local.get(['upworkProfile', 'upworkProfileUrl']);
        const storedUrl = result.upworkProfileUrl;
        
        // If we have a stored URL and it matches current page, don't show prompt
        if (storedUrl && context.url?.includes(storedUrl.split('/freelancers/')[1]?.split('?')[0])) {

          setShowProfilePrompt(false);
        } else {
          // New profile page - show prompt to scrape
          setShowProfilePrompt(true);
        }
      } else {
        setShowProfilePrompt(false);
      }
    } catch (err) {
      console.error('[PageContext] Detection failed:', err);
      setPageContext({ type: 'other', url: '', platform: 'other', isOwnProfile: false, confidence: 'low' });
    }
  };

  /**
   * Handle profile scraping from ProfileDetectedView
   */
  const handleProfileScrape = async (): Promise<void> => {
    if (!pageContext?.url) {
      throw new Error('No profile URL detected');
    }
    
    try {
      // Get the current active tab and run the scraper
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      
      if (!tab.id) {
        throw new Error('No active tab found');
      }
      
      // Send message to content script to scrape
      const response = await chrome.tabs.sendMessage(tab.id, { type: 'SCRAPE_PROFILE' });
      
      if (response?.success) {

        setHasUpworkConnected(true);
        setProfileScrapedThisSession(true);
        setShowProfilePrompt(false);
        
        // Save the profile URL
        await chrome.storage.local.set({ upworkProfileUrl: pageContext.url });
        
        // Explicitly trigger sync to backend (content script should do this too, but be sure)
        if (response.profile) {

          try {
            await chrome.runtime.sendMessage({
              action: 'SYNC_ACCOUNT_DATA',
              data: {
                platform: 'upwork',
                profileData: response.profile
              }
            });

          } catch (syncErr) {
            console.error('[ProfileScrape] ⚠️ Sync failed:', syncErr);
          }
        }
        
        return;
      } else {
        throw new Error(response?.error || 'Failed to scrape profile');
      }
    } catch (err: any) {
      // If content script isn't responding, try reloading the page
      console.error('[ProfileScrape] Error:', err);
      throw new Error('Could not scrape profile. Try refreshing the page and opening the extension again.');
    }
  };

  /**
   * Handle dismissing the profile prompt
   */
  const handleProfilePromptDismiss = () => {
    setShowProfilePrompt(false);
    setProfileScrapedThisSession(true); // Don't show again this session
  };

  /**
   * Re-scrape Upwork profile (called from Settings)
   */
  const rescrapeUpworkProfile = async (profileUrl: string): Promise<void> => {

    await triggerUpworkScrape(profileUrl);
  };

  const saveToHistory = async (item: HistoryItem) => {
    const newHistory = [item, ...history].slice(0, 50);
    setHistory(newHistory);
    await chrome.storage.local.set({ proposalHistory: newHistory });
  };

  const deleteFromHistory = async (id: string) => {
    const newHistory = history.filter(item => item.id !== id);
    setHistory(newHistory);
    await chrome.storage.local.set({ proposalHistory: newHistory });
  };

  const openWebApp = () => {
    chrome.tabs.create({ url: URLS.signin });
  };

  const handleSignOut = async () => {
    await chrome.storage.local.remove(['authToken', 'userData']);
    setIsAuthenticated(false);
    setUser(null);
  };

  const toggleSection = (section: string) => {
    setSelectedSections(prev => 
      prev.includes(section) ? prev.filter(s => s !== section) : [...prev, section]
    );
  };

  const detectJob = useCallback(async () => {
    setIsDetecting(true);
    setError(null);
    setJobData(null);
    
    try {
      const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
      if (!tab.id) throw new Error('No active tab');
      
      if (!tab.url?.includes('upwork.com') && !tab.url?.includes('freelancer.com') && !tab.url?.includes('fiverr.com')) {
        setError('Navigate to a job page on Upwork, Freelancer, or Fiverr to detect details.');
        setIsDetecting(false);
        return;
      }
      
      const mapToJobData = (data: any): JobData | null => {
        if (!data) return null;
        const title = data.jobTitle || data.title || '';
        const description = data.description || '';
        if (!title && !description) return null;
        return {
          title, description,
          budget: data.budget,
          skills: data.skills || [],
          clientInfo: data.clientInfo || {},
          url: data.url || tab.url,
          platform: data.platform || (tab.url?.includes('upwork') ? 'upwork' : 'other'),
          duration: data.duration,
          experienceLevel: data.experienceLevel,
        };
      };
      
      try {
        const response = await chrome.tabs.sendMessage(tab.id, { action: 'GET_JOB_DATA' });
        const mappedData = mapToJobData(response);
        if (mappedData) {
          setJobData(mappedData);
          setIsDetecting(false);
          return;
        }
      } catch (msgErr) {

      }
      
      const result = await chrome.storage.local.get(['currentJob']);
      if (result.currentJob) {
        const mappedData = mapToJobData(result.currentJob);
        if (mappedData) {
          setJobData(mappedData);
          setIsDetecting(false);
          return;
        }
      }
      
      const results = await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: () => {
          const title = document.querySelector('h1, [data-test="job-title"]')?.textContent?.trim() || '';
          const description = document.querySelector('[data-test="job-description"], .job-description, .description')?.textContent?.trim() || '';
          const budget = document.querySelector('[data-test="budget"], .budget')?.textContent?.trim();
          const skillElements = document.querySelectorAll('[data-test="skill"], .skill-badge, .air3-token');
          const skills = Array.from(skillElements).map(el => el.textContent?.trim()).filter(Boolean) as string[];
          return { title, description, budget, skills, clientInfo: {}, url: window.location.href };
        },
      });
      
      if (results[0]?.result) {
        const data = results[0].result;
        if (!data.title && !data.description) {
          setError('Could not detect job details. Make sure you are on a job posting page.');
        } else {
          setJobData(data);
        }
      }
    } catch (err) {
      setError('Failed to detect job. Please refresh the page.');
      console.error('[Popup] Detection error:', err);
    } finally {
      setIsDetecting(false);
    }
  }, []);

  // Streaming progress state
  const [streamingText, setStreamingText] = useState('');
  const [generationProgress, setGenerationProgress] = useState(0);
  const [retryCount, setRetryCount] = useState(0);

  // Retry helper with exponential backoff
  const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

  const generateProposal = async (attempt = 0) => {
    const MAX_RETRIES = 2;
    if (!jobData) return;
    setIsGenerating(true);
    setError(null);
    setStreamingText('');
    setProposal('');
    setGenerationProgress(0);
    
    try {
      const { authToken } = await chrome.storage.local.get(['authToken']);
      if (!authToken) {
        setError('Please sign in to generate proposals.');
        setIsGenerating(false);
        return;
      }
      
      const platform = jobData.url?.includes('fiverr') ? 'fiverr' 
        : jobData.url?.includes('freelancer') ? 'freelancer' : 'upwork';
      
      const title = (!jobData.title || jobData.title.length < 3) 
        ? (jobData.title ? jobData.title + ' (Job)' : 'Job Opportunity') 
        : jobData.title;

      let description = jobData.description || '';
      if (description.length < 50) {
        description = title + ' - ' + description + '. Please write a professional proposal for this job opportunity.';
      }

      const payload = {
        jobTitle: title,
        jobDescription: description,
        platform,
        tone: selectedTone,
        language: selectedLanguage,
        selectedSections: selectedSections.length > 0 ? selectedSections : ['introduction', 'approach', 'cta'],
        budget: jobData.budget || undefined,
        customInstructions: customInstructions.trim() || undefined,
      };

      // Try streaming endpoint first
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 120000); // 2 min for streaming
      
      const response = await fetch(`${API_BASE_URL}/api/proposals/generate-stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + authToken },
        body: JSON.stringify(payload),
        signal: controller.signal,
      });
      
      if (!response.ok) {
        clearTimeout(timeoutId);
        const data = await response.json().catch(() => ({}));
        const statusText = response.status === 401 ? 'Session expired - please sign in again'
          : response.status === 403 ? 'Limit reached - upgrade your plan'
          : response.status === 400 ? `Invalid request: ${data.error || 'check inputs'}`
          : response.status >= 500 ? `Server error (${response.status}): ${data.error || 'OpenAI may be down'}`
          : `Error ${response.status}: ${data.error || 'Unknown'}`;
        throw new Error(statusText);
      }

      // Handle streaming response
      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let fullContent = '';
      let estimatedTotal = 1500; // Estimated proposal length in chars
      
      if (reader) {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          
          const chunk = decoder.decode(value, { stream: true });
          const lines = chunk.split('\n');
          
          for (const line of lines) {
            if (line.startsWith('data: ')) {
              try {
                const data = JSON.parse(line.slice(6));
                if (data.error) {
                  throw new Error(data.error);
                }
                if (data.content) {
                  fullContent += data.content;
                  setStreamingText(fullContent);
                  // Update progress based on content length
                  setGenerationProgress(Math.min(95, (fullContent.length / estimatedTotal) * 100));
                }
                if (data.done && data.fullContent) {
                  fullContent = data.fullContent;
                }
              } catch (parseErr) {
                // Ignore parse errors for incomplete chunks
              }
            }
          }
        }
      }
      
      clearTimeout(timeoutId);
      setGenerationProgress(100);
      setProposal(fullContent);
      setStreamingText('');
      setRetryCount(0);
      
      await saveToHistory({
        id: Date.now().toString(),
        jobTitle: jobData.title,
        proposal: fullContent,
        timestamp: Date.now(),
        platform,
        tone: selectedTone,
        language: selectedLanguage,
      });
    } catch (err: any) {
      // Auto-retry on timeout or server errors
      const isRetryable = err.name === 'AbortError' || 
        (err.message && (err.message.includes('500') || err.message.includes('timeout')));
      
      if (isRetryable && attempt < MAX_RETRIES) {
        setRetryCount(attempt + 1);
        setError(`Connection issue, retrying... (${attempt + 1}/${MAX_RETRIES})`);
        await sleep(1000 * (attempt + 1)); // Exponential backoff
        return generateProposal(attempt + 1);
      }
      
      if (err.name === 'AbortError') {
        setError('Request timed out. Try again or check your connection.');
      } else {
        const errorMsg = err instanceof Error ? err.message : String(err);
        setError(`Error: ${errorMsg}`);
      }
    } finally {
      setIsGenerating(false);
      setStreamingText('');
      setGenerationProgress(0);
      setRetryCount(0);
    }
  };

  // AI Improve function
  const handleImproveProposal = async (currentProposal: string, instructions: string): Promise<string> => {
    const { authToken } = await chrome.storage.local.get(['authToken']);
    if (!authToken) {
      throw new Error('Not authenticated');
    }

    const response = await fetch(`${API_BASE_URL}/api/proposals/enhance`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Authorization': 'Bearer ' + authToken },
      body: JSON.stringify({ proposal: currentProposal, instructions }),
    });

    if (!response.ok) {
      const data = await response.json().catch(() => ({}));
      throw new Error(data.error || 'Failed to improve proposal');
    }

    const data = await response.json();
    return data.enhancedText || data.data?.enhancedText || currentProposal;
  };

  // Loading state - premium white aesthetic
  if (loading) {
    return (
      <div className="w-[380px] h-[520px] bg-gradient-to-br from-white via-slate-50 to-cyan-50/30 flex items-center justify-center relative overflow-hidden">
        <div className="absolute top-0 left-0 w-64 h-64 bg-cyan-500/5 rounded-full blur-[80px] -translate-x-1/2 -translate-y-1/2" />
        <div className="absolute bottom-0 right-0 w-48 h-48 bg-teal-500/5 rounded-full blur-[60px] translate-x-1/2 translate-y-1/2" />
        
        <div className="relative text-center z-10">
          <div className="w-14 h-14 mx-auto mb-4 rounded-2xl bg-gradient-to-br from-cyan-500 to-teal-500 flex items-center justify-center shadow-lg shadow-cyan-500/30 animate-pulse">
            <svg className="w-7 h-7 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
            </svg>
          </div>
          <img src={logoImg} alt="Propelo AI" className="h-8 w-auto mx-auto mb-3" />
          <div className="flex items-center justify-center gap-1">
            {[0, 1, 2].map((i) => (
              <div key={i} className="w-2 h-2 rounded-full bg-cyan-500 animate-bounce" style={{ animationDelay: i * 150 + 'ms' }} />
            ))}
          </div>
        </div>
      </div>
    );
  }

  // Sign in screen - premium white aesthetic
  if (!isAuthenticated) {
    return (
      <div className="w-[380px] h-[520px] overflow-hidden relative bg-gradient-to-br from-white via-slate-50 to-cyan-50/30">
        <div className="absolute top-0 left-0 w-64 h-64 bg-cyan-500/5 rounded-full blur-[80px] -translate-x-1/2 -translate-y-1/2" />
        <div className="absolute bottom-0 right-0 w-48 h-48 bg-teal-500/5 rounded-full blur-[60px] translate-x-1/2 translate-y-1/2" />
        
        <div className="relative h-full flex flex-col items-center justify-center px-8 z-10">
          <div className="mb-8">
            <img src={logoImg} alt="Propelo AI" className="h-10 w-auto" />
          </div>
          
          <div className="text-center mb-8">
            <h1 className="text-xl font-bold text-slate-800 mb-2">Generate Winning Proposals</h1>
            <p className="text-slate-500 text-sm">AI-powered proposals that get you hired</p>
          </div>
          
          <div className="w-full space-y-3 mb-8">
            {[
              { icon: "⚡", text: 'Generate in seconds' },
              { icon: "🎯", text: 'Smart job detection' },
              { icon: "🌍", text: 'Multi-language support' },
              { icon: "📈", text: '3x higher response rate' },
            ].map((feature, i) => (
              <div key={i} className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-white shadow-sm border border-slate-100">
                <span className="text-lg">{feature.icon}</span>
                <span className="text-sm text-slate-600">{feature.text}</span>
              </div>
            ))}
          </div>
          
          <button
            onClick={openWebApp}
            className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 hover:from-cyan-400 hover:to-teal-400 text-white font-semibold shadow-lg shadow-cyan-500/25 transition-all duration-200 flex items-center justify-center gap-2"
          >
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 16l-4-4m0 0l4-4m-4 4h14m-5 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h7a3 3 0 013 3v1" />
            </svg>
            Sign in to Get Started
          </button>
          
          <p className="text-xs text-slate-500 mt-4">
            New here? <button onClick={openWebApp} className="text-cyan-600 hover:text-cyan-500 font-medium">Create free account</button>
          </p>
        </div>
      </div>
    );
  }

  // First-launch onboarding screen - ask for Upwork data consent
  if (showOnboarding) {
    return (
      <OnboardingScreen 
        onConsent={handleOnboardingConsent}
        onSkip={handleOnboardingSkip}
      />
    );
  }

  // Main authenticated UI - light theme
  return (
    <div className="w-[380px] h-[520px] bg-[#F7F9FB] flex flex-col overflow-hidden font-sans">
      <Header user={user} onSignOut={handleSignOut} />
      
      <div className="flex-1 overflow-y-auto scrollbar-hide">
        {/* Profile page detection - show before other content */}
        {showProfilePrompt && pageContext?.type === 'freelancer-profile' && (
          <ProfileDetectedView
            profileUrl={pageContext.url || ''}
            isAlreadyConnected={hasUpworkConnected}
            onScrape={handleProfileScrape}
            onDismiss={handleProfilePromptDismiss}
            onBack={() => setShowProfilePrompt(false)}
          />
        )}
        
        {activeTab === 'generate' && (
          <div className="p-4 space-y-4">
            {error && (
              <div className="p-3 rounded-xl bg-red-50 border border-red-100 flex items-start gap-3">
                <div className="w-8 h-8 rounded-lg bg-red-100 flex items-center justify-center shrink-0">
                  <svg className="w-4 h-4 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>
                <div className="flex-1">
                  <p className="text-sm text-red-600">{error}</p>
                </div>
              </div>
            )}
            
            {!jobData && !proposal && (
              <div className="text-center py-10">
                <div className="w-20 h-20 mx-auto mb-5 rounded-2xl bg-white shadow-lg flex items-center justify-center">
                  {isDetecting ? (
                    <div className="w-8 h-8 border-3 border-slate-200 border-t-cyan-500 rounded-full animate-spin" />
                  ) : (
                    <img src={logoIcon} alt="Propelo" className="w-12 h-12 object-contain rounded-xl" />
                  )}
                </div>
                
                <h3 className="font-bold text-slate-800 mb-2">{isDetecting ? 'Scanning Page...' : 'Detect Job Details'}</h3>
                <p className="text-sm text-slate-500 mb-5 max-w-[240px] mx-auto">
                  {isDetecting ? 'Looking for job information' : 'Navigate to a job page on Upwork, Freelancer, or Fiverr'}
                </p>
                
                {!isDetecting && (
                  <div className="flex justify-center gap-2 mb-5">
                    {['Upwork', 'Freelancer', 'Fiverr'].map((platform) => (
                      <span key={platform} className="px-3 py-1 rounded-full bg-white text-xs text-slate-500 border border-slate-200">{platform}</span>
                    ))}
                  </div>
                )}
                
                <button onClick={detectJob} disabled={isDetecting} className="px-6 py-2.5 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 text-white font-medium shadow-lg shadow-cyan-500/20 hover:shadow-xl transition-all disabled:opacity-50 inline-flex items-center gap-2">
                  {isDetecting ? (
                    <>
                      <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                      Detecting...
                    </>
                  ) : (
                    <>
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                      </svg>
                      Detect Job
                    </>
                  )}
                </button>
              </div>
            )}
            
            {jobData && !proposal && (
              <div className="space-y-4">
                <JobCard job={jobData} onRefresh={detectJob} />
                
                <div className="bg-white rounded-2xl p-4 shadow-sm border border-slate-100 space-y-4">
                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-xs font-medium text-slate-500 uppercase tracking-wide mb-1.5">Tone</label>
                      <select value={selectedTone} onChange={(e) => setSelectedTone(e.target.value as ToneType)} className="w-full h-10 px-3 rounded-lg border border-slate-200 bg-slate-50 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 transition-all">
                        {TONES.map(tone => (<option key={tone.id} value={tone.id}>{tone.icon} {tone.name}</option>))}
                      </select>
                    </div>
                    <div>
                      <label className="block text-xs font-medium text-slate-500 uppercase tracking-wide mb-1.5">Language</label>
                      <select value={selectedLanguage} onChange={(e) => setSelectedLanguage(e.target.value)} className="w-full h-10 px-3 rounded-lg border border-slate-200 bg-slate-50 text-sm focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 transition-all">
                        {LANGUAGES.map(lang => (<option key={lang.code} value={lang.code}>{lang.flag} {lang.name}</option>))}
                      </select>
                    </div>
                  </div>
                  
                  <button onClick={() => setShowAdvanced(!showAdvanced)} className="w-full flex items-center justify-between py-2 text-sm text-slate-500 hover:text-slate-700 transition-colors">
                    <span className="flex items-center gap-2">
                      <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" />
                      </svg>
                      Advanced Options
                    </span>
                    <svg className={'w-4 h-4 transition-transform ' + (showAdvanced ? 'rotate-180' : '')} fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </button>
                  
                  {showAdvanced && (
                    <div className="space-y-4">
                      <div>
                        <label className="block text-xs font-medium text-slate-500 uppercase tracking-wide mb-2">Include Sections</label>
                        <div className="grid grid-cols-2 gap-2">
                          {SECTIONS.map(section => (
                            <button key={section.id} onClick={() => toggleSection(section.id)} className={'flex items-center gap-2 px-3 py-2 rounded-lg border text-left text-xs transition-all ' + (selectedSections.includes(section.id) ? 'bg-cyan-50 border-cyan-200 text-cyan-700' : 'bg-slate-50 border-slate-200 text-slate-600 hover:bg-slate-100')}>
                              <div className={'w-4 h-4 rounded border flex items-center justify-center ' + (selectedSections.includes(section.id) ? 'bg-cyan-500 border-cyan-500' : 'border-slate-300')}>
                                {selectedSections.includes(section.id) && (
                                  <svg className="w-3 h-3 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                                  </svg>
                                )}
                              </div>
                              {section.name}
                            </button>
                          ))}
                        </div>
                      </div>
                      
                      <div>
                        <label className="block text-xs font-medium text-slate-500 uppercase tracking-wide mb-2">Custom Instructions</label>
                        <textarea
                          value={customInstructions}
                          onChange={(e) => setCustomInstructions(e.target.value)}
                          placeholder="Add specific instructions for your proposal... (e.g., 'mention my 5 years of React experience', 'include a project timeline')"
                          className="w-full px-3 py-2.5 rounded-lg border border-slate-200 bg-slate-50 text-sm placeholder:text-slate-400 focus:border-cyan-500 focus:ring-1 focus:ring-cyan-500 transition-all resize-none"
                          rows={3}
                        />
                        <p className="text-xs text-slate-400 mt-1.5">These instructions will be used to personalize your proposal</p>
                      </div>
                    </div>
                  )}
                </div>
                
                <button onClick={() => generateProposal()} disabled={isGenerating} className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 text-white font-semibold shadow-lg shadow-cyan-500/20 hover:shadow-xl transition-all disabled:opacity-50 flex items-center justify-center gap-2">
                  {isGenerating ? (
                    <>
                      <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                      {retryCount > 0 ? `Retrying (${retryCount}/2)...` : streamingText ? 'Writing...' : 'Connecting to AI...'}
                    </>
                  ) : (
                    <>
                      <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                      </svg>
                      Generate Proposal
                    </>
                  )}
                </button>
                
                {/* Live streaming preview */}
                {isGenerating && streamingText && (
                  <div className="mt-4 p-4 bg-gradient-to-br from-white to-slate-50 rounded-xl border border-slate-200 shadow-inner">
                    <div className="flex items-center gap-2 mb-3">
                      <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                      <span className="text-xs font-medium text-slate-500">AI is writing your proposal...</span>
                      <span className="ml-auto text-xs text-slate-400">{streamingText.length} chars</span>
                    </div>
                    <div className="w-full h-1 bg-slate-200 rounded-full overflow-hidden mb-3">
                      <div 
                        className="h-full bg-gradient-to-r from-cyan-500 to-teal-500 transition-all duration-300"
                        style={{ width: `${generationProgress}%` }}
                      />
                    </div>
                    <div className="max-h-48 overflow-y-auto text-sm text-slate-700 leading-relaxed whitespace-pre-wrap">
                      {streamingText}
                      <span className="inline-block w-0.5 h-4 bg-cyan-500 animate-pulse ml-0.5 align-middle" />
                    </div>
                  </div>
                )}
              </div>
            )}
            
            {proposal && (
              <ProposalView 
                proposal={proposal} 
                onBack={() => { setProposal(''); setJobData(null); }} 
                onNewProposal={() => setProposal('')}
                onImprove={handleImproveProposal}
                onUpdate={(updated) => setProposal(updated)}
              />
            )}
          </div>
        )}
        
        {activeTab === 'history' && (
          <div className="p-4"><HistoryList history={history} onDelete={deleteFromHistory} /></div>
        )}
        
        {activeTab === 'settings' && (
          <div className="p-4">
            <SettingsView 
              templates={DEFAULT_TEMPLATES}
              defaultTemplateId={defaultTemplateId}
              onSetDefaultTemplate={async (id) => { setDefaultTemplateId(id); await chrome.storage.local.set({ defaultTemplateId: id }); }}
              defaultTone={defaultTone}
              defaultLanguage={defaultLanguage}
              onSetDefaultTone={async (tone) => { setDefaultTone(tone); await chrome.storage.local.set({ defaultTone: tone }); }}
              onSetDefaultLanguage={async (lang) => { setDefaultLanguage(lang); await chrome.storage.local.set({ defaultLanguage: lang }); }}
              hasUpworkConnected={hasUpworkConnected}
              onRescrapeUpwork={rescrapeUpworkProfile}
            />
          </div>
        )}
      </div>
      
      {/* Scraping Modal */}
      <ScrapeModal
        isOpen={showScrapeModal}
        state={scrapeState}
        onCancel={cancelScraping}
        onRetry={retryScraping}
      />
      
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
}

export default App;
