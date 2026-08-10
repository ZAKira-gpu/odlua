"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Sparkles, Mail, RefreshCw, AlertCircle } from "lucide-react";
import { FadeIn, SlideIn } from "@/components/ui/animations";
import { useAuth } from "@/lib/auth-context";
import toast from "react-hot-toast";

export default function VerifyEmailPage() {
  const router = useRouter();
  const { firebaseUser, resendVerificationEmail, refreshUser, logout } = useAuth();
  const [isResending, setIsResending] = React.useState(false);
  const [isChecking, setIsChecking] = React.useState(false);
  const [error, setError] = React.useState("");

  // Check if email is already verified
  React.useEffect(() => {
    if (firebaseUser?.emailVerified) {
      router.push("/dashboard");
    }
  }, [firebaseUser, router]);

  const handleResendEmail = async () => {
    setIsResending(true);
    setError("");
    
    try {
      await resendVerificationEmail();
      toast.success("Verification email sent!");
    } catch (error: any) {
      console.error("Resend error:", error);
      setError(error.message || "Failed to resend email");
      toast.error(error.message || "Failed to resend email");
    } finally {
      setIsResending(false);
    }
  };

  const handleCheckVerification = async () => {
    setIsChecking(true);
    setError("");
    
    try {
      await refreshUser();
      
      if (firebaseUser?.emailVerified) {
        toast.success("Email verified successfully!");
        router.push("/dashboard");
      } else {
        setError("Email not verified yet. Please check your inbox and click the verification link.");
      }
    } catch (error: any) {
      console.error("Check verification error:", error);
      setError(error.message || "Failed to check verification status");
    } finally {
      setIsChecking(false);
    }
  };

  const handleLogout = async () => {
    try {
      await logout();
      router.push("/auth/signin");
    } catch (error: any) {
      console.error("Logout error:", error);
      toast.error("Failed to log out");
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4" style={{ background: 'linear-gradient(135deg, #E8F4F8 0%, #D4EBF2 50%, #C5E4ED 100%)' }}>
      <div className="w-full max-w-md">
        {/* Logo */}
        <FadeIn>
          <Link href="/" className="flex flex-col items-center justify-center mb-8">
            <img src="/logo-banner.png" alt="Propelo AI" className="w-64 h-auto object-contain mb-4" />
          </Link>
        </FadeIn>

        {/* Verify Email Card */}
        <SlideIn direction="up" delay={0.1}>
          <Card className="p-8">
            <div className="text-center mb-6">
              <div className="mb-4 mx-auto w-16 h-16 bg-cyan-100 rounded-full flex items-center justify-center">
                <Mail className="h-8 w-8 text-cyan-600" />
              </div>
              <h1 className="text-2xl font-bold text-foreground mb-2">
                Verify your email
              </h1>
              <p className="text-muted-foreground">
                We've sent a verification link to
              </p>
              <p className="font-medium text-foreground mt-1">
                {firebaseUser?.email}
              </p>
            </div>

            {error && (
              <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg flex items-start gap-2">
                <AlertCircle className="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" />
                <p className="text-sm text-red-600">{error}</p>
              </div>
            )}

            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
              <h3 className="font-medium text-blue-900 mb-2">What to do next:</h3>
              <ol className="text-sm text-blue-900 space-y-2 list-decimal list-inside">
                <li>Open your email inbox</li>
                <li>Click the verification link in the email</li>
                <li>Come back here and click "I've verified my email"</li>
              </ol>
            </div>

            <div className="space-y-3">
              <Button 
                onClick={handleCheckVerification} 
                className="w-full" 
                size="lg"
                disabled={isChecking || isResending}
              >
                {isChecking ? (
                  <>
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                    Checking...
                  </>
                ) : (
                  <>
                    <RefreshCw className="h-5 w-5 mr-2" />
                    I've verified my email
                  </>
                )}
              </Button>

              <Button 
                onClick={handleResendEmail} 
                variant="outline" 
                className="w-full"
                disabled={isChecking || isResending}
              >
                {isResending ? (
                  <>
                    <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-cyan-600 mr-2"></div>
                    Sending...
                  </>
                ) : (
                  "Resend verification email"
                )}
              </Button>
            </div>

            <div className="mt-6 pt-6 border-t border-gray-200">
              <p className="text-center text-sm text-muted-foreground mb-3">
                Wrong email address?
              </p>
              <Button 
                onClick={handleLogout} 
                variant="ghost" 
                className="w-full"
              >
                Sign out and try again
              </Button>
            </div>
          </Card>
        </SlideIn>

        <p className="mt-6 text-center text-sm text-muted-foreground">
          Need help?{" "}
          <Link href="/support" className="text-cyan-600 hover:text-cyan-700">
            Contact support
          </Link>
        </p>
      </div>
    </div>
  );
}
