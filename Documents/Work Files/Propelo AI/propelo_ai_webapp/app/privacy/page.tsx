import { type Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Privacy Policy | Propelo AI",
  description: "Privacy policy and data handling practices for Propelo AI.",
};

export default function PrivacyPage() {
  return (
    <div className="min-h-screen bg-slate-50">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div className="mb-8">
          <Link 
            href="/"
            className="inline-flex items-center text-sm text-slate-500 hover:text-blue-600 transition-colors mb-6"
          >
            <ArrowLeft className="w-4 h-4 mr-2" />
            Back to Home
          </Link>
          <h1 className="text-3xl font-bold text-slate-900 sm:text-4xl">Privacy Policy</h1>
          <p className="mt-4 text-lg text-slate-600">
            Last updated: December 16, 2025
          </p>
        </div>

        <div className="prose prose-slate max-w-none bg-white p-8 rounded-2xl shadow-sm border border-slate-200">
          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">1. Introduction</h2>
            <p>
              Propelo AI ("we," "our," or "us") respects your privacy and is committed to protecting your personal data. 
              This privacy policy will inform you as to how we look after your personal data when you visit our website 
              and use our Chrome extension and services.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">2. Data We Collect</h2>
            <p>We collect and process the following types of information:</p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li><strong>Account Information:</strong> Name, email address, profile picture (via Google Auth), and billing details.</li>
              <li><strong>Usage Data:</strong> Information about how you use our website and extension, such as proposal generation counts.</li>
              <li><strong>User Content:</strong> Data you input for proposal generation, including scraping data (job descriptions, client names) and your professional profile information.</li>
              <li><strong>Technical Data:</strong> IP address, browser type and version, time zone setting, operating system, and platform.</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">3. How We Use Your Data</h2>
            <p>We use your data to:</p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li>Provide and maintain our Service (e.g., generating proposals).</li>
              <li>Process your payments and manage your subscription.</li>
              <li>Notify you about changes to our Service.</li>
              <li>Provide customer support.</li>
              <li>Monitor the usage of our Service to detect, prevent, and address technical issues.</li>
              <li>Improve our AI models (anonymized data only).</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">4. Chrome Extension Privacy</h2>
            <p>
              Our Chrome extension collects data specific to its function:
            </p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li>It reads content only from specific freelance platform URLs (e.g., Upwork, Fiverr) when you explicitly trigger it or enable auto-sync.</li>
              <li>It extracts job details (title, description, budget) and profile stats to generate relevant proposals.</li>
              <li>We do <strong>not</strong> collect your browsing history or data from other websites.</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">5. Data Sharing</h2>
            <p>
              We do not sell your personal data. We may share your data with:
            </p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li><strong>Service Providers:</strong> Third-party companies that perform services on our behalf (e.g., OpenAI for text generation, LemonSqueezy for payments, Google Firebase for authentication and hosting).</li>
              <li><strong>Legal Requirements:</strong> If required by law or in response to valid requests by public authorities.</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">6. Data Security</h2>
            <p>
              We have put in place appropriate security measures to prevent your personal data from being accidentally lost, used, 
              or accessed in an unauthorized way. Access to your personal data is limited to those employees, agents, contractors, 
              and other third parties who have a business need to know.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">7. Your Rights</h2>
            <p>
              Depending on your location, you may have rights under data privacy laws, including the right to access, correct, 
              or delete your personal data. To exercise these rights, please contact us.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">8. Contact Us</h2>
            <p>
              If you have any questions about this Privacy Policy, please contact us at: <a href="mailto:privacy@propeloai.com" className="text-blue-600 hover:underline">privacy@propeloai.com</a>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
