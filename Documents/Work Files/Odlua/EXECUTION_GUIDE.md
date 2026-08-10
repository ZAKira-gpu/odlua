# Odlua Phase-by-Phase Execution Guide

## 📚 How to Use This Guide

This document provides detailed execution steps for each phase. Use alongside:
- `IMPLEMENTATION_ROADMAP.md` - Complete technical details
- `IMPLEMENTATION_CHECKLIST.md` - Quick progress tracking  
- `PRIORITY_MATRIX.md` - Priority and resource planning

---

## 🔴 PHASE 1: Critical Security & Authentication Fixes

**Duration:** 2 weeks  
**Team:** 2 developers + 1 QA  
**Dependencies:** None  

### Week 1: Authentication & Verification

#### Day 1-2: Setup & Planning
```bash
# Create feature branch
git checkout -b phase-1-security-auth

# Review current authentication flow
# Check files:
- lib/layout/authentication/
- lib/utils/auth_service.dart
- Firebase Auth configuration
```

**Tasks:**
1. Audit current authentication screens
2. Review Firebase Auth setup
3. Document current issues
4. Create test cases

#### Day 3-4: Terms & Conditions Fix (#1)
**Files to Edit:**
- `lib/layout/authentication/sign_in/sign_in_screen.dart`
- `lib/layout/authentication/widgets/terms_widget.dart`

**Implementation:**
```dart
// Add scrollable terms view
SingleChildScrollView(
  child: Text(
    termsText,
    style: TextStyle(
      color: Colors.black87,
      fontSize: 14,
      height: 1.5,
    ),
  ),
)

// Add "Read full terms" link
TextButton(
  onPressed: () => _showFullTermsDialog(),
  child: Text('Read full Terms & Conditions'),
)
```

**Testing:**
- [ ] Text is readable on all screen sizes
- [ ] Scrolling works smoothly
- [ ] Checkbox functions correctly
- [ ] Link to full terms works
- [ ] Dark mode compatibility

#### Day 5-7: Password Reset Verification (#2, #57)
**Files to Edit:**
- `lib/layout/authentication/forgot_password/forgot_password_screen.dart`
- `lib/utils/auth_service.dart`

**Implementation:**
```dart
Future<void> resetPassword(String email) async {
  // Check if email is verified
  User? user = await _getUserByEmail(email);
  
  if (user != null && !user.emailVerified) {
    throw Exception('Please verify your email first');
  }
  
  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
}
```

**SMS Verification Fix:**
```dart
// Improve phone verification
Future<void> verifyPhoneNumber(String phoneNumber) async {
  await FirebaseAuth.instance.verifyPhoneNumber(
    phoneNumber: phoneNumber,
    timeout: const Duration(seconds: 60),
    verificationCompleted: (PhoneAuthCredential credential) async {
      await _signInWithCredential(credential);
    },
    verificationFailed: (FirebaseAuthException e) {
      if (e.code == 'invalid-phone-number') {
        // Handle properly
      }
    },
    codeSent: (String verificationId, int? resendToken) {
      // Store verificationId for later use
      _currentVerificationId = verificationId;
    },
    codeAutoRetrievalTimeout: (String verificationId) {
      _currentVerificationId = verificationId;
    },
  );
}
```

**Testing:**
- [ ] Unverified emails can't reset password
- [ ] Verification email sent correctly
- [ ] SMS arrives on first attempt
- [ ] Error messages are clear
- [ ] Multiple phone carriers tested

### Week 2: Account Status & Support Email

#### Day 8-9: Account Status Clarity (#3)
**Files to Edit:**
- `lib/layout/profile/profile_screen.dart`
- `lib/layout/authentication/verification_status_widget.dart`

**Implementation:**
```dart
// Add verification badge
Widget _buildVerificationBadge() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: user.emailVerified ? Colors.green : Colors.orange,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Icon(
          user.emailVerified ? Icons.verified : Icons.warning,
          size: 16,
        ),
        SizedBox(width: 4),
        Text(
          user.emailVerified ? 'Verified' : 'Pending Verification',
        ),
      ],
    ),
  );
}
```

#### Day 10-12: Support Email Update (#4)
**Files to Search & Replace:**
```bash
# Search for old email patterns
grep -r "support@" lib/
grep -r "contact@" lib/
grep -r "help@" lib/

# Files likely to update:
- lib/layout/profile/support_screen.dart
- lib/layout/profile/about_screen.dart
- Privacy Policy document
- Firebase email templates
- assets/i18n/*.json
```

**Update in Firebase Console:**
1. Firebase → Authentication → Templates
2. Email verification template
3. Password reset template
4. Update sender display name to "Odlua Support"

#### Day 13-14: Testing & Review
- [ ] Full authentication flow test
- [ ] Password reset end-to-end
- [ ] SMS verification multiple tests
- [ ] Support email in all locations
- [ ] Code review
- [ ] QA sign-off

---

## 🟡 PHASE 2: Location & Permissions UX

**Duration:** 1.5 weeks  
**Team:** 1-2 developers  
**Dependencies:** Phase 1 complete  

### Implementation Steps

#### Step 1: Make Location Optional (#6, #33)
**File:** `lib/utils/location_service.dart`

```dart
class LocationService {
  static const String _locationEnabledKey = 'location_enabled';
  
  Future<bool> isLocationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationEnabledKey) ?? false;
  }
  
  Future<void> setLocationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationEnabledKey, enabled);
  }
  
  Future<Position?> getCurrentLocation({bool showDialog = true}) async {
    if (!await isLocationEnabled()) {
      if (showDialog) {
        // Ask user if they want to enable location
        bool? enable = await _showLocationDialog();
        if (enable == true) {
          await setLocationEnabled(true);
        } else {
          return null; // User declined
        }
      } else {
        return null;
      }
    }
    
    return await Geolocator.getCurrentPosition();
  }
}
```

#### Step 2: Manual Location Input (#18, #67)
**File:** `lib/layout/dishes/dishes_screen/location_input_widget.dart`

```dart
class LocationInputWidget extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'Enter city or postal code',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.my_location),
          onPressed: _useCurrentLocation,
          tooltip: 'Use my location',
        ),
      ],
    );
  }
}
```

#### Step 3: Privacy - Hide Address (#34)
**Files:**
- `lib/layout/profile/profile_screen.dart`
- `lib/models/user_model.dart`

```dart
// User Model
class UserModel {
  // Private fields (stored but not displayed)
  String? privateFullAddress;
  
  // Public fields (safe to display)
  String? city;
  String? postalCode;
  
  String getPublicAddress() {
    return '${postalCode ?? ''} ${city ?? ''}'.trim();
  }
}

// Update profile display
Text(
  currentUser.getPublicAddress(),
  style: TextStyle(fontSize: 14),
)
```

#### Testing Checklist
- [ ] Location prompt only when needed
- [ ] Settings toggle works
- [ ] Manual city/postal input functional
- [ ] Address privacy maintained
- [ ] Search by location works

---

## 🔴 PHASE 3: Order Management Critical Fixes

**Duration:** 2 weeks  
**Team:** 2 developers + backend focus  
**Dependencies:** Phase 1 complete  

### Critical Fix: Chef Notification (#8)

**File:** `functions/index.js`

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

exports.onOrderCreated = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snap, context) => {
    const order = snap.data();
    const chefId = order.chefId;
    
    // Get chef's FCM token
    const chefDoc = await admin.firestore()
      .collection('users')
      .doc(chefId)
      .get();
    
    const fcmToken = chefDoc.data()?.fcmToken;
    
    if (!fcmToken) {
      console.error('Chef has no FCM token');
      return null;
    }
    
    // Send notification
    const message = {
      notification: {
        title: '🎉 New Order!',
        body: `You have a new order for ${order.dishName}`,
      },
      data: {
        orderId: context.params.orderId,
        type: 'new_order',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      token: fcmToken,
    };
    
    try {
      await admin.messaging().send(message);
      console.log('Notification sent successfully');
      
      // Update meal inventory
      await admin.firestore()
        .collection('dishes')
        .doc(order.dishId)
        .update({
          availableQuantity: admin.firestore.FieldValue.increment(-order.quantity),
        });
        
    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Fallback: Send email
      await sendEmailNotification(chefDoc.data().email, order);
    }
    
    return null;
  });
```

### Order Count Fix (#7)

**File:** `lib/layout/order_tracking_system/order_service.dart`

```dart
Future<int> getCompletedOrdersCount(String userId) async {
  final querySnapshot = await FirebaseFirestore.instance
    .collection('orders')
    .where('userId', isEqualTo: userId)
    .where('status', isEqualTo: OrderStatus.completed.toString())
    .get();
  
  // Only count actually completed, exclude cancelled
  return querySnapshot.docs
    .where((doc) => doc.data()['status'] != OrderStatus.cancelled.toString())
    .length;
}
```

### Testing
- [ ] Chef receives notification instantly
- [ ] Meal count decreases correctly
- [ ] Cancelled orders not counted
- [ ] Order statistics accurate
- [ ] Email fallback works

---

## 🟡 PHASE 4: Chat System Improvements

**Duration:** 2 weeks  
**Team:** 2 developers  
**Dependencies:** Phase 3 (notifications)  

### Deep Linking Setup (#10)

**File:** `lib/main.dart`

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  @override
  void initState() {
    super.initState();
    _configureNotificationHandling();
  }
  
  void _configureNotificationHandling() {
    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationClick(message);
    });
    
    // Handle notification tap when app is terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleNotificationClick(message);
      }
    });
  }
  
  void _handleNotificationClick(RemoteMessage message) {
    final data = message.data;
    
    if (data['type'] == 'chat_message') {
      final chatId = data['chatId'];
      final recipientId = data['senderId'];
      
      Get.to(() => ChatScreen(
        chatId: chatId,
        recipientId: recipientId,
      ));
    }
  }
}
```

### Image Viewer (#11)

```dart
// Add photo_view package to pubspec.yaml
// dependencies:
//   photo_view: ^0.14.0

class ChatImageViewer extends StatelessWidget {
  final String imageUrl;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () => _downloadImage(imageUrl),
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: CachedNetworkImageProvider(imageUrl),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 2,
      ),
    );
  }
}

// In chat message widget
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatImageViewer(imageUrl: message.imageUrl),
      ),
    );
  },
  child: CachedNetworkImage(imageUrl: message.imageUrl),
)
```

### Emoji Support (#45)

```dart
// Add emoji_picker_flutter to pubspec.yaml

bool _showEmojiPicker = false;

Column(
  children: [
    Expanded(child: _buildMessageList()),
    _buildInputArea(),
    if (_showEmojiPicker)
      SizedBox(
        height: 250,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) {
            _textController.text += emoji.emoji;
          },
        ),
      ),
  ],
)

// Input area with emoji button
Row(
  children: [
    IconButton(
      icon: Icon(_showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions),
      onPressed: () {
        setState(() {
          _showEmojiPicker = !_showEmojiPicker;
        });
      },
    ),
    Expanded(
      child: TextField(
        controller: _textController,
        // ...
      ),
    ),
  ],
)
```

---

## 🟢 PHASE 5-13: Continued Implementation

*Due to length, phases 5-13 follow similar detailed structure. Each phase includes:*
- Specific file paths
- Code snippets
- Testing checklists
- Dependencies
- Rollback procedures

**Full implementation details available in `IMPLEMENTATION_ROADMAP.md`**

---

## 🔧 Development Workflow

### For Each Issue:
1. **Create branch:** `git checkout -b issue-<number>-short-description`
2. **Implement:** Follow code snippets and guidelines
3. **Test locally:** Run all relevant tests
4. **Code review:** Submit PR for team review
5. **QA testing:** Pass to QA team
6. **Merge:** Merge to develop branch
7. **Update docs:** Check off in IMPLEMENTATION_CHECKLIST.md

### Testing Standards:
```dart
// Example unit test
test('Cancelled orders should not count as completed', () {
  final service = OrderService();
  // ... test implementation
});

// Example widget test
testWidgets('Terms should be readable', (WidgetTester tester) async {
  await tester.pumpWidget(SignInScreen());
  expect(find.text('Terms & Conditions'), findsOneWidget);
});
```

### Deployment Process:
```bash
# After each phase
git checkout develop
git merge phase-X-feature-name
flutter test
flutter build appbundle
# Deploy to internal testing track
```

---

## 📞 Support & Questions

- **Technical Lead:** Review architecture decisions
- **Product Owner:** Approve UI/UX changes
- **QA Lead:** Sign off on test coverage

---

**Last Updated:** November 9, 2025  
**Version:** 1.0
