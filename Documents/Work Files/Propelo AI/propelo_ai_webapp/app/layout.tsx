import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Head from 'next/head';
import { Toaster } from "react-hot-toast";
import { AuthProvider } from "@/lib/auth-context";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter" });

export const metadata: Metadata = {
  title: "Propelo AI - AI-Powered Freelance Proposal Writer",
  description: "From writing to winning, AI supercharges freelancing. Generate winning proposals in seconds.",
  keywords: ["freelance", "proposals", "AI", "Upwork", "Fiverr", "proposal writer"],
  authors: [{ name: "Propelo AI" }],
  openGraph: {
    title: "Propelo AI - AI-Powered Freelance Proposal Writer",
    description: "Generate winning freelance proposals in seconds with AI",
    type: "website",
    url: "https://propelo.ai",
  },
  twitter: {
    card: "summary_large_image",
    title: "Propelo AI - AI-Powered Freelance Proposal Writer",
    description: "Generate winning freelance proposals in seconds with AI",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <Head>
        <link rel="icon" type="image/png" sizes="64x64" href="/favicon-64.png" />
        <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png" />
        <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png" />
        <meta name="theme-color" content="#00C2FF" />
      </Head>
      <body className={inter.className}>
        <AuthProvider>
          {children}
          <Toaster 
            position="top-right"
            toastOptions={{
              duration: 4000,
              style: {
                background: '#fff',
                color: '#334155',
                border: '1px solid #e2e8f0',
                borderRadius: '0.5rem',
                padding: '1rem',
              },
              success: {
                iconTheme: {
                  primary: '#0EA5E9',
                  secondary: '#fff',
                },
              },
            }}
          />
        </AuthProvider>
      </body>
    </html>
  );
}


