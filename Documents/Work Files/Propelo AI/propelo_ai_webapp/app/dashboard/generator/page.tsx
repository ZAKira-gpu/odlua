"use client";

import * as React from "react";
import { PageContainer, PageHeader, Section } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Form, FormField } from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Button } from "@/components/ui/button";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { InsightsPanel } from "@/components/ui/insight-card";
import { Spinner } from "@/components/ui/spinner";
import { Alert } from "@/components/ui/alert";
import { Sparkles, Copy, Download, AlertCircle, Save, Pencil, Zap } from "lucide-react";
import { FadeIn } from "@/components/ui/animations";
import { PLATFORMS, TONES, CLIENT_TYPES } from "@/config/constants";
import type { JobInsight } from "@/types";
import { useAuth } from "@/lib/auth-context";
import { UsageTracker } from "@/components/ui/usage-tracker";
import toast from "react-hot-toast";
import { X } from "lucide-react";

// Quick fix presets
const QUICK_FIXES = [
  { id: "hook", label: "Better hook", instruction: "Add a stronger opening hook that grabs attention and shows I understand their pain" },
  { id: "human", label: "More human", instruction: "Make it sound more conversational and human, less corporate and robotic" },
  { id: "shorter", label: "Make shorter", instruction: "Make it more concise and scannable, remove fluff and filler words" },
  { id: "cta", label: "Stronger CTA", instruction: "Improve the call-to-action to be more compelling and low-friction" },
  { id: "proof", label: "Add proof", instruction: "Add more specific examples, numbers, or social proof to build credibility" },
  { id: "mvp", label: "MVP framing", instruction: "Frame the approach as MVP-first with quick wins before scaling" },
];

const LANGUAGES = [
  { value: "en", label: "English" },
  { value: "es", label: "Spanish" },
  { value: "fr", label: "French" },
  { value: "de", label: "German" },
  { value: "it", label: "Italian" },
  { value: "pt", label: "Portuguese" },
  { value: "ar", label: "Arabic" },
  { value: "zh", label: "Chinese" },
];

const SECTION_OPTIONS = [
  "introduction",
  "scope",
  "timeline",
  "deliverables",
  "pricing",
  "experience",
  "faq",
  "guarantee",
  "cta",
  "terms"
];

export default function GeneratorPage() {
  const { user, refreshUser, firebaseUser } = useAuth();
  const [isGenerating, setIsGenerating] = React.useState(false);
  const [isImproving, setIsImproving] = React.useState(false);
  const [isEditing, setIsEditing] = React.useState(false);
  const [editedContent, setEditedContent] = React.useState("");
  const [generatedProposal, setGeneratedProposal] = React.useState<any>(null);
  const [jobInsights, setJobInsights] = React.useState<JobInsight[]>([]);
  // AI Improve modal state
  const [showAIModal, setShowAIModal] = React.useState(false);
  const [selectedPreset, setSelectedPreset] = React.useState<string | null>(null);
  const [improveInstruction, setImproveInstruction] = React.useState("");
  // Streaming state
  const [streamingText, setStreamingText] = React.useState("");
  const [generationProgress, setGenerationProgress] = React.useState(0);

  const [formData, setFormData] = React.useState({
    jobTitle: "",
    jobDescription: "",
    platform: "upwork",
    tone: TONES[0] as string,
    clientName: "",
    budget: "",
    deadline: "",
    selectedSections: SECTION_OPTIONS,
    customInstructions: "",
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!formData.jobDescription.trim()) {
      toast.error("Please enter a job description");
      return;
    }

    if (!formData.jobTitle.trim()) {
      toast.error("Please enter a job title");
      return;
    }

    // Client-side validation to avoid Zod rejections and give better UX
    const errors: string[] = [];
    if (!formData.jobTitle || formData.jobTitle.trim().length < 3) {
      errors.push("Job title must be at least 3 characters");
    }
    if (!formData.jobDescription || formData.jobDescription.trim().length < 50) {
      errors.push("Job description must be at least 50 characters");
    }
    const toneValues = TONES.map((t) => String(t));
    if (!toneValues.includes(String(formData.tone))) {
      errors.push("Please select a valid tone");
    }
    const platformValues = PLATFORMS.map((p) => String(p.value));
    if (!platformValues.includes(String(formData.platform))) {
      errors.push("Please select a valid platform");
    }
    if (!formData.selectedSections || formData.selectedSections.length < 1) {
      errors.push("Select at least one section");
    }

    if (errors.length > 0) {
      errors.forEach((err) => toast.error(err));
      return;
    }

    // Check usage limits
    if (user && user.proposalsUsed >= user.proposalsLimit) {
      toast.error(`You've reached your limit of ${user.proposalsLimit} proposals. Upgrade to continue.`);
      return;
    }

    setIsGenerating(true);
    setStreamingText("");
    setGenerationProgress(0);
    
      try {
        // Get latest ID token (fallback) to send with request in Authorization header
        const idToken = await firebaseUser?.getIdToken();
      // Call streaming API to generate proposal
      const headers: Record<string, string> = { "Content-Type": "application/json" };
      if (idToken) {
        headers["Authorization"] = `Bearer ${idToken}`;
      }

      const response = await fetch("/api/proposals/generate-stream", {
        method: "POST",
        headers,
        credentials: "same-origin",
        body: JSON.stringify({ ...formData, _idToken: idToken }),
      });

      if (!response.ok) {
        const result = await response.json();
        if (result?.details && Array.isArray(result.details)) {
          result.details.forEach((d: any) => {
            const msg = d?.message || JSON.stringify(d);
            toast.error(msg);
          });
          return;
        }
        throw new Error(result.error || "Failed to generate proposal");
      }

      // Handle streaming response
      const reader = response.body?.getReader();
      const decoder = new TextDecoder();
      let fullContent = "";
      const estimatedTotal = 1500;

      if (reader) {
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const chunk = decoder.decode(value, { stream: true });
          const lines = chunk.split("\n");

          for (const line of lines) {
            if (line.startsWith("data: ")) {
              try {
                const data = JSON.parse(line.slice(6));
                if (data.error) {
                  throw new Error(data.error);
                }
                if (data.content) {
                  fullContent += data.content;
                  setStreamingText(fullContent);
                  setGenerationProgress(Math.min(95, (fullContent.length / estimatedTotal) * 100));
                }
                if (data.done && data.fullContent) {
                  fullContent = data.fullContent;
                }
              } catch {
                // Ignore parse errors for incomplete chunks
              }
            }
          }
        }
      }

      setGenerationProgress(100);
      setGeneratedProposal({ content: fullContent, title: formData.jobTitle });
      setStreamingText("");
      
      // Refresh user data to update usage
      await refreshUser();
      
      toast.success("Proposal generated successfully! 🎉");
    } catch (error: any) {
      console.error("Error:", error);
      toast.error(error.message || "Failed to generate proposal. Please try again.");
    } finally {
      setIsGenerating(false);
    }
  };

  const handleCopy = () => {
    if (generatedProposal?.content) {
      navigator.clipboard.writeText(generatedProposal.content);
      toast.success("Proposal copied to clipboard!");
    }
  };

  const handleDownload = () => {
    if (generatedProposal?.content) {
      const blob = new Blob([generatedProposal.content], { type: "text/plain" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `proposal-${Date.now()}.txt`;
      a.click();
      URL.revokeObjectURL(url);
      toast.success("Proposal downloaded successfully!");
    }
  };

  const handleEdit = () => {
    setIsEditing(true);
    setEditedContent(generatedProposal?.content || "");
  };

  const handleSaveEdit = () => {
    setGeneratedProposal({ ...generatedProposal, content: editedContent });
    setIsEditing(false);
    toast.success("Changes saved!");
  };

  const handleCancelEdit = () => {
    setIsEditing(false);
    setEditedContent(generatedProposal?.content || "");
  };

  // Open AI improve modal
  const handleImprove = () => {
    if (!generatedProposal?.content) return;
    setShowAIModal(true);
  };

  const handleCloseModal = () => {
    setShowAIModal(false);
    setSelectedPreset(null);
    setImproveInstruction("");
  };

  const handleSelectPreset = (presetId: string) => {
    setSelectedPreset(presetId);
    const preset = QUICK_FIXES.find(f => f.id === presetId);
    if (preset) {
      setImproveInstruction(preset.instruction);
    }
  };

  // Execute AI improvement with instructions
  const handleDoImprove = async () => {
    const instructions = improveInstruction.trim();
    if (!instructions && !selectedPreset) {
      toast.error("Please select a fix or describe what to improve");
      return;
    }

    handleCloseModal();
    setIsImproving(true);
    
    try {
      const idToken = await firebaseUser?.getIdToken();
      if (!idToken) {
        toast.error("Please sign in to improve proposals");
        return;
      }

      const response = await fetch("/api/proposals/enhance", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${idToken}`,
        },
        body: JSON.stringify({ 
          proposal: isEditing ? editedContent : generatedProposal.content,
          instructions: instructions,
        }),
      });

      if (!response.ok) {
        const data = await response.json();
        throw new Error(data.error || "Failed to improve proposal");
      }

      const data = await response.json();
      const improvedContent = data.enhancedText || data.data?.enhancedText;
      
      if (improvedContent) {
        setGeneratedProposal({ ...generatedProposal, content: improvedContent });
        setEditedContent(improvedContent);
        toast.success("Proposal improved with AI!");
      }
    } catch (error: any) {
      toast.error(error.message || "Failed to improve proposal");
    } finally {
      setIsImproving(false);
    }
  };

  return (
    <PageContainer>
      {/* Background Effects */}
      <div className="fixed inset-0 -z-10 gradient-mesh pointer-events-none" />
      <div className="fixed top-1/4 left-1/4 w-96 h-96 bg-cyan-500/5 rounded-full blur-3xl floating pointer-events-none" />
      <div className="fixed bottom-1/4 right-1/4 w-96 h-96 bg-teal-500/5 rounded-full blur-3xl floating-delayed pointer-events-none" />
      
      <FadeIn>
        <PageHeader
          title="Proposal Generator"
          description="Generate winning proposals with AI in seconds"
          breadcrumbs={
            <Breadcrumbs
              items={[
                { label: "Dashboard", href: "/dashboard" },
                { label: "Generator" },
              ]}
            />
          }
        />
      </FadeIn>

      <div className="grid lg:grid-cols-2 gap-8">
        {/* Input Form */}
        <FadeIn delay={0.1}>
          <Card className="p-8">
            <div className="flex items-center gap-3 mb-6">
              <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-primary to-secondary flex items-center justify-center">
                <Sparkles className="h-5 w-5 text-white" />
              </div>
              <div>
                <h2 className="text-xl font-bold text-foreground">AI Proposal Assistant</h2>
                <p className="text-sm text-muted-foreground">Fill in the details below</p>
              </div>
            </div>
            
            <Form onSubmit={handleSubmit}>
              <FormField
                label="Job Title"
                required
                hint="The title of the freelance gig"
              >
                <Input
                  placeholder="e.g., Full-Stack Developer for SaaS Project"
                  value={formData.jobTitle}
                  onChange={(e) =>
                    setFormData({ ...formData, jobTitle: e.target.value })
                  }
                  className="border-2 focus:border-primary/50 transition-colors"
                />
              </FormField>

              <FormField
                label="Job Description"
                required
                hint="Paste the complete job posting here"
              >
                <Textarea
                  placeholder="Paste the job description from Upwork, Fiverr, or any platform..."
                  rows={6}
                  value={formData.jobDescription}
                  onChange={(e) =>
                    setFormData({ ...formData, jobDescription: e.target.value })
                  }
                  className="border-2 focus:border-primary/50 transition-colors"
                />
              </FormField>

              <div className="grid md:grid-cols-2 gap-4">
                <FormField label="Platform" required>
                  <Select
                    value={formData.platform}
                    onValueChange={(value) =>
                      setFormData({ ...formData, platform: value })
                    }
                  >
                    <SelectTrigger className="border-2">
                      <SelectValue placeholder="Select platform" />
                    </SelectTrigger>
                    <SelectContent>
                      {PLATFORMS.map((platform) => (
                        <SelectItem key={platform.value} value={platform.value}>
                          {platform.label}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </FormField>

                <FormField label="Tone" required>
                  <Select
                    value={formData.tone}
                    onValueChange={(value) =>
                      setFormData({ ...formData, tone: value })
                    }
                  >
                    <SelectTrigger className="border-2">
                      <SelectValue placeholder="Select tone" />
                    </SelectTrigger>
                    <SelectContent>
                      {TONES.map((tone) => (
                        <SelectItem key={tone} value={tone}>
                          {tone}
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </FormField>
              </div>

              <div className="grid md:grid-cols-3 gap-4">
                <FormField label="Client Name (Optional)">
                  <Input
                    placeholder="John Doe"
                    value={formData.clientName}
                    onChange={(e) =>
                      setFormData({ ...formData, clientName: e.target.value })
                    }
                    className="border-2"
                  />
                </FormField>

                <FormField label="Budget (Optional)">
                  <Input
                    placeholder="$500-$1000"
                    value={formData.budget}
                    onChange={(e) =>
                      setFormData({ ...formData, budget: e.target.value })
                    }
                    className="border-2"
                  />
                </FormField>

                <FormField label="Deadline (Optional)">
                  <Input
                    placeholder="2 weeks"
                    value={formData.deadline}
                    onChange={(e) =>
                      setFormData({ ...formData, deadline: e.target.value })
                    }
                    className="border-2"
                  />
                </FormField>
              </div>

              <FormField
                label="Custom Instructions (Optional)"
                hint="Any specific requirements or details you want to highlight"
              >
                <Textarea
                  placeholder="e.g., Mention specific tools, experience, or unique selling points..."
                  rows={3}
                  value={formData.customInstructions}
                  onChange={(e) =>
                    setFormData({ ...formData, customInstructions: e.target.value })
                  }
                  className="border-2 focus:border-primary/50 transition-colors"
                />
              </FormField>

              {/* Usage Tracker */}
              {user && (
                <UsageTracker
                  used={user.proposalsUsed}
                  limit={user.proposalsLimit}
                  label="Proposals Generated"
                  upgradeLink="/dashboard/settings"
                />
              )}

              <Button
                type="submit"
                size="lg"
                className="w-full gradient-primary relative overflow-hidden group"
                disabled={isGenerating || (user !== null && user.proposalsUsed >= user.proposalsLimit)}
              >
                <span className="absolute inset-0 shimmer opacity-0 group-hover:opacity-100" />
                {isGenerating ? (
                  <>
                    <Spinner className="mr-2" />
                    <span className="relative z-10">{streamingText ? "Writing proposal..." : "Connecting to AI..."}</span>
                  </>
                ) : (
                  <>
                    <Sparkles className="h-5 w-5 mr-2 relative z-10 group-hover:rotate-180 transition-transform duration-500" />
                    <span className="relative z-10">Generate Proposal</span>
                  </>
                )}
              </Button>

              {/* Live streaming preview */}
              {isGenerating && streamingText && (
                <div className="mt-4 p-4 bg-muted/50 rounded-lg border border-border">
                  <div className="flex items-center gap-2 mb-3">
                    <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                    <span className="text-sm font-medium text-muted-foreground">AI is writing your proposal...</span>
                    <span className="ml-auto text-xs text-muted-foreground">{streamingText.length} chars</span>
                  </div>
                  <div className="w-full h-1.5 bg-muted rounded-full overflow-hidden mb-3">
                    <div 
                      className="h-full bg-gradient-to-r from-primary to-primary/70 transition-all duration-300"
                      style={{ width: `${generationProgress}%` }}
                    />
                  </div>
                  <div className="max-h-48 overflow-y-auto text-sm text-foreground leading-relaxed whitespace-pre-wrap font-mono">
                    {streamingText}
                    <span className="inline-block w-0.5 h-4 bg-primary animate-pulse ml-0.5 align-middle" />
                  </div>
                </div>
              )}
            </Form>
          </Card>
        </FadeIn>

        {/* Output */}
        <FadeIn delay={0.2}>
          <div className="space-y-6">
            {/* Job Insights */}
            {jobInsights.length > 0 && (
              <Card className="p-6">
                <h3 className="text-lg font-semibold mb-4 text-foreground flex items-center gap-2">
                  <div className="w-2 h-2 bg-primary rounded-full animate-pulse-glow" />
                  Job Insights
                </h3>
                <InsightsPanel insights={jobInsights} />
              </Card>
            )}

            {/* Generated Proposal */}
            {generatedProposal ? (
              <Card className="p-8">
                <div className="flex items-center justify-between mb-6">
                  <h3 className="text-lg font-semibold text-foreground flex items-center gap-2">
                    <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                    Generated Proposal
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
                      onClick={handleEdit}
                      disabled={isEditing}
                      className="hover:bg-blue-50 hover:text-blue-600 hover:border-blue-300"
                    >
                      <Pencil className="h-4 w-4 mr-2" />
                      Edit
                    </Button>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={handleImprove}
                      disabled={isImproving}
                      className="hover:bg-purple-50 hover:text-purple-600 hover:border-purple-300"
                    >
                      {isImproving ? (
                        <>
                          <Spinner className="h-4 w-4 mr-2" />
                          Improving...
                        </>
                      ) : (
                        <>
                          <Zap className="h-4 w-4 mr-2" />
                          AI Fix
                        </>
                      )}
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

                <div className="space-y-6">
                  {/* Title */}
                  <div>
                    <label className="text-sm font-semibold text-foreground mb-2 block">
                      Title
                    </label>
                    <Input
                      value={generatedProposal.title || ""}
                      readOnly
                      className="bg-muted/30 border-2"
                    />
                  </div>

                  {/* Proposal Content */}
                  <div>
                    <label className="text-sm font-semibold text-foreground mb-2 block flex items-center justify-between">
                      <span>Proposal</span>
                      {isEditing && (
                        <span className="text-xs text-blue-500 font-normal">Editing mode</span>
                      )}
                    </label>
                    <Textarea
                      value={isEditing ? editedContent : (generatedProposal.content || "")}
                      onChange={(e) => isEditing && setEditedContent(e.target.value)}
                      rows={12}
                      readOnly={!isEditing}
                      className={`border-2 font-mono text-sm ${isEditing ? 'bg-white border-blue-300 focus:border-blue-500' : 'bg-muted/30'}`}
                    />
                    {isEditing && (
                      <div className="flex gap-2 mt-3">
                        <Button
                          size="sm"
                          onClick={handleSaveEdit}
                          className="bg-green-500 hover:bg-green-600 text-white"
                        >
                          <Save className="h-4 w-4 mr-2" />
                          Save Changes
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={handleCancelEdit}
                        >
                          Cancel
                        </Button>
                      </div>
                    )}
                  </div>

                  {/* Metadata */}
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="text-sm font-semibold text-foreground mb-2 block">
                        Suggested Price
                      </label>
                      <Input
                        value={generatedProposal.suggestedPrice || "TBD"}
                        readOnly
                        className="bg-muted/30 border-2"
                      />
                    </div>
                    <div>
                      <label className="text-sm font-semibold text-foreground mb-2 block">
                        Timeframe
                      </label>
                      <Input
                        value={generatedProposal.suggestedTimeframe || "TBD"}
                        readOnly
                        className="bg-muted/30 border-2"
                      />
                    </div>
                  </div>

                  {/* Confidence Rating */}
                  {generatedProposal.confidenceRating && (
                    <div>
                      <label className="text-sm font-semibold text-foreground mb-2 block">
                        Confidence Rating
                      </label>
                      <Badge variant="secondary" className="text-sm px-4 py-2">
                        {generatedProposal.confidenceRating}
                      </Badge>
                    </div>
                  )}

                  {/* Pain Point Advice */}
                  {generatedProposal.painPoint && (
                    <Alert className="border-2 border-primary/20 bg-primary/5">
                      <AlertCircle className="h-4 w-4 text-primary" />
                      <div className="ml-2">
                        <p className="font-semibold text-foreground">Pain Point Detected:</p>
                        <p className="text-sm text-muted-foreground mt-1">
                          {generatedProposal.painPoint}
                        </p>
                      </div>
                    </Alert>
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
                    Fill out the form and click <span className="font-semibold text-primary">"Generate Proposal"</span> to see your AI-generated proposal here
                  </p>
                </div>
              </Card>
            )}
          </div>
        </FadeIn>
      </div>

      {/* AI Improve Modal */}
      {showAIModal && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md overflow-hidden animate-in zoom-in-95 duration-200">
            {/* Header */}
            <div className="p-5 border-b border-gray-100 bg-gradient-to-r from-purple-50 to-indigo-50">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-indigo-500 flex items-center justify-center shadow-lg shadow-purple-500/20">
                  <Zap className="w-6 h-6 text-white" />
                </div>
                <div>
                  <h3 className="font-semibold text-gray-900 text-lg">AI Fix</h3>
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
                        ? 'bg-purple-100 border-2 border-purple-400 text-purple-700'
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
                  value={improveInstruction}
                  onChange={(e) => {
                    setImproveInstruction(e.target.value);
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
                onClick={handleDoImprove}
                disabled={!improveInstruction.trim() && !selectedPreset}
                className="flex-1 bg-gradient-to-r from-purple-500 to-indigo-500 hover:from-purple-600 hover:to-indigo-600 text-white"
              >
                <Zap className="w-4 h-4 mr-2" />
                Improve
              </Button>
            </div>
          </div>
        </div>
      )}
    </PageContainer>
  );
}
