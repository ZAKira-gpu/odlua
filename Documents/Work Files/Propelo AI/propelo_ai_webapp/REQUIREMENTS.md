# 🎯 Requirements & Information Needed

## ✅ Already Configured (No Action Required)
- [x] Firebase Project ID: `sealthedeal-d48ef`
- [x] Firebase Web Config (all credentials provided)
- [x] Next.js Project Setup
- [x] UI Design System Complete
- [x] TypeScript Types & Interfaces

---

## 🔴 CRITICAL - YOU NEED TO PROVIDE

### 1. **Firebase Admin Service Account** (REQUIRED for API routes)
**Location:** Firebase Console → Project Settings → Service Accounts → Generate New Private Key

**Action Required:**
1. Go to https://console.firebase.google.com/project/sealthedeal-d48ef/settings/serviceaccounts/adminsdk
2. Click "Generate New Private Key"
3. Download the JSON file
4. Provide the following values from the JSON:

```bash
FIREBASE_PROJECT_ID=sealthedeal-d48ef
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@sealthedeal-d48ef.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

**Why:** Server-side Firebase operations (creating users, saving proposals, etc.)

---

### 2. **OpenAI API Key** (REQUIRED for proposal generation)
**Location:** https://platform.openai.com/api-keys

**Action Required:**
1. Go to https://platform.openai.com/api-keys
2. Create new secret key
3. Copy the key (starts with `sk-proj-...`)

```bash
OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Why:** AI proposal generation and enhancement features

**Cost Estimate:**
- GPT-4o: ~$2.50 per 1M input tokens, ~$10 per 1M output tokens
- GPT-4o-mini: ~$0.15 per 1M input tokens, ~$0.60 per 1M output tokens
- Average proposal: ~2,000 tokens = $0.005 with mini, $0.02 with GPT-4o

---

### 3. **Email Service** (OPTIONAL but RECOMMENDED)
**Options:**
- **Gmail SMTP** (Free, easiest for testing)
- **SendGrid** (Free tier: 100 emails/day)
- **Resend** (Free tier: 3,000 emails/month) - RECOMMENDED

#### Option A: Gmail (Quick Start)
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-specific-password  # Not your regular password!
EMAIL_FROM=your-email@gmail.com
```

**Setup:**
1. Go to https://myaccount.google.com/apppasswords
2. Generate app password for "Mail"
3. Use that 16-character password

#### Option B: Resend (Recommended)
```bash
RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EMAIL_FROM=noreply@propelo.ai  # Or your verified domain
```

**Setup:**
1. Sign up at https://resend.com
2. Get API key from dashboard
3. Verify your domain (or use resend.dev for testing)

**Why:** Welcome emails, proposal notifications, password resets

---

### 4. **Lemon Squeezy Account** (REQUIRED for payments - but can implement later)
**Location:** https://www.lemonsqueezy.com

**Action Required:**
1. Sign up at https://www.lemonsqueezy.com
2. Create your store
3. Create 3 products (Free, Pro, Ultimate plans)
4. Get API credentials

```bash
LEMONSQUEEZY_API_KEY=your-api-key
LEMONSQUEEZY_STORE_ID=your-store-id
LEMONSQUEEZY_WEBHOOK_SECRET=your-webhook-secret
NEXT_PUBLIC_LEMONSQUEEZY_CHECKOUT_URL=https://yourstore.lemonsqueezy.com
```

**Pricing Suggestion (based on your old app):**
- Free: $0/month - 15 proposals
- Pro: $9/month - 200 proposals
- Ultimate: $29/month - 500 proposals
- Lifetime: $199 one-time - Unlimited

**Why:** Subscription management and payments

**Status:** Can be implemented later, app will work without it initially

---

## 🟡 OPTIONAL - Nice to Have

### 5. **Google OAuth Credentials** (For "Sign in with Google")
**Location:** https://console.cloud.google.com/apis/credentials

**Action Required:**
1. Go to Google Cloud Console
2. Create OAuth 2.0 Client ID
3. Add authorized redirect URIs:
   - http://localhost:3000/api/auth/callback/google (dev)
   - https://propelo.ai/api/auth/callback/google (production)

```bash
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxxxxxxxxxxxxxxxxxx
```

**Why:** One-click sign in with Google account

**Status:** Already coded in auth context, just needs credentials

---

### 6. **Analytics** (Optional)
**Options:**
- Google Analytics 4 (Free)
- PostHog (Free tier available)
- Mixpanel (Free tier: 20M events/month)

```bash
NEXT_PUBLIC_GA_ID=G-XXXXXXXXXX
# OR
NEXT_PUBLIC_POSTHOG_KEY=phc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
NEXT_PUBLIC_POSTHOG_HOST=https://app.posthog.com
```

**Why:** Track user behavior, conversion rates, feature usage

---

## 📋 Summary Checklist

### To Start Development (Minimum Required):
- [ ] Firebase Admin Service Account JSON
- [ ] OpenAI API Key

### For Full Functionality:
- [ ] Email Service (Gmail or Resend)
- [ ] Lemon Squeezy Account & Products

### For Enhanced Experience:
- [ ] Google OAuth Credentials
- [ ] Analytics Platform

---

## 🔐 Security Notes

1. **NEVER commit the `.env.local` file to git**
2. **Keep your private keys secure**
3. **Use environment variables for all secrets**
4. **Rotate keys if exposed**
5. **Use different keys for dev/staging/production**

---

## 📝 Next Steps

Once you provide:
1. ✅ Firebase Admin credentials
2. ✅ OpenAI API key

We can immediately start implementing:
- Authentication UI (Sign In/Sign Up)
- Route protection
- Proposal generation
- Firestore integration
- User dashboard with real data

**Email and Lemon Squeezy can be added later without blocking core functionality.**
