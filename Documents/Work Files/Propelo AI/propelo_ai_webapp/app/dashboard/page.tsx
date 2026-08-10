"use client";

import * as React from "react";
import { PageContainer, PageHeader } from "@/components/ui/page-layout";
import { Button } from "@/components/ui/button";
import { StatsGrid } from "@/components/ui/stat-card";
import { ProposalCard } from "@/components/ui/proposal-card";
import { Sparkles, FileText, Eye, CheckCircle, TrendingUp, Download, Link as LinkIcon, Zap, Chrome } from "lucide-react";
import Link from "next/link";
import { FadeIn, StaggerChildren, staggerChildVariants } from "@/components/ui/animations";
import { motion } from "framer-motion";
import { useAuth } from "@/lib/auth-context";
import { useExtensionDetection } from "@/lib/use-extension-detection";
import { Card } from "@/components/ui/card";

const sampleProposal = {
  id: "sample-1",
  userId: "demo-user",
  title: "Example: E-commerce Website Redesign",
  content: "Sample proposal showing what your generated proposals will look like.",
  jobDescription: "Looking for someone to redesign our e-commerce platform",
  tone: "formal" as const,
  platform: "upwork" as const,
  clientName: "Example Client",
  status: "draft" as const,
  opened: false,
  openCount: 0,
  linkClicks: 0,
  version: 1,
  sections: [],
  insights: [],
  createdAt: new Date(),
  updatedAt: new Date(),
  analytics: { opens: 0, clicks: 0, timeSpent: 0 },
};

export default function DashboardPage() {
  const { user } = useAuth();
  const { installed: extensionInstalled } = useExtensionDetection();
  const hasConnectedPlatforms = user?.accounts && Object.keys(user.accounts).length > 0;
  const displayName = user?.name || user?.firstName || "there";
  
  const stats = [
    { title: "Total Proposals", value: user?.proposalsUsed || 0, icon: FileText, trend: { value: 0, isPositive: true } },
    { title: "Proposals Left", value: user?.proposalsLimit ? user.proposalsLimit - (user.proposalsUsed || 0) : 10, icon: Eye, trend: { value: 0, isPositive: true } },
    { title: "Platforms Connected", value: user?.accounts ? Object.keys(user.accounts).length : 0, icon: CheckCircle, trend: { value: 0, isPositive: true } },
    { title: "Account Status", value: (user?.subscriptionPlan === "pro" || user?.subscriptionPlan === "starter") ? (user.subscriptionPlan === "pro" ? "Pro" : "Starter") : "Free", icon: TrendingUp, trend: { value: 0, isPositive: true } },
  ];

  return (
    <PageContainer>
      <div className="fixed inset-0 -z-10 gradient-mesh pointer-events-none" />
      <div className="fixed top-20 left-10 w-72 h-72 bg-cyan-500/10 rounded-full blur-3xl floating pointer-events-none" />
      <div className="fixed bottom-20 right-10 w-96 h-96 bg-teal-500/10 rounded-full blur-3xl floating-delayed pointer-events-none" />
      
      <FadeIn>
        <PageHeader
          title={"Welcome, " + displayName + "!"}
          description="Here's an overview of your proposal performance."
          actions={
            <Link href="/dashboard/generator">
              <Button size="lg" className="gradient-primary glow-cyan-hover group relative overflow-hidden">
                <span className="absolute inset-0 shimmer" />
                <Sparkles className="h-5 w-5 mr-2 relative z-10 group-hover:rotate-12 transition-transform" />
                <span className="relative z-10">Generate Proposal</span>
              </Button>
            </Link>
          }
        />
      </FadeIn>

      <div className="space-y-8">
        {!hasConnectedPlatforms && (
          <FadeIn delay={0.05}>
            <Card className="p-6 bg-gradient-to-r from-cyan-50 to-teal-50 border-cyan-200">
              <div className="flex flex-col md:flex-row items-start md:items-center gap-4 md:gap-6">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-cyan-500 to-teal-600 flex items-center justify-center flex-shrink-0">
                  {extensionInstalled ? <Zap className="h-7 w-7 text-white" /> : <Chrome className="h-7 w-7 text-white" />}
                </div>
                <div className="flex-1">
                  {extensionInstalled ? (
                    <>
                      <div className="flex items-center gap-2">
                        <h3 className="text-lg font-bold text-cyan-900">Extension Installed</h3>
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-green-100 text-green-700 text-xs font-medium">
                          <CheckCircle className="h-3 w-3" />Active
                        </span>
                      </div>
                      <p className="text-cyan-700 mt-1">Visit Upwork to sync your profile and start generating personalized proposals.</p>
                    </>
                  ) : (
                    <>
                      <h3 className="text-lg font-bold text-cyan-900">Install the Chrome Extension</h3>
                      <p className="text-cyan-700 mt-1">Get the Propelo extension to auto-detect jobs and sync your Upwork profile.</p>
                    </>
                  )}
                </div>
                <div className="flex flex-wrap gap-3">
                  {extensionInstalled ? (
                    <a href="https://www.upwork.com/freelancers/~" target="_blank" rel="noopener noreferrer">
                      <Button className="bg-cyan-600 hover:bg-cyan-700">
                        <LinkIcon className="h-4 w-4 mr-2" />Go to Upwork
                      </Button>
                    </a>
                  ) : (
                    <>
                      <Link href="/dashboard/connect">
                        <Button variant="outline" className="border-cyan-300 text-cyan-700 hover:bg-cyan-100">
                          <LinkIcon className="h-4 w-4 mr-2" />Connect Accounts
                        </Button>
                      </Link>
                      <Link href="/dashboard/connect#extension">
                        <Button className="bg-cyan-600 hover:bg-cyan-700"><Download className="h-4 w-4 mr-2" />Get Extension</Button>
                      </Link>
                    </>
                  )}
                </div>
              </div>
            </Card>
          </FadeIn>
        )}
        
        <FadeIn delay={0.1}><StatsGrid stats={stats} /></FadeIn>

        <div className="space-y-4">
          <FadeIn delay={0.2}>
            <div className="flex items-center justify-between">
              <div>
                <h2 className="text-2xl font-bold text-foreground">Recent Proposals</h2>
                <p className="text-muted-foreground mt-1">Your most recent proposal submissions</p>
              </div>
              <Link href="/dashboard/history">
                <Button variant="outline" className="rounded-full hover:shadow-lg hover:shadow-cyan-500/20 transition-all">View All</Button>
              </Link>
            </div>
          </FadeIn>

          <StaggerChildren staggerDelay={0.1}>
            <div className="grid gap-6">
              {user?.proposalsUsed === 0 ? (
                <motion.div variants={staggerChildVariants}>
                  <Card className="p-8 text-center">
                    <div className="w-16 h-16 mx-auto rounded-2xl bg-gray-100 flex items-center justify-center mb-4">
                      <FileText className="h-8 w-8 text-gray-400" />
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">No proposals yet</h3>
                    <p className="text-gray-500 mb-4">Generate your first AI-powered proposal to get started</p>
                    <Link href="/dashboard/generator">
                      <Button className="gradient-primary"><Sparkles className="h-4 w-4 mr-2" />Generate Your First Proposal</Button>
                    </Link>
                  </Card>
                </motion.div>
              ) : (
                <motion.div variants={staggerChildVariants}>
                  <Card className="p-8 text-center">
                    <div className="w-16 h-16 mx-auto rounded-2xl bg-gradient-to-br from-cyan-100 to-teal-100 flex items-center justify-center mb-4">
                      <FileText className="h-8 w-8 text-cyan-600" />
                    </div>
                    <h3 className="text-lg font-semibold text-gray-900 mb-2">You've created {user?.proposalsUsed || 0} proposal{(user?.proposalsUsed || 0) !== 1 ? 's' : ''}</h3>
                    <p className="text-gray-500 mb-4">View your proposal history or generate a new one</p>
                    <div className="flex gap-3 justify-center">
                      <Link href="/dashboard/history">
                        <Button variant="outline"><Eye className="h-4 w-4 mr-2" />View History</Button>
                      </Link>
                      <Link href="/dashboard/generator">
                        <Button className="gradient-primary"><Sparkles className="h-4 w-4 mr-2" />New Proposal</Button>
                      </Link>
                    </div>
                  </Card>
                </motion.div>
              )}
            </div>
          </StaggerChildren>
        </div>

        <FadeIn delay={0.4}>
          <div className="relative card-elevated overflow-hidden group">
            <div className="absolute inset-0 gradient-primary opacity-100 group-hover:opacity-90 transition-opacity" />
            <div className="absolute inset-0 shimmer opacity-0 group-hover:opacity-100" />
            <div className="relative p-8 text-white">
              <div className="flex items-center justify-between">
                <div>
                  <h3 className="text-2xl font-bold mb-2">Ready to win your next project?</h3>
                  <p className="text-white/90">Generate a compelling proposal in seconds with AI</p>
                </div>
                <Link href="/dashboard/generator">
                  <Button size="lg" className="bg-white text-cyan-600 hover:bg-white/90 hover:scale-105 transition-all shadow-2xl">
                    <Sparkles className="h-5 w-5 mr-2" />Get Started
                  </Button>
                </Link>
              </div>
            </div>
          </div>
        </FadeIn>
      </div>
    </PageContainer>
  );
}
