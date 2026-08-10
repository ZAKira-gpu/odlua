"use client";

import * as React from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { Sparkles, Mail, ArrowLeft, CheckCircle, AlertCircle } from "lucide-react";
import { FadeIn, SlideIn } from "@/components/ui/animations";
import { useAuth } from "@/lib/auth-context";
import toast from "react-hot-toast";

export default function ForgotPasswordPage() {
  const { resetPassword } = useAuth();
  const [email, setEmail] = React.useState("");
  const [isLoading, setIsLoading] = React.useState(false);
  const [isSuccess, setIsSuccess] = React.useState(false);
  const [error, setError] = React.useState("");

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsLoading(true);
    setError("");
    
    try {
      await resetPassword(email);
      setIsSuccess(true);
      toast.success("Password reset email sent!");
    } catch (error: any) {
      console.error("Reset password error:", error);
      setError(error.message || "Failed to send reset email");
      toast.error(error.message || "Failed to send reset email");
    } finally {
      setIsLoading(false);
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

        {/* Forgot Password Card */}
        <SlideIn direction="up" delay={0.1}>
          <Card className="p-8">
            {!isSuccess ? (
              <>
                <div className="mb-6">
                  <h1 className="text-2xl font-bold text-foreground mb-2">
                    Reset your password
                  </h1>
                  <p className="text-muted-foreground">
                    Enter your email and we'll send you a link to reset your password
                  </p>
                </div>

                {error && (
                  <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg flex items-start gap-2">
                    <AlertCircle className="h-5 w-5 text-red-600 flex-shrink-0 mt-0.5" />
                    <p className="text-sm text-red-600">{error}</p>
                  </div>
                )}

                <form onSubmit={handleSubmit} className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="email">Email</Label>
                    <div className="relative">
                      <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
                      <Input
                        id="email"
                        type="email"
                        placeholder="you@example.com"
                        className="pl-10"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        disabled={isLoading}
                      />
                    </div>
                  </div>

                  <Button type="submit" className="w-full" size="lg" disabled={isLoading}>
                    {isLoading ? (
                      <>
                        <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                        Sending...
                      </>
                    ) : (
                      "Send Reset Link"
                    )}
                  </Button>
                </form>
              </>
            ) : (
              <div className="text-center">
                <div className="mb-4 mx-auto w-16 h-16 bg-green-100 rounded-full flex items-center justify-center">
                  <CheckCircle className="h-8 w-8 text-green-600" />
                </div>
                <h2 className="text-2xl font-bold text-foreground mb-2">
                  Check your email
                </h2>
                <p className="text-muted-foreground mb-6">
                  We've sent a password reset link to <strong>{email}</strong>
                </p>
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
                  <p className="text-sm text-blue-900">
                    <strong>Didn't receive the email?</strong>
                    <br />
                    Check your spam folder or{" "}
                    <button
                      onClick={() => {
                        setIsSuccess(false);
                        setEmail("");
                      }}
                      className="text-cyan-600 hover:text-cyan-700 underline"
                    >
                      try again
                    </button>
                  </p>
                </div>
              </div>
            )}

            <div className="mt-6">
              <Link
                href="/auth/signin"
                className="flex items-center justify-center text-sm text-cyan-600 hover:text-cyan-700"
              >
                <ArrowLeft className="h-4 w-4 mr-2" />
                Back to sign in
              </Link>
            </div>
          </Card>
        </SlideIn>
      </div>
    </div>
  );
}
