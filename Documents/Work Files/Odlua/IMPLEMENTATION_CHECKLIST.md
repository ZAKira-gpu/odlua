# Odlua Implementation Checklist
**Quick Reference for All 68 Issues**

## 🔴 PHASE 1: Critical Security & Authentication (Week 1-2)
- [ ] #1 - Terms readable/visible during sign-in
- [ ] #2 - Email verification required for password reset
- [ ] #3 - Clarify account status confirmation
- [ ] #4 - Update support email to support@odlua.com
- [ ] #57 - Fix SMS verification double-attempt bug

## 🟡 PHASE 2: Location & Permissions (Week 2-3)
- [ ] #5 - Improve location activation logic (flexible)
- [ ] #6 - Make login location request optional
- [ ] #18 - Enable filters without GPS
- [ ] #33 - Add manual location on/off toggle
- [ ] #34 - Hide private address, show postal code + city only
- [ ] #67 - Enable search by city/postal code

## 🔴 PHASE 3: Order Management & Notifications (Week 3-4)
- [ ] #7 - Fix cancelled order count logic
- [ ] #8 - Fix chef notification + meal count on order
- [ ] #32 - Fix page blink during order submission
- [ ] #42 - Remove offer acceptance timer

## 🟡 PHASE 4: Chat System (Week 4-6)
- [ ] #9 - Add message chef button on order page
- [ ] #10 - Fix app opening from chat notification
- [ ] #11 - Enable opening pictures in chat
- [ ] #12 - Fix chat input vibration during simultaneous typing
- [ ] #38 - Allow messaging chef before order from profile
- [ ] #43 - Hide 'last seen' for privacy
- [ ] #45 - Add simple emoji support
- [ ] #56 - Fix in-app reclamation/reporting
- [ ] #58 - Fix chat 'recent' timestamp behavior

## 🟢 PHASE 5: UI/UX Polish (Week 6-8)
- [ ] #13 - Complete splash logo, add Odlua branding
- [ ] #14 - Better vertical dish browsing
- [ ] #15 - Add dish photo enlarge/zoom
- [ ] #16 - Reduce chat box size for better look
- [ ] #17 - Make language switcher easily accessible
- [ ] #20 - Hide UID below profile picture
- [ ] #30 - Make dish photos smaller (2 per row, vertical)
- [ ] #31 - Fix Arabic auto-translate of Odlua logo
- [ ] #65 - Improve dish photo quality and detail visibility

## 🟡 PHASE 6: Notifications & Communication (Week 8-9)
- [ ] #21 - Clarify where to view notifications
- [ ] #22 - Simplify on-screen notification display
- [ ] #23 - Replace 'Message' label with 'Notification'
- [ ] #54 - Improve automated email professional look
- [ ] #55 - Add favorite chef/category publish notifications

## 🟢 PHASE 7: Rating & Social Features (Week 9-10)
- [ ] #24 - Add chef and dish rating system
- [ ] #25 - Enable follow and review for chefs
- [ ] #26 - Show likes and views count for dishes
- [ ] #52 - Add Favorite Chef and Favorite Plate Category

## 🟡 PHASE 8: Content Moderation & Search (Week 10-11)
- [ ] #27 - Check profile pictures for inappropriate content
- [ ] #28 - Enable searching for chefs
- [ ] #29 - Improve home page refresh behavior
- [ ] #59 - Fix 'Drink' category visibility

## 🟡 PHASE 9: Dish Management & Lifecycle (Week 11-12)
- [ ] #49 - Auto-delete dishes after expiration
- [ ] #50 - Add save/repost feature for chefs
- [ ] #51 - Fix: dishes remain published when date over
- [ ] #62 - Preserve likes when dish saved for republishing
- [ ] #63 - Add 'New' label to recently published dishes
- [ ] #66 - Unify dish categories in Add/Edit screens

## 🟢 PHASE 10: Business Logic & Meal Config (Week 12-13)
- [ ] #35 - Add negotiable price option
- [ ] #36 - Merge breakfast/lunch/dinner into one category
- [ ] #37 - Allow from 2 ingredients and up
- [ ] #39 - Re-evaluate card payment (temporarily removed)
- [ ] #44 - Pre-order for customers
- [ ] #47 - Improve meal exchange without price
- [ ] #64 - Pre-order option for customers and chefs

## 🟢 PHASE 11: Navigation & Info Architecture (Week 13-14)
- [ ] #40 - Replace 'Menu' with 'Message' section
- [ ] #41 - Fix calendar scheduling (full week)
- [ ] #46 - Fix menu bar language persistence
- [ ] #68 - Unify into 'My Listings' section (dishes, orders, reservations)

## 🔵 PHASE 12: Marketing & Demo Features (Week 14-15)
- [ ] #60 - Show demo plates in areas with no chefs
- [ ] #61 - Hide demo plates when real chefs active

## 🟡 PHASE 13: Privacy & Legal (Week 15-16)
- [ ] #19 - Update email in Privacy Policy
- [ ] #53 - Define plate reclamation process

---

## Priority Legend
- 🔴 **CRITICAL** - Security/breaking issues (must fix immediately)
- 🟡 **HIGH** - Important UX/functionality (fix soon)
- 🟢 **MEDIUM** - Enhancements (schedule accordingly)
- 🔵 **LOW** - Nice-to-have (when time permits)

---

## Progress Tracking

**Total Issues:** 68  
**Completed:** 0  
**In Progress:** 0  
**Not Started:** 68  

**Last Updated:** November 9, 2025
