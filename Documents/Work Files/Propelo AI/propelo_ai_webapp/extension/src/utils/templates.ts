export interface ProposalTemplate {
  id: string;
  name: string;
  category: 'introduction' | 'skills' | 'experience' | 'closing' | 'full';
  content: string;
  variables: string[]; // e.g., ['{{CLIENT_NAME}}', '{{JOB_TITLE}}']
  platform?: 'upwork' | 'fiverr' | 'freelancer' | 'linkedin' | 'all';
}

export const DEFAULT_TEMPLATES: ProposalTemplate[] = [
  {
    id: 'intro-enthusiastic',
    name: 'Enthusiastic Introduction',
    category: 'introduction',
    content: `Hi {{CLIENT_NAME}},

I'm excited about your {{JOB_TITLE}} project! With my expertise in this area, I'm confident I can deliver exceptional results that exceed your expectations.`,
    variables: ['{{CLIENT_NAME}}', '{{JOB_TITLE}}'],
    platform: 'all'
  },
  {
    id: 'intro-professional',
    name: 'Professional Introduction',
    category: 'introduction',
    content: `Dear {{CLIENT_NAME}},

I am writing to express my interest in your {{JOB_TITLE}} position. My background and experience align well with the requirements outlined in your job posting.`,
    variables: ['{{CLIENT_NAME}}', '{{JOB_TITLE}}'],
    platform: 'linkedin'
  },
  {
    id: 'skills-technical',
    name: 'Technical Skills Showcase',
    category: 'skills',
    content: `My technical skillset includes:
• {{SKILL_1}}
• {{SKILL_2}}
• {{SKILL_3}}

I've successfully applied these skills in numerous projects, delivering high-quality results on time and within budget.`,
    variables: ['{{SKILL_1}}', '{{SKILL_2}}', '{{SKILL_3}}'],
    platform: 'all'
  },
  {
    id: 'experience-years',
    name: 'Years of Experience',
    category: 'experience',
    content: `With over {{YEARS}} years of experience in {{FIELD}}, I've worked with clients ranging from startups to Fortune 500 companies. My expertise has helped businesses achieve {{OUTCOME}}.`,
    variables: ['{{YEARS}}', '{{FIELD}}', '{{OUTCOME}}'],
    platform: 'all'
  },
  {
    id: 'closing-cta',
    name: 'Call to Action Close',
    category: 'closing',
    content: `I'd love to discuss how I can help bring your vision to life. When would be a good time for a quick call to discuss the project details?

Looking forward to working together!

Best regards`,
    variables: [],
    platform: 'all'
  },
  {
    id: 'closing-availability',
    name: 'Availability Close',
    category: 'closing',
    content: `I'm available to start immediately and can dedicate {{HOURS}} hours per week to this project. I'm confident we can achieve great results together.

Thank you for considering my proposal!`,
    variables: ['{{HOURS}}'],
    platform: 'upwork'
  },
  {
    id: 'full-upwork-standard',
    name: 'Upwork Standard Proposal',
    category: 'full',
    content: `Hi {{CLIENT_NAME}},

I noticed your {{JOB_TITLE}} project and I'm excited to help! Here's why I'm a great fit:

✅ {{YEARS}}+ years of experience in {{FIELD}}
✅ {{KEY_SKILL_1}}, {{KEY_SKILL_2}}, and {{KEY_SKILL_3}}
✅ Track record of delivering quality work on time

I've reviewed your requirements and have some ideas on how to approach this project. I'd love to discuss the details and show you examples of similar work I've completed.

Available to start: {{START_DATE}}
Estimated timeline: {{TIMELINE}}

Looking forward to collaborating with you!

Best,
{{YOUR_NAME}}`,
    variables: ['{{CLIENT_NAME}}', '{{JOB_TITLE}}', '{{YEARS}}', '{{FIELD}}', '{{KEY_SKILL_1}}', '{{KEY_SKILL_2}}', '{{KEY_SKILL_3}}', '{{START_DATE}}', '{{TIMELINE}}', '{{YOUR_NAME}}'],
    platform: 'upwork'
  }
];

export function replaceTemplateVariables(
  template: string,
  variables: Record<string, string>
): string {
  let result = template;
  
  Object.entries(variables).forEach(([key, value]) => {
    const placeholder = key.startsWith('{{') ? key : `{{${key}}}`;
    result = result.replace(new RegExp(placeholder, 'g'), value);
  });
  
  return result;
}

export function extractTemplateVariables(template: string): string[] {
  const regex = /\{\{([^}]+)\}\}/g;
  const matches = template.match(regex);
  return matches ? [...new Set(matches)] : [];
}

export function getTemplatesByCategory(
  category: ProposalTemplate['category']
): ProposalTemplate[] {
  return DEFAULT_TEMPLATES.filter(t => t.category === category);
}

export function getTemplatesByPlatform(
  platform: 'upwork' | 'fiverr' | 'freelancer' | 'linkedin'
): ProposalTemplate[] {
  return DEFAULT_TEMPLATES.filter(t => t.platform === platform || t.platform === 'all');
}
