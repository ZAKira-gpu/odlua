"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  FileText,
  History,
  BarChart3,
  Sparkles,
  Users,
  FileEdit,
  User,
  Settings,
  LogOut,
  ChevronLeft,
  ChevronRight,
  Crown,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar";
import { UsageTracker } from "@/components/ui/usage-tracker";
import { cn } from "@/lib/utils";

const navigation = [
  { name: "Generator", href: "/dashboard/generator", icon: Sparkles },
  { name: "History", href: "/dashboard/history", icon: History },
  { name: "Analytics", href: "/dashboard/analytics", icon: BarChart3 },
  { name: "Enhancer", href: "/dashboard/enhancer", icon: FileEdit },
];

const bottomNavigation = [
  { name: "Plans", href: "/dashboard/subscription", icon: Crown, highlight: true },
  { name: "Profile", href: "/dashboard/profile", icon: User },
  { name: "Settings", href: "/dashboard/settings", icon: Settings },
];

interface SidebarProps {
  user?: {
    name: string;
    email: string;
    image?: string;
    proposalsUsed: number;
    proposalsLimit: number;
  };
  onSignOut?: () => void;
}

export function Sidebar({ user, onSignOut }: SidebarProps) {
  const pathname = usePathname();
  const [collapsed, setCollapsed] = React.useState(false);

  return (
    <div
      className={cn(
        "flex flex-col h-screen bg-sidebar border-r border-sidebar-border transition-all duration-300 ease-in-out z-20 shadow-sm relative",
        collapsed ? "w-20" : "w-64"
      )}
    >
      {/* Header */}
      <div className="flex items-center justify-between p-6 border-b border-sidebar-border/50 h-[80px]">
        {!collapsed && (
          <Link href="/" className="flex items-center gap-2 group">
            <img 
              src="/logo-banner.png" 
              alt="Propelo" 
              className="h-8 w-auto object-contain transition-transform group-hover:scale-105" 
            />
          </Link>
        )}
        {collapsed && (
          <Link href="/" className="flex items-center justify-center w-full group">
            <img 
              src="/logo-icon.png" 
              alt="Propelo" 
              className="h-8 w-8 object-contain transition-transform group-hover:scale-110" 
            />
          </Link>
        )}
      </div>
      
      {/* Collapse Button - Floating */}
      <Button
        variant="outline"
        size="icon"
        onClick={() => setCollapsed(!collapsed)}
        className="absolute -right-3 top-24 h-6 w-6 rounded-full border-sidebar-border bg-sidebar shadow-md hover:bg-sidebar-accent transition-all z-30"
      >
        {collapsed ? (
          <ChevronRight className="h-3 w-3 text-sidebar-foreground" />
        ) : (
          <ChevronLeft className="h-3 w-3 text-sidebar-foreground" />
        )}
      </Button>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-1.5 overflow-y-auto no-scrollbar">
        {navigation.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200 group relative overflow-hidden",
                isActive
                  ? "bg-sidebar-accent text-sidebar-primary font-semibold shadow-sm"
                  : "text-sidebar-foreground/70 hover:bg-sidebar-accent/50 hover:text-sidebar-foreground"
              )}
            >
              <span className={cn(
                "absolute left-0 top-1/2 -translate-y-1/2 w-1 h-8 bg-sidebar-primary rounded-r-full transition-all duration-200",
                isActive ? "opacity-100" : "opacity-0 -translate-x-full"
              )} />
              
              <item.icon className={cn(
                "h-5 w-5 flex-shrink-0 transition-colors", 
                isActive ? "text-sidebar-primary" : "text-slate-400 group-hover:text-sidebar-foreground"
              )} />
              
              {!collapsed && (
                <span className="text-sm truncate animate-fade-in">
                  {item.name}
                </span>
              )}
            </Link>
          );
        })}
      </nav>

      {/* Usage Tracker */}
      {!collapsed && user && (
        <div className="px-4 pb-4 animate-fade-in">
          <UsageTracker
            used={user.proposalsUsed}
            limit={user.proposalsLimit}
            label="Monthly Credits"
            upgradeLink="/dashboard/subscription"
            className="bg-sidebar-accent/50 border-sidebar-border/50 shadow-none hover:shadow-sm transition-all"
          />
        </div>
      )}

      {/* Bottom Navigation */}
      <div className="p-4 border-t border-sidebar-border/50 space-y-1.5 bg-sidebar/50">
        {bottomNavigation.map((item) => {
          const isActive = pathname === item.href;
          const isHighlight = 'highlight' in item && item.highlight;
          
          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all duration-200 group",
                isActive
                  ? "bg-sidebar-accent text-sidebar-primary font-medium"
                  : isHighlight
                  ? "text-amber-600 hover:bg-amber-50/50 dark:hover:bg-amber-900/20"
                  : "text-sidebar-foreground/70 hover:bg-sidebar-accent/50 hover:text-sidebar-foreground"
              )}
            >
              <item.icon className={cn(
                "h-5 w-5 flex-shrink-0", 
                isActive ? "text-sidebar-primary" : isHighlight ? "text-amber-500" : "text-slate-400 group-hover:text-sidebar-foreground"
              )} />
              {!collapsed && <span className="text-sm">{item.name}</span>}
            </Link>
          );
        })}

        {onSignOut && (
          <Button
            variant="ghost"
            onClick={onSignOut}
            className="w-full justify-start text-slate-500 hover:bg-red-50 hover:text-red-600 dark:hover:bg-red-900/20 rounded-xl px-3"
          >
            <LogOut className="h-5 w-5 mr-3" />
            {!collapsed && <span className="text-sm">Sign Out</span>}
          </Button>
        )}
      </div>

      {/* User Profile */}
      {user && !collapsed && (
          <div className="p-4 border-t border-sidebar-border/50 bg-sidebar-accent/20">
            <div className="flex items-center gap-3 p-2 rounded-xl hover:bg-sidebar-accent transition-colors cursor-pointer group">
              <Avatar className="h-9 w-9 border border-sidebar-border shadow-sm">
                <AvatarImage src={user.image} />
                <AvatarFallback className="bg-gradient-to-br from-cyan-500 to-teal-500 text-white text-sm font-medium">
                  {user.name.split(" ").map((n) => n[0]).join("").toUpperCase().slice(0, 2)}
                </AvatarFallback>
              </Avatar>
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-sidebar-foreground truncate group-hover:text-sidebar-primary transition-colors">{user.name}</p>
                <p className="text-xs text-sidebar-foreground/60 truncate">{user.email}</p>
              </div>
            </div>
          </div>
      )}
    </div>
  );
}
