# Propelo Chrome Extension

Auto-generate winning proposals for Upwork, Fiverr, Freelancer, and LinkedIn using AI.

## 🚀 Quick Start

### Prerequisites
- Node.js 18+ installed
- npm or yarn
- Firebase project (same as web app)
- OpenAI API key configured in Firebase

### Installation

1. **Install dependencies:**
```bash
cd extension
npm install
```

2. **Set up environment variables:**
```bash
cp .env.example .env
```

Edit `.env` and add your Firebase configuration (copy from main web app).

3. **Build the extension:**
```bash
npm run build
```

4. **Load in Chrome:**
   - Open Chrome and go to `chrome://extensions/`
   - Enable "Developer mode" (top right)
   - Click "Load unpacked"
   - Select the `extension/dist` folder

## 📁 Project Structure

```
extension/
├── manifest.json          # Chrome extension manifest
├── popup.html            # Popup UI entry point
├── src/
│   ├── background.ts     # Background service worker
│   ├── types.ts          # TypeScript interfaces
│   ├── firebase.ts       # Firebase client config
│   ├── content-scripts/  # Platform scrapers (to be added)
│   ├── popup/
│   │   ├── App.tsx       # Main popup React component
│   │   ├── components/   # UI components
│   │   └── styles.css    # Tailwind styles
│   └── utils/            # Utility functions (to be added)
└── icons/                # Extension icons (to be added)
```

## 🛠️ Development

### Build for development (with watch mode):
```bash
npm run dev
```

### Build for production:
```bash
npm run build
```

### Run tests:
```bash
npm test
```

## 📋 Phase 1 Status

✅ **Completed:**
- Project structure created
- Package.json configured
- TypeScript setup
- Vite build configuration
- Tailwind CSS setup
- Manifest V3 configuration
- Background service worker skeleton
- Popup UI components (App, ProposalView, ConsentDialog)
- Firebase client setup
- Type definitions

⏳ **Next Steps (Phase 2):**
- Create platform scrapers (Upwork, Fiverr, Freelancer, LinkedIn)
- Add icon assets
- Install dependencies
- Test extension loading

## 🔧 Available Scripts

- `npm run dev` - Build with watch mode
- `npm run build` - Production build
- `npm test` - Run unit tests
- `npm run test:e2e` - Run E2E tests (Playwright)

## 🌐 Environment Variables

Required environment variables (in `.env`):

```
VITE_FIREBASE_API_KEY          # Firebase API key
VITE_FIREBASE_AUTH_DOMAIN      # Firebase auth domain
VITE_FIREBASE_PROJECT_ID       # Firebase project ID
VITE_FIREBASE_STORAGE_BUCKET   # Firebase storage bucket
VITE_FIREBASE_MESSAGING_SENDER_ID  # Firebase messaging sender ID
VITE_FIREBASE_APP_ID           # Firebase app ID
VITE_CLOUD_FUNCTION_URL        # Cloud Function URL for proposal generation
```

## 🔐 Security

- No API keys are stored in the extension
- User authentication via Firebase
- All data encrypted in transit
- Consent-based data collection

## 📝 Notes

- This extension requires the Propelo web app to be set up first
- Firebase Cloud Function for proposal generation must be deployed
- Users must sign in to the Propelo web app before using the extension

## 🐛 Troubleshooting

**Extension doesn't load:**
- Make sure you built the extension (`npm run build`)
- Check that `dist` folder exists
- Verify manifest.json has no errors

**Firebase errors:**
- Check that `.env` file has correct Firebase config
- Verify Firebase project is active
- Check console for specific error messages

**Popup doesn't open:**
- Check browser console for errors
- Verify build completed successfully
- Try reloading the extension

## 📞 Support

For issues or questions, refer to the main project documentation.
