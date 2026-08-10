import { useState } from 'react';
import { JobData, PLATFORMS } from '../types';

interface JobCardProps {
  job: JobData;
  onRefresh: () => void;
}

export const JobCard = ({ job, onRefresh }: JobCardProps) => {
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isExpanded, setIsExpanded] = useState(false);

  const handleRefresh = async () => {
    setIsRefreshing(true);
    await onRefresh();
    setTimeout(() => setIsRefreshing(false), 1000);
  };

  const getPlatformConfig = (platform?: string) => {
    const key = platform?.toLowerCase() as keyof typeof PLATFORMS;
    return PLATFORMS[key] || PLATFORMS.upwork;
  };

  const config = getPlatformConfig(job.platform);

  return (
    <div className="bg-white rounded-2xl shadow-md border border-gray-100 overflow-hidden hover:shadow-lg transition-all duration-300">
      {/* Top bar */}
      <div className={`h-1 bg-gradient-to-r ${config.gradient}`} />
      
      <div className="p-4">
        {/* Header */}
        <div className="flex items-start justify-between mb-3">
          <div className="flex items-start gap-3 flex-1 min-w-0">
            {/* Platform icon */}
            <div className={`w-12 h-12 rounded-xl ${config.bg} border ${config.border} flex items-center justify-center text-2xl shrink-0`}>
              {config.icon}
            </div>
            
            <div className="flex-1 min-w-0">
              {/* Platform badge */}
              <div className="flex items-center gap-2 mb-1">
                <span className={`px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider bg-gradient-to-r ${config.gradient} text-white`}>
                  {job.platform || 'Job'}
                </span>
                {job.budget && (
                  <span className="text-xs text-emerald-600 font-semibold">
                    {job.budget}
                  </span>
                )}
              </div>
              
              {/* Title */}
              <h3 className="text-gray-900 font-semibold text-sm leading-tight line-clamp-2">
                {job.title || 'Untitled Job'}
              </h3>
            </div>
          </div>
          
          {/* Refresh button */}
          <button
            onClick={handleRefresh}
            disabled={isRefreshing}
            className="w-9 h-9 rounded-xl bg-gray-50 border border-gray-200 flex items-center justify-center text-gray-400 hover:text-cyan-600 hover:bg-cyan-50 hover:border-cyan-200 transition-all shrink-0 ml-2"
            title="Refresh"
          >
            <svg 
              className={`w-4 h-4 transition-transform ${isRefreshing ? 'animate-spin' : 'hover:rotate-180'}`} 
              fill="none" 
              viewBox="0 0 24 24" 
              stroke="currentColor"
            >
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
            </svg>
          </button>
        </div>
        
        {/* Description */}
        <div 
          className="relative cursor-pointer group"
          onClick={() => setIsExpanded(!isExpanded)}
        >
          <p className={`text-sm text-gray-600 leading-relaxed ${isExpanded ? '' : 'line-clamp-2'}`}>
            {job.description || 'No description available'}
          </p>
          
          {/* Expand indicator */}
          {job.description && job.description.length > 100 && (
            <div className="flex items-center justify-center mt-2">
              <button className="text-xs text-cyan-600/70 hover:text-cyan-600 flex items-center gap-1 transition-colors">
                <span>{isExpanded ? 'Show less' : 'Show more'}</span>
                <svg 
                  className={`w-3 h-3 transition-transform ${isExpanded ? 'rotate-180' : ''}`} 
                  fill="none" 
                  viewBox="0 0 24 24" 
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                </svg>
              </button>
            </div>
          )}
        </div>
        
        {/* Skills */}
        {job.skills && job.skills.length > 0 && (
          <div className="mt-3 pt-3 border-t border-gray-100">
            <div className="flex flex-wrap gap-1.5">
              {job.skills.slice(0, 5).map((skill, index) => (
                <span
                  key={index}
                  className="px-2 py-1 rounded-md text-[10px] font-medium bg-gray-50 text-gray-600 border border-gray-100 hover:bg-cyan-50 hover:text-cyan-700 hover:border-cyan-200 transition-colors cursor-default"
                >
                  {skill}
                </span>
              ))}
              {job.skills.length > 5 && (
                <span className="px-2 py-1 rounded-md text-[10px] font-medium bg-cyan-50 text-cyan-600 border border-cyan-100">
                  +{job.skills.length - 5} more
                </span>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
