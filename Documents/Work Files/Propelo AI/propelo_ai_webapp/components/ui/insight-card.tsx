"use client";

import * as React from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { JobInsight, InsightType, InsightImportance } from "@/types";
import { AlertCircle, CheckCircle2, Info, TrendingUp, AlertTriangle, Lightbulb, LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

interface InsightCardProps {
  insight: JobInsight;
  className?: string;
}

const insightIcons: Record<InsightType, LucideIcon> = {
  pain_point: AlertCircle,
  requirement: CheckCircle2,
  budget: TrendingUp,
  timeline: Info,
  risk: AlertTriangle,
  opportunity: Lightbulb,
};

const insightColors: Record<InsightType, string> = {
  pain_point: "text-red-500",
  requirement: "text-blue-500",
  budget: "text-green-500",
  timeline: "text-purple-500",
  risk: "text-orange-500",
  opportunity: "text-yellow-500",
};

const importanceColors: Record<InsightImportance, string> = {
  high: "border-red-200 bg-red-50",
  medium: "border-yellow-200 bg-yellow-50",
  low: "border-blue-200 bg-blue-50",
};

export function InsightCard({ insight, className }: InsightCardProps) {
  const Icon = insightIcons[insight.type];

  return (
    <Card
      className={cn(
        "p-4 border-l-4",
        importanceColors[insight.importance],
        className
      )}
    >
      <div className="flex items-start gap-3">
        <Icon className={cn("h-5 w-5 mt-0.5", insightColors[insight.type])} />
        <div className="flex-1">
          <div className="flex items-center justify-between mb-1">
            <h4 className="font-semibold text-sm text-[rgb(var(--foreground))]">
              {insight.title}
            </h4>
            <Badge variant="outline" className="text-xs">
              {insight.importance}
            </Badge>
          </div>
          <p className="text-sm text-gray-600">{insight.description}</p>
        </div>
      </div>
    </Card>
  );
}

interface InsightsPanelProps {
  insights: JobInsight[];
  className?: string;
}

export function InsightsPanel({ insights, className }: InsightsPanelProps) {
  if (insights.length === 0) {
    return (
      <Card className={cn("p-6 text-center", className)}>
        <Info className="h-8 w-8 mx-auto mb-2 text-gray-400" />
        <p className="text-sm text-gray-500">No insights available yet</p>
      </Card>
    );
  }

  return (
    <div className={cn("space-y-3", className)}>
      <h3 className="text-lg font-semibold text-[rgb(var(--foreground))]">
        Propelo's Job Insights
      </h3>
      {insights.map((insight) => (
        <InsightCard key={insight.id} insight={insight} />
      ))}
    </div>
  );
}
