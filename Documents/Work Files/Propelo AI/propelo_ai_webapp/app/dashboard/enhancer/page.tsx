"use client";

import * as React from "react";
import { PageContainer, PageHeader } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Form, FormField } from "@/components/ui/form";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Sparkles, Copy, Download, RotateCw, TrendingUp, AlertCircle, Zap, X } from "lucide-react";
import { FadeIn } from "@/components/ui/animations";
import toast from "react-hot-toast";

// Quick fix presets
const QUICK_FIXES = [
  { id: "hook", label: "Better hook", instruction: "Add a stronger opening hook that grabs attention and shows I understand their pain" },
  { id: "human", label: "More human", instruction: "Make it sound more conversational and human, less corporate and robotic" },
  { id: "shorter", label: "Make shorter", instruction: "Make it more concise and scannable, remove fluff and filler words" },
  { id: "cta", label: "Stronger CTA", instruction: "Improve the call-to-action to be more compelling and low-friction" },
  { id: "proof", label: "Add proof", instruction: "Add more specific examples, numbers, or social proof to build credibility" },
  { id: "mvp", label: "MVP framing", instruction: "Frame the approach as MVP-first with quick wins before scaling" },
];

export default function EnhancerPage() {
  const [originalProposal, setOriginalProposal] = React.useState("");
  const [enhancedResult, setEnhancedResult] = React.useState<any>(null);
  const [isEnhancing, setIsEnhancing] = React.useState(false);
  
  // Modal state
  const [showAIModal, setShowAIModal] = React.useState(false);
  const [selectedPreset, setSelectedPreset] = React.useState<string | null>(null);
  const [customInstruction, setCustomInstruction] = React.useState("");

  const handleOpenModal = () => {
    if (!originalProposal.trim()) {
      toast.error("Please enter a proposal to enhance");
      return;
    }
    if (originalProposal.trim().length < 100) {
      toast.error("Proposal must be at least 100 characters");
      return;
    }
    setShowAIModal(true);
  };

  const handleCloseModal = () => {
    setShowAIModal(false);
    setSelectedPreset(null);
    setCustomInstruction("");
  };

  const handleSelectPreset = (presetId: string) => {
    setSelectedPreset(presetId);
    const preset = QUICK_FIXES.find(f => f.id === presetId);
    if (preset) {
      setCustomInstruction(preset.instruction);
    }
  };

  const handleEnhance = async () => {
    const instructions = customInstruction.trim();
    if (!instructions && !selectedPreset) {
      toast.error("Please select a fix or describe what to improve");
      return;
    }

    setIsEnhancing(true);
    handleCloseModal();
    
    try {
      const response = await fetch("/api/proposals/enhance", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          originalText: originalProposal,
          instructions: instructions,
        }),
      });

      const result = await response.json();

      if (!response.ok) {
        throw new Error(result.error || "Failed to enhance proposal");
      }

      setEnhancedResult(result.data);
      toast.success("Proposal enhanced successfully! 🎉");
    } catch (error: any) {
      toast.error(error.message || "Failed to enhance proposal. Please try again.");
    } finally {
      setIsEnhancing(false);
    }
  };

  const handleCopy = () => {
    if (enhancedResult?.enhancedText) {
      navigator.clipboard.writeText(enhancedResult.enhancedText);
      toast.success("Enhanced proposal copied to clipboard!");
    }
  };

  const handleDownload = () => {
    if (enhancedResult?.enhancedText) {
      const blob = new Blob([enhancedResult.enhancedText], { type: "text/plain" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `enhanced-proposal-${Date.now()}.txt`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success("Proposal downloaded!");
    }
  };

  return (
    <PageContainer>
      <FadeIn>
        <PageHeader
          title="Proposal Enhancer"
          description="Improve your existing proposals with AI-powered suggestions"
          breadcrumbs={
            <Breadcrumbs
              items={[
                { label: "Dashboard", href: "/dashboard" },
                { label: "Enhancer" },
              ]}
            />
          }
        />
      </FadeIn>

      <div className="grid lg:grid-cols-2 gap-8">
        {/* Input */}
        <FadeIn delay={0.1}>
          <Card className="p-6">
            <Form onSubmit={(e) => { e.preventDefault(); handleOpenModal(); }}>
              <FormField
                label="Original Proposal"
                required
                hint="Paste your existing proposal here"
              >
                <Textarea
                  placeholder="Paste your proposal text..."
                  rows={12}
                  value={originalProposal}
                  onChange={(e) => setOriginalProposal(e.target.value)}
                  className="border-2 focus:border-primary/50 transition-colors"
                />
              </FormField>

              <Button
                type="submit"
                size="lg"
                className="w-full gradient-primary relative overflow-hidden group"
                disabled={isEnhancing}
              >
                <span className="absolute inset-0 shimmer opacity-0 group-hover:opacity-100" />
                {isEnhancing ? (
                  <>
                    <RotateCw className="h-5 w-5 mr-2 animate-spin relative z-10" />
                    <span className="relative z-10">Enhancing...</span>
                  </>
                ) : (
                  <>
                    <Sparkles className="h-5 w-5 mr-2 relative z-10 group-hover:rotate-180 transition-transform duration-500" />
                    <span className="relative z-10">Enhance Proposal</span>
                  </>
                )}
              </Button>
            </Form>
          </Card>
        </FadeIn>

        {/* Output */}
        <FadeIn delay={0.2}>
          {enhancedResult ? (
            <Card className="p-8">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-lg font-semibold text-foreground flex items-center gap-2">
                  <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                  Enhanced Proposal
                </h3>
                <div className="flex gap-2">
                  <Button 
                    variant="outline" 
                    size="sm" 
                    onClick={handleCopy}
                    className="hover:bg-primary/5 hover:text-primary hover:border-primary/50"
                  >
                    <Copy className="h-4 w-4 mr-2" />
                    Copy
                  </Button>
                  <Button 
                    variant="outline" 
                    size="sm" 
                    onClick={handleDownload}
                    className="hover:bg-primary/5 hover:text-primary hover:border-primary/50"
                  >
                    <Download className="h-4 w-4 mr-2" />
                    Download
                  </Button>
                </div>
              </div>

              {/* Quality Ratings */}
              {(enhancedResult.beforeRating || enhancedResult.afterRating) && (
                <div className="mb-6 p-4 bg-gradient-to-r from-cyan-50 to-teal-50 border border-cyan-100 rounded-xl">
                  <h4 className="text-sm font-semibold text-foreground mb-3 flex items-center gap-2">
                    <TrendingUp className="h-4 w-4 text-primary" />
                    Quality Improvement
                  </h4>
                  <div className="flex items-center justify-between">
                    <div>
                      <p className="text-sm text-muted-foreground mb-1">Before</p>
                      <Badge variant="secondary" className="text-base px-3 py-1">
                        {enhancedResult.beforeRating}/10
                      </Badge>
                    </div>
                    <div className="text-3xl text-primary animate-pulse">→</div>
                    <div>
                      <p className="text-sm text-muted-foreground mb-1">After</p>
                      <Badge className="bg-green-500 text-white text-base px-3 py-1">
                        {enhancedResult.afterRating}/10
                      </Badge>
                    </div>
                  </div>
                </div>
              )}

              <div className="space-y-6">
                <div>
                  <label className="text-sm font-semibold text-foreground mb-2 block">
                    Enhanced Proposal
                  </label>
                  <Textarea
                    value={enhancedResult.enhancedText || ""}
                    rows={15}
                    readOnly
                    className="bg-muted/30 border-2 font-mono text-sm"
                  />
                </div>

                {/* Improvement Suggestions */}
                {enhancedResult.improvements && enhancedResult.improvements.length > 0 && (
                  <div>
                    <label className="text-sm font-semibold text-foreground mb-3 block flex items-center gap-2">
                      <AlertCircle className="h-4 w-4 text-primary" />
                      Key Improvements Made
                    </label>
                    <div className="space-y-3">
                      {enhancedResult.improvements.map((improvement: any, index: number) => (
                        <div 
                          key={index} 
                          className="p-4 bg-muted/30 border border-muted rounded-lg"
                        >
                          <div className="flex items-start gap-3">
                            <div className="w-6 h-6 rounded-full bg-green-100 flex items-center justify-center flex-shrink-0 mt-0.5">
                              <span className="text-green-600 text-sm">✓</span>
                            </div>
                            <div className="flex-1">
                              <div className="flex items-center gap-2 mb-1">
                                <Badge variant="secondary" className="text-xs">
                                  {improvement.type}
                                </Badge>
                              </div>
                              <p className="text-sm font-medium text-foreground mb-1">
                                {improvement.description}
                              </p>
                              {improvement.suggestion && (
                                <p className="text-xs text-muted-foreground">
                                  {improvement.suggestion}
                                </p>
                              )}
                            </div>
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>
            </Card>
          ) : (
            <Card className="p-16 text-center relative overflow-hidden group">
              <div className="absolute inset-0 gradient-mesh opacity-50" />
              <div className="relative z-10">
                <div className="w-20 h-20 rounded-3xl bg-gradient-to-br from-primary/20 to-secondary/20 flex items-center justify-center mx-auto mb-6 group-hover:scale-110 transition-transform duration-300">
                  <Sparkles className="h-10 w-10 text-primary animate-pulse" />
                </div>
                <p className="text-muted-foreground text-lg max-w-sm mx-auto">
                  Paste your proposal and click <span className="font-semibold text-primary">"Enhance Proposal"</span> to see AI-powered improvements
                </p>
              </div>
            </Card>
          )}
        </FadeIn>
      </div>

      {/* AI Improve Modal */}
      {showAIModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="p-5 border-b border-gray-100 bg-gradient-to-r from-cyan-50 to-teal-50">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-cyan-500 to-teal-500 flex items-center justify-center shadow-lg shadow-cyan-500/20">
                  <Zap className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 text-lg">AI Enhance</h3>
                  <p className="text-sm text-gray-500">What should I improve?</p>
                </div>
                <button
                  onClick={handleCloseModal}
                  className="ml-auto p-2 rounded-lg hover:bg-gray-100 text-gray-400 hover:text-gray-600 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Quick fixes */}
            <div className="p-5 space-y-4">
              <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide">Quick fixes</p>
              <div className="grid grid-cols-2 gap-2">
                {QUICK_FIXES.map((fix) => (
                  <button
                    key={fix.id}
                    onClick={() => handleSelectPreset(fix.id)}
                    className={`p-3 rounded-xl text-left text-sm font-medium transition-all ${
                      selectedPreset === fix.id
                        ? 'bg-cyan-100 border-2 border-cyan-400 text-cyan-700'
                        : 'bg-gray-50 border-2 border-gray-200 text-gray-700 hover:bg-gray-100 hover:border-gray-300'
                    }`}
                  >
                    {fix.label}
                  </button>
                ))}
              </div>

              {/* Custom instruction */}
              <div className="pt-2">
                <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Or describe what to fix</p>
                <Textarea
                  value={customInstruction}
                  onChange={(e) => {
                    setCustomInstruction(e.target.value);
                    setSelectedPreset(null);
                  }}
                  placeholder="e.g., Make it shorter and add more urgency..."
                  rows={3}
                  className="resize-none"
                />
              </div>
            </div>

            {/* Footer */}
            <div className="p-5 border-t border-gray-100 flex gap-3">
              <Button
                variant="outline"
                onClick={handleCloseModal}
                className="flex-1"
              >
                Cancel
              </Button>
              <Button
                onClick={handleEnhance}
                disabled={!customInstruction.trim() && !selectedPreset}
                className="flex-1 gradient-primary"
              >
                <Zap className="w-4 h-4 mr-2" />
                Enhance
              </Button>
            </div>
          </div>
        </div>
      )}
    </PageContainer>
  );
}
