/**
 * OnboardingScreen Component
 * 
 * First-launch onboarding flow that asks for user consent to collect
 * Upwork profile data for personalized proposal generation.
 * 
 * This screen is shown ONLY on first launch after authentication.
 * Once the user consents or skips, it's never shown again.
 */

import { useState } from 'react';
import logoImg from '../../assets/logo-banner.png';

interface OnboardingScreenProps {
  /** Called when user consents to data collection with their profile URL */
  onConsent: (profileUrl: string) => Promise<void>;
  /** Called when user skips onboarding */
  onSkip: () => void;
}

export const OnboardingScreen = ({ onConsent, onSkip }: OnboardingScreenProps) => {
  const [isCollecting, setIsCollecting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [profileUrl, setProfileUrl] = useState('');

  /**
   * Validate Upwork profile URL
   */
  const isValidProfileUrl = (url: string): boolean => {
    return (url.includes('upwork.com/freelancers/~') || url.includes('upwork.com/ab/profiles/')) && 
           (url.match(/\/freelancers\/~[a-zA-Z0-9]+/) !== null || url.match(/\/ab\/profiles\/[a-zA-Z0-9_]+/) !== null);
  };

  /**
   * Handle user consent - trigger profile scraping
   */
  const handleConsent = async () => {
    if (!profileUrl.trim()) {
      setError('Please paste your Upwork profile URL');
      return;
    }
    
    if (!isValidProfileUrl(profileUrl)) {
      setError('Invalid URL. Please paste a URL like: https://www.upwork.com/freelancers/~01a3358405f230ab04');
      return;
    }
    
    setIsCollecting(true);
    setError(null);
    
    try {
      await onConsent(profileUrl.trim());
    } catch (err) {
      console.error('[Onboarding] Collection failed:', err);
      setError('Failed to collect profile data. Please check the URL and try again.');
      setIsCollecting(false);
    }
  };

  return (
    <div className="w-[380px] h-[520px] overflow-y-auto relative bg-gradient-to-br from-white via-slate-50 to-cyan-50/30 scrollbar-hide">
      {/* Subtle background gradient orbs */}
      <div className="absolute top-0 left-0 w-64 h-64 bg-cyan-500/5 rounded-full blur-[80px] -translate-x-1/2 -translate-y-1/2 pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-48 h-48 bg-teal-500/5 rounded-full blur-[60px] translate-x-1/2 translate-y-1/2 pointer-events-none" />
      
      <div className="relative min-h-full flex flex-col px-7 py-6 z-10">
        {/* Logo */}
        <div className="flex justify-center mb-4 shrink-0">
          <img src={logoImg} alt="Propelo AI" className="h-7 w-auto" />
        </div>
        
        {/* Main Content */}
        <div className="flex-1 flex flex-col">
          {/* Icon */}
          <div className="w-12 h-12 mx-auto mb-3 rounded-2xl bg-gradient-to-br from-cyan-500 to-teal-500 flex items-center justify-center shadow-lg shadow-cyan-500/25 shrink-0">
            <svg className="w-6 h-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
          </div>
          
          {/* Title */}
          <h1 className="text-lg font-bold text-slate-800 text-center mb-2">
            Connect Your Upwork Profile
          </h1>
          
          {/* Body */}
          <p className="text-sm text-slate-500 text-center leading-relaxed mb-4 max-w-[300px] mx-auto">
            Paste your Upwork profile URL to generate personalized proposals based on your skills and experience.
          </p>
          
          {/* Profile URL Input */}
          <div className="mb-4">
            <label className="block text-xs font-medium text-slate-600 mb-1.5">
              Your Upwork Profile URL
            </label>
            <input
              type="url"
              value={profileUrl}
              onChange={(e) => setProfileUrl(e.target.value)}
              placeholder="https://www.upwork.com/freelancers/~01a33..."
              className="w-full px-3 py-2.5 rounded-xl border border-slate-200 bg-white text-sm placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-cyan-500/20 focus:border-cyan-500 transition-all"
            />
            <p className="text-[10px] text-slate-400 mt-1.5">
              💡 Go to Upwork → Click your profile picture → Copy the URL from your browser
            </p>
          </div>
          
          {/* Features */}
          <div className="space-y-1.5 mb-4">
            {[
              { icon: '🎯', text: 'Tailored to your expertise' },
              { icon: '⚡', text: 'Auto-fill your skills & experience' },
              { icon: '📈', text: 'Higher proposal success rate' },
            ].map((feature, i) => (
              <div key={i} className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-white/60 border border-slate-100">
                <span className="text-sm">{feature.icon}</span>
                <span className="text-xs text-slate-600">{feature.text}</span>
              </div>
            ))}
          </div>
          
          {/* Error message */}
          {error && (
            <div className="mb-3 p-2.5 rounded-xl bg-red-50 border border-red-100">
              <p className="text-xs text-red-600 text-center">{error}</p>
            </div>
          )}
        </div>
        
        {/* Actions */}
        <div className="space-y-2 pt-2 shrink-0">
          {/* Primary CTA */}
          <button
            onClick={handleConsent}
            disabled={isCollecting || !profileUrl.trim()}
            className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 hover:from-cyan-400 hover:to-teal-400 text-white font-semibold shadow-lg shadow-cyan-500/25 transition-all duration-200 flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isCollecting ? (
              <>
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                <span>Collecting profile...</span>
              </>
            ) : (
              <>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
                </svg>
                <span>Connect & Collect Data</span>
              </>
            )}
          </button>
          
          {/* Secondary action */}
          <button
            onClick={onSkip}
            disabled={isCollecting}
            className="w-full py-2 rounded-xl text-slate-500 hover:text-slate-700 hover:bg-slate-100 text-sm font-medium transition-all disabled:opacity-50"
          >
            Skip for now
          </button>
        </div>
        
        {/* Privacy reassurance */}
        <p className="text-[10px] text-slate-400 text-center mt-3 leading-relaxed shrink-0">
          We only read publicly available profile data.
        </p>
      </div>
    </div>
  );
};
