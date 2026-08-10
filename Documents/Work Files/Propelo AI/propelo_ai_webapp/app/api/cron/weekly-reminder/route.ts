import { NextRequest, NextResponse } from 'next/server';
import { sendEmail } from '@/lib/email';
import { getWeeklyReminderTemplate } from '@/lib/email/templates';
import { generateAIMessage } from '@/lib/email/ai-messages';
import { db } from '@/lib/firebase-admin';

export const dynamic = 'force-dynamic';
export const maxDuration = 300; // 5 minutes max for processing all users

export async function GET(request: NextRequest) {
  // Verify the cron secret to prevent unauthorized access
  const authHeader = request.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;

  if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
    console.warn('Unauthorized cron job attempt');
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  try {
    // Fetch users who have weekly reports enabled
    // Note: preferences.weeklyReports is nested, so we query all users and filter
    const usersSnapshot = await db
      .collection('users')
      .get();

    const users: { email: string; name: string; uid: string }[] = [];
    
    usersSnapshot.forEach((doc: FirebaseFirestore.QueryDocumentSnapshot) => {
      const data = doc.data();
      // Check if weekly reports are enabled in preferences
      const weeklyReportsEnabled = data.preferences?.weeklyReports === true;
      if (data.email && weeklyReportsEnabled) {
        users.push({
          uid: doc.id,
          email: data.email,
          name: data.firstName || data.name || data.displayName || 'Freelancer',
        });
      }
    });

    console.log(`Processing weekly reminders for ${users.length} users`);

    let sent = 0;
    let failed = 0;
    const errors: string[] = [];

    for (const user of users) {
      try {
        const aiMessage = await generateAIMessage(user.name);
        
        const result = await sendEmail({
          to: user.email,
          subject: "Your weekly Propelo check-in 📊",
          html: getWeeklyReminderTemplate(user.name, aiMessage, user.email),
        });

        if (result.success) {
          sent++;
        } else {
          failed++;
          errors.push(`${user.email}: ${result.error}`);
        }

        // Rate limiting: wait 100ms between emails to avoid SMTP limits
        await new Promise((resolve) => setTimeout(resolve, 100));
      } catch (error) {
        failed++;
        errors.push(`${user.email}: ${error}`);
      }
    }

    console.log(`Weekly reminders complete: ${sent} sent, ${failed} failed`);

    return NextResponse.json({
      success: true,
      sent,
      failed,
      total: users.length,
      timestamp: new Date().toISOString(),
      ...(errors.length > 0 && { errors: errors.slice(0, 10) }), // Only return first 10 errors
    });
  } catch (error) {
    console.error('Weekly reminder cron error:', error);
    return NextResponse.json(
      { error: 'Internal server error', details: String(error) },
      { status: 500 }
    );
  }
}
