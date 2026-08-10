/**
 * ProfileDetectedView Component
 * 
 * Shown when the extension detects that the user is on an Upwork freelancer profile page.
 * Prompts the user to collect their profile data for personalized proposals.
 */

import { useState } from 'react';
import logoImg from '../../assets/logo-banner.png';

interface ProfileDetectedViewProps {
  /** Profile URL detected */
  profileUrl: string;
  /** Whether profile is already connected */
  isAlreadyConnected: boolean;
  /** Callback when user consents to scraping */
  onScrape: () => Promise<void>;
  /** Callback when user declines */
  onDismiss: () => void;
  /** Callback to go back to main view */
  onBack: () => void;
}

export const ProfileDetectedView = ({ 
  profileUrl,
  isAlreadyConnected,
  onScrape, 
  onDismiss,
  onBack
}: ProfileDetectedViewProps) => {
  const [isScraping, setIsScraping] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState(false);

  const handleScrape = async () => {
    setIsScraping(true);
    setError(null);
    
    try {
      await onScrape();
      setSuccess(true);
    } catch (err) {
      console.error('[ProfileDetected] Scraping failed:', err);
      setError(err instanceof Error ? err.message : 'Failed to collect profile data. Please try again.');
    } finally {
      setIsScraping(false);
    }
  };

  // Success state
  if (success) {
    return (
      <div className="w-[380px] h-[520px] bg-white flex flex-col">
        <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
          {/* Success Icon */}
          <div className="w-20 h-20 rounded-full bg-gradient-to-br from-green-400 to-emerald-500 flex items-center justify-center mb-6 shadow-lg shadow-green-500/30">
            <svg className="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M5 13l4 4L19 7" />
            </svg>
          </div>
          
          <h2 className="text-xl font-bold text-gray-900 mb-2">Profile Connected!</h2>
          <p className="text-gray-500 text-sm mb-8">
            Your Upwork profile data has been collected. Propelo will now generate more personalized proposals for you.
          </p>
          
          <button
            onClick={onBack}
            className="px-8 py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 text-white font-semibold shadow-lg shadow-cyan-500/25 hover:shadow-xl transition-all"
          >
            Continue to Proposal Generator
          </button>
        </div>
      </div>
    );
  }

  // Already connected state
  if (isAlreadyConnected) {
    return (
      <div className="w-[380px] h-[520px] bg-white flex flex-col">
        {/* Header */}
        <div className="px-6 py-4 border-b border-gray-100">
          <div className="flex items-center justify-between">
            <img src={logoImg} alt="Propelo" className="h-6" />
            <button
              onClick={onBack}
              className="text-sm text-gray-500 hover:text-gray-700 transition-colors"
            >
              ← Back
            </button>
          </div>
        </div>

        <div className="flex-1 flex flex-col items-center justify-center px-8 text-center">
          {/* Connected Icon */}
          <div className="w-16 h-16 rounded-full bg-green-100 flex items-center justify-center mb-5">
            <svg className="w-8 h-8 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
          
          <h2 className="text-lg font-bold text-gray-900 mb-2">Profile Already Connected</h2>
          <p className="text-gray-500 text-sm mb-6">
            Your Upwork profile is already synced. Proposals are being personalized with your data.
          </p>
          
          <div className="space-y-3 w-full">
            <button
              onClick={handleScrape}
              disabled={isScraping}
              className="w-full py-3 rounded-xl border-2 border-gray-200 text-gray-700 font-medium hover:bg-gray-50 hover:border-gray-300 transition-all flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {isScraping ? (
                <>
                  <div className="w-4 h-4 border-2 border-gray-300 border-t-gray-600 rounded-full animate-spin" />
                  Updating...
                </>
              ) : (
                <>
                  <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                  </svg>
                  Re-sync Profile Data
                </>
              )}
            </button>
            
            <button
              onClick={onBack}
              className="w-full py-3 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 text-white font-semibold shadow-lg shadow-cyan-500/25 hover:shadow-xl transition-all"
            >
              Generate Proposal
            </button>
          </div>
        </div>
      </div>
    );
  }

  // Main prompt state
  return (
    <div className="w-[380px] h-[520px] bg-white flex flex-col">
      {/* Header */}
      <div className="px-6 py-4 border-b border-gray-100">
        <div className="flex items-center justify-between">
          <img src={logoImg} alt="Propelo" className="h-6" />
          <span className="text-xs text-cyan-600 font-medium px-2 py-1 bg-cyan-50 rounded-full">
            Profile Detected
          </span>
        </div>
      </div>

      {/* Content */}
      <div className="flex-1 flex flex-col px-7 py-6">
        {/* Icon */}
        <div className="w-14 h-14 mx-auto mb-5 rounded-2xl bg-gradient-to-br from-cyan-500 to-teal-500 flex items-center justify-center shadow-lg shadow-cyan-500/25">
          <svg className="w-7 h-7 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        </div>

        {/* Title */}
        <h2 className="text-xl font-bold text-gray-900 text-center mb-3">
          Collect your Upwork profile data?
        </h2>

        {/* Description */}
        <p className="text-sm text-gray-500 text-center leading-relaxed mb-6">
          Propelo can analyze your profile (skills, experience, bio, job history) to generate highly personalized proposals and improve your chances of winning jobs.
        </p>

        {/* Benefits */}
        <div className="space-y-2.5 mb-6">
          {[
            { icon: '🎯', text: 'Proposals tailored to your expertise' },
            { icon: '⚡', text: 'Auto-fill skills & experience' },
            { icon: '📈', text: 'Higher win rate with personalization' },
          ].map((item, i) => (
            <div key={i} className="flex items-center gap-3 px-4 py-2.5 rounded-xl bg-gray-50 border border-gray-100">
              <span className="text-lg">{item.icon}</span>
              <span className="text-sm text-gray-600">{item.text}</span>
            </div>
          ))}
        </div>

        {/* Error message */}
        {error && (
          <div className="mb-4 p-3 rounded-xl bg-red-50 border border-red-100">
            <p className="text-xs text-red-600 text-center">{error}</p>
          </div>
        )}

        {/* Spacer */}
        <div className="flex-1" />

        {/* Actions */}
        <div className="space-y-3">
          <button
            onClick={handleScrape}
            disabled={isScraping}
            className="w-full py-3.5 rounded-xl bg-gradient-to-r from-cyan-500 to-teal-500 hover:from-cyan-400 hover:to-teal-400 text-white font-semibold shadow-lg shadow-cyan-500/25 transition-all flex items-center justify-center gap-2 disabled:opacity-70"
          >
            {isScraping ? (
              <>
                <div className="w-5 h-5 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                Collecting profile...
              </>
            ) : (
              <>
                <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                Yes, scrape my profile
              </>
            )}
          </button>
          
          <button
            onClick={onDismiss}
            disabled={isScraping}
            className="w-full py-2.5 rounded-xl text-gray-500 hover:text-gray-700 hover:bg-gray-100 text-sm font-medium transition-all disabled:opacity-50"
          >
            Not now
          </button>
        </div>

        {/* Privacy note */}
        <p className="text-[10px] text-gray-400 text-center mt-4">
          We only read publicly available profile data. Nothing is posted or changed.
        </p>
      </div>
    </div>
  );
};
