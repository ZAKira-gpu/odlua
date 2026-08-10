import { useState } from 'react';
import { HistoryItem, PLATFORMS } from '../types';

interface HistoryListProps {
  history: HistoryItem[];
  onDelete: (id: string) => void;
}

export const HistoryList = ({ history, onDelete }: HistoryListProps) => {
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const copyToClipboard = async (text: string, id: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const formatDate = (timestamp: number) => {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) return 'Today';
    if (days === 1) return 'Yesterday';
    if (days < 7) return `${days} days ago`;
    return date.toLocaleDateString();
  };

  const getPlatformConfig = (platform?: string) => {
    const key = platform?.toLowerCase() as keyof typeof PLATFORMS;
    return PLATFORMS[key] || PLATFORMS.upwork;
  };

  if (history.length === 0) {
    return (
      <div className="text-center py-16 animate-fade-in">
        {/* Empty state icon */}
        <div className="relative w-24 h-24 mx-auto mb-6">
          {/* Outer ring */}
          <div className="absolute inset-0 rounded-full border-2 border-dashed border-gray-200 animate-spin" style={{ animationDuration: '20s' }} />
          
          {/* Icon */}
          <div className="absolute inset-4 rounded-full bg-gray-50 border border-gray-200 flex items-center justify-center">
            <svg className="w-10 h-10 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
          </div>
        </div>
        
        <h3 className="font-bold text-gray-900 mb-2 text-lg">No History Yet</h3>
        <p className="text-sm text-gray-500 max-w-[200px] mx-auto">
          Your generated proposals will appear here for easy access
        </p>
        
        {/* Decorative dots */}
        <div className="flex justify-center gap-2 mt-6">
          {[...Array(3)].map((_, i) => (
            <div 
              key={i}
              className="w-2 h-2 rounded-full animate-pulse"
              style={{ 
                background: ['#0EA5E9', '#14B8A6', '#0EA5E9'][i],
                animationDelay: `${i * 200}ms`
              }}
            />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {/* Header */}
      <div className="flex items-center justify-between mb-4">
        <div className="flex items-center gap-2">
          <h2 className="text-lg font-bold text-gray-900">Recent Proposals</h2>
          <div className="w-1.5 h-1.5 rounded-full bg-cyan-500 animate-pulse" />
        </div>
        <span className="text-xs text-gray-500 bg-gray-50 px-3 py-1.5 rounded-full border border-gray-200 flex items-center gap-1.5">
          <span className="w-1.5 h-1.5 rounded-full bg-teal-500" />
          {history.length} saved
        </span>
      </div>
      
      {history.map((item, index) => {
        const isExpanded = expandedId === item.id;
        const isCopied = copiedId === item.id;
        const platformConfig = getPlatformConfig(item.platform);
        
        return (
          <div
            key={item.id}
            className="bg-white rounded-xl border border-gray-100 overflow-hidden transition-all duration-300 group hover:shadow-lg animate-fade-in"
            style={{ animationDelay: `${index * 50}ms` }}
          >
            {/* Top bar */}
            <div className={`h-1 bg-gradient-to-r ${platformConfig.gradient}`} />
            
            {/* Header */}
            <div 
              className="p-4 cursor-pointer"
              onClick={() => setExpandedId(isExpanded ? null : item.id)}
            >
              <div className="flex items-start gap-3">
                {/* Platform icon */}
                <div className={`w-11 h-11 rounded-xl ${platformConfig.bg} border ${platformConfig.border} flex items-center justify-center shrink-0 group-hover:scale-105 transition-transform`}>
                  <span className="text-xl">{platformConfig.icon}</span>
                </div>
                
                <div className="flex-1 min-w-0">
                  <h3 className="font-medium text-gray-900 truncate group-hover:text-cyan-600 transition-colors">
                    {item.jobTitle || 'Untitled Proposal'}
                  </h3>
                  <div className="flex items-center gap-2 mt-1.5">
                    <span className="text-xs text-gray-400 flex items-center gap-1">
                      <svg className="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      {formatDate(item.timestamp)}
                    </span>
                    {item.platform && (
                      <span className={`text-[10px] px-2 py-0.5 rounded-full ${platformConfig.bg} ${platformConfig.border} border text-gray-700 capitalize font-medium`}>
                        {item.platform}
                      </span>
                    )}
                  </div>
                </div>
                
                {/* Expand/collapse indicator */}
                <div className={`w-8 h-8 rounded-lg ${isExpanded ? 'bg-cyan-50 border-cyan-200' : 'bg-gray-50 border-gray-200'} border flex items-center justify-center transition-all`}>
                  <svg 
                    className={`w-4 h-4 ${isExpanded ? 'text-cyan-600' : 'text-gray-400'} transition-all duration-300 ${isExpanded ? 'rotate-180' : ''}`} 
                    fill="none" 
                    viewBox="0 0 24 24" 
                    stroke="currentColor"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                  </svg>
                </div>
              </div>
            </div>
            
            {/* Expanded content */}
            {isExpanded && (
              <div className="px-4 pb-4 animate-fade-in">
                {/* Proposal preview */}
                <div className="relative bg-gray-50 rounded-xl p-4 mb-3 max-h-48 overflow-y-auto border border-gray-100">
                  {/* Character count badge */}
                  <div className="absolute top-2 right-2 text-[10px] px-2 py-0.5 rounded-full bg-white text-gray-400 border border-gray-100">
                    {item.proposal.length} chars
                  </div>
                  <p className="text-sm text-gray-700 whitespace-pre-wrap leading-relaxed pr-16">{item.proposal}</p>
                </div>
                
                {/* Action buttons */}
                <div className="flex gap-2">
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      copyToClipboard(item.proposal, item.id);
                    }}
                    className={`flex-1 py-2.5 rounded-xl text-sm font-medium flex items-center justify-center gap-2 transition-all ${
                      isCopied 
                        ? 'bg-emerald-50 text-emerald-600 border border-emerald-200' 
                        : 'bg-gradient-to-r from-cyan-500 to-teal-500 text-white shadow-lg shadow-cyan-500/25 hover:shadow-xl'
                    }`}
                  >
                    {isCopied ? (
                      <>
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                        </svg>
                        Copied!
                      </>
                    ) : (
                      <>
                        <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                        </svg>
                        Copy
                      </>
                    )}
                  </button>
                  
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      onDelete(item.id);
                    }}
                    className="py-2.5 px-4 rounded-xl text-sm font-medium bg-red-50 text-red-600 border border-red-100 hover:bg-red-100 transition-all flex items-center justify-center gap-2"
                  >
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                    Delete
                  </button>
                </div>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
};
