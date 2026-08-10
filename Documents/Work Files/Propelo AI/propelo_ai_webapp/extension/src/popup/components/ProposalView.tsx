import { useEffect, useState, useRef } from 'react';

interface ProposalViewProps {
  proposal: string;
  onBack: () => void;
  onNewProposal?: () => void;
  onImprove?: (proposal: string, instructions: string) => Promise<string>;
  onUpdate?: (proposal: string) => void;
}

// Quick fix presets
const QUICK_FIXES = [
  { id: 'hook', label: '🎯 Stronger hook', instruction: 'Add a more compelling opening hook that shows I understand their problem' },
  { id: 'human', label: '💬 More human', instruction: 'Make it sound more human and conversational, less corporate' },
  { id: 'shorter', label: '✂️ Make shorter', instruction: 'Make it more concise, remove fluff, keep the key points' },
  { id: 'cta', label: '📞 Better CTA', instruction: 'Add a natural, low-friction call-to-action at the end' },
  { id: 'proof', label: '📊 Add proof', instruction: 'Add more specifics, social proof, or relevant experience' },
  { id: 'mvp', label: '🚀 MVP focus', instruction: 'Emphasize MVP-first approach and validate before building big' },
];

export const ProposalView = ({ proposal, onBack, onNewProposal, onImprove, onUpdate }: ProposalViewProps) => {
  const [displayedContent, setDisplayedContent] = useState('');
  const [editedContent, setEditedContent] = useState('');
  const [copied, setCopied] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  const [isTyping, setIsTyping] = useState(true);
  const [charCount, setCharCount] = useState(0);
  const [isEditing, setIsEditing] = useState(false);
  const [isImproving, setIsImproving] = useState(false);
  const [showAIModal, setShowAIModal] = useState(false);
  const [customInstruction, setCustomInstruction] = useState('');
  const [selectedPreset, setSelectedPreset] = useState<string | null>(null);
  const [improveError, setImproveError] = useState<string | null>(null);
  const contentRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Typing effect with counter
  useEffect(() => {
    if (!proposal) return;
    
    let index = 0;
    const speed = 6;
    setDisplayedContent('');
    setEditedContent(proposal);
    setIsTyping(true);
    setCharCount(0);
    
    const interval = setInterval(() => {
      if (index < proposal.length) {
        setDisplayedContent((prev) => prev + proposal.charAt(index));
        setCharCount(index + 1);
        index++;
        if (contentRef.current) {
          contentRef.current.scrollTop = contentRef.current.scrollHeight;
        }
      } else {
        setIsTyping(false);
        clearInterval(interval);
      }
    }, speed);

    return () => clearInterval(interval);
  }, [proposal]);

  const handleCopy = async () => {
    const textToCopy = isEditing ? editedContent : proposal;
    await navigator.clipboard.writeText(textToCopy);
    setCopied(true);
    setShowSuccess(true);
    setTimeout(() => {
      setCopied(false);
      setShowSuccess(false);
    }, 2500);
  };

  const handleEdit = () => {
    setIsEditing(true);
    setEditedContent(proposal);
    setTimeout(() => textareaRef.current?.focus(), 100);
  };

  const handleSaveEdit = () => {
    setIsEditing(false);
    if (onUpdate && editedContent !== proposal) {
      onUpdate(editedContent);
    }
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setEditedContent(proposal);
  };

  const handleOpenAIModal = () => {
    setShowAIModal(true);
    setCustomInstruction('');
    setSelectedPreset(null);
    setImproveError(null);
  };

  const handleCloseAIModal = () => {
    setShowAIModal(false);
    setCustomInstruction('');
    setSelectedPreset(null);
    setImproveError(null);
  };

  const handleSelectPreset = (presetId: string) => {
    if (selectedPreset === presetId) {
      setSelectedPreset(null);
    } else {
      setSelectedPreset(presetId);
      const preset = QUICK_FIXES.find(p => p.id === presetId);
      if (preset) {
        setCustomInstruction(preset.instruction);
      }
    }
  };

  const handleImprove = async () => {
    if (!onImprove) return;
    
    const instruction = customInstruction.trim() || 'Make this proposal more human, compelling, and persuasive';
    
    setIsImproving(true);
    setImproveError(null);
    setShowAIModal(false);
    
    try {
      const improved = await onImprove(isEditing ? editedContent : proposal, instruction);
      setDisplayedContent(improved);
      setEditedContent(improved);
      if (onUpdate) onUpdate(improved);
    } catch (err: any) {
      setImproveError(err.message || 'Failed to improve proposal');
      setShowAIModal(true);
    } finally {
      setIsImproving(false);
    }
  };

  const currentContent = isEditing ? editedContent : displayedContent;
  const wordCount = currentContent.split(/\s+/).filter(Boolean).length;

  return (
    <div className="space-y-4 animate-fade-in">
      {/* Header */}
      <div className="flex items-center justify-between">
        <button
          onClick={onBack}
          className="flex items-center gap-2 text-gray-500 hover:text-gray-700 transition-colors group"
        >
          <div className="w-8 h-8 rounded-lg bg-gray-50 border border-gray-200 flex items-center justify-center group-hover:bg-gray-100 transition-colors">
            <svg className="w-4 h-4 group-hover:-translate-x-0.5 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </div>
          <span className="text-sm font-medium">Back</span>
        </button>
        
        {/* Status indicator */}
        <div className={`flex items-center gap-2 px-3 py-1.5 rounded-full bg-white border ${isTyping ? 'border-cyan-200 text-cyan-600' : 'border-emerald-200 text-emerald-600'}`}>
          <div className={`w-2 h-2 rounded-full ${isTyping ? 'bg-cyan-500 animate-pulse' : 'bg-emerald-500'}`} />
          <span className="text-xs font-medium">
            {isTyping ? 'Generating...' : 'Complete'}
          </span>
        </div>
      </div>

      {/* Proposal card */}
      <div className="bg-white rounded-2xl shadow-lg border border-gray-100 overflow-hidden">
        {/* Progress bar */}
        <div className="h-1 bg-gray-100 overflow-hidden">
          <div 
            className="h-full bg-gradient-to-r from-cyan-500 to-teal-500 transition-all duration-100"
            style={{ width: `${(charCount / proposal.length) * 100}%` }}
          />
        </div>
        
        {/* Content */}
        <div 
          ref={contentRef}
          className="p-4 max-h-[240px] overflow-y-auto"
        >
          {isEditing ? (
            <textarea
              ref={textareaRef}
              value={editedContent}
              onChange={(e) => setEditedContent(e.target.value)}
              className="w-full h-48 text-sm text-gray-700 leading-relaxed resize-none border-0 focus:ring-0 focus:outline-none bg-transparent"
              placeholder="Edit your proposal..."
            />
          ) : (
            <p className="text-sm text-gray-700 whitespace-pre-wrap leading-relaxed">
              {displayedContent}
              {isTyping && (
                <span className="inline-block w-0.5 h-4 bg-cyan-500 animate-pulse ml-0.5" />
              )}
            </p>
          )}
        </div>
        
        {/* Bottom fade */}
        <div className="absolute bottom-0 left-0 right-0 h-8 bg-gradient-to-t from-white to-transparent pointer-events-none" />
      </div>

      {/* Stats bar */}
      <div className="flex items-center justify-center gap-6 py-2">
        <div className="flex items-center gap-2 text-gray-400">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129" />
          </svg>
          <span className="text-xs font-medium">{currentContent.length} chars</span>
        </div>
        <div className="w-px h-4 bg-gray-200" />
        <div className="flex items-center gap-2 text-gray-400">
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <span className="text-xs font-medium">{wordCount} words</span>
        </div>
      </div>

      {/* Edit mode buttons */}
      {isEditing && (
        <div className="flex gap-2">
          <button
            onClick={handleSaveEdit}
            className="flex-1 py-2.5 px-4 rounded-xl font-medium text-sm bg-emerald-500 text-white hover:bg-emerald-600 transition-all flex items-center justify-center gap-2"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
            </svg>
            Save Changes
          </button>
          <button
            onClick={handleCancelEdit}
            className="py-2.5 px-4 rounded-xl font-medium text-sm bg-gray-100 text-gray-600 hover:bg-gray-200 transition-all"
          >
            Cancel
          </button>
        </div>
      )}

      {/* Action buttons */}
      <div className="flex gap-2">
        {/* Copy button */}
        <button
          onClick={handleCopy}
          disabled={isTyping || isEditing}
          className={`flex-1 py-3 px-4 rounded-xl font-semibold text-sm transition-all flex items-center justify-center gap-2 ${
            copied 
              ? 'bg-emerald-50 text-emerald-600 border border-emerald-200' 
              : 'bg-gradient-to-r from-cyan-500 to-teal-500 text-white shadow-lg shadow-cyan-500/25 hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed'
          }`}
        >
          {copied ? (
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
        
        {/* Edit button */}
        <button
          onClick={handleEdit}
          disabled={isTyping || isEditing}
          className="py-3 px-4 rounded-xl font-medium text-sm bg-gray-50 border border-gray-200 text-gray-600 hover:text-blue-600 hover:bg-blue-50 hover:border-blue-200 transition-all disabled:opacity-50"
          title="Edit manually"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>

        {/* AI Improve button */}
        {onImprove && (
          <button
            onClick={handleOpenAIModal}
            disabled={isTyping || isImproving}
            className="py-3 px-4 rounded-xl font-medium text-sm bg-purple-50 border border-purple-200 text-purple-600 hover:bg-purple-100 hover:border-purple-300 transition-all disabled:opacity-50 flex items-center gap-1.5"
            title="Improve with AI"
          >
            {isImproving ? (
              <svg className="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
              </svg>
            ) : (
              <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            )}
            <span>{isImproving ? '...' : 'AI'}</span>
          </button>
        )}
        
        {/* New proposal button */}
        <button
          onClick={onNewProposal || onBack}
          disabled={isEditing}
          className="py-3 px-4 rounded-xl font-medium text-sm bg-gray-50 border border-gray-200 text-gray-600 hover:text-cyan-600 hover:bg-cyan-50 hover:border-cyan-200 transition-all disabled:opacity-50"
          title="New proposal"
        >
          <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
          </svg>
        </button>
      </div>

      {/* AI Improve Modal */}
      {showAIModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 animate-fade-in">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-sm overflow-hidden">
            {/* Header */}
            <div className="p-4 border-b border-gray-100 bg-gradient-to-r from-purple-50 to-indigo-50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-purple-500 to-indigo-500 flex items-center justify-center">
                  <svg className="w-5 h-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900">AI Improve</h3>
                  <p className="text-xs text-gray-500">What should I fix?</p>
                </div>
                <button
                  onClick={handleCloseAIModal}
                  className="ml-auto p-1.5 rounded-lg hover:bg-gray-100 text-gray-400 hover:text-gray-600"
                >
                  <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            {/* Quick fixes */}
            <div className="p-4 space-y-3">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide">Quick fixes</p>
              <div className="grid grid-cols-2 gap-2">
                {QUICK_FIXES.map((fix) => (
                  <button
                    key={fix.id}
                    onClick={() => handleSelectPreset(fix.id)}
                    className={`p-2.5 rounded-xl text-left text-sm transition-all ${
                      selectedPreset === fix.id
                        ? 'bg-purple-100 border-2 border-purple-400 text-purple-700'
                        : 'bg-gray-50 border border-gray-200 text-gray-700 hover:bg-gray-100 hover:border-gray-300'
                    }`}
                  >
                    {fix.label}
                  </button>
                ))}
              </div>

              {/* Custom instruction */}
              <div className="pt-2">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">Or describe what to fix</p>
                <textarea
                  value={customInstruction}
                  onChange={(e) => {
                    setCustomInstruction(e.target.value);
                    setSelectedPreset(null);
                  }}
                  placeholder="e.g., Make it shorter and add more urgency..."
                  className="w-full h-20 p-3 rounded-xl border border-gray-200 text-sm resize-none focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                />
              </div>

              {/* Error message */}
              {improveError && (
                <div className="p-3 rounded-xl bg-red-50 border border-red-200 text-red-600 text-sm">
                  {improveError}
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="p-4 border-t border-gray-100 flex gap-2">
              <button
                onClick={handleCloseAIModal}
                className="flex-1 py-2.5 px-4 rounded-xl font-medium text-sm bg-gray-100 text-gray-600 hover:bg-gray-200 transition-all"
              >
                Cancel
              </button>
              <button
                onClick={handleImprove}
                disabled={!customInstruction.trim() && !selectedPreset}
                className="flex-1 py-2.5 px-4 rounded-xl font-medium text-sm bg-gradient-to-r from-purple-500 to-indigo-500 text-white hover:from-purple-600 hover:to-indigo-600 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
              >
                <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
                </svg>
                Improve
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
