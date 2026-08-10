# 🚀 Chrome Extension Setup Checklist

Follow these steps to get the Propelo Chrome Extension up and running.

---

## ✅ Prerequisites

- [x] Node.js 18+ installed
- [x] npm installed
- [ ] Firebase project configured (from main web app)
- [ ] OpenAI API key set in Firebase
- [ ] Main Propelo web app running

---

## 📋 Setup Steps

### 1. Environment Configuration

- [ ] Copy `.env.example` to `.env`
  ```bash
  cd extension
  cp .env.example .env
  ```

- [ ] Edit `.env` and add your Firebase configuration:
  - Get these values from your main web app's `.env.local` file
  - Or from Firebase Console → Project Settings → General
  
  ```
  VITE_FIREBASE_API_KEY=...
  VITE_FIREBASE_AUTH_DOMAIN=...
  VITE_FIREBASE_PROJECT_ID=...
  VITE_FIREBASE_STORAGE_BUCKET=...
  VITE_FIREBASE_MESSAGING_SENDER_ID=...
  VITE_FIREBASE_APP_ID=...
  VITE_CLOUD_FUNCTION_URL=https://us-central1-YOUR_PROJECT.cloudfunctions.net/generateProposal
  ```

### 2. Create Icon Assets

- [ ] Create or copy icon files (PNG format):
  - `icons/icon16.png` (16x16 pixels)
  - `icons/icon48.png` (48x48 pixels)
  - `icons/icon128.png` (128x128 pixels)

**Quick Temporary Solution:**
You can use any PNG images as placeholders for now. Just make sure they are the correct sizes.

### 3. Build the Extension

- [ ] Install dependencies (already done ✅)
  ```bash
  npm install
  ```

- [ ] Build the extension
  ```bash
  npm run build
  ```

- [ ] Verify `dist/` folder was created with:
  - `manifest.json`
  - `popup.html`
  - `background.js`
  - Icon files

### 4. Load Extension in Chrome

- [ ] Open Chrome browser
- [ ] Navigate to `chrome://extensions/`
- [ ] Enable "Developer mode" (toggle in top-right corner)
- [ ] Click "Load unpacked" button
- [ ] Select the `extension/dist` folder
- [ ] Verify extension appears in the list

### 5. Test Basic Functionality

- [ ] Click the Propelo extension icon in Chrome toolbar
- [ ] Popup should open showing "Sign in to Propelo"
- [ ] Click "Sign In" button
- [ ] Should open Propelo web app login page
- [ ] Sign in to web app
- [ ] Return to extension popup
- [ ] Should now show authenticated state

### 6. Troubleshooting

**Popup doesn't open:**
- Check browser console for errors (F12)
- Verify build completed successfully
- Try reloading extension

**"Sign in to Propelo" doesn't detect auth:**
- Make sure you're signed in to the web app
- Check that Firebase config is correct
- Verify `authToken` is being set in Chrome storage

**Build errors:**
- Check that all icon files exist
- Verify `.env` file has all required variables
- Run `npm install` again if needed

---

## 🔄 Development Workflow

### For Active Development:

1. **Run in watch mode:**
   ```bash
   npm run dev
   ```

2. **After code changes:**
   - Go to `chrome://extensions/`
   - Click reload icon on Propelo extension
   - Test changes

3. **View logs:**
   - Background script: `chrome://extensions/` → "Inspect views: service worker"
   - Popup: Right-click extension icon → Inspect popup
   - Content scripts: Regular browser DevTools (F12)

---

## 📝 Before Moving to Phase 2

- [ ] Extension loads without errors
- [ ] Popup opens and displays correctly
- [ ] Firebase authentication works
- [ ] Consent dialog appears on first use
- [ ] All TypeScript compiles without errors

---

## 🎯 Next Phase

Once setup is complete, you're ready for **Phase 2: Platform Scrapers**

This involves:
- Building content scripts for Upwork, Fiverr, Freelancer, LinkedIn
- Testing job data extraction
- Implementing data validation

---

## 💡 Tips

1. **Keep main web app running** - Extension relies on it for auth
2. **Use Chrome DevTools** - Essential for debugging
3. **Check console logs** - Most errors will appear there
4. **Reload extension often** - Changes require reload

---

## ❓ Need Help?

- Check `README.md` for detailed documentation
- Review `PHASE_1_COMPLETE.md` for architecture details
- See `CHROME_EXTENSION_TODO.md` for full roadmap

---

## ✨ You're All Set!

Once all checkboxes are complete, you have a working Chrome extension foundation ready for Phase 2 development.
