"use client";

import * as React from "react";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";
import { SubscriptionPlan } from "@/types";

interface PricingCardProps {
  name: string;
  price: string | number;
  interval: string;
  description?: string;
  features: string[];
  popular?: boolean;
  currentPlan?: boolean;
  ctaText?: string;
  onSelect?: () => void;
  className?: string;
}

export function PricingCard({
  name,
  price,
  interval,
  description,
  features,
  popular,
  currentPlan,
  ctaText = "Get Started",
  onSelect,
  className,
}: PricingCardProps) {
  return (
    <Card
      className={cn(
        "relative p-6 flex flex-col",
        popular && "border-2 border-[rgb(var(--primary))] shadow-lg",
        currentPlan && "ring-2 ring-green-500",
        className
      )}
    >
      {popular && (
        <div className="absolute -top-4 left-1/2 transform -translate-x-1/2">
          <Badge className="bg-[rgb(var(--primary))] text-white">Most Popular</Badge>
        </div>
      )}

      {currentPlan && (
        <div className="absolute -top-4 right-4">
          <Badge className="bg-green-500 text-white">Current Plan</Badge>
        </div>
      )}

      <div className="mb-6">
        <h3 className="text-2xl font-bold text-[rgb(var(--foreground))] mb-2">
          {name}
        </h3>
        {description && (
          <p className="text-sm text-gray-500 mb-4">{description}</p>
        )}
        <div className="flex items-baseline gap-1">
          <span className="text-4xl font-bold text-[rgb(var(--foreground))]">
            ${typeof price === "number" ? price : price}
          </span>
          <span className="text-gray-500">/{interval}</span>
        </div>
      </div>

      <ul className="space-y-3 mb-6 flex-1">
        {features.map((feature, index) => (
          <li key={index} className="flex items-start gap-2">
            <Check className="h-5 w-5 text-[rgb(var(--primary))] flex-shrink-0 mt-0.5" />
            <span className="text-sm text-gray-600">{feature}</span>
          </li>
        ))}
      </ul>

      <Button
        onClick={onSelect}
        className={cn(
          "w-full",
          popular && "bg-[rgb(var(--primary))] hover:bg-[rgb(var(--secondary))]",
          currentPlan && "opacity-50 cursor-not-allowed"
        )}
        disabled={currentPlan}
        variant={popular ? "default" : "outline"}
      >
        {currentPlan ? "Current Plan" : ctaText}
      </Button>
    </Card>
  );
}
