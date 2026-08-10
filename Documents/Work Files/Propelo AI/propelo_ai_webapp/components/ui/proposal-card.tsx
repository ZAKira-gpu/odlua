"use client";

import * as React from "react";
import { Card } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Proposal } from "@/types";
import { StatusBadge } from "@/components/ui/status-badge";
import { formatRelativeTime } from "@/lib/utils";
import { Eye, Clock, MousePointerClick, MoreVertical, Copy, Trash2, ExternalLink, Share2 } from "lucide-react";
import toast from "react-hot-toast";
import { cn } from "@/lib/utils";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface ProposalCardProps {
  proposal: Proposal;
  onView?: (proposal: Proposal) => void;
  onDelete?: (proposal: Proposal) => void;
  onDuplicate?: (proposal: Proposal) => void;
  selected?: boolean;
  className?: string;
}

export function ProposalCard({
  proposal,
  onView,
  onDelete,
  onDuplicate,
  selected,
  className,
}: ProposalCardProps) {
  const handleShare = async (e: React.MouseEvent) => {
    e.stopPropagation();
    const shareUrl = `${window.location.origin}/proposals/${proposal.id}`;
    
    try {
      await navigator.clipboard.writeText(shareUrl);
      toast.success("Share link copied to clipboard!");
    } catch (error) {
      toast.error("Failed to copy link");
    }
  };

  return (
    <Card
      className={cn(
        "p-4 cursor-pointer transition-all hover:shadow-md",
        selected && "ring-2 ring-[rgb(var(--primary))] shadow-lg",
        className
      )}
      onClick={() => onView?.(proposal)}
    >
      <div className="flex items-start justify-between mb-3">
        <div className="flex-1">
          <h3 className="font-semibold text-[rgb(var(--foreground))] mb-1 line-clamp-1">
            {proposal.title}
          </h3>
          <div className="flex items-center gap-2 text-sm text-gray-500">
            <Badge variant="outline" className="text-xs">
              {proposal.platform}
            </Badge>
            <span>•</span>
            <span>{formatRelativeTime(proposal.createdAt)}</span>
          </div>
        </div>
        <div className="flex items-center gap-2">
          <StatusBadge status={proposal.status} />
          <DropdownMenu>
            <DropdownMenuTrigger asChild onClick={(e) => e.stopPropagation()}>
              <Button variant="ghost" size="sm" className="h-8 w-8 p-0">
                <MoreVertical className="h-4 w-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              <DropdownMenuItem onClick={(e) => {
                e.stopPropagation();
                onView?.(proposal);
              }}>
                <ExternalLink className="mr-2 h-4 w-4" />
                View
              </DropdownMenuItem>
              <DropdownMenuItem onClick={handleShare}>
                <Share2 className="mr-2 h-4 w-4" />
                Share
              </DropdownMenuItem>
              <DropdownMenuItem onClick={(e) => {
                e.stopPropagation();
                onDuplicate?.(proposal);
              }}>
                <Copy className="mr-2 h-4 w-4" />
                Duplicate
              </DropdownMenuItem>
              <DropdownMenuItem
                onClick={(e) => {
                  e.stopPropagation();
                  onDelete?.(proposal);
                }}
                className="text-red-600"
              >
                <Trash2 className="mr-2 h-4 w-4" />
                Delete
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </div>

      <p className="text-sm text-gray-600 line-clamp-2 mb-3">
        {proposal.jobDescription}
      </p>

      {proposal.clientName && (
        <div className="mb-3">
          <span className="text-sm font-medium text-gray-700">Client: </span>
          <span className="text-sm text-gray-600">{proposal.clientName}</span>
        </div>
      )}

      <div className="flex items-center gap-4 text-sm text-gray-500 pt-3 border-t">
        <div className="flex items-center gap-1">
          <Eye className="h-4 w-4" />
          <span>{proposal.openCount}</span>
        </div>
        <div className="flex items-center gap-1">
          <MousePointerClick className="h-4 w-4" />
          <span>{proposal.linkClicks}</span>
        </div>
        {proposal.timeSpent && (
          <div className="flex items-center gap-1">
            <Clock className="h-4 w-4" />
            <span>{Math.floor(proposal.timeSpent / 60)}m</span>
          </div>
        )}
      </div>
    </Card>
  );
}
