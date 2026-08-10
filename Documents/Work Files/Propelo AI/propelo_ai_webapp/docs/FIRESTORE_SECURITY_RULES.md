# Firestore Security Rules for Account & Proposal Tracking

## Rules to Add

Add these rules to your `firestore.rules` file to secure the new platformAccounts and proposalTracking subcollections:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // User documents - users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Platform Accounts Subcollection
      // Users can only access their own platform account data
      match /platformAccounts/{platform} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if request.auth != null && request.auth.uid == userId
          && request.resource.data.userId == userId;
        
        // Validate platform data structure
        allow create: if request.auth != null && request.auth.uid == userId
          && request.resource.data.keys().hasAll(['platform', 'userId', 'profileData', 'lastSynced'])
          && request.resource.data.platform in ['upwork', 'fiverr', 'freelancer', 'linkedin', 'toptal'];
        
        allow update: if request.auth != null && request.auth.uid == userId
          && request.resource.data.userId == userId
          && resource.data.userId == userId;
      }
      
      // Proposal Tracking Subcollection
      // Users can only access their own proposal submissions
      match /proposalTracking/{proposalId} {
        allow read: if request.auth != null && request.auth.uid == userId;
        allow write: if request.auth != null && request.auth.uid == userId
          && request.resource.data.userId == userId;
        
        // Validate proposal data structure
        allow create: if request.auth != null && request.auth.uid == userId
          && request.resource.data.keys().hasAll(['id', 'platform', 'userId', 'jobTitle'])
          && request.resource.data.platform in ['upwork', 'fiverr', 'freelancer', 'linkedin'];
        
        allow update: if request.auth != null && request.auth.uid == userId
          && request.resource.data.userId == userId
          && resource.data.userId == userId;
      }
    }
    
    // Prevent unauthorized access to all other paths
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

## Rule Explanations

### Platform Accounts Rules
- **Read Access**: Users can only read their own platform account data
- **Write Access**: Users can only write to their own platform accounts and must include their userId
- **Create Validation**: 
  - Requires: platform, userId, profileData, lastSynced fields
  - Platform must be one of: upwork, fiverr, freelancer, linkedin, toptal
- **Update Validation**: Prevents userId tampering

### Proposal Tracking Rules
- **Read Access**: Users can only read their own proposal submissions
- **Write Access**: Users can only write their own proposals and must include their userId
- **Create Validation**:
  - Requires: id, platform, userId, jobTitle fields minimum
  - Platform must be one of: upwork, fiverr, freelancer, linkedin
- **Update Validation**: Prevents userId tampering and cross-user updates

## Testing Security Rules

Use the Firebase Emulator to test these rules:

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Initialize Firebase Emulators
firebase init emulators

# Run emulator with security rules
firebase emulators:start --only firestore
```

## Test Scenarios

### ✅ Should Allow
1. User A creating their own platform account: `users/userA/platformAccounts/upwork`
2. User A reading their own proposals: `users/userA/proposalTracking/*`
3. User A updating their own proposal status
4. Authenticated API calls with matching userId

### ❌ Should Deny
1. User A reading User B's platform accounts
2. User A writing to User B's proposal tracking
3. Unauthenticated requests to any subcollection
4. Creating platform accounts with invalid platform names
5. Creating proposals without required fields (id, platform, userId, jobTitle)
6. Updating a proposal to change the userId

## Deployment

After testing, deploy the updated rules:

```bash
firebase deploy --only firestore:rules
```

## Monitoring

Monitor rule violations in Firebase Console:
1. Go to Firestore → Rules
2. Check "Rules Simulator" to test queries
3. Monitor "Requests" tab for denied access attempts
