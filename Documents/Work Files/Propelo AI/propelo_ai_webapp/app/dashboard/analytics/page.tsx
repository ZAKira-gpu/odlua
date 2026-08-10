"use client";

import { PageContainer, PageHeader } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Card } from "@/components/ui/card";
import { BarChart3, Clock, TrendingUp, PieChart, Target, Zap } from "lucide-react";
import { FadeIn } from "@/components/ui/animations";
import { Button } from "@/components/ui/button";
import Link from "next/link";
import { useAuth } from "@/lib/auth-context";
import toast from "react-hot-toast";

export default function AnalyticsPage() {
  const { user } = useAuth();
  const isPro = user?.subscriptionPlan === "pro" || user?.subscriptionPlan === "starter";

  const handleNotifyMe = () => {
    toast.success("We'll notify you when Analytics launches!");
  };

  return (
    <PageContainer>
      <FadeIn>
        <PageHeader
          title="Analytics"
          description="Track your proposal performance and insights"
          breadcrumbs={
            <Breadcrumbs
              items={[
                { label: "Dashboard", href: "/dashboard" },
                { label: "Analytics" },
              ]}
            />
          }
        />
      </FadeIn>

      <div className="flex flex-col items-center justify-center min-h-[60vh] space-y-6">
        <FadeIn delay={0.1}>
          <div className="relative">
            <div className="absolute inset-0 bg-gradient-to-r from-cyan-500/20 to-teal-500/20 blur-xl rounded-full" />
            <div className="relative bg-white p-6 rounded-2xl shadow-xl border border-slate-100">
              <BarChart3 className="w-16 h-16 text-cyan-500" />
              <div className="absolute -top-2 -right-2 bg-gradient-to-r from-amber-500 to-orange-500 text-white text-xs font-bold px-2 py-1 rounded-full shadow-lg">
                Pro
              </div>
            </div>
          </div>
        </FadeIn>

        <FadeIn delay={0.2} className="text-center max-w-md space-y-2">
          <h2 className="text-2xl font-bold text-slate-900">
            Advanced Analytics Coming Soon
          </h2>
          <p className="text-slate-500">
            We're building powerful insights to help you track win rates, optimize proposals, and grow your freelance business.
          </p>
        </FadeIn>

        <FadeIn delay={0.3} className="grid grid-cols-1 md:grid-cols-3 gap-4 w-full max-w-2xl mt-8">
          <Card className="p-4 flex items-start gap-4 bg-slate-50 border-slate-100">
            <div className="p-2 bg-white rounded-lg shadow-sm">
              <TrendingUp className="w-5 h-5 text-green-600" />
            </div>
            <div>
              <h3 className="font-semibold text-sm text-slate-900">Win Rate</h3>
              <p className="text-xs text-slate-500 mt-1">Track proposal success rates</p>
            </div>
          </Card>
          
          <Card className="p-4 flex items-start gap-4 bg-slate-50 border-slate-100">
            <div className="p-2 bg-white rounded-lg shadow-sm">
              <PieChart className="w-5 h-5 text-teal-600" />
            </div>
            <div>
              <h3 className="font-semibold text-sm text-slate-900">Conversion</h3>
              <p className="text-xs text-slate-500 mt-1">Views to replies ratio</p>
            </div>
          </Card>

          <Card className="p-4 flex items-start gap-4 bg-slate-50 border-slate-100">
            <div className="p-2 bg-white rounded-lg shadow-sm">
              <Target className="w-5 h-5 text-cyan-600" />
            </div>
            <div>
              <h3 className="font-semibold text-sm text-slate-900">Best Niches</h3>
              <p className="text-xs text-slate-500 mt-1">Your top performing areas</p>
            </div>
          </Card>
        </FadeIn>

        <FadeIn delay={0.4}>
          <div className="flex gap-4 mt-4">
            <Button asChild variant="outline">
              <Link href="/dashboard">Back to Dashboard</Link>
            </Button>
            <Button 
              onClick={handleNotifyMe}
              className="bg-gradient-to-r from-cyan-500 to-teal-500 text-white border-0"
            >
              <Zap className="w-4 h-4 mr-2" />
              Notify Me When Ready
            </Button>
          </div>
        </FadeIn>
      </div>
    </PageContainer>
  );
}
