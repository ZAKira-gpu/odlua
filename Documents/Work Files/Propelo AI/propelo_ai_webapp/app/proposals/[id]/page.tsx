"use client";

import * as React from "react";
import { useParams } from "next/navigation";
import { Card } from "@/components/ui/card";
import { Spinner } from "@/components/ui/spinner";
import { Badge } from "@/components/ui/badge";
import { Eye, Clock } from "lucide-react";

export default function PublicProposalPage() {
  const params = useParams();
  const proposalId = params.id as string;
  
  const [proposal, setProposal] = React.useState<any>(null);
  const [loading, setLoading] = React.useState(true);
  const [viewTracked, setViewTracked] = React.useState(false);
  const startTime = React.useRef(Date.now());

  // Track view event
  React.useEffect(() => {
    if (proposalId && !viewTracked) {
      const trackView = async () => {
        try {
          await fetch("/api/analytics", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              proposalId,
              eventType: "view",
              metadata: {
                timestamp: new Date().toISOString(),
                userAgent: navigator.userAgent,
              },
            }),
          });
          setViewTracked(true);
        } catch (error) {
          console.error("Failed to track view:", error);
        }
      };

      trackView();
    }
  }, [proposalId, viewTracked]);

  // Track time spent on page
  React.useEffect(() => {
    const trackTimeSpent = async () => {
      const timeSpent = Math.floor((Date.now() - startTime.current) / 1000);
      
      try {
        await fetch("/api/analytics", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            proposalId,
            eventType: "time_spent",
            metadata: { timeSpent },
          }),
        });
      } catch (error) {
        console.error("Failed to track time:", error);
      }
    };

    // Track time spent every 30 seconds
    const interval = setInterval(trackTimeSpent, 30000);

    // Track on page unload
    const handleBeforeUnload = () => {
      trackTimeSpent();
    };

    window.addEventListener("beforeunload", handleBeforeUnload);

    return () => {
      clearInterval(interval);
      window.removeEventListener("beforeunload", handleBeforeUnload);
      trackTimeSpent();
    };
  }, [proposalId]);

  // Fetch proposal data
  React.useEffect(() => {
    const fetchProposal = async () => {
      try {
        const response = await fetch(`/api/proposals?id=${proposalId}`);
        const result = await response.json();

        if (!response.ok) {
          throw new Error(result.error || "Failed to fetch proposal");
        }

        setProposal(result.data);
      } catch (error: any) {
        console.error("Error fetching proposal:", error);
      } finally {
        setLoading(false);
      }
    };

    if (proposalId) {
      fetchProposal();
    }
  }, [proposalId]);

  // Track link clicks
  const handleLinkClick = async (link: string) => {
    try {
      await fetch("/api/analytics", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          proposalId,
          eventType: "click",
          metadata: { link },
        }),
      });
    } catch (error) {
      console.error("Failed to track click:", error);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-gray-50 to-white">
        <Spinner className="h-8 w-8" />
      </div>
    );
  }

  if (!proposal) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gradient-to-b from-gray-50 to-white">
        <Card className="p-8 max-w-md">
          <h1 className="text-2xl font-bold text-center mb-4">Proposal Not Found</h1>
          <p className="text-muted-foreground text-center">
            This proposal may have been deleted or the link is incorrect.
          </p>
        </Card>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white py-12 px-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="mb-8 text-center">
          <Badge className="mb-4" variant="secondary">
            <Eye className="h-3 w-3 mr-1" />
            Proposal View
          </Badge>
          <h1 className="text-4xl font-bold text-gray-900 mb-2">
            {proposal.title}
          </h1>
          <div className="flex items-center justify-center gap-4 text-sm text-gray-600">
            <span className="flex items-center">
              <Clock className="h-4 w-4 mr-1" />
              {new Date(proposal.createdAt?.seconds * 1000 || proposal.createdAt).toLocaleDateString()}
            </span>
            <span>•</span>
            <span className="capitalize">{proposal.platform}</span>
            <span>•</span>
            <span className="capitalize">{proposal.tone} tone</span>
          </div>
        </div>

        {/* Proposal Content */}
        <Card className="p-8 prose prose-lg max-w-none">
          <div className="whitespace-pre-wrap text-gray-800 leading-relaxed">
            {proposal.content}
          </div>
        </Card>

        {/* Job Insights (if available) */}
        {proposal.insights && proposal.insights.length > 0 && (
          <Card className="mt-8 p-6">
            <h3 className="text-lg font-semibold mb-4">Key Insights</h3>
            <div className="space-y-3">
              {proposal.insights.map((insight: any, index: number) => (
                <div key={index} className="flex items-start gap-3 p-3 bg-blue-50 rounded-lg">
                  <Badge variant="secondary" className="mt-0.5">
                    {insight.importance}
                  </Badge>
                  <div>
                    <p className="font-medium text-sm">{insight.title}</p>
                    <p className="text-sm text-gray-600">{insight.description}</p>
                  </div>
                </div>
              ))}
            </div>
          </Card>
        )}

        {/* Footer */}
        <div className="mt-12 text-center text-sm text-gray-500">
          <p>
            Powered by{" "}
            <a
              href="/"
              onClick={() => handleLinkClick("/")}
              className="text-primary hover:underline font-medium"
            >
              Propelo AI
            </a>
          </p>
          <p className="mt-2">
            Generate winning proposals in seconds with AI
          </p>
        </div>
      </div>
    </div>
  );
}
