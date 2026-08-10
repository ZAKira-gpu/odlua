"use client";

import * as React from "react";
import { Sidebar } from "@/components/dashboard/sidebar";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth-context";

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const { user, logout } = useAuth();

  const handleSignOut = async () => {
    await logout();
    router.push("/auth/signin");
  };

  return (
    <div className="flex h-screen overflow-hidden bg-[rgb(var(--background))]">
      <Sidebar 
        user={user ? {
          name: user.name || user.firstName || "User",
          email: user.email,
          image: user.image || user.profileImage,
          proposalsUsed: user.proposalsUsed || 0,
          proposalsLimit: user.proposalsLimit || 10
        } : undefined} 
        onSignOut={handleSignOut} 
      />
      <main className="flex-1 overflow-y-auto">
        {children}
      </main>
    </div>
  );
}
