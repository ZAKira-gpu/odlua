"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

export default function Home() {
  const router = useRouter();
  const { user, loading } = useAuth();

  React.useEffect(() => {
    if (!loading) {
      if (user) {
        router.replace("/dashboard");
      } else {
        router.replace("/auth/signin");
      }
    }
  }, [user, loading, router]);

  // Show loading spinner while determining auth state
  return (
    <div className="min-h-screen flex items-center justify-center bg-gradient-to-br from-cyan-50 via-white to-teal-50">
      <div className="text-center">
        <img src="/logo-banner.png" alt="Propelo AI" className="w-56 h-auto mx-auto mb-6 object-contain animate-pulse" />
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-cyan-500 mx-auto"></div>
        <p className="mt-4 text-gray-600">Loading Propelo AI...</p>
      </div>
    </div>
  );
}
