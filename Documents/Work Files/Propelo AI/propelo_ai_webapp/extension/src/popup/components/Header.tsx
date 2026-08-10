import { useState } from 'react';
import { UserData } from '../types';
import { URLS } from '../../config';
import logoBanner from '../../assets/logo-banner.png';

interface HeaderProps {
  user: UserData | null;
  onSignOut: () => void;
}

export const Header = ({ user, onSignOut }: HeaderProps) => {
  const [showMenu, setShowMenu] = useState(false);
  
  const openDashboard = () => {
    chrome.tabs.create({ url: URLS.dashboard });
  };

  return (
    <div className="shrink-0 bg-white border-b border-slate-100">
      <div className="px-4 py-3 flex items-center justify-between">
        {/* Logo */}
        <img src={logoBanner} alt="Propelo AI" className="h-7 w-auto object-contain" />
        
        {/* Actions */}
        <div className="flex items-center gap-2">
          <button
            onClick={openDashboard}
            className="w-8 h-8 rounded-lg bg-slate-50 border border-slate-200 flex items-center justify-center text-slate-500 hover:text-cyan-600 hover:bg-cyan-50 hover:border-cyan-200 transition-all"
            title="Open Dashboard"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
            </svg>
          </button>
          
          {/* Profile */}
          <div className="relative">
            <button
              onClick={() => setShowMenu(!showMenu)}
              className="w-8 h-8 rounded-full bg-gradient-to-br from-cyan-500 to-teal-500 flex items-center justify-center overflow-hidden transition-all hover:scale-105 shadow-md shadow-cyan-500/20"
            >
              {user?.photoURL ? (
                <img src={user.photoURL} alt="" className="w-full h-full object-cover" />
              ) : (
                <span className="text-white text-sm font-bold">
                  {user?.firstName?.[0] || user?.name?.[0] || 'U'}
                </span>
              )}
            </button>
            
            {showMenu && (
              <>
                <div className="fixed inset-0 z-40" onClick={() => setShowMenu(false)} />
                <div className="absolute right-0 top-full mt-2 w-44 bg-white rounded-xl shadow-xl border border-slate-100 py-1 z-50">
                  <div className="px-3 py-2 border-b border-slate-100">
                    <p className="text-slate-900 text-sm font-medium truncate">{user?.name || user?.firstName || 'User'}</p>
                    <p className="text-slate-500 text-xs truncate">{user?.email}</p>
                  </div>
                  <button
                    onClick={openDashboard}
                    className="w-full px-3 py-2 text-left text-sm text-slate-600 hover:bg-slate-50 flex items-center gap-2 transition-colors"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
                    </svg>
                    Open Dashboard
                  </button>
                  <button
                    onClick={() => { setShowMenu(false); onSignOut(); }}
                    className="w-full px-3 py-2 text-left text-sm text-red-600 hover:bg-red-50 flex items-center gap-2 transition-colors"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                    </svg>
                    Sign Out
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
