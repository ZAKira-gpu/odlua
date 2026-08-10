import { type Metadata } from "next";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export const metadata: Metadata = {
  title: "Terms of Service | Propelo AI",
  description: "Terms and conditions for using Propelo AI services.",
};

export default function TermsPage() {
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
          <h1 className="text-3xl font-bold text-slate-900 sm:text-4xl">Terms of Service</h1>
          <p className="mt-4 text-lg text-slate-600">
            Last updated: December 16, 2025
          </p>
        </div>

        <div className="prose prose-slate max-w-none bg-white p-8 rounded-2xl shadow-sm border border-slate-200">
          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">1. Agreement to Terms</h2>
            <p>
              By accessing or using the Propelo AI website, Chrome extension, or any related services (collectively, the "Service"), 
              you agree to be bound by these Terms of Service ("Terms"). If you disagree with any part of the terms, 
              you may not access the Service.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">2. Description of Service</h2>
            <p>
              Propelo AI provides an AI-powered proposal generation tool for freelancers. The Service includes:
            </p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li>A web dashboard for managing proposals and profiles.</li>
              <li>A Chrome extension for extracting job data from freelance platforms.</li>
              <li>AI generation of proposal content based on user inputs.</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">3. User Accounts</h2>
            <p>
              To access certain features, you must register for an account. You are responsible for maintaining the confidentiality 
              of your account credentials and for all activities that occur under your account. You agree to provide accurate 
              and complete information during registration.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">4. Acceptable Use</h2>
            <p>
              You agree not to use the Service to:
            </p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li>Generate content that is illegal, harmful, threatening, or discriminatory.</li>
              <li>Violate the terms of service of third-party platforms (e.g., Upwork, Fiverr).</li>
              <li>Attempt to reverse engineer the Service or access it via unauthorized automated means.</li>
              <li>Share your account credentials with third parties.</li>
            </ul>
            <p className="mt-4">
              We reserve the right to terminate or suspend your account immediately, without prior notice or liability, 
              for any reason whatsoever, including without limitation if you breach the Terms.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">5. Intellectual Property</h2>
            <p>
              The Service and its original content (excluding user-generated content), features, and functionality are and will remain 
              the exclusive property of Propelo AI and its licensors. The Service is protected by copyright, trademark, and other laws.
            </p>
            <p className="mt-2">
              You retain ownership of the proposals generated using the Service. However, you grant Propelo AI a non-exclusive license 
              to use your inputs to improve our AI models and service quality.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">6. Subscriptions and billing</h2>
            <p>
              Some parts of the Service are billed on a subscription basis. You will be billed in advance on a recurring and periodic basis 
              (such as monthly or annually).
            </p>
            <ul className="list-disc pl-6 space-y-2 mt-2">
              <li><strong>Free Trial:</strong> We may offer a limited free trial (e.g., 10 proposals).</li>
              <li><strong>Cancellation:</strong> You may cancel your subscription at any time. Your access will continue until the end of the current billing period.</li>
              <li><strong>Refunds:</strong> Refunds are handled on a case-by-case basis and are generally not provided for partial months.</li>
            </ul>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">7. Limitation of Liability</h2>
            <p>
              In no event shall Propelo AI, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, 
              incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, goodwill, 
              or other intangible losses, resulting from your access to or use of or inability to access or use the Service.
            </p>
          </section>

          <section className="mb-8">
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">8. Disclaimer</h2>
            <p>
              The Service is provided on an "AS IS" and "AS AVAILABLE" basis. The Service is provided without warranties of any kind, 
              whether express or implied, including, but not limited to, implied warranties of merchantability, fitness for a particular purpose, 
              non-infringement, or course of performance.
            </p>
            <p className="mt-2 text-slate-500 italic">
              <strong>Note:</strong> Propelo AI is an independent tool and is not affiliated with, endorsed by, or sponsored by Upwork, Fiverr, 
              or any other freelance platform.
            </p>
          </section>

          <section>
            <h2 className="text-2xl font-semibold text-slate-900 mb-4">9. Contact Us</h2>
            <p>
              If you have any questions about these Terms, please contact us at: <a href="mailto:support@propeloai.com" className="text-blue-600 hover:underline">support@propeloai.com</a>
            </p>
          </section>
        </div>
      </div>
    </div>
  );
}
