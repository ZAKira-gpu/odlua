# Odlua Implementation Priority Matrix

## 🎯 Start Here: Top 10 Critical Issues

These issues should be addressed **immediately** as they affect security, data integrity, or core functionality:

| # | Issue | Impact | Effort | Phase |
|---|-------|--------|--------|-------|
| 2 | Password reset without email verification | 🔴 Security Risk | Medium | 1 |
| 57 | SMS verification fails first time | 🔴 Blocks Users | Medium | 1 |
| 8 | Chef not notified on order | 🔴 Lost Revenue | High | 3 |
| 7 | Cancelled orders count as completed | 🔴 Wrong Data | Medium | 3 |
| 4 | Update support email | 🔴 Communication | Low | 1 |
| 10 | App doesn't open from notification | 🔴 UX Blocker | High | 4 |
| 56 | In-app reporting doesn't work | 🔴 Safety Issue | Medium | 4 |
| 49 | Expired dishes not auto-deleted | 🔴 Data Quality | Medium | 9 |
| 6 | Location request bothers users | 🟡 UX Problem | Medium | 2 |
| 1 | Terms not readable | 🟡 Legal/UX | Low | 1 |

---

## 📊 Issue Priority Matrix

### High Impact + Low Effort (Do First) ⭐
| Issue | Description | Phase |
|-------|-------------|-------|
| #4 | Update support email | 1 |
| #20 | Hide UID below profile | 5 |
| #43 | Hide last seen in chat | 4 |
| #42 | Remove offer timer | 3 |
| #59 | Fix Drink category | 8 |
| #31 | Fix Odlua logo translation | 5 |
| #23 | Replace Message with Notification label | 6 |

### High Impact + High Effort (Schedule & Plan) 📅
| Issue | Description | Phase |
|-------|-------------|-------|
| #8 | Chef notification on order | 3 |
| #68 | Unify My Listings section | 11 |
| #10 | Fix notification deep linking | 4 |
| #28 | Enable chef search | 8 |
| #64 | Pre-order system | 10 |
| #24 | Rating system | 7 |
| #50 | Dish save/repost feature | 9 |

### Low Impact + Low Effort (Quick Wins) ✅
| Issue | Description | Phase |
|-------|-------------|-------|
| #16 | Reduce chat box size | 5 |
| #40 | Replace Menu with Message | 11 |
| #37 | Min 2 ingredients | 10 |
| #35 | Negotiable price option | 10 |
| #63 | Add "New" label | 9 |
| #13 | Complete splash logo | 5 |

### Low Impact + High Effort (Do Last) ⏳
| Issue | Description | Phase |
|-------|-------------|-------|
| #60 | Demo plates marketing | 12 |
| #61 | Hide demo when chefs active | 12 |
| #27 | Profile picture moderation | 8 |
| #41 | Calendar full week view | 11 |

---

## 🚦 Implementation Sequence Recommendation

### Sprint 1 (Week 1-2): Foundation & Security
**Goal:** Fix critical security and authentication issues
- [ ] #4 - Support email
- [ ] #2 - Password reset verification
- [ ] #57 - SMS verification bug
- [ ] #1 - Terms visibility
- [ ] #3 - Account status clarity

### Sprint 2 (Week 2-3): Location & Core UX
**Goal:** Improve location handling and reduce friction
- [ ] #6 - Optional location at login
- [ ] #5 - Flexible location activation
- [ ] #33 - Manual location toggle
- [ ] #34 - Hide private address
- [ ] #18 - Filters without GPS

### Sprint 3 (Week 3-4): Order Flow Critical
**Goal:** Fix broken order and notification system
- [ ] #8 - Chef notification
- [ ] #7 - Order count logic
- [ ] #32 - Page blink fix
- [ ] #42 - Remove timer

### Sprint 4 (Week 4-5): Chat Foundation
**Goal:** Fix critical chat issues
- [ ] #10 - Notification deep linking
- [ ] #12 - Input vibration fix
- [ ] #56 - In-app reporting
- [ ] #9 - Message chef from order

### Sprint 5 (Week 5-6): Chat Polish
**Goal:** Complete chat improvements
- [ ] #11 - Picture viewing
- [ ] #38 - Message before order
- [ ] #43 - Hide last seen
- [ ] #45 - Emoji support
- [ ] #58 - Timestamp fix

### Sprint 6 (Week 6-7): UI Quick Wins
**Goal:** Low-effort visual improvements
- [ ] #20 - Hide UID
- [ ] #31 - Logo translation
- [ ] #13 - Splash screen
- [ ] #16 - Chat box size
- [ ] #17 - Language switcher

### Sprint 7 (Week 7-8): Dish Browsing
**Goal:** Improve dish discovery and viewing
- [ ] #30 - 2 photos per row
- [ ] #14 - Vertical browsing
- [ ] #15 - Photo zoom
- [ ] #65 - Photo quality
- [ ] #29 - Home refresh

### Sprint 8 (Week 8-9): Notifications System
**Goal:** Complete notification improvements
- [ ] #21 - Notification location
- [ ] #22 - On-screen display
- [ ] #23 - Label updates
- [ ] #54 - Email templates
- [ ] #55 - Favorite notifications

### Sprint 9 (Week 9-10): Search & Discovery
**Goal:** Enhance search capabilities
- [ ] #28 - Chef search
- [ ] #67 - City/postal search
- [ ] #59 - Drink category
- [ ] #27 - Content moderation

### Sprint 10 (Week 10-11): Dish Lifecycle
**Goal:** Automated dish management
- [ ] #49/#51 - Auto-delete expired
- [ ] #50 - Save/repost feature
- [ ] #62 - Preserve likes
- [ ] #63 - "New" label
- [ ] #66 - Unify categories

### Sprint 11 (Week 11-12): Social Features
**Goal:** Add engagement features
- [ ] #24 - Rating system
- [ ] #25 - Follow/review chefs
- [ ] #26 - Likes/views count
- [ ] #52 - Favorites

### Sprint 12 (Week 12-13): Business Features
**Goal:** Advanced meal configuration
- [ ] #64/#44 - Pre-order system
- [ ] #35 - Negotiable price
- [ ] #36 - Merge meal categories
- [ ] #37 - Min ingredients
- [ ] #47 - Exchange logic

### Sprint 13 (Week 13-14): Navigation
**Goal:** Improve app structure
- [ ] #68 - My Listings unified
- [ ] #40 - Menu/Message labels
- [ ] #41 - Calendar scheduling
- [ ] #46 - Language persistence

### Sprint 14 (Week 14-15): Polish & Marketing
**Goal:** Final touches
- [ ] #60 - Demo plates
- [ ] #61 - Hide demo logic
- [ ] #19 - Privacy policy email
- [ ] #53 - Reclamation process
- [ ] #39 - Payment evaluation

---

## 📈 Resource Allocation Guide

### Backend Developer Focus
1. **Critical:** #8, #2, #57, #49
2. **High:** #10, #56, #55, #27
3. **Medium:** #64, #50, #7

### Frontend Developer Focus
1. **Critical:** #1, #6, #10, #12
2. **High:** #30, #14, #68, #24
3. **Medium:** #15, #17, #11, #28

### Design Focus
1. **Critical:** #13, #65, #30
2. **High:** #14, #15, #22
3. **Medium:** #16, #63, #54

### DevOps/Infrastructure
1. **Critical:** #49, #8, #10
2. **High:** #55, #27, #54
3. **Medium:** #60, #61

---

## 🎯 Success Metrics

### Phase 1-3 (Critical Fixes)
- Zero authentication failures
- 100% chef notification delivery
- < 5% order counting errors
- User complaints down 80%

### Phase 4-6 (Chat & Notifications)
- 90% notification tap-through rate
- Chat load time < 2 seconds
- Zero chat sync issues
- Emoji usage > 30% of messages

### Phase 7-9 (Features & Search)
- Average rating > 4.0 stars
- Search success rate > 85%
- Dish discovery time reduced 40%
- Favorite feature usage > 60%

### Phase 10-13 (Advanced Features)
- Pre-order adoption > 20%
- My Listings engagement up 50%
- Demo conversion rate tracked
- Zero privacy policy violations

---

## ⚠️ Risk Mitigation

### High Risk Items
| Issue | Risk | Mitigation |
|-------|------|------------|
| #8 | Chef loses orders | Add fallback email notification |
| #2 | Account security | Add extra verification steps |
| #68 | Complex refactor | Phase implementation, feature flags |
| #64 | Pre-order complexity | Start with simple MVP |
| #27 | Moderation accuracy | Manual review fallback |

### Dependencies to Watch
- #10 depends on notification infrastructure
- #68 requires backend schema changes
- #64 affects multiple order flows
- #55 requires #52 (favorites) first
- #62 depends on #50 implementation

---

**Last Updated:** November 9, 2025  
**Next Review:** After Sprint 3 completion
