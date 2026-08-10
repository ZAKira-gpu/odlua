"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

export interface EmptyStateProps {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({
  icon,
  title,
  description,
  action,
  className,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center py-20 px-4 text-center relative overflow-hidden",
        className
      )}
    >
      {/* Gradient Background */}
      <div className="absolute inset-0 gradient-mesh opacity-50" />
      <div className="absolute top-1/4 left-1/4 w-64 h-64 bg-cyan-500/10 rounded-full blur-3xl floating" />
      <div className="absolute bottom-1/4 right-1/4 w-64 h-64 bg-teal-500/10 rounded-full blur-3xl floating-delayed" />
      
      <div className="relative z-10">
        {icon && (
          <div className="mb-6 rounded-3xl bg-gradient-to-br from-primary/10 to-secondary/10 p-6 text-primary inline-block animate-floating">
            {icon}
          </div>
        )}
        <h3 className="mb-3 text-2xl font-bold text-foreground">
          {title}
        </h3>
        {description && (
          <p className="mb-8 max-w-md text-base text-muted-foreground">{description}</p>
        )}
        {action && <div>{action}</div>}
      </div>
    </div>
  );
}
