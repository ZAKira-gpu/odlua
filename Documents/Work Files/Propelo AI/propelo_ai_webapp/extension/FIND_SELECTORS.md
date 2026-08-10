# 🔍 Find Missing Selectors - Debug Guide

## Current Status (Based on Your Profile)

### ✅ Working Fields
- Name: "Noureldeen S."
- Title: "All work"
- Location: "Cairo, Egypt"
- Hourly Rate: $50
- Skills: 8 items
- Bio: 95 characters
- Profile Image: Found

### ❌ Missing Fields
- Job Success Score
- Total Earnings
- Total Jobs
- Total Hours
- Categories
- Languages
- Portfolio (found 2, extracted 0)
- Rating
- Review Count
- Member Since (showing "|")

## 🛠️ How to Find the Right Selectors

### Step 1: Open DevTools Inspector

1. Go to your Upwork profile: https://www.upwork.com/freelancers/~01a3358405f230ab04
2. Press `Cmd + Option + I` (Mac) or `F12` (Windows)
3. Click the "Elements" tab
4. Click the "Select Element" tool (or press `Cmd + Shift + C`)

### Step 2: Find Each Missing Field

For each missing field, follow these steps:

#### Job Success Score

1. **Hover over** the Job Success Score number on your profile
2. **Click** to select it in Elements tab
3. **Look at** the HTML structure
4. **Copy** the selector patterns you see

Example HTML patterns to look for:
```html
<!-- Common patterns -->
<span class="some-class">95%</span>
<div data-test="job-success">95%</div>
<strong>95%</strong>

<!-- Check parent elements too -->
<div class="stats-container">
  <div class="stat-item">
    <label>Job Success</label>
    <span>95%</span>
  </div>
</div>
```

**In the Console, test selectors:**
```javascript
// Try these one by one:
document.querySelector('[data-test="job-success"]')?.textContent
document.querySelector('[class*="job-success"]')?.textContent
document.querySelector('span:has-text("95%")')?.textContent

// Or find by nearby text:
const label = Array.from(document.querySelectorAll('*')).find(el => 
  el.textContent === 'Job Success'
);
const value = label?.nextElementSibling?.textContent;
console.log('JSS:', value);
```

#### Total Earnings, Jobs, Hours

Same process:
1. Hover over the number
2. Inspect element
3. Copy the class/data attributes
4. Test in console:

```javascript
// Test earnings selector
document.querySelector('[class*="earnings"]')?.textContent
document.querySelector('strong')?.textContent

// If they're in a stats section:
const stats = document.querySelectorAll('[class*="stat"]');
stats.forEach((stat, i) => {
  console.log(`Stat ${i}:`, stat.textContent.trim());
});
```

#### Portfolio Items

The scraper found 2 items but couldn't extract titles. Let's debug:

```javascript
// Find portfolio section
const portfolioSection = document.querySelector('[class*="portfolio"]');
console.log('Portfolio section:', portfolioSection);

// Find items
const items = portfolioSection?.querySelectorAll('li');
console.log('Found', items?.length, 'items');

// Check each item's structure
items?.forEach((item, i) => {
  console.log(`\n=== Item ${i} ===`);
  console.log('HTML:', item.innerHTML.substring(0, 200));
  console.log('Text:', item.textContent?.trim().substring(0, 100));
  
  // Try different title selectors
  const h3 = item.querySelector('h3');
  const h4 = item.querySelector('h4');
  const strong = item.querySelector('strong');
  const a = item.querySelector('a');
  
  console.log('h3:', h3?.textContent?.trim());
  console.log('h4:', h4?.textContent?.trim());
  console.log('strong:', strong?.textContent?.trim());
  console.log('a:', a?.textContent?.trim());
});
```

#### Languages & Categories

```javascript
// Find language section
const langSection = Array.from(document.querySelectorAll('h2, h3, h4')).find(h => 
  h.textContent?.includes('Language')
);
console.log('Language section:', langSection);

// Get languages
const langItems = langSection?.parentElement?.querySelectorAll('li');
langItems?.forEach(item => {
  console.log('Language:', item.textContent?.trim());
});

// Same for categories
const catSection = Array.from(document.querySelectorAll('h2, h3, h4')).find(h => 
  h.textContent?.includes('Categor')
);
const catItems = catSection?.parentElement?.querySelectorAll('li, a, span');
```

#### Member Since

```javascript
// Find "Member since" text
const memberText = Array.from(document.querySelectorAll('*')).find(el => 
  el.textContent?.includes('Member since')
);
console.log('Member element:', memberText);
console.log('Parent:', memberText?.parentElement);
console.log('Next sibling:', memberText?.nextElementSibling?.textContent);

// Check for time elements
document.querySelectorAll('time').forEach(time => {
  console.log('Time element:', time.textContent, time.getAttribute('datetime'));
});
```

### Step 3: Add Selectors to Code

Once you find working selectors, add them to `upwork.ts`:

1. Open `/Users/nourmahmoud/Desktop/propelo_ai_webapp/extension/src/content-scripts/upwork.ts`
2. Find the field (e.g., search for "Job Success Score")
3. Add your working selector at the TOP of the selector list:

```typescript
// Before:
const jobSuccessText = extractText(
  '[data-test="job-success"]',
  // ... other selectors
);

// After (add your working selector first):
const jobSuccessText = extractText(
  'YOUR_WORKING_SELECTOR_HERE', // ← Add this
  '[data-test="job-success"]',
  // ... other selectors
);
```

### Step 4: Quick Test Script

Run this in the console to get ALL the data at once:

```javascript
// Complete diagnostic script
console.log('=== UPWORK PROFILE DIAGNOSTICS ===\n');

// 1. Job Success Score
const jssElements = [
  document.querySelector('[data-test="job-success"]'),
  document.querySelector('[class*="job-success"]'),
  ...document.querySelectorAll('strong')
].filter(Boolean);
console.log('JSS candidates:', jssElements.map(el => el.textContent?.trim()));

// 2. Stats (Earnings, Jobs, Hours)
const stats = document.querySelectorAll('[class*="stat"]');
console.log('\nStats sections:', stats.length);
stats.forEach((stat, i) => {
  console.log(`  Stat ${i}:`, stat.textContent?.trim().substring(0, 100));
});

// 3. Portfolio
const portfolioSection = document.querySelector('[class*="portfolio"]');
const portfolioItems = portfolioSection?.querySelectorAll('li, article, div[class*="item"]');
console.log('\nPortfolio items:', portfolioItems?.length);
portfolioItems?.forEach((item, i) => {
  const title = item.querySelector('h3, h4, h5, strong, a')?.textContent?.trim();
  console.log(`  Item ${i}:`, title?.substring(0, 50) || 'NO TITLE');
});

// 4. Languages
const langSection = Array.from(document.querySelectorAll('*')).find(el =>
  el.textContent?.trim().toLowerCase() === 'languages'
);
const langItems = langSection?.nextElementSibling?.querySelectorAll('li, span');
console.log('\nLanguages:', langItems?.length || 0);
langItems?.forEach(item => {
  console.log('  -', item.textContent?.trim());
});

// 5. Categories
const catSection = Array.from(document.querySelectorAll('*')).find(el =>
  el.textContent?.trim().toLowerCase().includes('categor')
);
console.log('\nCategory section:', catSection?.textContent?.substring(0, 100));

// 6. Member Since
const memberElements = Array.from(document.querySelectorAll('*')).filter(el =>
  el.textContent?.includes('Member since')
);
console.log('\nMember since candidates:', memberElements.map(el => 
  el.textContent?.trim().substring(0, 50)
));

// 7. Rating & Reviews
const ratingElements = document.querySelectorAll('[class*="rating"], [class*="review"], [class*="star"]');
console.log('\nRating/Review elements:', ratingElements.length);
ratingElements.forEach(el => {
  console.log('  -', el.textContent?.trim().substring(0, 50));
});

console.log('\n=== END DIAGNOSTICS ===');
```

## 📝 Report Back Format

After running the diagnostic script, reply with:

```
Job Success Score: [selector that works or "Not visible on profile"]
Total Earnings: [selector or "Not visible"]
Total Jobs: [selector or "Not visible"]
Total Hours: [selector or "Not visible"]
Languages: [selector or "Not visible"]
Categories: [selector or "Not visible"]
Portfolio Item Title: [selector that works]
Rating: [selector or "Not visible"]
Review Count: [selector or "Not visible"]
Member Since: [selector or "Not visible"]
```

## 🎯 Common Reasons for Missing Fields

1. **New Upwork Profile**: Some stats (JSS, earnings, jobs) only show after completing work
2. **Privacy Settings**: User might have hidden certain stats
3. **Layout Changes**: Upwork frequently updates their UI
4. **Profile Type**: Different layouts for new vs experienced freelancers

## 🚀 Quick Fix Alternative

If you want, you can:

1. **Share your profile HTML**: Right-click on profile → "View Page Source" → Copy relevant section
2. **Share a screenshot**: Show me where the missing data appears
3. **Run the diagnostic script**: Copy/paste the output

I can then create exact selectors for YOUR specific profile layout!

---

**Current Build**: content-upwork.js is 34.90 kB with 30-35 selectors per field
**Next Step**: Find the working selectors and I'll add them to the code
