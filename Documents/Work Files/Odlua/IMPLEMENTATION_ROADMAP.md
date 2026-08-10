# Odlua App - Implementation Roadmap
**Last Updated:** November 9, 2025  
**Total Issues:** 68  
**Estimated Timeline:** 12-16 weeks

---

## 📋 Overview

This document outlines a comprehensive, phased approach to implementing all requested features and fixes for the Odlua app. Issues are organized by priority, dependency, and complexity.

---

## 🎯 Phase Priorities

### **Priority Levels:**
- 🔴 **CRITICAL** - Security, data integrity, or app-breaking issues
- 🟡 **HIGH** - User experience blockers or important functionality
- 🟢 **MEDIUM** - Feature enhancements and improvements
- 🔵 **LOW** - Nice-to-have features and polish

---

## PHASE 1: Critical Security & Authentication Fixes
**Timeline:** Week 1-2  
**Priority:** 🔴 CRITICAL

### Issues Addressed: #1, #2, #3, #4, #57

#### 1.1 Fix Terms & Conditions Visibility (#1)
- **File:** `lib/layout/authentication/sign_in/`
- **Tasks:**
  - [ ] Ensure Terms text is readable (proper contrast, font size)
  - [ ] Add scrollable view for long terms
  - [ ] Fix checkbox/acknowledgment functionality
  - [ ] Add link to full terms page
  - [ ] Test on all screen sizes

#### 1.2 Require Email Verification for Password Reset (#2)
- **Files:** `lib/layout/authentication/forgot_password/`
- **Tasks:**
  - [ ] Update Firebase Auth rules
  - [ ] Add email verification check before reset
  - [ ] Implement verification email sending
  - [ ] Add user feedback for verification status
  - [ ] Test entire password reset flow

#### 1.3 Clarify Account Status Confirmation (#3)
- **Files:** `lib/layout/authentication/`, `lib/layout/profile/`
- **Tasks:**
  - [ ] Add account status indicator in profile
  - [ ] Show verification badge for verified users
  - [ ] Add clear messaging for unverified accounts
  - [ ] Implement re-send verification email
  - [ ] Update onboarding to explain verification

#### 1.4 Update Support Email to support@odlua.com (#4)
- **Files:** Multiple locations
- **Tasks:**
  - [ ] Update in Privacy Policy
  - [ ] Update in Contact/Support screens
  - [ ] Update Firebase email templates
  - [ ] Update in app settings
  - [ ] Search codebase for old email addresses
  - [ ] Update in Google Play & App Store listings

#### 1.5 Fix SMS Verification Double-Attempt Issue (#57)
- **Files:** `lib/layout/authentication/phone_verification/`
- **Tasks:**
  - [ ] Debug Firebase phone auth flow
  - [ ] Check timeout/retry logic
  - [ ] Add proper error handling
  - [ ] Improve user feedback during verification
  - [ ] Test with multiple carriers

---

## PHASE 2: Location & Permissions UX Improvements
**Timeline:** Week 2-3  
**Priority:** 🟡 HIGH

### Issues Addressed: #5, #6, #18, #33, #34, #67

#### 2.1 Improve Location Activation Logic (#5)
- **Files:** `lib/utils/location_service.dart`
- **Tasks:**
  - [ ] Implement proper state management for location
  - [ ] Add re-request capability
  - [ ] Store location permission status
  - [ ] Add manual refresh option
  - [ ] Handle permission denial gracefully

#### 2.2 Make Location Request Optional at Login (#6)
- **Files:** `lib/layout/authentication/login/`, `lib/main.dart`
- **Tasks:**
  - [ ] Remove mandatory location prompt
  - [ ] Request location only when needed (browsing dishes)
  - [ ] Add "Skip for now" option
  - [ ] Store user preference
  - [ ] Add explanation of location benefits

#### 2.3 Enable Filters Without GPS (#18)
- **Files:** `lib/layout/dishes/dishes_screen/`, `lib/layout/home/`
- **Tasks:**
  - [ ] Add manual location input field
  - [ ] Allow city/postal code entry
  - [ ] Update Firestore queries to support manual location
  - [ ] Add "Use my location" vs "Enter location" toggle
  - [ ] Cache last used location

#### 2.4 Add Manual Location On/Off Toggle (#33)
- **Files:** `lib/layout/profile/settings/`
- **Tasks:**
  - [ ] Create settings screen section
  - [ ] Add toggle switch for GPS
  - [ ] Store preference in SharedPreferences
  - [ ] Update app-wide location logic
  - [ ] Show current location status

#### 2.5 Hide Private Address, Show Only Postal Code + City (#34)
- **Files:** `lib/layout/profile/`, `lib/layout/dishes/`
- **Tasks:**
  - [ ] Update user profile display logic
  - [ ] Modify address display components
  - [ ] Keep full address in private user data
  - [ ] Show only city + postal publicly
  - [ ] Update Firestore security rules

#### 2.6 Enable Search by City or Postal Code (#67)
- **Files:** `lib/layout/dishes/search/`, Firestore indexes
- **Tasks:**
  - [ ] Add search field to UI
  - [ ] Create Firestore compound indexes
  - [ ] Implement autocomplete for cities
  - [ ] Add postal code validation
  - [ ] Test search performance

---

## PHASE 3: Order Management & Chef Notification Fixes
**Timeline:** Week 3-4  
**Priority:** 🔴 CRITICAL

### Issues Addressed: #7, #8, #32, #42

#### 3.1 Fix Cancelled Order Count Logic (#7)
- **Files:** `lib/layout/order_tracking_system/`, Cloud Functions
- **Tasks:**
  - [ ] Review order status enum/states
  - [ ] Update counter logic to exclude cancelled
  - [ ] Fix Firestore aggregation queries
  - [ ] Add status filter to analytics
  - [ ] Test all order status transitions

#### 3.2 Fix Chef Notification When Order Placed (#8)
- **Files:** `functions/index.js`, `lib/utils/notification_service.dart`
- **Tasks:**
  - [ ] Debug FCM token registration for chefs
  - [ ] Create Cloud Function trigger on order creation
  - [ ] Send immediate notification to chef
  - [ ] Update meal inventory count correctly
  - [ ] Add notification sound/vibration
  - [ ] Test notification delivery

#### 3.3 Fix Page Blink During Order Submission (#32)
- **Files:** `lib/layout/dishes/confirm_order_screen.dart`
- **Tasks:**
  - [ ] Review state management during submission
  - [ ] Add loading overlay instead of navigation
  - [ ] Optimize widget rebuilds
  - [ ] Use smooth transitions
  - [ ] Test on low-end devices

#### 3.4 Remove Offer Acceptance Timer (#42)
- **Files:** `lib/layout/chef/chef_order_management/`
- **Tasks:**
  - [ ] Remove countdown timer UI
  - [ ] Update order acceptance logic
  - [ ] Remove timer-related Cloud Functions
  - [ ] Simplify order flow
  - [ ] Update user documentation

---

## PHASE 4: Chat System Improvements
**Timeline:** Week 4-6  
**Priority:** 🟡 HIGH

### Issues Addressed: #9, #10, #11, #12, #38, #43, #45, #56, #58

#### 4.1 Add Message Chef Button to Order Page (#9)
- **Files:** `lib/layout/order_tracking_system/order_details.dart`
- **Tasks:**
  - [ ] Add "Message Chef" button to order details
  - [ ] Pass chef ID and context to chat
  - [ ] Handle navigation to chat screen
  - [ ] Pre-fill order reference in chat
  - [ ] Test from various order states

#### 4.2 Fix App Opening from Chat Notification (#10)
- **Files:** `lib/main.dart`, `lib/utils/notification_service.dart`
- **Tasks:**
  - [ ] Implement deep linking for chat
  - [ ] Configure Firebase Dynamic Links or URL scheme
  - [ ] Handle notification tap in background/terminated state
  - [ ] Navigate to specific chat on notification tap
  - [ ] Test on iOS and Android

#### 4.3 Enable Picture Opening/Viewing in Chat (#11)
- **Files:** `lib/layout/chat/chat_screen.dart`
- **Tasks:**
  - [ ] Add image tap handler
  - [ ] Implement full-screen image viewer
  - [ ] Add pinch-to-zoom functionality
  - [ ] Add download/share options
  - [ ] Support multiple image formats

#### 4.4 Fix Chat Input Vibration During Simultaneous Typing (#12)
- **Files:** `lib/layout/chat/chat_screen.dart`
- **Tasks:**
  - [ ] Review TextField focus management
  - [ ] Fix listener update logic
  - [ ] Debounce typing indicator updates
  - [ ] Test with two devices simultaneously
  - [ ] Optimize Firestore real-time listeners

#### 4.5 Enable Messaging Chef Before Order (#38)
- **Files:** `lib/layout/seller/seller_profile_screen.dart`
- **Tasks:**
  - [ ] Add "Message" button to chef profile
  - [ ] Create chat room if doesn't exist
  - [ ] Navigate to chat screen
  - [ ] Add context about which dish interested in
  - [ ] Test message delivery

#### 4.6 Hide 'Last Seen' in Chat for Privacy (#43)
- **Files:** `lib/layout/chat/chat_screen.dart`
- **Tasks:**
  - [ ] Remove last seen display from UI
  - [ ] Keep online/offline indicator only (optional)
  - [ ] Update privacy settings
  - [ ] Clean up Firestore last seen tracking
  - [ ] Update privacy policy

#### 4.7 Add Simple Emoji Support in Chat (#45)
- **Files:** `lib/layout/chat/chat_screen.dart`
- **Tasks:**
  - [ ] Add emoji picker package (emoji_picker_flutter)
  - [ ] Add emoji button to input area
  - [ ] Configure emoji panel
  - [ ] Support emoji rendering
  - [ ] Test on iOS and Android

#### 4.8 Fix In-App Reclamation/Reporting (#56)
- **Files:** `lib/layout/chat/`, Cloud Functions
- **Tasks:**
  - [ ] Debug report/flag functionality
  - [ ] Create proper Firestore collection for reports
  - [ ] Add Cloud Function to process reports
  - [ ] Send admin notification on report
  - [ ] Test end-to-end reporting flow

#### 4.9 Fix Chat 'Recent' Timestamp Behavior (#58)
- **Files:** `lib/layout/chat/chat_list_screen.dart`
- **Tasks:**
  - [ ] Only update timestamp on actual message send
  - [ ] Don't update on chat open/close
  - [ ] Show actual last message time
  - [ ] Sort chats by last message time
  - [ ] Test sorting accuracy

---

## PHASE 5: UI/UX Polish & Design Improvements
**Timeline:** Week 6-8  
**Priority:** 🟢 MEDIUM

### Issues Addressed: #13, #14, #15, #16, #17, #20, #30, #31, #65

#### 5.1 Complete Splash Logo and Add Odlua Branding (#13)
- **Files:** `assets/`, `pubspec.yaml`, splash configuration
- **Tasks:**
  - [ ] Update splash screen asset
  - [ ] Add "Odlua" text to splash
  - [ ] Ensure logo is complete and high-res
  - [ ] Test on various screen sizes
  - [ ] Update app icon if needed

#### 5.2 Implement Better Vertical Dish Browsing (#14)
- **Files:** `lib/layout/dishes/dishes_screen/`, `lib/layout/home/`
- **Tasks:**
  - [ ] Replace horizontal scroll with vertical
  - [ ] Implement GridView with 2 columns
  - [ ] Optimize scroll performance
  - [ ] Add smooth animations
  - [ ] Test with large datasets

#### 5.3 Add Dish Photo Enlarge/Zoom Feature (#15)
- **Files:** `lib/layout/dishes/dish_details/`
- **Tasks:**
  - [ ] Add tap-to-zoom on dish images
  - [ ] Implement photo viewer widget
  - [ ] Support swipe between multiple photos
  - [ ] Add pinch-to-zoom
  - [ ] Add close button

#### 5.4 Reduce Chat Box Size for Better Aesthetics (#16)
- **Files:** `lib/layout/chat/chat_screen.dart`
- **Tasks:**
  - [ ] Reduce input field height
  - [ ] Optimize message bubble sizes
  - [ ] Adjust padding and margins
  - [ ] Improve overall chat layout
  - [ ] Test readability

#### 5.5 Make Language Switcher Easily Accessible (#17)
- **Files:** `lib/layout/home/`, `lib/app.dart`
- **Tasks:**
  - [ ] Add language icon to app bar
  - [ ] Create language selector dialog
  - [ ] Support easy switching (en, ar, fr, de)
  - [ ] Persist language choice
  - [ ] Update entire app on language change

#### 5.6 Hide UID Below Profile Picture (#20)
- **Files:** `lib/layout/profile/profile_screen.dart`
- **Tasks:**
  - [ ] Remove UID display from UI
  - [ ] Keep in debug mode only (optional)
  - [ ] Clean up profile layout
  - [ ] Test profile appearance

#### 5.7 Make Dish Photos Smaller - 2 Per Row (#30)
- **Files:** `lib/layout/dishes/dishes_screen/`, widget components
- **Tasks:**
  - [ ] Implement GridView with 2 columns
  - [ ] Resize image cards
  - [ ] Maintain aspect ratio
  - [ ] Ensure text legibility
  - [ ] Optimize image loading

#### 5.8 Fix Arabic Auto-Translate of Odlua Logo (#31)
- **Files:** `assets/i18n/`, `lib/layout/`
- **Tasks:**
  - [ ] Mark "Odlua" as non-translatable
  - [ ] Update localization files
  - [ ] Test in Arabic mode
  - [ ] Ensure brand consistency

#### 5.9 Improve Dish Photo Quality and Detail Visibility (#65)
- **Files:** `lib/layout/dishes/dish_card.dart`, dish details
- **Tasks:**
  - [ ] Increase image quality settings
  - [ ] Ensure price overlay is readable
  - [ ] Add shadow/border for text contrast
  - [ ] Optimize image compression
  - [ ] Test on various backgrounds

---

## PHASE 6: Notifications & Communication
**Timeline:** Week 8-9  
**Priority:** 🟡 HIGH

### Issues Addressed: #21, #22, #23, #54, #55

#### 6.1 Clarify Notification Viewing Location (#21)
- **Files:** `lib/layout/home/`, navigation
- **Tasks:**
  - [ ] Add notifications icon to app bar
  - [ ] Show badge with unread count
  - [ ] Create dedicated notifications screen
  - [ ] Clear navigation path
  - [ ] Add onboarding tutorial

#### 6.2 Simplify On-Screen Notification Display (#22)
- **Files:** `lib/utils/notification_service.dart`
- **Tasks:**
  - [ ] Simplify in-app notification banners
  - [ ] Reduce display time
  - [ ] Improve styling and positioning
  - [ ] Add dismiss gesture
  - [ ] Test notification UX

#### 6.3 Replace 'Message' Label with 'Notification' (#23)
- **Files:** `assets/i18n/*.json`, UI components
- **Tasks:**
  - [ ] Update all language files
  - [ ] Replace 'Message' with 'Notification' where appropriate
  - [ ] Keep 'Message' for actual chat messages
  - [ ] Review entire app for consistency
  - [ ] Test in all languages

#### 6.4 Improve Automated Email Professional Look (#54)
- **Files:** Firebase email templates, Cloud Functions
- **Tasks:**
  - [ ] Create branded HTML email templates
  - [ ] Add proper sender name and email
  - [ ] Include Odlua logo and colors
  - [ ] Test email rendering across clients
  - [ ] Update all automated emails

#### 6.5 Add Favorite Chef/Dish Category Notifications (#55)
- **Files:** Cloud Functions, `lib/layout/favorites/`
- **Tasks:**
  - [ ] Implement FCM topic subscriptions
  - [ ] Subscribe users to favorite chef topics
  - [ ] Subscribe to category topics
  - [ ] Send notification on new dish publish
  - [ ] Add notification preferences in settings

---

## PHASE 7: Rating & Social Features
**Timeline:** Week 9-10  
**Priority:** 🟢 MEDIUM

### Issues Addressed: #24, #25, #26, #52

#### 7.1 Add Chef and Dish Rating System (#24)
- **Files:** `lib/layout/dishes/`, `lib/layout/seller/`, Firestore
- **Tasks:**
  - [ ] Create rating UI with stars
  - [ ] Add rating collection after order completion
  - [ ] Calculate and display average ratings
  - [ ] Update Firestore schema for ratings
  - [ ] Display ratings on chef profile and dishes

#### 7.2 Enable Follow and Review for Chefs (#25)
- **Files:** `lib/layout/seller/seller_profile_screen.dart`
- **Tasks:**
  - [ ] Add follow button to chef profiles
  - [ ] Store follower relationships in Firestore
  - [ ] Display follower count
  - [ ] Add written review section
  - [ ] Implement review moderation

#### 7.3 Show Likes and Views Count for Each Dish (#26)
- **Files:** `lib/layout/dishes/dish_card.dart`, Firestore
- **Tasks:**
  - [ ] Add like button to dish cards
  - [ ] Track view count on dish open
  - [ ] Display counts with icons
  - [ ] Optimize counter updates
  - [ ] Add trending/popular sorting

#### 7.4 Add Favorite Chef and Plate Category Features (#52)
- **Files:** `lib/layout/favorites/`, `lib/layout/profile/`
- **Tasks:**
  - [ ] Create favorites section in profile
  - [ ] Add favorite chef functionality
  - [ ] Add favorite category selection
  - [ ] Store in user preferences
  - [ ] Use for personalized recommendations

---

## PHASE 8: Content Moderation & Search
**Timeline:** Week 10-11  
**Priority:** 🟡 HIGH

### Issues Addressed: #27, #28, #29, #59

#### 8.1 Add Profile Picture Content Moderation (#27)
- **Files:** Cloud Functions, `lib/layout/profile/`
- **Tasks:**
  - [ ] Integrate ML Kit for image safety detection
  - [ ] Create Cloud Function for image analysis
  - [ ] Flag inappropriate images for review
  - [ ] Add manual admin review interface
  - [ ] Implement image rejection flow

#### 8.2 Enable Searching for Chefs in Search Bar (#28)
- **Files:** `lib/layout/dishes/search/`, Firestore
- **Tasks:**
  - [ ] Add "Chefs" tab to search results
  - [ ] Query chef profiles in search
  - [ ] Display chef search results
  - [ ] Add filters for chef search
  - [ ] Test search performance

#### 8.3 Improve Home Page Refresh Behavior (#29)
- **Files:** `lib/layout/home/home_screen.dart`
- **Tasks:**
  - [ ] Implement proper pull-to-refresh
  - [ ] Add loading indicators
  - [ ] Optimize data fetching
  - [ ] Cache results appropriately
  - [ ] Test refresh on slow connections

#### 8.4 Fix 'Drink' Category Visibility (#59)
- **Files:** `lib/utils/constants.dart`, dish category logic
- **Tasks:**
  - [ ] Check category enum definition
  - [ ] Ensure "Drink" is included
  - [ ] Update UI category filters
  - [ ] Add drink icon
  - [ ] Test category filtering

---

## PHASE 9: Dish Management & Lifecycle
**Timeline:** Week 11-12  
**Priority:** 🟡 HIGH

### Issues Addressed: #49, #50, #51, #62, #63, #66

#### 9.1 Auto-Delete Dishes After Expiration (#49, #51)
- **Files:** Cloud Functions, Firestore
- **Tasks:**
  - [ ] Create scheduled Cloud Function (daily)
  - [ ] Query expired dishes
  - [ ] Archive or delete expired dishes
  - [ ] Notify chef of removal
  - [ ] Test with various expiration dates

#### 9.2 Add Dish Save/Repost Feature for Chefs (#50)
- **Files:** `lib/layout/dishes/`, `lib/layout/seller/`
- **Tasks:**
  - [ ] Add "Save as template" button
  - [ ] Create saved meals Firestore collection
  - [ ] Add "My Saved Meals" section
  - [ ] Implement quick repost functionality
  - [ ] Test template saving and loading

#### 9.3 Preserve Likes When Dish Republished (#62)
- **Files:** `lib/layout/dishes/`, Firestore
- **Tasks:**
  - [ ] Store like count in template
  - [ ] Restore likes on republish
  - [ ] Add "previously X likes" indicator
  - [ ] Update like tracking logic
  - [ ] Test like persistence

#### 9.4 Add 'New' Label to Recently Published Dishes (#63)
- **Files:** `lib/layout/dishes/dish_card.dart`
- **Tasks:**
  - [ ] Add "NEW" badge to dish cards
  - [ ] Calculate if dish is < 24 hours old
  - [ ] Style badge prominently
  - [ ] Auto-remove after time period
  - [ ] Test badge display

#### 9.5 Unify Dish Categories in Add/Edit Screens (#66)
- **Files:** `lib/layout/dishes/add_dishes/`, `lib/layout/dishes/edit_dish/`
- **Tasks:**
  - [ ] Create shared category constants
  - [ ] Update both screens to use same list
  - [ ] Ensure categories match exactly
  - [ ] Include all categories (soup, salad, breakfast, etc.)
  - [ ] Test category selection

---

## PHASE 10: Business Logic & Meal Configuration
**Timeline:** Week 12-13  
**Priority:** 🟢 MEDIUM

### Issues Addressed: #35, #36, #37, #39, #44, #47, #64

#### 10.1 Add Negotiable Price Option (#35)
- **Files:** `lib/layout/dishes/add_dishes/`, dish details
- **Tasks:**
  - [ ] Add "Price negotiable" checkbox
  - [ ] Store in dish data model
  - [ ] Display on dish card/details
  - [ ] Update price display logic
  - [ ] Test negotiation flow

#### 10.2 Merge Breakfast, Lunch, Dinner Categories (#36)
- **Files:** `lib/utils/constants.dart`, category logic
- **Tasks:**
  - [ ] Combine meal time categories
  - [ ] Create single "Meal Time" or remove entirely
  - [ ] Update existing dishes
  - [ ] Update UI dropdowns
  - [ ] Migrate data if needed

#### 10.3 Allow From 2 Ingredients and Up (#37)
- **Files:** `lib/layout/dishes/add_dishes/add_dishes_screen.dart`
- **Tasks:**
  - [ ] Update ingredient validation
  - [ ] Set minimum to 2 ingredients
  - [ ] Update error messages
  - [ ] Test validation logic
  - [ ] Update user guidance

#### 10.4 Re-evaluate Card Payment Feature (#39)
- **Files:** Documentation, payment flow
- **Tasks:**
  - [ ] Document current payment methods
  - [ ] Research payment provider options
  - [ ] Plan future implementation if needed
  - [ ] Update user documentation
  - [ ] Keep payment code modular

#### 10.5 Improve Meal Exchange Logic (#47)
- **Files:** Order flow, exchange screens
- **Tasks:**
  - [ ] Clarify exchange vs purchase UI
  - [ ] Add exchange without price option
  - [ ] Update exchange flow
  - [ ] Add user guidance
  - [ ] Test exchange scenarios

#### 10.6 Add Pre-Order for Customers and Chefs (#44, #64)
- **Files:** `lib/layout/dishes/`, order system
- **Tasks:**
  - [ ] Add "Schedule for later" option
  - [ ] Implement date/time picker
  - [ ] Store pre-order in Firestore
  - [ ] Notify chef of pre-order
  - [ ] Handle pre-order fulfillment
  - [ ] Test scheduling logic

---

## PHASE 11: Navigation & Information Architecture
**Timeline:** Week 13-14  
**Priority:** 🟢 MEDIUM

### Issues Addressed: #40, #41, #46, #68

#### 11.1 Replace 'Menu' with 'Message' Section (#40)
- **Files:** Navigation, `assets/i18n/*.json`
- **Tasks:**
  - [ ] Update navigation labels
  - [ ] Rename Menu to Messages
  - [ ] Update icons
  - [ ] Update all translations
  - [ ] Test navigation flow

#### 11.2 Fix and Organize Calendar Scheduling (#41)
- **Files:** `lib/layout/dishes/`, calendar widgets
- **Tasks:**
  - [ ] Implement week view calendar
  - [ ] Allow scheduling for full week
  - [ ] Add availability management
  - [ ] Improve date picker UI
  - [ ] Test scheduling logic

#### 11.3 Fix Menu Bar Language Persistence (#46)
- **Files:** `lib/app.dart`, `lib/layout/home/`
- **Tasks:**
  - [ ] Debug language change state management
  - [ ] Ensure menu bar updates on language change
  - [ ] Update profile on language change
  - [ ] Test all screens
  - [ ] Fix any cached translations

#### 11.4 Unify Listings into 'My Listings' Section (#68)
- **Files:** `lib/layout/dishes/listings/`, navigation
- **Tasks:**
  - [ ] Create unified "My Listings" screen
  - [ ] Add tabs: My Dishes, My Orders, Active Reservations, Chef Reservations
  - [ ] Implement tab navigation
  - [ ] Update main navigation to point here
  - [ ] Test all listing types

---

## PHASE 12: Marketing & Demo Features
**Timeline:** Week 14-15  
**Priority:** 🔵 LOW

### Issues Addressed: #60, #61

#### 12.1 Add Demo Plates in Areas Without Active Chefs (#60)
- **Files:** `lib/layout/dishes/`, Firestore
- **Tasks:**
  - [ ] Create demo dish data
  - [ ] Add "Demo" flag to dishes
  - [ ] Show demo dishes in empty areas
  - [ ] Add "Demo - Example only" label
  - [ ] Update search/filter logic

#### 12.2 Hide Demo Plates When Real Chefs Active (#61)
- **Files:** `lib/layout/dishes/`, dish query logic
- **Tasks:**
  - [ ] Check for active chefs in user's area
  - [ ] Filter out demo dishes if real chefs exist
  - [ ] Optimize query performance
  - [ ] Test transition from demo to real
  - [ ] Monitor chef activity

---

## PHASE 13: Privacy & Legal Compliance
**Timeline:** Week 15-16  
**Priority:** 🟡 HIGH

### Issues Addressed: #19, #53

#### 13.1 Update Email in Privacy Policy (#19)
- **Files:** Privacy policy document, web assets
- **Tasks:**
  - [ ] Update privacy policy document
  - [ ] Change to support@odlua.com
  - [ ] Update in-app privacy policy display
  - [ ] Update web version
  - [ ] Get legal review if needed

#### 13.2 Define Plate Reclamation Process (#53)
- **Files:** Documentation, reporting system
- **Tasks:**
  - [ ] Define reclamation workflow
  - [ ] Decide: chef notification vs admin review
  - [ ] Create reclamation UI
  - [ ] Implement notification system
  - [ ] Test reclamation flow
  - [ ] Document process for users

---

## 📊 Implementation Metrics

### Complexity Breakdown
- **Simple fixes:** 18 issues (~1-2 hours each)
- **Medium complexity:** 32 issues (~4-8 hours each)
- **Complex features:** 18 issues (~1-3 days each)

### Resource Requirements
- **Frontend Development:** ~70% of work
- **Backend/Cloud Functions:** ~20% of work
- **Design/UX:** ~10% of work

### Testing Requirements
- **Unit tests:** All new functions
- **Integration tests:** Critical flows (auth, orders, payment)
- **UI tests:** Main user journeys
- **Manual QA:** Full regression before each phase release

---

## 🚀 Deployment Strategy

### Phased Rollout
1. **Internal Testing:** After each phase
2. **Beta Testing:** Phases 1-3 combined
3. **Staged Rollout:** 10% → 25% → 50% → 100%
4. **Monitoring:** Firebase Analytics, Crashlytics

### Rollback Plan
- Keep previous version ready
- Feature flags for major changes
- Database migrations reversible
- Quick rollback procedure documented

---

## 📝 Notes and Considerations

### Breaking Changes
- Database schema changes require migration
- Some features need backend API updates
- Consider backward compatibility

### Dependencies
- Some issues must be done in order
- Chat improvements depend on notification fixes
- UI changes may require design assets

### User Communication
- Announce major changes in release notes
- In-app changelog for significant features
- Email notification for security updates

---

## ✅ Definition of Done

Each issue is complete when:
- [ ] Code implemented and peer-reviewed
- [ ] Unit tests written and passing
- [ ] Integration tests passing
- [ ] Manual QA completed
- [ ] Documentation updated
- [ ] Translations updated (en, ar, fr, de)
- [ ] Performance tested
- [ ] Accessibility verified
- [ ] Deployed to staging
- [ ] Product owner approval

---

## 🔄 Review Cycle

- **Daily Standups:** Progress tracking
- **Weekly Reviews:** Demo completed features
- **Phase Reviews:** Stakeholder approval before next phase
- **Post-Launch Reviews:** Monitor metrics and user feedback

---

**End of Implementation Roadmap**
