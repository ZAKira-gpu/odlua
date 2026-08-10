# Propelo Chrome Extension Overview

## Mission
The Propelo Chrome Extension automates the detection and scraping of freelance job postings from Upwork, Fiverr, Freelancer, and LinkedIn. It extracts structured data such as job titles, descriptions, budgets, and skills, normalizes this data into a predefined schema, and securely transmits it to a Firebase Cloud Function. The function then merges the scraped data with the user's stored context in Firestore and leverages the Anthropic Claude Sonnet 4.5 API to generate a tailored proposal. The extension displays this proposal, providing tools for copying, editing, and accessing the full Propelo web app.

## Data Flow
1. **Scraping**: Content scripts in the Chrome extension detect and extract data from job listing pages.
2. **Normalization**: The data is converted to a standard JSON schema.
3. **Backend Processing**: The normalized data is sent via HTTPS to a Firebase Cloud Function endpoint.
4. **AI Proposal Generation**: The function queries the Claude API with the merged data and user context.
5. **Response Handling**: The generated proposal is returned and displayed in the extension's popup.

## Integration with Firebase and Propelo Web App
- **Firebase Cloud Functions**: These handle the server-side logic for proposal generation, using environment variables for API keys and Firestore for data persistence.
- **Propelo Web App**: The extension integrates with the web app for user authentication, viewing proposal history, and configuration settings. API calls are made to backend endpoints for features like opening the web app or managing user preferences.

## Key Components
- **Frontend Extension**: Built with Manifest V3, includes background service worker for scheduling, popup UI for display, and content scripts for scraping.
- **Backend**: Firebase Cloud Functions written in TypeScript, managing the AI call and data storage.
- **Storage**: Firestore for user context and proposal data.