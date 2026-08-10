# 🧪 Chrome Extension Testing Guide

Quick guide to test the Propelo Chrome Extension scrapers on real job pages.

---

## 🚀 Quick Setup

1. **Build the extension:**
   ```bash
   cd extension
   npm run build
   ```

2. **Load in Chrome:**
   - Open Chrome: `chrome://extensions/`
   - Enable "Developer mode" (top right)
   - Click "Load unpacked"
   - Select the `extension/dist` folder
   - Extension should appear in toolbar

---

## 🧪 Testing Each Platform

### 1. Upwork Testing

**Test URLs:**
- Go to https://www.upwork.com/
- Sign in to your account
- Browse jobs or search for "web developer"
- Click on any job posting

**What to Check:**
1. Open DevTools (F12) → Console tab
2. Look for these messages:
   ```
   [Propelo] Initializing Upwork scraper...
   [Propelo] Starting Upwork job scrape...
   [Propelo] Successfully scraped Upwork job: [Job Title]
   ```

3. Check stored data:
   ```javascript
   chrome.storage.local.get(['currentJob'], console.log)
   ```

**Expected Data:**
- Job title (required)
- Description (required)
- Budget (if available)
- Skills array
- Client info

---

### 2. Fiverr Testing

**Test URLs:**
- Go to https://www.fiverr.com/
- Browse gigs or buyer requests
- Click on any gig

**Console Output:**
```
[Propelo] Initializing Fiverr scraper...
[Propelo] Starting Fiverr job scrape...
[Propelo] Successfully scraped Fiverr job: [Gig Title]
```

**Note:** Fiverr buyer requests may require login

---

### 3. Freelancer Testing

**Test URLs:**
- Go to https://www.freelancer.com/
- Browse projects (may require login)
- Click on any project

**Console Output:**
```
[Propelo] Initializing Freelancer scraper...
[Propelo] Starting Freelancer job scrape...
[Propelo] Successfully scraped Freelancer job: [Project Title]
```

---

### 4. LinkedIn Testing

**Test URLs:**
- Go to https://www.linkedin.com/jobs/
- Search for any job
- Click on a job posting

**Console Output:**
```
[Propelo] Initializing LinkedIn scraper...
[Propelo] Starting LinkedIn job scrape...
[Propelo] Successfully scraped LinkedIn job: [Job Title]
```

**Note:** Skills may not always be available on LinkedIn

---

## 🔍 Debugging Tips

### View Background Script Logs:
1. Go to `chrome://extensions/`
2. Find Propelo extension
3. Click "Inspect views: service worker"
4. Check console for errors

### View Content Script Logs:
1. Navigate to job page
2. Open DevTools (F12)
3. Console tab shows `[Propelo]` messages

### View Popup Logs:
1. Click extension icon
2. Right-click popup → Inspect
3. Console shows popup errors

### Check Stored Data:
Run in any console:
```javascript
// Check current job
chrome.storage.local.get(['currentJob'], (data) => {
  console.log('Current Job:', data.currentJob);
});

// Check errors
chrome.storage.local.get(['errors'], (data) => {
  console.log('Errors:', data.errors);
});

// Check consent
chrome.storage.local.get(['consent'], (data) => {
  console.log('Consent:', data.consent);
});
```

---

## ✅ Testing Checklist

### For Each Platform:

- [ ] Navigate to job page
- [ ] Check console for `[Propelo]` logs
- [ ] Verify no errors in console
- [ ] Open extension popup
- [ ] Should see "Generate Proposal" button (if signed in)
- [ ] Check stored data has all fields
- [ ] Navigate to different job on same platform
- [ ] Verify scraper re-runs

### Success Criteria:

- ✅ Job title extracted
- ✅ Description extracted (min 50 chars)
- ✅ URL captured
- ✅ Platform identified correctly
- ✅ Skills array populated (if available)
- ✅ No errors in console

---

## 🚨 Common Issues

### Issue: No logs appear
**Fix:** Reload the extension at `chrome://extensions/`

### Issue: "No job detected"
**Fix:** 
- Check if selectors match current page structure
- Open DevTools and inspect elements
- Update selectors in content script if needed

### Issue: Scraper runs multiple times
**Fix:** This is normal - runs on page load and URL changes

### Issue: Extension not showing in toolbar
**Fix:** 
- Check manifest.json loaded correctly
- Verify icons exist
- Reload extension

---

## 📊 Test Results Template

Use this to track your testing:

```markdown
## Upwork Test Results
- Date: ___________
- Job URL: ___________
- ✅/❌ Job title extracted
- ✅/❌ Description extracted
- ✅/❌ Budget extracted
- ✅/❌ Skills extracted
- Notes: ___________

## Fiverr Test Results
- Date: ___________
- Gig URL: ___________
- ✅/❌ Title extracted
- ✅/❌ Description extracted
- ✅/❌ Price extracted
- Notes: ___________

## Freelancer Test Results
- Date: ___________
- Project URL: ___________
- ✅/❌ Title extracted
- ✅/❌ Description extracted
- ✅/❌ Budget extracted
- Notes: ___________

## LinkedIn Test Results
- Date: ___________
- Job URL: ___________
- ✅/❌ Title extracted
- ✅/❌ Description extracted
- ✅/❌ Company extracted
- Notes: ___________
```

---

## 🎯 Next Steps After Testing

Once testing is complete:

1. **Report Issues:**
   - Note which selectors failed
   - Capture console errors
   - Take screenshots if needed

2. **Update Selectors:**
   - Modify content scripts with correct selectors
   - Rebuild: `npm run build`
   - Reload extension and retest

3. **Document Findings:**
   - Update selector mappings
   - Note platform-specific quirks
   - Document edge cases

---

## 💡 Pro Tips

1. **Keep DevTools Open:** Always have console open when testing
2. **Test Multiple Jobs:** Try 3-5 jobs per platform
3. **Test Different Job Types:** Hourly, fixed-price, contract, etc.
4. **Clear Storage:** Between tests, clear with:
   ```javascript
   chrome.storage.local.clear()
   ```
5. **Watch Network Tab:** See if pages load content via AJAX

---

## 📞 Need Help?

If scrapers aren't working:
1. Check console for errors
2. Verify DOM structure hasn't changed
3. Update selectors in content scripts
4. Rebuild and reload extension
5. Test again

**Remember:** Platforms update their HTML frequently. Selectors may need periodic updates!
