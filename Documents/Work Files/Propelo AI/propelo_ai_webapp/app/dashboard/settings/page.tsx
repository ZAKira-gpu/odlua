"use client";

import * as React from "react";
import { PageContainer, PageHeader } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Select, SelectTrigger, SelectValue, SelectContent, SelectItem } from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { Bell, Shield, Zap, CreditCard, Loader2 } from "lucide-react";
import { FadeIn } from "@/components/ui/animations";
import { useAuth } from "@/lib/auth-context";
import { doc, updateDoc } from "firebase/firestore";
import { db } from "@/lib/firebase";
import toast from "react-hot-toast";

export default function SettingsPage() {
  const { user, refreshUser } = useAuth();
  const [isSaving, setIsSaving] = React.useState(false);
  const [settings, setSettings] = React.useState({
    emailNotifications: true,
    proposalOpenAlerts: true,
    weeklyReports: false,
    marketingEmails: false,
    language: "en",
    timezone: "UTC",
    theme: "light",
    autoSave: true,
  });

  // Load settings from user data
  React.useEffect(() => {
    if (user?.preferences) {
      setSettings({
        emailNotifications: user.preferences.emailNotifications ?? true,
        proposalOpenAlerts: user.preferences.proposalOpenAlerts ?? true,
        weeklyReports: user.preferences.weeklyReports ?? false,
        marketingEmails: user.preferences.marketingEmails ?? false,
        language: user.preferences.language ?? "en",
        timezone: user.preferences.timezone ?? "UTC",
        theme: user.preferences.theme ?? "light",
        autoSave: user.preferences.autoSave ?? true,
      });
    }
  }, [user]);

  const handleSave = async () => {
    if (!user) {
      toast.error("You must be logged in to save settings");
      return;
    }

    setIsSaving(true);
    
    try {
      const userRef = doc(db, "users", user.id);
      await updateDoc(userRef, {
        preferences: settings,
        updatedAt: new Date(),
      });
      
      await refreshUser();
      toast.success("Settings saved successfully!");
    } catch (error: any) {
      console.error("Save settings error:", error);
      toast.error(error.message || "Failed to save settings");
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <PageContainer>
      <div className="fixed inset-0 -z-10 gradient-mesh pointer-events-none" />
      
      <FadeIn>
        <PageHeader
          title="Settings"
          description="Manage your account preferences and security"
          breadcrumbs={
            <Breadcrumbs
              items={[
                { label: "Dashboard", href: "/dashboard" },
                { label: "Settings" },
              ]}
            />
          }
          actions={
            <Button onClick={handleSave} disabled={isSaving}>
              {isSaving ? (
                <>
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                  Saving...
                </>
              ) : (
                "Save Changes"
              )}
            </Button>
          }
        />
      </FadeIn>

      <div className="grid gap-6">
        <FadeIn delay={0.1}>
          <Card className="p-6">
            <div className="flex items-center gap-2 mb-4">
              <Bell className="h-5 w-5" />
              <h3 className="text-lg font-semibold">Notifications</h3>
            </div>
            <Separator className="mb-4" />
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div>
                  <Label htmlFor="email-notifications">Email Notifications</Label>
                  <p className="text-sm text-muted-foreground">Receive updates about your proposals</p>
                </div>
                <Switch
                  id="email-notifications"
                  checked={settings.emailNotifications}
                  onCheckedChange={(checked) => setSettings({ ...settings, emailNotifications: checked })}
                />
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <Label htmlFor="proposal-alerts">Proposal Open Alerts</Label>
                  <p className="text-sm text-muted-foreground">Get notified when clients open your proposals</p>
                </div>
                <Switch
                  id="proposal-alerts"
                  checked={settings.proposalOpenAlerts}
                  onCheckedChange={(checked) => setSettings({ ...settings, proposalOpenAlerts: checked })}
                />
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <Label htmlFor="weekly-reports">Weekly Motivation Emails</Label>
                  <p className="text-sm text-muted-foreground">Receive AI-powered tips and reminders every week</p>
                </div>
                <Switch
                  id="weekly-reports"
                  checked={settings.weeklyReports}
                  onCheckedChange={(checked) => setSettings({ ...settings, weeklyReports: checked })}
                />
              </div>
            </div>
          </Card>
        </FadeIn>

        <FadeIn delay={0.2}>
          <Card className="p-6">
            <div className="flex items-center gap-2 mb-4">
              <Zap className="h-5 w-5" />
              <h3 className="text-lg font-semibold">Preferences</h3>
            </div>
            <Separator className="mb-4" />
            <div className="space-y-4">
              <div>
                <Label htmlFor="language">Language</Label>
                <Select value={settings.language} onValueChange={(value) => setSettings({ ...settings, language: value })}>
                  <SelectTrigger id="language">
                    <SelectValue placeholder="Select language" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="en">English</SelectItem>
                    <SelectItem value="es">Spanish</SelectItem>
                    <SelectItem value="fr">French</SelectItem>
                    <SelectItem value="de">German</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label htmlFor="timezone">Timezone</Label>
                <Select value={settings.timezone} onValueChange={(value) => setSettings({ ...settings, timezone: value })}>
                  <SelectTrigger id="timezone">
                    <SelectValue placeholder="Select timezone" />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="UTC">UTC</SelectItem>
                    <SelectItem value="America/New_York">Eastern Time</SelectItem>
                    <SelectItem value="America/Chicago">Central Time</SelectItem>
                    <SelectItem value="America/Los_Angeles">Pacific Time</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div className="flex items-center justify-between">
                <div>
                  <Label htmlFor="auto-save">Auto-save drafts</Label>
                  <p className="text-sm text-muted-foreground">Automatically save your work</p>
                </div>
                <Switch
                  id="auto-save"
                  checked={settings.autoSave}
                  onCheckedChange={(checked) => setSettings({ ...settings, autoSave: checked })}
                />
              </div>
            </div>
          </Card>
        </FadeIn>
      </div>
    </PageContainer>
  );
}
