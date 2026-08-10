"use client";

import { useState, useEffect } from "react";
import { Check, Zap, Crown, Loader2, AlertCircle, Sparkles, ArrowRight, Shield, CreditCard, X, Ban } from "lucide-react";
import { useAuth } from "@/lib/auth-context";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

// Icon mapping for plans
const PLAN_ICONS: Record<string, typeof Sparkles> = {
  free: Sparkles,
  starter: Zap,
  pro: Crown,
};

// Plan type definition
interface Plan {
  id: string;
  name: string;
  price: number;
  originalPrice?: number;
  period: string;
  description: string;
  features: string[];
  limitations?: string[];
  popular: boolean;
  variantId: string | null;
  color: string;
  icon?: typeof Sparkles;
}

// Success modal component
function SuccessModal({ isOpen, onClose }: { isOpen: boolean; onClose: () => void }) {
  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      >
        <motion.div
          initial={{ scale: 0.9, opacity: 0 }}
          animate={{ scale: 1, opacity: 1 }}
          exit={{ scale: 0.9, opacity: 0 }}
          className="bg-white rounded-2xl shadow-2xl p-8 max-w-md mx-4 text-center"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <Check className="w-8 h-8 text-green-600" />
          </div>
          <h3 className="text-2xl font-bold text-slate-900 mb-2">Welcome to Pro!</h3>
          <p className="text-slate-600 mb-6">
            Your subscription is now active. Start creating winning proposals today!
          </p>
          <Link
            href="/dashboard/generator"
            className="block w-full py-3 bg-blue-600 text-white font-semibold rounded-xl hover:bg-blue-700 transition-colors text-center"
          >
            Start Creating Proposals
          </Link>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
}

export default function SubscriptionPage() {
  const { user, loading: authLoading, refreshUser } = useAuth();
  const [loading, setLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [showSuccess, setShowSuccess] = useState(false);
  const [syncing, setSyncing] = useState(false);
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [canceling, setCanceling] = useState(false);
  const [plans, setPlans] = useState<Plan[]>([]);
  const [plansLoading, setPlansLoading] = useState(true);

  // Fetch plans from backend API (keeps variant IDs server-side)
  useEffect(() => {
    const fetchPlans = async () => {
      try {
        const response = await fetch("/api/billing/plans");
        const data = await response.json();
        if (data.success && data.plans) {
          // Add icons to plans
          const plansWithIcons = data.plans.map((plan: Plan) => ({
            ...plan,
            icon: PLAN_ICONS[plan.id] || Sparkles,
          }));
          setPlans(plansWithIcons);
        }
      } catch (err) {
        console.error("Failed to fetch plans:", err);
      } finally {
        setPlansLoading(false);
      }
    };
    fetchPlans();
  }, []);

  // Sync subscription from Lemon Squeezy on page load
  const syncSubscription = async () => {
    if (syncing) return;
    setSyncing(true);
    try {
      const response = await fetch("/api/billing/sync", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });
      const data = await response.json();
      if (data.synced && data.subscription) {
        // Refresh user data to reflect the synced subscription
        refreshUser?.();
      }
    } catch (err) {
      // Silent fail - user can manually refresh if needed
    } finally {
      setSyncing(false);
    }
  };

  // Check for successful payment return and sync subscription
  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get("success") === "true") {
      // Remove query params from URL
      window.history.replaceState({}, "", window.location.pathname);
      // Sync subscription from Lemon Squeezy
      syncSubscription().then(() => {
        setShowSuccess(true);
        refreshUser?.();
      });
    } else {
      // Also sync on initial page load to ensure subscription is up to date
      syncSubscription();
    }
  }, []);

  const currentPlan = user?.subscriptionPlan || "free";
  const subscriptionStatus = user?.subscriptionStatus || "active";
  const proposalsUsed = user?.proposalsUsed || 0;
  const proposalsLimit = user?.proposalsLimit || 15;

  const handleUpgrade = async (planId: string, variantId: string | null) => {
    if (!variantId) {
      setError("This plan doesn't require payment.");
      return;
    }

    if (!user) {
      setError("Please sign in to upgrade your plan.");
      return;
    }

    setLoading(planId);
    setError(null);

    try {
      const response = await fetch("/api/billing/checkout", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ 
          variantId,
          redirectUrl: `${window.location.origin}/dashboard/subscription?success=true`
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to start checkout");
      }

      if (data.url) {
        // Redirect to Lemon Squeezy checkout
        window.location.href = data.url;
      } else {
        throw new Error("No checkout URL received");
      }
    } catch (err: any) {
      console.error("Checkout error:", err);
      setError(err.message || "Something went wrong. Please try again.");
      setLoading(null);
    }
  };

  const handleManageSubscription = async () => {
    try {
      setLoading("manage");
      const response = await fetch("/api/billing/portal", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to open billing portal");
      }

      if (data.url) {
        window.location.href = data.url;
      } else {
        // Fallback - show instructions
        alert("Please check your email for subscription management options, or visit your Lemon Squeezy account.");
      }
    } catch (err: any) {
      console.error("Portal error:", err);
      // Fallback message
      alert("To manage your subscription, please check your email for the subscription receipt or contact support.");
    } finally {
      setLoading(null);
    }
  };

  const handleCancelSubscription = async () => {
    setCanceling(true);
    setError(null);

    try {
      const response = await fetch("/api/billing/cancel", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || "Failed to cancel subscription");
      }

      // Refresh user data to reflect cancellation
      await refreshUser?.();
      
      // Close dialog and show success
      setShowCancelDialog(false);
      setError(null);
      
      alert(data.message || "Subscription cancelled successfully. You'll have access until the end of your billing period.");
    } catch (err: any) {
      console.error("Cancel error:", err);
      setError(err.message || "Failed to cancel subscription. Please try again.");
      setShowCancelDialog(false);
    } finally {
      setCanceling(false);
    }
  };

  const getButtonText = (plan: Plan) => {
    if (loading === plan.id) return null; // Show loader
    if (currentPlan === plan.id) return "Current Plan";
    if (plan.id === "free") return "Free";
    if (currentPlan !== "free" && plan.id === "starter") return "Downgrade";
    return "Get Started";
  };

  const isButtonDisabled = (plan: Plan) => {
    return loading !== null || currentPlan === plan.id || plan.id === "free";
  };

  if (authLoading || plansLoading) {
    return (
      <div className="flex h-[80vh] items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
      </div>
    );
  }

  return (
    <div className="py-8 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Success Modal */}
      <SuccessModal isOpen={showSuccess} onClose={() => setShowSuccess(false)} />

      {/* Header */}
      <div className="text-center mb-8">
        <motion.h1 
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-4xl font-extrabold text-slate-900 sm:text-5xl"
        >
          Choose Your Plan
        </motion.h1>
        <motion.p 
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="mt-4 text-xl text-slate-600 max-w-2xl mx-auto"
        >
          Write winning proposals 10x faster with AI. Upgrade anytime.
        </motion.p>
      </div>

      {/* Error Alert */}
      <AnimatePresence>
        {error && (
          <motion.div
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -10 }}
            className="mb-8 max-w-md mx-auto bg-red-50 border border-red-200 text-red-700 p-4 rounded-xl flex items-center justify-between"
          >
            <div className="flex items-center">
              <AlertCircle className="w-5 h-5 mr-2 flex-shrink-0" />
              <span className="text-sm">{error}</span>
            </div>
            <button onClick={() => setError(null)} className="text-red-500 hover:text-red-700">
              <X className="w-4 h-4" />
            </button>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Current Subscription Status */}
      <motion.div 
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.2 }}
        className="mb-10 bg-gradient-to-r from-slate-50 to-blue-50 rounded-2xl border border-slate-200 p-6"
      >
        <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
          <div className="flex items-center gap-4">
            <div className={`h-14 w-14 rounded-xl flex items-center justify-center ${
              currentPlan === "pro" ? "bg-purple-100" :
              currentPlan === "starter" ? "bg-blue-100" : "bg-slate-100"
            }`}>
              {currentPlan === "pro" ? (
                <Crown className="w-7 h-7 text-purple-600" />
              ) : currentPlan === "starter" ? (
                <Zap className="w-7 h-7 text-blue-600" />
              ) : (
                <Sparkles className="w-7 h-7 text-slate-500" />
              )}
            </div>
            <div>
              <p className="text-sm font-medium text-slate-500">Current Plan</p>
              <h3 className="text-xl font-bold text-slate-900">
                {plans.find((p: Plan) => p.id === currentPlan)?.name || "Free Trial"}
              </h3>
              {subscriptionStatus === "canceled" && (
                <p className="text-xs text-amber-600 font-medium mt-1">
                  Subscription ending soon
                </p>
              )}
              {syncing && (
                <p className="text-xs text-blue-600 font-medium mt-1 flex items-center gap-1">
                  <Loader2 className="w-3 h-3 animate-spin" />
                  Syncing subscription...
                </p>
              )}
            </div>
          </div>

          <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4">
            {/* Usage Progress */}
            <div className="text-left sm:text-right">
              <p className="text-sm text-slate-500 mb-1">Usage This Month</p>
              <div className="flex items-center gap-3">
                <div className="w-32 h-2.5 bg-slate-200 rounded-full overflow-hidden">
                  <motion.div
                    initial={{ width: 0 }}
                    animate={{ width: `${Math.min((proposalsUsed / proposalsLimit) * 100, 100)}%` }}
                    transition={{ duration: 0.5, delay: 0.3 }}
                    className={`h-full rounded-full ${
                      proposalsUsed / proposalsLimit > 0.9 ? "bg-red-500" :
                      proposalsUsed / proposalsLimit > 0.7 ? "bg-amber-500" : "bg-blue-500"
                    }`}
                  />
                </div>
                <span className="text-sm font-semibold text-slate-700">
                  {proposalsUsed}/{proposalsLimit}
                </span>
              </div>
            </div>

            {/* Sync & Manage Buttons */}
            <div className="flex items-center gap-2">
              {/* Sync Button - useful when webhook doesn't work */}
              <button
                onClick={() => syncSubscription()}
                disabled={syncing}
                className="px-3 py-2.5 border border-slate-300 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 hover:border-slate-400 transition-all flex items-center gap-2"
                title="Refresh subscription status"
              >
                {syncing ? (
                  <Loader2 className="w-4 h-4 animate-spin" />
                ) : (
                  <ArrowRight className="w-4 h-4 rotate-45" />
                )}
              </button>

              {/* Manage Subscription Button */}
              {currentPlan !== "free" && subscriptionStatus !== "canceled" && (
                <button
                  onClick={handleManageSubscription}
                  disabled={loading === "manage"}
                  className="px-5 py-2.5 border border-slate-300 rounded-xl text-sm font-medium text-slate-700 hover:bg-slate-50 hover:border-slate-400 transition-all flex items-center gap-2"
                >
                  {loading === "manage" ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <CreditCard className="w-4 h-4" />
                  )}
                  Manage Billing
                </button>
              )}

              {/* Cancel Subscription Button */}
              {currentPlan !== "free" && subscriptionStatus !== "canceled" && (
                <button
                  onClick={() => setShowCancelDialog(true)}
                  disabled={canceling}
                  className="px-5 py-2.5 border border-red-200 bg-red-50 rounded-xl text-sm font-medium text-red-700 hover:bg-red-100 hover:border-red-300 transition-all flex items-center gap-2"
                >
                  {canceling ? (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  ) : (
                    <Ban className="w-4 h-4" />
                  )}
                  Cancel Plan
                </button>
              )}
            </div>
          </div>
        </div>
      </motion.div>

      {/* Pricing Cards */}
      <div className="grid md:grid-cols-3 gap-6 lg:gap-8 max-w-6xl mx-auto">
        {plansLoading ? (
          <div className="col-span-3 flex justify-center py-12">
            <Loader2 className="w-8 h-8 animate-spin text-blue-600" />
          </div>
        ) : plans.map((plan, index) => {
          const Icon = plan.icon || Sparkles;
          const isCurrentPlan = currentPlan === plan.id;
          
          return (
            <motion.div
              key={plan.id}
              initial={{ opacity: 0, y: 30 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1 * (index + 1) }}
              className={`relative bg-white rounded-2xl border-2 ${
                plan.popular 
                  ? "border-blue-500 shadow-xl shadow-blue-100" 
                  : isCurrentPlan
                    ? "border-green-500 shadow-lg shadow-green-50"
                    : "border-slate-200 shadow-sm hover:shadow-md hover:border-slate-300"
              } p-6 lg:p-8 flex flex-col transition-all duration-200`}
            >
              {/* Popular Badge */}
              {plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <span className="bg-gradient-to-r from-blue-600 to-blue-500 text-white px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wide shadow-lg">
                    Most Popular
                  </span>
                </div>
              )}

              {/* Current Plan Badge */}
              {isCurrentPlan && !plan.popular && (
                <div className="absolute -top-3 left-1/2 -translate-x-1/2">
                  <span className="bg-green-500 text-white px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wide">
                    Current Plan
                  </span>
                </div>
              )}

              {/* Plan Header */}
              <div className="mb-6">
                <div className={`w-12 h-12 rounded-xl flex items-center justify-center mb-4 ${
                  plan.color === "purple" ? "bg-purple-100" :
                  plan.color === "blue" ? "bg-blue-100" : "bg-slate-100"
                }`}>
                  <Icon className={`w-6 h-6 ${
                    plan.color === "purple" ? "text-purple-600" :
                    plan.color === "blue" ? "text-blue-600" : "text-slate-500"
                  }`} />
                </div>
                <h3 className="text-xl font-bold text-slate-900">{plan.name}</h3>
                <p className="text-slate-500 mt-1 text-sm">{plan.description}</p>
              </div>

              {/* Price */}
              <div className="mb-6">
                <div className="flex items-baseline gap-1">
                  <span className="text-4xl font-extrabold text-slate-900">
                    ${plan.price}
                  </span>
                  {plan.period && (
                    <span className="text-slate-500">{plan.period}</span>
                  )}
                </div>
                {plan.originalPrice && (
                  <div className="flex items-center gap-2 mt-1">
                    <span className="text-slate-400 line-through text-lg">
                      ${plan.originalPrice}
                    </span>
                    <span className="text-xs font-semibold text-green-600 bg-green-50 px-2 py-0.5 rounded-full">
                      Save {Math.round((1 - plan.price / plan.originalPrice) * 100)}%
                    </span>
                  </div>
                )}
              </div>

              {/* Features */}
              <ul className="space-y-3 mb-8 flex-1">
                {plan.features.map((feature, i) => (
                  <li key={i} className="flex items-start gap-3">
                    <Check className={`w-5 h-5 flex-shrink-0 ${
                      plan.color === "purple" ? "text-purple-500" :
                      plan.color === "blue" ? "text-blue-500" : "text-slate-400"
                    }`} />
                    <span className="text-slate-600 text-sm">{feature}</span>
                  </li>
                ))}
                {plan.limitations?.map((limitation, i) => (
                  <li key={`limit-${i}`} className="flex items-start gap-3 opacity-60">
                    <X className="w-5 h-5 flex-shrink-0 text-slate-400" />
                    <span className="text-slate-500 text-sm">{limitation}</span>
                  </li>
                ))}
              </ul>

              {/* CTA Button */}
              <button
                onClick={() => handleUpgrade(plan.id, plan.variantId)}
                disabled={isButtonDisabled(plan)}
                className={`w-full py-4 rounded-xl font-bold text-white transition-all transform active:scale-[0.98] flex items-center justify-center gap-2 ${
                  isCurrentPlan
                    ? "bg-green-500 cursor-default"
                    : loading === plan.id
                      ? "bg-slate-400 cursor-wait"
                      : plan.id === "free"
                        ? "bg-slate-200 text-slate-500 cursor-default"
                        : plan.popular
                          ? "bg-gradient-to-r from-blue-600 to-blue-500 hover:from-blue-700 hover:to-blue-600 shadow-lg shadow-blue-200 hover:shadow-xl"
                          : "bg-slate-900 hover:bg-slate-800 shadow-lg shadow-slate-200"
                }`}
              >
                {loading === plan.id ? (
                  <Loader2 className="w-5 h-5 animate-spin" />
                ) : (
                  <>
                    {getButtonText(plan)}
                    {!isCurrentPlan && plan.id !== "free" && (
                      <ArrowRight className="w-4 h-4" />
                    )}
                  </>
                )}
              </button>
            </motion.div>
          );
        })}
      </div>

      {/* Trust Badges */}
      <motion.div 
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.5 }}
        className="mt-12 flex flex-col sm:flex-row items-center justify-center gap-6 text-sm text-slate-500"
      >
        <div className="flex items-center gap-2">
          <Shield className="w-5 h-5 text-green-500" />
          <span>Secure payments via Lemon Squeezy</span>
        </div>
        <div className="flex items-center gap-2">
          <CreditCard className="w-5 h-5 text-blue-500" />
          <span>Cancel anytime, no questions asked</span>
        </div>
      </motion.div>

      {/* FAQ/Help Link */}
      <div className="mt-8 text-center">
        <p className="text-sm text-slate-400">
          Questions? <Link href="/dashboard/settings" className="text-blue-600 hover:underline">Contact support</Link> or read our{" "}
          <Link href="/terms" className="text-blue-600 hover:underline">Terms of Service</Link>
        </p>
      </div>

      {/* Cancel Confirmation Dialog */}
      <Dialog open={showCancelDialog} onOpenChange={setShowCancelDialog}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle className="flex items-center gap-2 text-red-700">
              <Ban className="w-5 h-5" />
              Cancel Subscription
            </DialogTitle>
            <DialogDescription className="text-left pt-2">
              Are you sure you want to cancel your subscription? You&apos;ll lose access to premium features at the end of your current billing period.
            </DialogDescription>
          </DialogHeader>
          
          <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 my-4">
            <p className="text-sm text-amber-800">
              <strong>What happens next:</strong>
            </p>
            <ul className="text-sm text-amber-700 mt-2 space-y-1 list-disc list-inside">
              <li>Your subscription will remain active until the end of the current billing period</li>
              <li>You&apos;ll keep all premium features until then</li>
              <li>After expiration, you&apos;ll be moved to the free plan</li>
              <li>You can resubscribe anytime</li>
            </ul>
          </div>

          <DialogFooter className="gap-2 sm:gap-0">
            <Button
              variant="outline"
              onClick={() => setShowCancelDialog(false)}
              disabled={canceling}
            >
              Keep Subscription
            </Button>
            <Button
              variant="destructive"
              onClick={handleCancelSubscription}
              disabled={canceling}
            >
              {canceling ? (
                <>
                  <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                  Canceling...
                </>
              ) : (
                "Yes, Cancel Subscription"
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
