const APP_URL = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000';

import { createHmac } from 'crypto';

/**
 * Generate a secure unsubscribe token using HMAC
 */
function generateUnsubscribeToken(email: string): string {
  const secret = process.env.UNSUBSCRIBE_SECRET || process.env.CSRF_SECRET || process.env.NEXTAUTH_SECRET || 'dev-secret';
  const hmac = createHmac('sha256', secret);
  hmac.update(email.toLowerCase());
  return hmac.digest('hex');
}

/**
 * Generate unsubscribe URL with secure token
 */
function getUnsubscribeUrl(email: string): string {
  const token = generateUnsubscribeToken(email);
  return `${APP_URL}/api/email/unsubscribe?email=${encodeURIComponent(email)}&token=${token}`;
}

// Base email styles
const baseStyles = `
  body { 
    font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
    background: #f4f4f4; 
    padding: 20px; 
    margin: 0;
  }
  .container { 
    max-width: 600px; 
    margin: 0 auto; 
    background: white; 
    border-radius: 12px; 
    padding: 40px; 
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  }
  .header { 
    text-align: center; 
    margin-bottom: 30px; 
  }
  .logo { 
    font-size: 28px; 
    font-weight: bold; 
    color: #6366f1; 
  }
  h1 { 
    color: #1f2937; 
    margin-bottom: 20px; 
    font-size: 24px;
  }
  p { 
    color: #4b5563; 
    line-height: 1.6; 
    margin-bottom: 16px;
  }
  ul {
    color: #4b5563;
    line-height: 1.8;
    padding-left: 20px;
  }
  li {
    margin-bottom: 8px;
  }
  .cta { 
    display: inline-block; 
    background: #6366f1; 
    color: white !important; 
    padding: 14px 28px; 
    text-decoration: none; 
    border-radius: 8px; 
    margin-top: 20px;
    font-weight: 600;
  }
  .cta:hover {
    background: #4f46e5;
  }
  .footer { 
    text-align: center; 
    margin-top: 40px; 
    padding-top: 20px;
    border-top: 1px solid #e5e7eb;
    color: #9ca3af; 
    font-size: 12px; 
  }
  .footer a {
    color: #6366f1;
    text-decoration: none;
  }
`;

export function getWelcomeEmailTemplate(name: string): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Welcome to Propelo</title>
      <style>${baseStyles}</style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Propelo</div>
        </div>
        <h1>Welcome aboard, ${escapeHtml(name)}! 🎉</h1>
        <p>We're thrilled to have you join Propelo. You've just taken the first step toward supercharging your freelance career with the power of AI.</p>
        <p>Here's what you can do now:</p>
        <ul>
          <li><strong>Generate Proposals</strong> - Let AI craft winning proposals for you</li>
          <li><strong>Enhance Your Profile</strong> - Stand out from the competition</li>
          <li><strong>Track Analytics</strong> - Monitor your success rate</li>
          <li><strong>Connect Platforms</strong> - Link your freelance accounts</li>
        </ul>
        <p>Ready to land your next gig?</p>
        <a href="${APP_URL}/dashboard" class="cta">Go to Dashboard</a>
        <div class="footer">
          <p>© ${new Date().getFullYear()} Propelo. All rights reserved.</p>
          <p>You received this email because you signed up for Propelo.</p>
        </div>
      </div>
    </body>
    </html>
  `;
}

export function getWeeklyReminderTemplate(name: string, aiMessage: string, email: string): string {
  const unsubscribeUrl = getUnsubscribeUrl(email);
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Your Weekly Propelo Check-in</title>
      <style>
        ${baseStyles}
        .ai-message { 
          background: linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%);
          border-left: 4px solid #6366f1; 
          padding: 20px; 
          margin: 24px 0; 
          border-radius: 0 8px 8px 0;
        }
        .ai-message strong {
          color: #6366f1;
        }
        .stats-box {
          background: #f9fafb;
          border-radius: 8px;
          padding: 20px;
          margin: 20px 0;
          text-align: center;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Propelo</div>
        </div>
        <h1>Hey ${escapeHtml(name)}, here's your weekly boost! 💪</h1>
        <p>Another week, another opportunity to grow your freelance business. Here's a little motivation to keep you going:</p>
        <div class="ai-message">
          <strong>🤖 AI Motivation:</strong>
          <p style="margin-bottom: 0; margin-top: 12px;">${escapeHtml(aiMessage)}</p>
        </div>
        <p>Don't let another week slip by without making progress. Your next big client could be just one proposal away!</p>
        <a href="${APP_URL}/dashboard/generator" class="cta">Generate a Proposal</a>
        <div class="footer">
          <p>© ${new Date().getFullYear()} Propelo. All rights reserved.</p>
          <p>
            <a href="${APP_URL}/dashboard/settings">Manage Preferences</a> · 
            <a href="${unsubscribeUrl}">Unsubscribe</a>
          </p>
        </div>
      </div>
    </body>
    </html>
  `;
}

export function getPasswordResetTemplate(name: string, resetLink: string): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Reset Your Password</title>
      <style>${baseStyles}</style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <div class="logo">Propelo</div>
        </div>
        <h1>Password Reset Request 🔐</h1>
        <p>Hi ${escapeHtml(name)},</p>
        <p>We received a request to reset your password. Click the button below to create a new password:</p>
        <a href="${resetLink}" class="cta">Reset Password</a>
        <p style="margin-top: 24px; font-size: 14px; color: #6b7280;">
          This link will expire in 1 hour. If you didn't request a password reset, you can safely ignore this email.
        </p>
        <div class="footer">
          <p>© ${new Date().getFullYear()} Propelo. All rights reserved.</p>
        </div>
      </div>
    </body>
    </html>
  `;
}

// Helper to escape HTML and prevent XSS
function escapeHtml(text: string): string {
  const map: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  };
  return text.replace(/[&<>"']/g, (char) => map[char]);
}
