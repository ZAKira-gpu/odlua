"use client";
import * as React from "react";
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  onIdTokenChanged,
  sendEmailVerification,
  sendPasswordResetEmail,
  updateProfile,
  User as FirebaseUser,
  GoogleAuthProvider,
  signInWithPopup,
} from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { auth, db } from "./firebase";
import { User, PlanType } from "@/types";
interface AuthContextType {
  user: User | null;
  firebaseUser: FirebaseUser | null;
  loading: boolean;
  signUp: (
    email: string,
    password: string,
    firstName: string,
    lastName: string
  ) => Promise<void>;
  signIn: (email: string, password: string) => Promise<void>;
  signInWithGoogle: () => Promise<void>;
  logout: () => Promise<void>;
  resetPassword: (email: string) => Promise<void>;
  resendVerificationEmail: () => Promise<void>;
  refreshUser: () => Promise<void>;
}
const AuthContext = React.createContext<AuthContextType | undefined>(undefined);
export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = React.useState<User | null>(null);
  const [firebaseUser, setFirebaseUser] = React.useState<FirebaseUser | null>(
    null
  );
  const [loading, setLoading] = React.useState(true);

  // Helper to safely convert Firestore Timestamp or ISO string to Date
  const toDate = (value: any): Date | undefined => {
    if (!value) return undefined;
    if (value.toDate && typeof value.toDate === 'function') {
      return value.toDate();
    }
    if (value instanceof Date) {
      return value;
    }
    if (typeof value === 'string' || typeof value === 'number') {
      return new Date(value);
    }
    return undefined;
  };

  // Fetch user data from Firestore
  const fetchUserData = async (
    firebaseUser: FirebaseUser
  ): Promise<User | null> => {
    try {
      const userDoc = await getDoc(doc(db, "users", firebaseUser.uid));
      if (userDoc.exists()) {
        const data = userDoc.data();
        return {
          id: firebaseUser.uid,
          email: firebaseUser.email!,
          emailVerified: firebaseUser.emailVerified,
          firstName: data.firstName || "",
          lastName: data.lastName || "",
          profileImage: firebaseUser.photoURL || data.profileImage || "",
          bio: data.bio || "",
          primarySpecialization: data.primarySpecialization || "",
          yearsOfExperience: data.yearsOfExperience || 0,
          preferredHourlyRate: data.preferredHourlyRate || 0,
          skills: data.skills || [],
          languages: data.languages || [],
          projects: data.projects || [],
          createdAt: toDate(data.createdAt) || new Date(),
          updatedAt: toDate(data.updatedAt) || new Date(),
          subscriptionPlan: data.subscriptionPlan || "free",
          subscriptionStatus: data.subscriptionStatus || "active",
          subscriptionId: data.subscriptionId,
          currentPeriodEnd: toDate(data.currentPeriodEnd),
          proposalsUsed: data.proposalsUsed || 0,
          proposalsLimit: data.proposalsLimit || 15,
          preferredTone: data.preferredTone,
          customTone: data.customTone,
          plan: data.plan || "free",
          lastResetDate: toDate(data.lastResetDate),
          billingCycleDay: data.billingCycleDay,
          trialEndsAt: toDate(data.trialEndsAt),
          welcomeSentAt: toDate(data.welcomeSentAt),
          reengageStages: data.reengageStages,
          // Include connected accounts (synced from extension)
          accounts: data.accounts || {},
          platforms: data.platforms || {},
          preferences: data.preferences || {
            theme: "light",
            emailNotifications: true,
            proposalOpenAlerts: true,
            weeklyReports: false,
            marketingEmails: false,
            language: "en",
            timezone: "UTC",
            autoSave: true,
          },
          analytics: data.analytics,
        } as User;
      }
      return null;
    } catch (error) {
      console.error("Error fetching user data:", error);
      return null;
    }
  };
  // Sync user with backend (safe server-side initialization)
  const syncUserWithBackend = async (firebaseUser: FirebaseUser) => {
    try {
      const token = await firebaseUser.getIdToken();
      const response = await fetch("/api/auth/sync", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token }),
      });
      if (!response.ok) {
        throw new Error("Failed to sync user with backend");
      }
      const data = await response.json();
    } catch (error) {
      console.error("[Auth Context] Sync error:", error);
      // We don't throw here to allow partial login even if sync fails,
      // though app might behave oddly if user doc is missing.
    }
  };
  // Sign up with email and password
  const signUp = async (
    email: string,
    password: string,
    firstName: string,
    lastName: string
  ) => {
    try {
      const userCredential = await createUserWithEmailAndPassword(
        auth,
        email,
        password
      );
      // Update display name
      await updateProfile(userCredential.user, {
        displayName: `${firstName} ${lastName}`,
      });
      // Create user document via server API
      await syncUserWithBackend(userCredential.user);
      // Send verification email
      await sendEmailVerification(userCredential.user);
    } catch (error: any) {
      console.error("Sign up error:", error);
      throw new Error(error.message || "Failed to create account");
    }
  };
  // Sign in with email and password
  const signIn = async (email: string, password: string) => {
    try {
      await signInWithEmailAndPassword(auth, email, password);
    } catch (error: any) {
      console.error("Sign in error:", error);
      throw new Error(error.message || "Failed to sign in");
    }
  };
  // Sign in with Google (planned for later implementation)
  const signInWithGoogle = async () => {
    try {
      const provider = new GoogleAuthProvider();
      const userCredential = await signInWithPopup(auth, provider);
      // Check if user document exists, create if not
      const userDoc = await getDoc(doc(db, "users", userCredential.user.uid));
      if (!userDoc.exists()) {
        const displayName = userCredential.user.displayName || "";
        const [firstName = "", lastName = ""] = displayName.split(" ");
        // Always try to sync/create user doc via server API
        await syncUserWithBackend(userCredential.user);
      }
    } catch (error: any) {
      console.error("Google sign in error:", error);
      throw new Error(error.message || "Failed to sign in with Google");
    }
  };
  // Logout
  const logout = async () => {
    try {
      await signOut(auth);
      // Also clear server-side cookie (best-effort)
      try {
        await fetch("/api/auth/logout", { method: "POST" });
      } catch (err) {
        console.warn("Server logout failed:", err);
      }
    } catch (error: any) {
      console.error("Logout error:", error);
      throw new Error(error.message || "Failed to logout");
    }
  };
  // Reset password
  const resetPassword = async (email: string) => {
    try {
      await sendPasswordResetEmail(auth, email);
    } catch (error: any) {
      console.error("Reset password error:", error);
      throw new Error(error.message || "Failed to send reset email");
    }
  };
  // Resend verification email
  const resendVerificationEmail = async () => {
    if (!firebaseUser) {
      throw new Error("No user is currently signed in");
    }
    try {
      await sendEmailVerification(firebaseUser);
    } catch (error: any) {
      console.error("Resend verification error:", error);
      throw new Error(error.message || "Failed to resend verification email");
    }
  };
  // Refresh user data
  const refreshUser = async () => {
    if (firebaseUser) {
      await firebaseUser.reload();
      const userData = await fetchUserData(firebaseUser);
      setUser(userData);
    }
  };
  // Listen to auth state changes
  React.useEffect(() => {
    // Use onIdTokenChanged to catch token refreshes as well as sign-in/out events
    const unsubscribe = onIdTokenChanged(auth, async (firebaseUser) => {
      setLoading(true);
      if (firebaseUser) {
        setFirebaseUser(firebaseUser);
        const userData = await fetchUserData(firebaseUser);
        setUser(userData);
        // Set session cookie for middleware with secure settings
        try {
          const token = await firebaseUser.getIdToken();
          // Use Strict SameSite for better CSRF protection
          // HttpOnly cannot be set from JavaScript - that requires server-side cookie setting
          const isSecure = window.location.protocol === 'https:';
          const cookieOptions = [
            `session=${token}`,
            'path=/',
            `max-age=${60 * 60 * 24 * 7}`, // 7 days
            'SameSite=Strict',
            isSecure ? 'Secure' : '',
          ].filter(Boolean).join('; ');
          document.cookie = cookieOptions;
        } catch (error) {
          console.error("[Auth Context] Failed to get ID token:", error);
        }
      } else {
        setFirebaseUser(null);
        setUser(null);
        // Clear client cookie and attempt server-side clear as well
        document.cookie = "session=; path=/; max-age=0";
        try {
          await fetch("/api/auth/logout", { method: "POST" });
        } catch (err) {
          // non-fatal; server clear is best-effort
          console.warn("Server logout failed:", err);
        }
      }
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);
  const value: AuthContextType = {
    user,
    firebaseUser,
    loading,
    signUp,
    signIn,
    signInWithGoogle,
    logout,
    resetPassword,
    resendVerificationEmail,
    refreshUser,
  };
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
export function useAuth() {
  const context = React.useContext(AuthContext);
  if (context === undefined) {
    throw new Error("useAuth must be used within an AuthProvider");
  }
  return context;
}
