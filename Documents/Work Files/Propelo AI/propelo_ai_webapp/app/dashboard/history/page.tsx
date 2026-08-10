"use client";

import * as React from "react";
import { PageContainer, PageHeader } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ProposalCard } from "@/components/ui/proposal-card";
import { EmptyState } from "@/components/ui/empty-state";
import { Spinner } from "@/components/ui/spinner";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Search, Filter, FileText, RefreshCw } from "lucide-react";
import { FadeIn } from "@/components/ui/animations";
import type { Proposal } from "@/types";
import { useAuth } from "@/lib/auth-context";
import toast from "react-hot-toast";
import Link from "next/link";

export default function HistoryPage() {
  const { user } = useAuth();
  const [proposals, setProposals] = React.useState<Proposal[]>([]);
  const [isLoading, setIsLoading] = React.useState(true);
  const [searchQuery, setSearchQuery] = React.useState("");
  const [statusFilter, setStatusFilter] = React.useState<string>("all");
  const [platformFilter, setPlatformFilter] = React.useState<string>("all");

  const fetchProposals = React.useCallback(async () => {
    if (!user) return;
    setIsLoading(true);
    try {
      const params = new URLSearchParams();
      if (statusFilter !== "all") params.append("status", statusFilter);
      if (platformFilter !== "all") params.append("platform", platformFilter);
      const response = await fetch(`/api/proposals?${params.toString()}`);
      const result = await response.json();
      if (!response.ok) throw new Error(result.error || "Failed to fetch proposals");
      setProposals(result.data || []);
    } catch (error: any) {
      console.error("Error fetching proposals:", error);
      toast.error(error.message || "Failed to load proposals");
    } finally {
      setIsLoading(false);
    }
  }, [user, statusFilter, platformFilter]);

  React.useEffect(() => {
    fetchProposals();
  }, [fetchProposals]);

  const filteredProposals = React.useMemo(() => {
    if (!searchQuery.trim()) return proposals;
    const query = searchQuery.toLowerCase();
    return proposals.filter((proposal) =>
      proposal.title?.toLowerCase().includes(query) ||
      proposal.clientName?.toLowerCase().includes(query) ||
      proposal.jobDescription?.toLowerCase().includes(query)
    );
  }, [proposals, searchQuery]);

  return (
    <PageContainer>
      <div className="fixed inset-0 -z-10 gradient-mesh pointer-events-none" />
      <FadeIn>
        <PageHeader
          title="Proposal History"
          description="View and manage all your generated proposals"
          breadcrumbs={<Breadcrumbs items={[{ label: "Dashboard", href: "/dashboard" }, { label: "History" }]} />}
          actions={
            <Button onClick={fetchProposals} variant="outline" disabled={isLoading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${isLoading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          }
        />
      </FadeIn>
      <FadeIn delay={0.1}>
        <div className="flex flex-col sm:flex-row gap-4 mb-8">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-4 w-4 text-muted-foreground" />
            <Input placeholder="Search proposals..." value={searchQuery} onChange={(e) => setSearchQuery(e.target.value)} className="pl-10 border-2 focus:border-primary/50" />
          </div>
          <Select value={statusFilter} onValueChange={setStatusFilter}>
            <SelectTrigger className="w-full sm:w-[180px] border-2">
              <Filter className="h-4 w-4 mr-2" />
              <SelectValue placeholder="Status" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Status</SelectItem>
              <SelectItem value="draft">Draft</SelectItem>
              <SelectItem value="sent">Sent</SelectItem>
              <SelectItem value="opened">Opened</SelectItem>
              <SelectItem value="accepted">Accepted</SelectItem>
              <SelectItem value="rejected">Rejected</SelectItem>
            </SelectContent>
          </Select>
          <Select value={platformFilter} onValueChange={setPlatformFilter}>
            <SelectTrigger className="w-full sm:w-[180px] border-2">
              <SelectValue placeholder="Platform" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="all">All Platforms</SelectItem>
              <SelectItem value="upwork">Upwork</SelectItem>
              <SelectItem value="fiverr">Fiverr</SelectItem>
              <SelectItem value="freelancer">Freelancer</SelectItem>
              <SelectItem value="toptal">Toptal</SelectItem>
              <SelectItem value="other">Other</SelectItem>
            </SelectContent>
          </Select>
        </div>
      </FadeIn>
      {isLoading ? (
        <div className="flex items-center justify-center py-20">
          <Spinner className="h-8 w-8" />
          <span className="ml-3 text-muted-foreground">Loading proposals...</span>
        </div>
      ) : filteredProposals.length > 0 ? (
        <div className="grid gap-6">
          {filteredProposals.map((proposal, index) => (
            <FadeIn key={proposal.id} delay={0.1 + index * 0.05}>
              <ProposalCard proposal={proposal} />
            </FadeIn>
          ))}
        </div>
      ) : (
        <FadeIn delay={0.2}>
          <EmptyState
            icon={<FileText className="h-12 w-12 text-primary" />}
            title="No proposals found"
            description={
              searchQuery || statusFilter !== "all" || platformFilter !== "all"
                ? "Try adjusting your filters or search query"
                : "Get started by generating your first proposal"
            }
            action={
              <Link href="/dashboard/generator">
                <Button size="lg">
                  Generate Proposal
                </Button>
              </Link>
            }
          />
        </FadeIn>
      )}
    </PageContainer>
  );
}
