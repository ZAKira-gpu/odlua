"use client";

import * as React from "react";
import { Card } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { AlertCircle, Zap, CheckCircle2 } from "lucide-react";
import { cn } from "@/lib/utils";

interface UsageTrackerProps {
  used: number;
  limit: number;
  label: string;
  upgradeLink?: string;
  className?: string;
}

export function UsageTracker({
  used,
  limit,
  label,
  upgradeLink,
  className,
}: UsageTrackerProps) {
  const percentage = Math.min((used / limit) * 100, 100);
  const isNearLimit = percentage >= 80;
  const isAtLimit = used >= limit;

  return (
    <Card className={cn("p-4 border shadow-sm", className)}>
      <div className="space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <h4 className="font-semibold text-sm text-foreground">
              {label}
            </h4>
            {isNearLimit && !isAtLimit && (
              <Badge variant="warning" className="text-[10px] px-1.5 h-5 font-bold shadow-none">
                Low
              </Badge>
            )}
             {isAtLimit && (
              <Badge variant="destructive" className="text-[10px] px-1.5 h-5 font-bold shadow-none">
                Limit
              </Badge>
            )}
          </div>
          <span className="text-xs font-mono font-medium text-muted-foreground bg-muted/50 px-2 py-0.5 rounded-md border border-border/50">
            {used} / {limit}
          </span>
        </div>

        <Progress
          value={percentage}
          className={cn(
            "h-2 bg-secondary",
          )}
          indicatorClassName={cn(
            isAtLimit ? "bg-destructive" : isNearLimit ? "bg-amber-500" : "bg-primary"
          )}
        />

        {isAtLimit ? (
          <div className="flex items-start gap-3 p-3 rounded-xl bg-destructive/10 border border-destructive/20 transition-all animate-fade-in">
            <AlertCircle className="h-4 w-4 text-destructive flex-shrink-0 mt-0.5" />
            <div className="flex-1">
              <p className="text-xs font-medium text-destructive mb-3 leading-relaxed">
                You have reached your {label.toLowerCase()} limit for this billing cycle.
              </p>
              {upgradeLink && (
                <Button size="sm" className="h-8 text-xs w-full bg-destructive text-destructive-foreground hover:bg-destructive/90 shadow-sm border-0" asChild>
                  <a href={upgradeLink}>
                    <Zap className="h-3 w-3 mr-1.5 fill-current" />
                    Upgrade Plan
                  </a>
                </Button>
              )}
            </div>
          </div>
        ) : isNearLimit && (
          <div className="flex items-center justify-between p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-900/50 animate-fade-in">
            <p className="text-xs font-medium text-amber-700 dark:text-amber-400">
              <span className="font-bold">{limit - used}</span> remaining
            </p>
            {upgradeLink && (
              <Button size="sm" variant="ghost" className="h-6 px-2 text-xs text-amber-700 hover:text-amber-800 hover:bg-amber-100 dark:text-amber-400 dark:hover:bg-amber-900/40" asChild>
                <a href={upgradeLink}>Upgrade</a>
              </Button>
            )}
          </div>
        )}
      </div>
    </Card>
  );
}
