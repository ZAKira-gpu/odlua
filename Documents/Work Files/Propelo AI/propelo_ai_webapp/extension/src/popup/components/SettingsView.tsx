import { useState, useEffect } from 'react';
import { Template, LANGUAGES, TONES, ToneType } from '../types';
import { openWebAppPage } from '../../config';
import logoAltImg from '../../assets/logo-alt.png';

interface SettingsViewProps {
  templates: Template[];
  defaultTemplateId: string;
  onSetDefaultTemplate: (id: string) => void;
  defaultTone?: ToneType;
  defaultLanguage?: string;
  onSetDefaultTone?: (tone: ToneType) => void;
  onSetDefaultLanguage?: (language: string) => void;
  /** Whether Upwork profile is connected */
  hasUpworkConnected?: boolean;
  /** Callback to trigger Upwork profile re-scrape with URL */
  onRescrapeUpwork?: (profileUrl: string) => Promise<void>;
}

// Template icons
const templateIcons: Record<string, string> = {
  '1': '💼',
  '2': '👋',
  '3': '🎯',
  '4': '⚡',
};

export const SettingsView = ({ 
  templates, 
  defaultTemplateId, 
  onSetDefaultTemplate,
  defaultTone = 'professional',
  defaultLanguage = 'en',
  onSetDefaultTone,
  onSetDefaultLanguage,
  hasUpworkConnected = false,
  onRescrapeUpwork
}: SettingsViewProps) => {
  const [isRescraping, setIsRescraping] = useState(false);
  const [rescrapeError, setRescrapeError] = useState<string | null>(null);
  const [rescrapeSuccess, setRescrapeSuccess] = useState(false);
  const [profileUrl, setProfileUrl] = useState('');
  const [showUrlInput, setShowUrlInput] = useState(!hasUpworkConnected);

  // Load saved profile URL
  useEffect(() => {
    chrome.storage.local.get(['upworkProfileUrl']).then((result) => {
      if (result.upworkProfileUrl) {
        setProfileUrl(result.upworkProfileUrl);
      }
    });
  }, []);

  const isValidProfileUrl = (url: string): boolean => {
    return url.includes('upwork.com/freelancers/~') && url.match(/\/freelancers\/~[a-zA-Z0-9]+/) !== null;
  };

  const handleRescrape = async () => {
    if (!onRescrapeUpwork) return;
    
    if (!profileUrl.trim()) {
      setRescrapeError('Please enter your Upwork profile URL');
      return;
    }
    
    if (!isValidProfileUrl(profileUrl)) {
      setRescrapeError('Invalid URL format. Example: https://www.upwork.com/freelancers/~01a3358405f230ab04');
      return;
    }
    
    setIsRescraping(true);
    setRescrapeError(null);
    setRescrapeSuccess(false);
    
    try {
      await onRescrapeUpwork(profileUrl.trim());
      setRescrapeSuccess(true);
      setShowUrlInput(false);
      setTimeout(() => setRescrapeSuccess(false), 3000);
    } catch (err) {
      setRescrapeError(err instanceof Error ? err.message : 'Failed to scrape profile');
    } finally {
      setIsRescraping(false);
    }
  };

  const openWebApp = (path: string) => {
    openWebAppPage(path);
  };

  return (
    <div className="space-y-5 animate-fade-in">
      {/* Default Template Section */}
      <div className="bg-white rounded-2xl p-4 shadow-lg border border-gray-100">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-cyan-500 to-teal-500 flex items-center justify-center shadow-lg shadow-cyan-500/25">
            <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
            </svg>
          </div>
          <div>
            <h3 className="font-semibold text-gray-900">Default Template</h3>
            <p className="text-xs text-gray-500">Choose your preferred proposal style</p>
          </div>
        </div>
        
        <div className="grid grid-cols-2 gap-2">
          {templates.map((template, i) => (
            <button
              key={template.id}
              onClick={() => onSetDefaultTemplate(template.id)}
              className={`p-3 rounded-xl text-left transition-all relative overflow-hidden group ${
                defaultTemplateId === template.id
                  ? 'bg-cyan-50 border-2 border-cyan-500'
                  : 'bg-gray-50 border border-gray-200 hover:bg-gray-100 hover:border-gray-300'
              }`}
            >
              <div className="relative z-10 flex items-center gap-2">
                <span className="text-lg group-hover:scale-110 transition-transform">{templateIcons[template.id]}</span>
                <div>
                  <div className={`font-medium text-sm ${defaultTemplateId === template.id ? 'text-cyan-700' : 'text-gray-900'}`}>
                    {template.name}
                  </div>
                  <div className="text-[10px] text-gray-500 capitalize">{template.tone}</div>
                </div>
              </div>
              {defaultTemplateId === template.id && (
                <div className="absolute top-2 right-2">
                  <svg className="w-4 h-4 text-cyan-500" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                  </svg>
                </div>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* Upwork Profile Section */}
      <div className="bg-white rounded-2xl p-4 shadow-lg border border-gray-100">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-green-500 to-emerald-500 flex items-center justify-center shadow-lg shadow-green-500/25">
            <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </div>
          <div className="flex-1">
            <h3 className="font-semibold text-gray-900">Upwork Profile</h3>
            <p className="text-xs text-gray-500">
              {hasUpworkConnected ? 'Profile data synced' : 'Not connected yet'}
            </p>
          </div>
          {hasUpworkConnected && (
            <div className="flex items-center gap-1 px-2 py-1 rounded-full bg-green-50 text-green-600 text-[10px] font-medium">
              <svg className="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              Connected
            </div>
          )}
        </div>
        
        {/* Status message */}
        {rescrapeError && (
          <div className="mb-3 p-2.5 rounded-lg bg-red-50 border border-red-100">
            <p className="text-xs text-red-600">{rescrapeError}</p>
          </div>
        )}
        {rescrapeSuccess && (
          <div className="mb-3 p-2.5 rounded-lg bg-green-50 border border-green-100">
            <p className="text-xs text-green-600">Profile scraped successfully!</p>
          </div>
        )}
        
        {/* URL Input */}
        {(showUrlInput || !hasUpworkConnected) && (
          <div className="mb-3">
            <label className="block text-xs font-medium text-gray-600 mb-1.5">
              Upwork Profile URL
            </label>
            <input
              type="url"
              value={profileUrl}
              onChange={(e) => setProfileUrl(e.target.value)}
              placeholder="https://www.upwork.com/freelancers/~01a33..."
              className="w-full px-3 py-2 rounded-lg border border-gray-200 bg-gray-50 text-sm placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-green-500/20 focus:border-green-500 transition-all"
            />
            <p className="text-[10px] text-gray-400 mt-1">
              Go to Upwork → Click your profile picture → Copy URL
            </p>
          </div>
        )}
        
        {/* Connected state with edit option */}
        {hasUpworkConnected && !showUrlInput && (
          <div className="mb-3 p-2.5 rounded-lg bg-gray-50 border border-gray-200 flex items-center justify-between">
            <div className="flex-1 min-w-0">
              <p className="text-xs text-gray-600 truncate">{profileUrl || 'Profile connected'}</p>
            </div>
            <button
              onClick={() => setShowUrlInput(true)}
              className="ml-2 text-xs text-cyan-600 hover:text-cyan-700 font-medium"
            >
              Edit
            </button>
          </div>
        )}
        
        <button
          onClick={handleRescrape}
          disabled={isRescraping}
          className="w-full p-3 rounded-xl bg-gray-50 border border-gray-200 hover:bg-green-50 hover:border-green-200 hover:shadow-md transition-all flex items-center gap-3 group disabled:opacity-60 disabled:cursor-not-allowed"
        >
          <div className="w-9 h-9 rounded-lg bg-green-50 group-hover:bg-green-100 flex items-center justify-center transition-colors">
            {isRescraping ? (
              <div className="w-4 h-4 border-2 border-green-300 border-t-green-600 rounded-full animate-spin" />
            ) : (
              <svg className="w-4 h-4 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
            )}
          </div>
          <div className="flex-1 text-left">
            <div className="text-sm font-medium text-gray-900 group-hover:text-green-700 transition-colors">
              {hasUpworkConnected ? 'Re-scrape Upwork Profile' : 'Connect Upwork Profile'}
            </div>
            <div className="text-[10px] text-gray-500">
              {isRescraping ? 'Opening Upwork...' : 'Update your profile data'}
            </div>
          </div>
          <svg className="w-4 h-4 text-gray-400 group-hover:text-green-600 group-hover:translate-x-1 transition-all" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </button>
        
        <p className="text-[10px] text-gray-400 mt-2 text-center">
          We only read publicly available profile data
        </p>
      </div>

      {/* Default Language & Tone Section */}
      <div className="bg-white rounded-2xl p-4 shadow-lg border border-gray-100">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-teal-500 to-emerald-500 flex items-center justify-center shadow-lg shadow-teal-500/25">
            <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
            </svg>
          </div>
          <div>
            <h3 className="font-semibold text-gray-900">Proposal Defaults</h3>
            <p className="text-xs text-gray-500">Set your preferred language and tone</p>
          </div>
        </div>
        
        <div className="space-y-3">
          {/* Language selector */}
          <div>
            <label className="text-xs font-medium text-gray-600 mb-1.5 block">Default Language</label>
            <select
              value={defaultLanguage}
              onChange={(e) => onSetDefaultLanguage?.(e.target.value)}
              className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-cyan-500/20 focus:border-cyan-500 transition-all"
            >
              {LANGUAGES.map((lang) => (
                <option key={lang.code} value={lang.code}>
                  {lang.flag} {lang.name}
                </option>
              ))}
            </select>
          </div>

          {/* Tone selector */}
          <div>
            <label className="text-xs font-medium text-gray-600 mb-1.5 block">Default Tone</label>
            <select
              value={defaultTone}
              onChange={(e) => onSetDefaultTone?.(e.target.value as ToneType)}
              className="w-full px-3 py-2.5 rounded-xl bg-gray-50 border border-gray-200 text-sm text-gray-900 focus:outline-none focus:ring-2 focus:ring-cyan-500/20 focus:border-cyan-500 transition-all"
            >
              {TONES.map((tone) => (
                <option key={tone.id} value={tone.id}>
                  {tone.icon} {tone.name}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Quick Links Section */}
      <div className="bg-white rounded-2xl p-4 shadow-lg border border-gray-100">
        <div className="flex items-center gap-3 mb-4">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500 to-purple-500 flex items-center justify-center shadow-lg shadow-violet-500/25">
            <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
            </svg>
          </div>
          <div>
            <h3 className="font-semibold text-gray-900">Quick Links</h3>
            <p className="text-xs text-gray-500">Access your account settings</p>
          </div>
        </div>
        
        <div className="space-y-2">
          {[
            { 
              path: '/dashboard/profile', 
              icon: (
                <svg className="w-4 h-4 text-cyan-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              ),
              title: 'Edit Profile',
              desc: 'Update your information',
              iconBg: 'bg-cyan-50'
            },
            { 
              path: '/dashboard', 
              icon: (
                <svg className="w-4 h-4 text-teal-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
                </svg>
              ),
              title: 'Dashboard',
              desc: 'View analytics & more',
              iconBg: 'bg-teal-50'
            },
            { 
              path: '/dashboard/enhancer', 
              icon: (
                <svg className="w-4 h-4 text-violet-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
                </svg>
              ),
              title: 'AI Enhancer',
              desc: 'Improve your proposals',
              iconBg: 'bg-violet-50'
            }
          ].map((link, i) => (
            <button 
              key={link.path}
              onClick={() => openWebApp(link.path)}
              className="w-full p-3 rounded-xl bg-gray-50 border border-gray-200 hover:bg-white hover:border-gray-300 hover:shadow-md transition-all flex items-center gap-3 group"
            >
              <div className={`w-9 h-9 rounded-lg ${link.iconBg} flex items-center justify-center group-hover:scale-105 transition-transform`}>
                {link.icon}
              </div>
              <div className="flex-1 text-left">
                <div className="text-sm font-medium text-gray-900 group-hover:text-cyan-600 transition-colors">{link.title}</div>
                <div className="text-[10px] text-gray-500">{link.desc}</div>
              </div>
              <svg className="w-4 h-4 text-gray-400 group-hover:text-cyan-600 group-hover:translate-x-1 transition-all" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
              </svg>
            </button>
          ))}
        </div>
      </div>

      {/* App Info */}
      <div className="text-center py-3">
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-gray-50 border border-gray-200">
          <img src={logoAltImg} alt="Propelo" className="w-6 h-6 object-contain" />
          <span className="text-xs text-gray-500 font-medium">Propelo v1.0.0</span>
        </div>
        <p className="text-[10px] text-gray-400 mt-2 flex items-center justify-center gap-1">
          Made with <span className="text-cyan-500">✨</span> for freelancers
        </p>
      </div>
    </div>
  );
};
