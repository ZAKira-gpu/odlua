import { sendEmail } from './index';
import { getWelcomeEmailTemplate } from './templates';

/**
 * Send a welcome email to a new user
 * Call this after successful signup
 */
export async function sendWelcomeEmail(
  email: string,
  name: string
): Promise<boolean> {
  try {
    const result = await sendEmail({
      to: email,
      subject: 'Welcome to Propelo! 🎉',
      html: getWelcomeEmailTemplate(name),
    });

    if (result.success) {
      console.log(`Welcome email sent to ${email}`);
    } else {
      console.error(`Failed to send welcome email to ${email}:`, result.error);
    }

    return result.success;
  } catch (error) {
    console.error('Error sending welcome email:', error);
    return false;
  }
}

/**
 * Queue welcome email via API route (for client-side usage)
 * Use this when you don't have direct access to the email service
 */
export async function queueWelcomeEmail(
  email: string,
  name: string
): Promise<boolean> {
  try {
    const response = await fetch('/api/email/welcome', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, name }),
    });

    return response.ok;
  } catch (error) {
    console.error('Failed to queue welcome email:', error);
    return false;
  }
}
