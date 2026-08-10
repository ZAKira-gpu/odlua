# Architectural Breakdown

## Chrome Extension (Manifest V3)

- **Manifest File (`manifest.json`)**: 
  - Defines extension name, version, description, permissions (tabs, scripting, storage), background service worker, content scripts for specific URLs, and popup UI.

- **Background Service Worker**:
  - Listens for events (e.g., browserAction on clicked), manages scraping schedules, handles messaging between content scripts and popup.

- **Content Scripts**:
  - Injected into target websites (Upwork, etc.).
  - Extract job data using DOM selectors and fallback heuristics.
  - Use MutationObserver for dynamic content.
  - Send data to background service worker.

- **Popup UI**:
  - HTML/CSS/JS for displaying scraped jobs, generated proposals.
  - Buttons for copying proposal, editing, opening Propelo web app.

## Firebase Cloud Functions

- **generateProposal.ts**:
  - Triggered by HTTPS request from extension.
  - Retrieves user context from Firestore.
  - Merges with scraped data.
  - Calls Anthropic Claude API with the merged data.
  - Returns structured proposal.

## Firestore Database

- **Collections**:
  - `users`: User authentication data.
  - `userContext`: User preferences, past jobs, etc.
  - `proposals`: Generated proposals for review.

## Integration with Propelo Web App

- **Authentication**: Firebase Auth for user login, linking to web app.
- **API Endpoints**: Extension uses `/api/proposals/generate` to POST scraped data.