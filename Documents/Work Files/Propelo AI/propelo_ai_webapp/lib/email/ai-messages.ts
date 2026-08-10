// Pre-written motivational messages to save API costs
// These rotate weekly to keep content fresh

const motivationalMessages = [
  "Small steps lead to big changes. What's one proposal you can send today?",
  "Remember: progress, not perfection. Every proposal you send increases your chances!",
  "Your future self will thank you for the effort you put in today. Keep applying!",
  "Consistency beats intensity. Show up every day, even if it's just one application.",
  "You're closer to landing that dream client than you were last week. Keep going!",
  "The best time to send a proposal was yesterday. The second best time is now.",
  "Success is the sum of small efforts repeated day in and day out. You've got this!",
  "Don't wait for the perfect job posting. Create opportunities through action!",
  "Every 'no' brings you closer to a 'yes'. Keep pushing forward!",
  "Your skills are valuable. Someone out there is looking for exactly what you offer.",
  "The freelance journey is a marathon, not a sprint. Pace yourself and stay consistent.",
  "Today's proposals are tomorrow's clients. Invest in your future self!",
  "Rejection is redirection. That 'no' just cleared the path for a better 'yes'.",
  "You have something unique to offer. Don't let imposter syndrome hold you back!",
  "One great proposal is worth more than ten mediocre ones. Focus on quality!",
];

const tips = [
  "💡 Tip: Personalize your proposals by mentioning specific details from the job posting.",
  "💡 Tip: Keep your proposals concise - clients appreciate brevity and clarity.",
  "💡 Tip: Start with the client's problem, then explain how you'll solve it.",
  "💡 Tip: Include relevant portfolio pieces that match the project requirements.",
  "💡 Tip: Follow up on proposals you sent last week - persistence pays off!",
  "💡 Tip: Update your profile regularly to stay visible in search results.",
  "💡 Tip: Set a daily goal for applications - consistency builds momentum.",
  "💡 Tip: Read the job posting twice before writing your proposal.",
];

/**
 * Get a random motivational message
 * Uses the current week number to ensure variety
 */
export function getRandomMotivationalMessage(): string {
  const weekOfYear = getWeekNumber(new Date());
  const index = weekOfYear % motivationalMessages.length;
  return motivationalMessages[index];
}

/**
 * Get a random tip
 */
export function getRandomTip(): string {
  const dayOfYear = getDayOfYear(new Date());
  const index = dayOfYear % tips.length;
  return tips[index];
}

/**
 * Generate a combined message with motivation and tip
 */
export function generateWeeklyMessage(): string {
  return `${getRandomMotivationalMessage()}\n\n${getRandomTip()}`;
}

/**
 * For truly AI-generated messages (uses your existing OpenAI setup)
 * Uncomment and modify if you want to use actual AI generation
 */
export async function generateAIMessage(userName: string): Promise<string> {
  // To save costs, we use pre-written messages
  // If you want AI-generated content, integrate with your OpenAI setup:
  
  // try {
  //   const response = await fetch(`${process.env.NEXT_PUBLIC_APP_URL}/api/ai/generate-message`, {
  //     method: 'POST',
  //     headers: { 'Content-Type': 'application/json' },
  //     body: JSON.stringify({ 
  //       prompt: `Generate a short, motivational message for a freelancer named ${userName}. Keep it under 50 words.`
  //     }),
  //   });
  //   const data = await response.json();
  //   return data.message;
  // } catch {
  //   return getRandomMotivationalMessage();
  // }

  return getRandomMotivationalMessage();
}

// Helper functions
function getWeekNumber(date: Date): number {
  const startOfYear = new Date(date.getFullYear(), 0, 1);
  const diff = date.getTime() - startOfYear.getTime();
  const oneWeek = 1000 * 60 * 60 * 24 * 7;
  return Math.floor(diff / oneWeek);
}

function getDayOfYear(date: Date): number {
  const startOfYear = new Date(date.getFullYear(), 0, 0);
  const diff = date.getTime() - startOfYear.getTime();
  const oneDay = 1000 * 60 * 60 * 24;
  return Math.floor(diff / oneDay);
}
