# Propelo AI - Setup Instructions

## 🚀 Quick Start Guide

You've successfully created the Propelo AI project structure! Follow these steps to get it running:

### 1. Install Dependencies

```bash
npm install --legacy-peer-deps
```

*Note: Using `--legacy-peer-deps` due to Next.js 16 compatibility*

### 2. Configure Environment Variables

Create a `.env.local` file in the root directory:

```bash
cp .env.example .env.local
```

Then fill in the following required variables:

#### Firebase Setup
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable Firestore Database
4. Go to Project Settings > Service Accounts
5. Generate a new private key
6. Add credentials to `.env.local`:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour-Private-Key-Here\n-----END PRIVATE KEY-----\n"
```

#### OpenAI Setup
1. Go to [OpenAI Platform](https://platform.openai.com/)
2. Create an API key
3. Add to `.env.local`:

```env
OPENAI_API_KEY=sk-proj-xxxxx
OPENAI_MODEL=gpt-4o-mini
```

#### Lemon Squeezy Setup
1. Go to [Lemon Squeezy](https://lemonsqueezy.com/)
2. Create a store
3. Create products for each plan:
   - Starter Plan ($12/month)
   - Pro Plan ($19.99/month)
   - Agency Plan (optional)
4. Get API key from Settings > API
5. Set up webhook endpoint: `https://yourdomain.com/api/webhooks/lemonsqueezy`
6. Add credentials to `.env.local`:

```env
LEMONSQUEEZY_API_KEY=your-api-key
LEMONSQUEEZY_STORE_ID=your-store-id
LEMONSQUEEZY_WEBHOOK_SECRET=your-webhook-secret
LEMONSQUEEZY_STARTER_VARIANT_ID=variant-id
LEMONSQUEEZY_PRO_VARIANT_ID=variant-id
```

#### App Configuration

```env
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXTAUTH_SECRET=generate-a-random-secret-here
NEXTAUTH_URL=http://localhost:3000
```

Generate a secret:
```bash
openssl rand -base64 32
```

### 3. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to see your app!

## 📁 What's Been Created

### Core Files
- ✅ **Types** (`types/index.ts`) - Complete TypeScript definitions
- ✅ **Constants** (`config/constants.ts`) - App-wide configuration
- ✅ **Utilities** (`lib/utils.ts`) - Helper functions
- ✅ **Validations** (`lib/validations.ts`) - Zod schemas
- ✅ **Store** (`lib/store.ts`) - Zustand state management

### Integrations
- ✅ **OpenAI Client** (`lib/openai.ts`) - Proposal generation & enhancement
- ✅ **Lemon Squeezy Client** (`lib/lemonsqueezy.ts`) - Payment processing
- ✅ **Firebase Admin** (`lib/firebase-admin.ts`) - Database operations

### API Routes
- ✅ `/api/proposals/generate` - Generate AI proposals
- ✅ `/api/proposals/enhance` - Enhance existing proposals
- ✅ `/api/proposals` - CRUD operations
- ✅ `/api/analytics` - Track proposal analytics
- ✅ `/api/webhooks/lemonsqueezy` - Handle payment webhooks

### UI Components
- ✅ **Landing Page** (`app/page.tsx`) - Beautiful marketing site
- ✅ **Layout** (`app/layout.tsx`) - Root layout with toast notifications
- ✅ **UI Components** (`components/ui/`) - Reusable components

## 🎯 Next Steps

### 1. Build Dashboard Pages

Create these pages in `app/dashboard/`:

```
dashboard/
├── page.tsx                 # Dashboard overview
├── generator/
│   └── page.tsx            # Proposal generator
├── history/
│   └── page.tsx            # Proposal history
├── enhancer/
│   └── page.tsx            # Proposal enhancer
├── analytics/
│   └── page.tsx            # Analytics dashboard
├── clients/
│   └── page.tsx            # CRM
├── snippets/
│   └── page.tsx            # Snippets library
├── profile/
│   └── page.tsx            # User profile
└── settings/
    └── page.tsx            # Settings
```

### 2. Build Authentication Pages

Create in `app/auth/`:

```
auth/
├── signin/
│   └── page.tsx            # Sign in
├── signup/
│   └── page.tsx            # Sign up
├── verify/
│   └── page.tsx            # Email verification
└── forgot-password/
    └── page.tsx            # Password reset
```

### 3. Add Authentication

Implement Firebase Authentication or another auth provider.

### 4. Test API Endpoints

Use tools like Postman or create test scripts to verify:
- Proposal generation
- Proposal enhancement
- Analytics tracking
- Webhook handling

### 5. Deploy to Vercel

```bash
vercel
```

Or connect your GitHub repo to Vercel for automatic deployments.

## 🎨 Design System

### Colors
- **Background:** #FFFEFB
- **Primary:** #0EA5E9 (Cyan)
- **Secondary:** #0369A1 (Teal)
- **Text:** #334155 (Gray)

### Components
All using Radix UI + Tailwind CSS for:
- Accessibility
- Customization
- Performance
- Mobile responsiveness

## 📚 Key Features to Implement

### High Priority
1. **Proposal Generator** - Core AI generation with tone selection
2. **Proposal Enhancer** - Before/after comparison with improvements
3. **Proposal Tracking** - Status management (draft, sent, opened, accepted)
4. **Analytics Dashboard** - Track opens, clicks, time spent
5. **User Profile** - Skills, experience, portfolio management

### Medium Priority
6. **CRM Lite** - Client management
7. **Snippets Library** - Reusable content blocks
8. **Job Insights** - AI-powered brief analysis
9. **Email Notifications** - Status updates
10. **Mobile Optimization** - Responsive design refinements

### Future Features
11. **Chrome Extension** - Upwork integration
12. **Team Mode** - Collaboration features
13. **Advanced Analytics** - Heatmaps, exports
14. **CV Scraper** - Auto-fill profile from LinkedIn
15. **Template Library** - Niche-specific templates

## 🐛 Troubleshooting

### Common Issues

**"Module not found" errors**
```bash
npm install --legacy-peer-deps
```

**Firebase connection issues**
- Verify project ID matches
- Check private key formatting (should include `\n`)
- Ensure Firestore is enabled

**OpenAI rate limits**
- Start with `gpt-4o-mini` for development
- Implement request queuing for production

**Type errors**
- Run `npm run build` to check for errors
- Most types are defined in `types/index.ts`

## 📞 Need Help?

- Check the [README.md](./README.md) for detailed documentation
- Review example code in API routes
- Check Firestore/Firebase docs for database queries
- OpenAI docs for prompt engineering

## ✅ Project Status

| Component | Status |
|-----------|--------|
| Project Setup | ✅ Complete |
| Type Definitions | ✅ Complete |
| API Integrations | ✅ Complete |
| API Routes | ✅ Complete |
| Landing Page | ✅ Complete |
| UI Components | ✅ Partial |
| Dashboard Pages | ⏳ Pending |
| Auth Pages | ⏳ Pending |
| Authentication | ⏳ Pending |
| Testing | ⏳ Pending |
| Deployment | ⏳ Pending |

---

**🎉 You're all set! Start building your features and launch Propelo AI!**
