/**
 * ScrapeModal Component
 * 
 * Real-time scraping progress UI shown in the extension popup.
 * Displays step-by-step progress with animations and status messages.
 */

import React, { useEffect, useState } from 'react';
import type { ScrapeStateData, ScrapeStep } from '../../types';

interface ScrapeModalProps {
  isOpen: boolean;
  state: ScrapeStateData;
  onCancel: () => void;
  onRetry: () => void;
}

const STEP_ICONS: Record<ScrapeStep, string> = {
  'opening_profile': '📂',
  'extracting_name': '👤',
  'extracting_title': '💼',
  'extracting_bio': '📝',
  'extracting_rate': '💰',
  'extracting_location': '📍',
  'extracting_skills': '⚡',
  'extracting_stats': '📊',
  'extracting_portfolio': '🎨',
  'validating_data': '✓',
  'syncing_to_backend': '🔄',
};

export const ScrapeModal: React.FC<ScrapeModalProps> = ({ 
  isOpen, 
  state, 
  onCancel, 
  onRetry 
}) => {
  const [displayProgress, setDisplayProgress] = useState(0);

  // Smooth progress animation
  useEffect(() => {
    const interval = setInterval(() => {
      setDisplayProgress(prev => {
        const diff = state.progress - prev;
        if (Math.abs(diff) < 1) return state.progress;
        return prev + (diff > 0 ? Math.ceil(diff / 10) : Math.floor(diff / 10));
      });
    }, 100);
    
    return () => clearInterval(interval);
  }, [state.progress]);

  if (!isOpen) return null;

  const isLoading = state.state === 'opening' || state.state === 'scraping' || state.state === 'syncing';
  const isSuccess = state.state === 'complete';
  const isError = state.state === 'error';

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div className="bg-white rounded-2xl shadow-2xl p-8 w-[400px] max-w-[90vw]">
        {/* Loading State */}
        {isLoading && (
          <div className="space-y-6">
            {/* Header */}
            <div className="text-center">
              <div className="text-4xl mb-3 animate-bounce">📊</div>
              <h2 className="text-xl font-bold text-gray-900">
                {state.state === 'opening' && 'Opening your profile…'}
                {state.state === 'scraping' && 'Collecting your data…'}
                {state.state === 'syncing' && 'Syncing with Propelo…'}
              </h2>
              <p className="text-sm text-gray-500 mt-1">
                This usually takes less than 30 seconds
              </p>
            </div>

            {/* Progress Bar */}
            <div className="space-y-2">
              <div className="w-full bg-gray-200 rounded-full h-2 overflow-hidden">
                <div
                  className="h-full bg-gradient-to-r from-cyan-500 to-teal-500 transition-all duration-300 ease-out"
                  style={{ width: `${displayProgress}%` }}
                />
              </div>
              <div className="text-right text-xs text-gray-500">
                {Math.round(displayProgress)}%
              </div>
            </div>

            {/* Current Step */}
            {state.currentStep && (
              <div className="bg-gradient-to-r from-cyan-50 to-teal-50 border border-cyan-200 rounded-xl p-4">
                <div className="flex items-center gap-3">
                  <span className="text-2xl">
                    {STEP_ICONS[state.currentStep.step]}
                  </span>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-gray-900">
                      {state.currentStep.message}
                    </p>
                  </div>
                  <div className="animate-spin">⚙️</div>
                </div>
              </div>
            )}

            {/* Steps History */}
            {state.steps.length > 0 && (
              <div className="space-y-2 max-h-[200px] overflow-y-auto">
                {state.steps.map((step, idx) => (
                  <div
                    key={idx}
                    className="flex items-center gap-2 text-xs text-gray-600 opacity-75"
                  >
                    <span className="text-lg">{STEP_ICONS[step.step]}</span>
                    <span className="truncate">{step.message}</span>
                    <span className="text-green-600 font-semibold ml-auto">✓</span>
                  </div>
                ))}
              </div>
            )}

            {/* Cancel Button */}
            <button
              onClick={onCancel}
              className="w-full py-2 text-sm font-medium text-gray-600 hover:text-gray-900 bg-gray-100 hover:bg-gray-200 rounded-lg transition"
            >
              Cancel
            </button>
          </div>
        )}

        {/* Success State */}
        {isSuccess && (
          <div className="space-y-6 text-center">
            {/* Animated Success Icon */}
            <div className="flex justify-center">
              <div className="relative w-16 h-16">
                <div className="absolute inset-0 bg-green-100 rounded-full animate-ping opacity-75" />
                <div className="relative w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
                  <span className="text-3xl">✅</span>
                </div>
              </div>
            </div>

            <div>
              <h2 className="text-xl font-bold text-gray-900">
                Profile synced successfully!
              </h2>
              <p className="text-sm text-gray-500 mt-1">
                Your data has been saved to Propelo. You can now generate winning proposals.
              </p>
            </div>

            {/* Stats */}
            {state.duration && (
              <div className="bg-gray-50 rounded-lg p-3 text-sm text-gray-600">
                <span className="font-medium">Completed in {Math.round(state.duration / 1000)}s</span>
                {state.steps.length > 0 && (
                  <span className="text-gray-500"> • {state.steps.length} data points collected</span>
                )}
              </div>
            )}

            {/* Close Button */}
            <button
              onClick={onCancel}
              className="w-full py-3 bg-gradient-to-r from-cyan-500 to-teal-500 hover:from-cyan-600 hover:to-teal-600 text-white font-semibold rounded-lg transition"
            >
              Done
            </button>
          </div>
        )}

        {/* Error State */}
        {isError && (
          <div className="space-y-6">
            {/* Error Icon */}
            <div className="text-center">
              <div className="text-4xl mb-3">⚠️</div>
              <h2 className="text-xl font-bold text-red-600">
                Something went wrong
              </h2>
              <p className="text-sm text-gray-600 mt-2">
                {state.error || 'Failed to collect your profile data'}
              </p>
              {state.errorStep && (
                <p className="text-xs text-gray-500 mt-1">
                  Failed at: {state.errorStep.replace(/_/g, ' ')}
                </p>
              )}
            </div>

            {/* Error Details */}
            <div className="bg-red-50 border border-red-200 rounded-lg p-3 text-sm text-red-700">
              <p className="font-medium">What you can try:</p>
              <ul className="mt-2 space-y-1 text-xs">
                <li>• Make sure you're logged into Upwork</li>
                <li>• Check that the profile URL is correct</li>
                <li>• Refresh the page and try again</li>
              </ul>
            </div>

            {/* Action Buttons */}
            <div className="flex gap-3">
              <button
                onClick={onCancel}
                className="flex-1 py-2 text-sm font-medium text-gray-600 bg-gray-100 hover:bg-gray-200 rounded-lg transition"
              >
                Close
              </button>
              {state.canRetry && (
                <button
                  onClick={onRetry}
                  className="flex-1 py-2 text-sm font-medium text-white bg-cyan-600 hover:bg-cyan-700 rounded-lg transition"
                >
                  Retry
                </button>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ScrapeModal;
