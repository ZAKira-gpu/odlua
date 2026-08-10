'use client';

// Declare chrome global for Chrome Extension API access
declare const chrome: {
  runtime?: {
    sendMessage: (extensionId: string, message: any, callback: (response: any) => void) => void;
    lastError?: { message?: string };
  };
  storage?: {
    local: {
      get: (keys: string[], callback: (result: Record<string, any>) => void) => void;
    };
  };
} | undefined;

import { useState, useEffect } from 'react';
import { Button } from '@/components/ui/button';
import { Card } from '@/components/ui/card';
import { Loader2, CheckCircle2, XCircle, Link as LinkIcon, AlertCircle } from 'lucide-react';

const EXTENSION_ID = process.env.NEXT_PUBLIC_EXTENSION_ID || 'YOUR_EXTENSION_ID';

export default function ConnectAccountPage() {
  const [status, setStatus] = useState<'idle' | 'connecting' | 'success' | 'error'>('idle');
  const [message, setMessage] = useState('');
  const [profileData, setProfileData] = useState<any>(null);
  const [extensionInstalled, setExtensionInstalled] = useState(false);
  const [checkingExtension, setCheckingExtension] = useState(true);

  // Check if extension is installed
  useEffect(() => {
    const checkExtension = async () => {
      try {
        if (typeof chrome !== 'undefined' && chrome?.runtime) {
          // Try to ping the extension
          chrome.runtime.sendMessage(
            EXTENSION_ID,
            { action: 'PING' },
            (response) => {
              if (chrome?.runtime?.lastError) {
                setExtensionInstalled(false);
              } else {
                setExtensionInstalled(true);
              }
              setCheckingExtension(false);
            }
          );
        } else {
          setExtensionInstalled(false);
          setCheckingExtension(false);
        }
      } catch (error) {
        setExtensionInstalled(false);
        setCheckingExtension(false);
      }
    };

    checkExtension();
    
    // Recheck every 5 seconds
    const interval = setInterval(checkExtension, 5000);
    return () => clearInterval(interval);
  }, []);

  const handleConnectUpwork = async () => {
    try {
      setStatus('connecting');
      setMessage('Starting connection process...');

      // Check extension first
      if (!extensionInstalled) {
        setStatus('error');
        setMessage('Please install the Propelo Chrome extension first');
        setTimeout(() => {
          window.open('https://chrome.google.com/webstore/detail/propelo', '_blank');
        }, 1000);
        return;
      }

      // Send message to extension to start auto-scrape
      chrome?.runtime?.sendMessage(
        EXTENSION_ID,
        {
          action: 'AUTO_SCRAPE_PROFILE',
          data: { platform: 'upwork' }
        },
        async (response) => {
          if (chrome?.runtime?.lastError) {
            console.error('Extension error:', chrome?.runtime?.lastError);
            setStatus('error');
            setMessage('Extension communication error. Please reload the page.');
            return;
          }

          if (response?.success) {
            setMessage('Fetching profile data...');
            
            // Wait a moment for data to be stored
            await new Promise(resolve => setTimeout(resolve, 2000));
            
            // Fetch the profile data from extension storage
            chrome?.storage?.local.get(['upworkProfile'], async (result) => {
              if (result.upworkProfile) {
                setProfileData(result.upworkProfile);
                
                // Send to our API
                try {
                  const apiResponse = await fetch('/api/account/receive-profile', {
                    method: 'POST',
                    headers: {
                      'Content-Type': 'application/json',
                    },
                    body: JSON.stringify({
                      platform: 'upwork',
                      profileData: result.upworkProfile
                    })
                  });

                  if (apiResponse.ok) {
                    setStatus('success');
                    setMessage('Profile connected successfully!');
                  } else {
                    throw new Error('Failed to save profile data');
                  }
                } catch (apiError) {
                  console.error('API error:', apiError);
                  setStatus('error');
                  setMessage('Profile collected but failed to save. Please try again.');
                }
              } else {
                setStatus('error');
                setMessage('No profile data found. Please try again.');
              }
            });
          } else {
            setStatus('error');
            setMessage(response?.message || 'Failed to connect profile');
          }
        }
      );
    } catch (error) {
      console.error('Connect error:', error);
      setStatus('error');
      setMessage(error instanceof Error ? error.message : 'Unknown error occurred');
    }
  };

  return (
    <div className="container mx-auto px-4 py-8 max-w-4xl">
      <div className="mb-8">
        <h1 className="text-3xl font-bold mb-2 bg-gradient-to-r from-cyan-600 to-teal-600 bg-clip-text text-transparent">Connect Your Accounts</h1>
        <p className="text-gray-600">
          Connect your freelance platform accounts to unlock AI-powered proposal generation
        </p>
      </div>

      {/* Extension Install Section with anchor */}
      <div id="extension" className="scroll-mt-8">

      {/* Extension Status Notice */}
      {checkingExtension ? (
        <Card className="p-4 mb-6 bg-cyan-50 border-cyan-200">
          <div className="flex items-center gap-3">
            <Loader2 className="w-5 h-5 text-cyan-600 animate-spin" />
            <p className="text-cyan-800">Checking for Chrome extension...</p>
          </div>
        </Card>
      ) : !extensionInstalled ? (
        <Card className="p-6 mb-6 bg-gradient-to-r from-cyan-50 to-teal-50 border-cyan-200">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-cyan-500 to-teal-600 flex items-center justify-center">
              <AlertCircle className="w-7 h-7 text-white" />
            </div>
            <div className="flex-1">
              <p className="text-cyan-900 font-bold text-lg mb-1">Chrome Extension Required</p>
              <p className="text-cyan-700 text-sm mb-4">
                The Propelo Chrome extension connects to freelance platforms and syncs your profile data automatically.
              </p>
              <div className="bg-white/70 rounded-xl p-4 border border-cyan-200 mb-4">
                <h4 className="font-semibold text-cyan-800 mb-2">Quick Install Guide:</h4>
                <ol className="text-sm text-cyan-700 space-y-1">
                  <li>1. Download the extension files from your admin</li>
                  <li>2. Go to <code className="bg-cyan-100 px-1 rounded">chrome://extensions</code></li>
                  <li>3. Enable "Developer mode" (top right)</li>
                  <li>4. Click "Load unpacked" and select the extension folder</li>
                </ol>
              </div>
              <Button 
                size="sm"
                className="bg-gradient-to-r from-cyan-500 to-teal-500 hover:from-cyan-600 hover:to-teal-600"
                onClick={() => {
                  navigator.clipboard.writeText('chrome://extensions');
                  alert('Copied chrome://extensions to clipboard! Paste in a new tab.');
                }}
              >
                Copy Extensions URL
              </Button>
            </div>
          </div>
        </Card>
      ) : (
        <Card className="p-4 mb-6 bg-green-50 border-green-200">
          <div className="flex items-center gap-3">
            <CheckCircle2 className="w-5 h-5 text-green-600" />
            <p className="text-green-800 font-medium">Chrome extension detected and ready!</p>
          </div>
        </Card>
      )}
      </div>

      {/* Upwork Connection Card */}
      <Card className="p-6 mb-6">
        <div className="flex items-start gap-4">
          {/* Upwork Logo */}
          <div className="flex-shrink-0">
            <div className="w-16 h-16 bg-green-500 rounded-lg flex items-center justify-center">
              <LinkIcon className="w-8 h-8 text-white" />
            </div>
          </div>

          {/* Content */}
          <div className="flex-1">
            <h2 className="text-xl font-semibold mb-2">Upwork</h2>
            <p className="text-gray-600 mb-4">
              Connect your Upwork account to automatically import your profile data and track proposals
            </p>

            {/* Connection Status */}
            {status === 'idle' && (
              <Button 
                onClick={handleConnectUpwork}
                size="lg"
                className="bg-green-600 hover:bg-green-700"
              >
                <LinkIcon className="w-4 h-4 mr-2" />
                Connect Upwork Account
              </Button>
            )}

            {status === 'connecting' && (
              <div className="space-y-3">
                <div className="flex items-center gap-3 text-blue-600">
                  <Loader2 className="w-5 h-5 animate-spin" />
                  <span className="font-medium">{message}</span>
                </div>
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
                  <p className="text-sm text-blue-800">
                    Please log in to Upwork if prompted. We'll automatically collect your profile information.
                  </p>
                </div>
              </div>
            )}

            {status === 'success' && profileData && (
              <div className="space-y-4">
                <div className="flex items-center gap-3 text-green-600">
                  <CheckCircle2 className="w-5 h-5" />
                  <span className="font-medium">Successfully connected!</span>
                </div>

                {/* Profile Summary */}
                <div className="bg-green-50 border border-green-200 rounded-lg p-4">
                  <h3 className="font-semibold mb-3">Profile Data Collected:</h3>
                  <div className="grid grid-cols-2 gap-3 text-sm">
                    <div>
                      <span className="text-gray-600">Name:</span>
                      <span className="font-medium ml-2">{profileData.displayName}</span>
                    </div>
                    {profileData.title && (
                      <div>
                        <span className="text-gray-600">Title:</span>
                        <span className="font-medium ml-2">{profileData.title}</span>
                      </div>
                    )}
                    {profileData.hourlyRate && (
                      <div>
                        <span className="text-gray-600">Rate:</span>
                        <span className="font-medium ml-2">${profileData.hourlyRate}/hr</span>
                      </div>
                    )}
                    {profileData.jobSuccessScore && (
                      <div>
                        <span className="text-gray-600">JSS:</span>
                        <span className="font-medium ml-2">{profileData.jobSuccessScore}%</span>
                      </div>
                    )}
                    <div>
                      <span className="text-gray-600">Portfolio:</span>
                      <span className="font-medium ml-2">
                        {profileData.portfolio?.length || 0} items
                      </span>
                    </div>
                    <div>
                      <span className="text-gray-600">Skills:</span>
                      <span className="font-medium ml-2">
                        {profileData.skills?.length || 0} skills
                      </span>
                    </div>
                  </div>
                </div>

                <Button 
                  onClick={() => {
                    setStatus('idle');
                    setProfileData(null);
                  }}
                  variant="outline"
                >
                  Reconnect
                </Button>
              </div>
            )}

            {status === 'error' && (
              <div className="space-y-3">
                <div className="flex items-center gap-3 text-red-600">
                  <XCircle className="w-5 h-5" />
                  <span className="font-medium">Connection failed</span>
                </div>
                <div className="bg-red-50 border border-red-200 rounded-lg p-4">
                  <p className="text-sm text-red-800 mb-3">{message}</p>
                  <Button 
                    onClick={() => setStatus('idle')}
                    variant="outline"
                    size="sm"
                  >
                    Try Again
                  </Button>
                </div>
              </div>
            )}
          </div>
        </div>
      </Card>

      {/* Coming Soon Cards */}
      <div className="grid md:grid-cols-2 gap-6">
        <Card className="p-6 opacity-50">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-blue-500 rounded-lg flex items-center justify-center">
              <LinkIcon className="w-6 h-6 text-white" />
            </div>
            <div>
              <h3 className="font-semibold mb-1">Fiverr</h3>
              <p className="text-sm text-gray-600">Coming soon</p>
            </div>
          </div>
        </Card>

        <Card className="p-6 opacity-50">
          <div className="flex items-start gap-4">
            <div className="w-12 h-12 bg-orange-500 rounded-lg flex items-center justify-center">
              <LinkIcon className="w-6 h-6 text-white" />
            </div>
            <div>
              <h3 className="font-semibold mb-1">Freelancer</h3>
              <p className="text-sm text-gray-600">Coming soon</p>
            </div>
          </div>
        </Card>
      </div>

      {/* Instructions */}
      <Card className="mt-8 p-6 bg-blue-50 border-blue-200">
        <h3 className="font-semibold mb-3">How it works:</h3>
        <ol className="space-y-2 text-sm text-gray-700">
          <li className="flex gap-2">
            <span className="font-semibold">1.</span>
            <span>Click "Connect Upwork Account" to start</span>
          </li>
          <li className="flex gap-2">
            <span className="font-semibold">2.</span>
            <span>Log in to Upwork if you're not already logged in</span>
          </li>
          <li className="flex gap-2">
            <span className="font-semibold">3.</span>
            <span>We'll automatically navigate to your profile and collect your data</span>
          </li>
          <li className="flex gap-2">
            <span className="font-semibold">4.</span>
            <span>Your profile data will be used to generate personalized proposals</span>
          </li>
        </ol>
      </Card>
    </div>
  );
}
