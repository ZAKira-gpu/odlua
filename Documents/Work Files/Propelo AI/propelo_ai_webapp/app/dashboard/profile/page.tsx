"use client";

import * as React from "react";
import Link from "next/link";
import { PageContainer, PageHeader, Section } from "@/components/ui/page-layout";
import { Breadcrumbs } from "@/components/ui/breadcrumbs";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Badge } from "@/components/ui/badge";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { FadeIn } from "@/components/ui/animations";
import { useAuth } from "@/lib/auth-context";
import { useUpworkProfile } from "@/lib/use-upwork-profile";
import { db } from "@/lib/firebase";
import { doc, setDoc } from "firebase/firestore";
import { 
  User, 
  Mail, 
  Calendar, 
  Star, 
  Briefcase,
  DollarSign,
  CheckCircle,
  ExternalLink,
  Download,
  RefreshCw,
  Award,
  Edit3,
  Save,
  Image as ImageIcon,
  MapPin,
  Clock,
  TrendingUp,
  Zap,
  Globe,
  FileText,
  Link as LinkIcon,
  Loader2
} from "lucide-react";
import toast from "react-hot-toast";

// Upwork profile data interface
interface UpworkProfileData {
  platform: string;
  displayName: string;
  username?: string;
  title?: string;
  profileUrl?: string;
  location?: string;
  profileImage?: string;
  hourlyRate?: number;
  hourlyRateMin?: number;
  hourlyRateMax?: number;
  jobSuccessScore?: number;
  totalEarnings?: number;
  totalJobs?: number;
  totalHours?: number;
  profileCompleteness?: number;
  isVerified?: boolean;
  isTopRated?: boolean;
  isRisingTalent?: boolean;
  skills?: string[];
  categories?: string[];
  languages?: { name: string; proficiency: string }[];
  portfolio?: { title: string; description?: string; url?: string; imageUrl?: string; skills?: string[] }[];
  rating?: number;
  reviewCount?: number;
  bio?: string;
  memberSince?: string;
  availability?: string;
  responseTime?: string;
  scrapedAt?: string | Date;
  scrapedFrom?: string;
}

const PLATFORMS = [
  { id: "upwork", name: "Upwork", icon: "🟢", lightColor: "bg-green-50", borderColor: "border-green-200", url: "https://www.upwork.com/freelancers/~" },
];

// Other platforms for future expansion
// { id: "fiverr", name: "Fiverr", icon: "🟢", lightColor: "bg-emerald-50", borderColor: "border-emerald-200", url: "https://www.fiverr.com/" },
// { id: "freelancer", name: "Freelancer", icon: "🔵", lightColor: "bg-blue-50", borderColor: "border-blue-200", url: "https://www.freelancer.com/dashboard" },
// { id: "linkedin", name: "LinkedIn", icon: "🔵", lightColor: "bg-sky-50", borderColor: "border-sky-200", url: "https://www.linkedin.com/in/" },

export default function ProfilePage() {
  const { user, refreshUser } = useAuth();
  const { 
    connected: upworkConnected, 
    profile: upworkProfile, 
    lastSynced: upworkLastSynced,
    loading: upworkLoading, 
    error: upworkError,
    refresh: refreshUpwork 
  } = useUpworkProfile({ enablePolling: false }); // Refresh on window focus is enabled by default
  
  const [isEditing, setIsEditing] = React.useState(false);
  const [isSaving, setIsSaving] = React.useState(false);
  const [isRefreshing, setIsRefreshing] = React.useState(false);
  const [editedProfile, setEditedProfile] = React.useState({ name: "", bio: "", location: "" });

  React.useEffect(() => {
    if (user) setEditedProfile({ name: user.name || "", bio: "", location: "" });
  }, [user]);

  const handleRefreshProfile = async () => {
    setIsRefreshing(true);
    try {
      await refreshUpwork();
      toast.success("Profile data refreshed!");
    } catch (error) {
      toast.error("Failed to refresh");
    } finally {
      setIsRefreshing(false);
    }
  };

  const handleSaveProfile = async () => {
    if (!user) return;
    setIsSaving(true);
    try {
      await setDoc(doc(db, "users", user.id), {
        firstName: editedProfile.name.split(" ")[0],
        lastName: editedProfile.name.split(" ").slice(1).join(" "),
        bio: editedProfile.bio,
        // location: editedProfile.location // Add to User type if needed
      }, { merge: true });
      
      await refreshUser();
      toast.success("Profile updated!");
      setIsEditing(false);
    } catch (error) {
      console.error(error);
      toast.error("Failed to save");
    } finally {
      setIsSaving(false);
    }
  };

  const connectedPlatforms = React.useMemo(() => {
    // Use the new hook data instead of auth context
    if (!upworkConnected) return [];
    return [{ 
      id: 'upwork', 
      name: 'Upwork', 
      connected: true, 
      data: upworkProfile 
    }];
  }, [upworkConnected, upworkProfile]);

  // Get Upwork stats directly from the hook
  const getUpworkStats = (): UpworkProfileData | null => {
    if (!upworkConnected || !upworkProfile) return null;
    
    const pd = upworkProfile;
    return {
      platform: pd.platform || 'upwork',
      displayName: pd.displayName || '',
      username: pd.username,
      title: pd.title,
      profileUrl: pd.profileUrl,
      location: pd.location,
      profileImage: pd.profileImage,
      hourlyRate: typeof pd.hourlyRate === 'string' ? parseFloat(pd.hourlyRate) || undefined : pd.hourlyRate,
      hourlyRateMin: pd.hourlyRateMin,
      hourlyRateMax: pd.hourlyRateMax,
      jobSuccessScore: pd.jobSuccessScore,
      totalEarnings: typeof pd.totalEarnings === 'string' ? parseFloat(pd.totalEarnings.replace(/[^0-9.]/g, '')) || undefined : pd.totalEarnings,
      totalJobs: pd.totalJobs,
      totalHours: pd.totalHours,
      profileCompleteness: pd.profileCompleteness,
      isVerified: pd.isVerified,
      isTopRated: pd.isTopRated,
      isRisingTalent: pd.isRisingTalent,
      skills: pd.skills,
      categories: pd.categories,
      languages: pd.languages as any,
      portfolio: pd.portfolio as any,
      bio: pd.description || pd.overview,
      scrapedAt: pd.scrapedAt || pd.syncedAt,
    };
  };

  // Legacy function for backwards compatibility
  const getPlatformStats = (id: string): UpworkProfileData | null => {
    if (id !== 'upwork') return null;
    return getUpworkStats();
  };

  return (
    <PageContainer>
      <div className="fixed inset-0 -z-10 gradient-mesh pointer-events-none" />
      

      
      <FadeIn>
        <PageHeader
          title="Profile"
          description="Manage your profile and connected accounts"
          breadcrumbs={<Breadcrumbs items={[{ label: "Dashboard", href: "/dashboard" }, { label: "Profile" }]} />}
        />
      </FadeIn>

      <div className="space-y-8">
        <FadeIn delay={0.1}>
          <Card className="p-6">
            <div className="flex flex-col md:flex-row gap-6">
              <Avatar className="w-24 h-24">
                <AvatarImage src={user?.image} />
                <AvatarFallback className="text-2xl bg-gradient-to-br from-cyan-500 to-teal-600 text-white">
                  {user?.name?.split(" ").map(n => n[0]).join("").toUpperCase() || "U"}
                </AvatarFallback>
              </Avatar>
              
              <div className="flex-1 space-y-4">
                {isEditing ? (
                  <>
                    <Input placeholder="Your name" value={editedProfile.name} onChange={(e) => setEditedProfile(prev => ({ ...prev, name: e.target.value }))} />
                    <Input placeholder="Location" value={editedProfile.location} onChange={(e) => setEditedProfile(prev => ({ ...prev, location: e.target.value }))} />
                    <Textarea placeholder="Short bio" value={editedProfile.bio} onChange={(e) => setEditedProfile(prev => ({ ...prev, bio: e.target.value }))} rows={3} />
                    <div className="flex gap-2">
                      <Button onClick={handleSaveProfile} disabled={isSaving}><Save className="h-4 w-4 mr-2" />{isSaving ? "Saving..." : "Save"}</Button>
                      <Button variant="outline" onClick={() => setIsEditing(false)}>Cancel</Button>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="flex items-center justify-between">
                      <div>
                        <h2 className="text-2xl font-bold text-gray-900">{user?.name || "User"}</h2>
                        <p className="text-gray-500 flex items-center gap-2 mt-1"><Mail className="h-4 w-4" />{user?.email}</p>
                      </div>
                      <Button variant="outline" onClick={() => setIsEditing(true)}><Edit3 className="h-4 w-4 mr-2" />Edit</Button>
                    </div>
                    <div className="flex flex-wrap gap-4 pt-2">
                      <Badge variant="outline" className="text-sm py-1 px-3"><User className="h-4 w-4 mr-1" />{user?.subscriptionPlan === "pro" ? "Pro" : user?.subscriptionPlan === "starter" ? "Starter" : "Free"}</Badge>
                      <Badge variant="outline" className="text-sm py-1 px-3"><Calendar className="h-4 w-4 mr-1" />Member since {user?.createdAt ? new Date(user.createdAt).toLocaleDateString() : "Recently"}</Badge>
                      <Badge variant="outline" className="text-sm py-1 px-3"><Briefcase className="h-4 w-4 mr-1" />{user?.proposalsUsed || 0} / {user?.proposalsLimit || 10} Proposals</Badge>
                    </div>
                  </>
                )}
              </div>
            </div>
          </Card>
        </FadeIn>

        <Section>
          <FadeIn delay={0.2}>
            <div className="flex items-center justify-between mb-6">
              <div>
                <h2 className="text-xl font-bold text-gray-900">Upwork Profile</h2>
                <p className="text-gray-500 mt-1">Your synced freelance profile data</p>
              </div>
              <Button 
                variant="outline" 
                onClick={() => refreshUpwork()}
                disabled={upworkLoading}
              >
                {upworkLoading ? (
                  <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                ) : (
                  <RefreshCw className="h-4 w-4 mr-2" />
                )}
                Refresh
              </Button>
            </div>
          </FadeIn>

          {/* Loading State */}
          {upworkLoading && (
            <FadeIn delay={0.25}>
              <Card className="p-6 mb-6">
                <div className="flex items-center justify-center gap-3 py-8">
                  <Loader2 className="h-6 w-6 text-cyan-600 animate-spin" />
                  <p className="text-gray-500">Loading Upwork profile...</p>
                </div>
              </Card>
            </FadeIn>
          )}

          {/* Error State */}
          {upworkError && !upworkLoading && (
            <FadeIn delay={0.25}>
              <Card className="p-6 mb-6 bg-red-50 border-red-200">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center">
                    <Zap className="h-5 w-5 text-red-600" />
                  </div>
                  <div>
                    <h3 className="font-semibold text-red-900">Failed to load profile</h3>
                    <p className="text-red-700 text-sm">{upworkError}</p>
                  </div>
                  <Button 
                    variant="outline" 
                    size="sm" 
                    className="ml-auto"
                    onClick={() => refreshUpwork()}
                  >
                    <RefreshCw className="h-4 w-4 mr-2" />
                    Retry
                  </Button>
                </div>
              </Card>
            </FadeIn>
          )}

          {/* Not Connected State */}
          {!upworkConnected && !upworkLoading && !upworkError && (
            <FadeIn delay={0.25}>
              <Card className="p-6 mb-6 bg-gradient-to-r from-cyan-50 to-teal-50 border-cyan-200">
                <div className="flex flex-col md:flex-row items-center gap-4">
                  <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-cyan-500 to-teal-600 flex items-center justify-center">
                    <Download className="h-8 w-8 text-white" />
                  </div>
                  <div className="flex-1 text-center md:text-left">
                    <h3 className="text-lg font-bold text-cyan-900">Connect Your Upwork Profile</h3>
                    <p className="text-cyan-700 mt-1">Install the Chrome extension and sync your profile to generate personalized proposals.</p>
                  </div>
                  <Link href="/dashboard/connect#extension">
                    <Button className="bg-cyan-600 hover:bg-cyan-700"><Download className="h-4 w-4 mr-2" />Get Extension<ExternalLink className="h-4 w-4 ml-2" /></Button>
                  </Link>
                </div>
              </Card>
            </FadeIn>
          )}

          {/* Upwork Profile Display */}
          {upworkConnected && !upworkLoading && (() => {
            const stats = getUpworkStats();
            if (!stats) return null;
            
            return (
              <FadeIn delay={0.3}>
                <div className="space-y-6">
                  {/* Sync Status Bar */}
                  <div className="flex items-center justify-between px-4 py-2 bg-gray-50 rounded-lg">
                    <div className="flex items-center gap-2 text-sm text-gray-500">
                      <CheckCircle className="h-4 w-4 text-green-500" />
                      <span>Synced from Upwork</span>
                      {upworkLastSynced && (
                        <span className="text-gray-400">
                          • Last updated {new Date(upworkLastSynced).toLocaleString()}
                        </span>
                      )}
                    </div>
                    <Button 
                      variant="ghost" 
                      size="sm"
                      onClick={handleRefreshProfile}
                      disabled={isRefreshing}
                      className="text-gray-500 hover:text-gray-700"
                    >
                      <RefreshCw className={`h-4 w-4 mr-1 ${isRefreshing ? 'animate-spin' : ''}`} />
                      {isRefreshing ? 'Refreshing...' : 'Refresh'}
                    </Button>
                  </div>

                  {/* Profile Header Card */}
                  <Card className="p-6 border-green-200 border-2">
                    <div className="flex flex-col md:flex-row gap-6">
                      {/* Profile Image */}
                      <div className="flex-shrink-0">
                        <Avatar className="w-24 h-24 ring-4 ring-green-100">
                          <AvatarImage src={stats.profileImage} />
                          <AvatarFallback className="text-2xl bg-gradient-to-br from-green-500 to-emerald-600 text-white">
                            {stats.displayName?.split(" ").map(n => n[0]).join("").toUpperCase() || "U"}
                          </AvatarFallback>
                        </Avatar>
                      </div>
                      
                      {/* Profile Info */}
                      <div className="flex-1 space-y-3">
                        <div className="flex flex-wrap items-center gap-2">
                          <h3 className="text-2xl font-bold text-gray-900">{stats.displayName}</h3>
                          {stats.isTopRated && (
                            <Badge className="bg-yellow-100 text-yellow-700 border-yellow-200">
                              <Award className="h-3 w-3 mr-1" /> Top Rated
                            </Badge>
                          )}
                          {stats.isRisingTalent && (
                            <Badge className="bg-blue-100 text-blue-700 border-blue-200">
                              <TrendingUp className="h-3 w-3 mr-1" /> Rising Talent
                            </Badge>
                          )}
                          {stats.isVerified && (
                            <Badge className="bg-green-100 text-green-700 border-green-200">
                              <CheckCircle className="h-3 w-3 mr-1" /> Verified
                            </Badge>
                          )}
                        </div>
                        
                        {stats.title && (
                          <p className="text-lg text-gray-600">{stats.title}</p>
                        )}
                        
                        <div className="flex flex-wrap gap-4 text-sm text-gray-500">
                          {stats.location && (
                            <span className="flex items-center gap-1">
                              <MapPin className="h-4 w-4" /> {stats.location}
                            </span>
                          )}
                          {stats.memberSince && (
                            <span className="flex items-center gap-1">
                              <Calendar className="h-4 w-4" /> Member since {stats.memberSince}
                            </span>
                          )}
                          {stats.responseTime && (
                            <span className="flex items-center gap-1">
                              <Clock className="h-4 w-4" /> {stats.responseTime}
                            </span>
                          )}
                        </div>
                        
                        {stats.profileUrl && (
                          <a 
                            href={stats.profileUrl} 
                            target="_blank" 
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 text-sm text-cyan-600 hover:text-cyan-700"
                          >
                            <LinkIcon className="h-4 w-4" /> View on Upwork
                            <ExternalLink className="h-3 w-3" />
                          </a>
                        )}
                      </div>
                    </div>
                  </Card>

                  {/* Stats Grid */}
                  <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                    {stats.jobSuccessScore !== undefined && (
                      <Card className="p-4 text-center bg-gradient-to-br from-green-50 to-emerald-50 border-green-200">
                        <div className="w-12 h-12 mx-auto mb-2 rounded-xl bg-green-100 flex items-center justify-center">
                          <Award className="h-6 w-6 text-green-600" />
                        </div>
                        <p className="text-2xl font-bold text-green-700">{stats.jobSuccessScore}%</p>
                        <p className="text-sm text-green-600">Job Success</p>
                      </Card>
                    )}
                    
                    {stats.hourlyRate !== undefined && (
                      <Card className="p-4 text-center bg-gradient-to-br from-cyan-50 to-teal-50 border-cyan-200">
                        <div className="w-12 h-12 mx-auto mb-2 rounded-xl bg-cyan-100 flex items-center justify-center">
                          <DollarSign className="h-6 w-6 text-cyan-600" />
                        </div>
                        <p className="text-2xl font-bold text-cyan-700">${stats.hourlyRate}/hr</p>
                        <p className="text-sm text-cyan-600">Hourly Rate</p>
                      </Card>
                    )}
                    
                    {stats.totalEarnings !== undefined && (
                      <Card className="p-4 text-center bg-gradient-to-br from-emerald-50 to-green-50 border-emerald-200">
                        <div className="w-12 h-12 mx-auto mb-2 rounded-xl bg-emerald-100 flex items-center justify-center">
                          <TrendingUp className="h-6 w-6 text-emerald-600" />
                        </div>
                        <p className="text-2xl font-bold text-emerald-700">
                          ${typeof stats.totalEarnings === 'number' ? stats.totalEarnings.toLocaleString() : stats.totalEarnings}
                        </p>
                        <p className="text-sm text-emerald-600">Total Earned</p>
                      </Card>
                    )}
                    
                    {stats.totalJobs !== undefined && (
                      <Card className="p-4 text-center bg-gradient-to-br from-blue-50 to-indigo-50 border-blue-200">
                        <div className="w-12 h-12 mx-auto mb-2 rounded-xl bg-blue-100 flex items-center justify-center">
                          <Briefcase className="h-6 w-6 text-blue-600" />
                        </div>
                        <p className="text-2xl font-bold text-blue-700">{stats.totalJobs}</p>
                        <p className="text-sm text-blue-600">Jobs Completed</p>
                      </Card>
                    )}
                    
                    {stats.totalHours !== undefined && (
                      <Card className="p-4 text-center bg-gradient-to-br from-purple-50 to-violet-50 border-purple-200">
                        <div className="w-12 h-12 mx-auto mb-2 rounded-xl bg-purple-100 flex items-center justify-center">
                          <Clock className="h-6 w-6 text-purple-600" />
                        </div>
                        <p className="text-2xl font-bold text-purple-700">{stats.totalHours.toLocaleString()}</p>
                        <p className="text-sm text-purple-600">Hours Worked</p>
                      </Card>
                    )}
                    
                    {stats.rating !== undefined && (
                      <Card className="p-4 text-center bg-gradient-to-br from-yellow-50 to-amber-50 border-yellow-200">
                        <div className="w-12 h-12 mx-auto mb-2 rounded-xl bg-yellow-100 flex items-center justify-center">
                          <Star className="h-6 w-6 text-yellow-600" />
                        </div>
                        <p className="text-2xl font-bold text-yellow-700">{stats.rating}</p>
                        <p className="text-sm text-yellow-600">Rating {stats.reviewCount ? `(${stats.reviewCount} reviews)` : ''}</p>
                      </Card>
                    )}
                  </div>

                  {/* Bio Section */}
                  {stats.bio && (
                    <Card className="p-6">
                      <h4 className="font-semibold text-gray-900 mb-3 flex items-center gap-2">
                        <FileText className="h-5 w-5 text-gray-400" /> Professional Overview
                      </h4>
                      <p className="text-gray-600 whitespace-pre-wrap leading-relaxed">{stats.bio}</p>
                    </Card>
                  )}

                  {/* Skills Section */}
                  {stats.skills && stats.skills.length > 0 && (
                    <Card className="p-6">
                      <h4 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
                        <Zap className="h-5 w-5 text-gray-400" /> Skills ({stats.skills.length})
                      </h4>
                      <div className="flex flex-wrap gap-2">
                        {stats.skills.map((skill, idx) => (
                          <Badge key={idx} variant="secondary" className="px-3 py-1 text-sm bg-gray-100 hover:bg-gray-200 transition-colors">
                            {skill}
                          </Badge>
                        ))}
                      </div>
                    </Card>
                  )}

                  {/* Languages Section */}
                  {stats.languages && stats.languages.length > 0 && (
                    <Card className="p-6">
                      <h4 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
                        <Globe className="h-5 w-5 text-gray-400" /> Languages
                      </h4>
                      <div className="flex flex-wrap gap-3">
                        {stats.languages.map((lang, idx) => (
                          <div key={idx} className="flex items-center gap-2 px-3 py-2 rounded-lg bg-gray-50 border border-gray-200">
                            <span className="font-medium text-gray-800">{lang.name}</span>
                            <span className="text-sm text-gray-500 capitalize">({lang.proficiency})</span>
                          </div>
                        ))}
                      </div>
                    </Card>
                  )}

                  {/* Categories Section */}
                  {stats.categories && stats.categories.length > 0 && (
                    <Card className="p-6">
                      <h4 className="font-semibold text-gray-900 mb-4 flex items-center gap-2">
                        <Briefcase className="h-5 w-5 text-gray-400" /> Categories
                      </h4>
                      <div className="flex flex-wrap gap-2">
                        {stats.categories.map((category, idx) => (
                          <Badge key={idx} className="bg-cyan-100 text-cyan-700 border-cyan-200">
                            {category}
                          </Badge>
                        ))}
                      </div>
                    </Card>
                  )}

                  {/* Last Synced */}
                  {stats.scrapedAt && (
                    <p className="text-sm text-gray-400 text-center">
                      Last synced: {new Date(stats.scrapedAt).toLocaleString()}
                    </p>
                  )}
                </div>
              </FadeIn>
            );
          })()}
        </Section>

        {/* Portfolio Section */}
        {connectedPlatforms.length > 0 && (() => {
          const stats = getPlatformStats('upwork');
          if (!stats?.portfolio || stats.portfolio.length === 0) return null;
          
          return (
            <Section>
              <FadeIn delay={0.5}>
                <h2 className="text-xl font-bold text-gray-900 mb-4 flex items-center gap-2">
                  <ImageIcon className="h-5 w-5 text-gray-400" /> Portfolio ({stats.portfolio.length} projects)
                </h2>
                <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
                  {stats.portfolio.map((item, idx) => (
                    <Card key={idx} className="overflow-hidden hover:shadow-lg transition-shadow group">
                      <div className="aspect-video bg-gray-100 flex items-center justify-center relative">
                        {item.imageUrl ? (
                          <img src={item.imageUrl} alt={item.title} className="w-full h-full object-cover" />
                        ) : (
                          <ImageIcon className="h-12 w-12 text-gray-300" />
                        )}
                        {item.url && (
                          <a 
                            href={item.url} 
                            target="_blank" 
                            rel="noopener noreferrer"
                            className="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center"
                          >
                            <ExternalLink className="h-8 w-8 text-white" />
                          </a>
                        )}
                      </div>
                      <div className="p-4">
                        <h4 className="font-medium text-gray-900 line-clamp-2">{item.title || "Untitled"}</h4>
                        {item.description && (
                          <p className="text-sm text-gray-500 mt-1 line-clamp-2">{item.description}</p>
                        )}
                        {item.skills && item.skills.length > 0 && (
                          <div className="flex flex-wrap gap-1 mt-2">
                            {item.skills.slice(0, 3).map((skill, i) => (
                              <Badge key={i} variant="secondary" className="text-xs">{skill}</Badge>
                            ))}
                            {item.skills.length > 3 && (
                              <Badge variant="secondary" className="text-xs">+{item.skills.length - 3}</Badge>
                            )}
                          </div>
                        )}
                      </div>
                    </Card>
                  ))}
                </div>
              </FadeIn>
            </Section>
          );
        })()}
      </div>
    </PageContainer>
  );
}
