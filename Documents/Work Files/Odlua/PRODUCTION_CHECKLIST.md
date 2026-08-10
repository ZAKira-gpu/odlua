# 📋 Odlua Production Checklist

## ✅ Visual Polish
- [ ] Remove all "lorem ipsum" and placeholder text
- [ ] Verify consistent color scheme across all screens (check `lib/utils/constants/colors.dart`)
- [ ] Check all images load properly (no broken images)
- [ ] Test on multiple screen sizes (small phone, tablet)
- [ ] Add smooth transitions between screens (use `FadePageRoute`)
- [ ] Ensure proper padding/margins on all screens (check `custom_widgets.dart`)
- [ ] Review empty states for all lists (use `EmptyStateWidget`)
- [ ] Check loading states (use `OdluaLoadingIndicator`)
- [ ] Review error states (use `ErrorStateWidget`)

## ✅ Functionality
- [ ] Test all login flows (phone, email, Google, Apple)
- [ ] Test signup and OTP verification
- [ ] Verify password reset works
- [ ] Test dish search and filters
- [ ] Test checkout and order placement
- [ ] Test chat functionality
- [ ] Verify location services work
- [ ] Test reservation system
- [ ] **Remove all print() statements** (use `DebugHelper` instead)
- [ ] Set `DebugHelper.isDebugMode = false` in `lib/utils/helpers/debug_helper.dart`
- [ ] Test all forms validate properly
- [ ] Verify no blank field submits or crashes
- [ ] Test all buttons work (no dead or duplicate buttons)

## ✅ Branding
- [ ] App icon generated and looks good on both platforms
- [ ] Splash screen shows brand correctly
- [ ] App name displays correctly on device
- [ ] All app bars show "Odlua" not "Flutter Demo"
- [ ] About/Profile shows correct app version
- [ ] Consistent logo usage across all screens

## ✅ User Experience
- [ ] Empty states show friendly messages (implemented via `EmptyStateWidget`)
- [ ] Loading indicators appear during async operations (use `OdluaLoadingIndicator`)
- [ ] Success/error messages show via Snackbar (use helper functions)
- [ ] Back button navigation works smoothly
- [ ] **Onboarding shows only on first launch** ✅ (implemented via `OnboardingHelper`)
- [ ] Default language is English ✅
- [ ] All forms validate properly
- [ ] No duplicate buttons or actions
- [ ] Confirmation dialogs for destructive actions

## ✅ Performance
- [ ] No memory leaks (dispose controllers properly)
- [ ] Images are optimized (not too large)
- [ ] API calls have proper timeout handling
- [ ] Offline mode shows appropriate message
- [ ] Test with slow internet connection
- [ ] Test with no internet connection

## ✅ Legal & Privacy
- [ ] Privacy policy link in profile ✅
- [ ] Terms of service accessible ✅
- [ ] Data collection disclosed
- [ ] Required permissions explained
- [ ] Contact support email correct (`odlua.app@gmail.com`)

## ✅ Testing Checklist
- [ ] Test on iOS device
- [ ] Test on Android device
- [ ] Test with slow internet
- [ ] Test with no internet
- [ ] Test with different user types (chef/client)
- [ ] Test push notifications
- [ ] Test location services
- [ ] Test chat messages
- [ ] Test order placement and checkout
- [ ] Test reservation system

## ✅ Code Quality
- [ ] All `print()` statements replaced with `DebugHelper`
- [ ] No hardcoded strings (all use `.tr()` for i18n)
- [ ] No TODO or FIXME comments left
- [ ] All images in `image_strings.dart` exist in assets
- [ ] No compilation errors or warnings
- [ ] Linter passes (`flutter analyze`)

## ✅ Build Configuration
- [ ] Update version number in `pubspec.yaml`
- [ ] Generate app icons: `flutter pub run flutter_launcher_icons`
- [ ] Generate splash screens: `flutter pub run flutter_native_splash:create`
- [ ] Update Android package name (if needed)
- [ ] Update iOS bundle ID (if needed)
- [ ] Configure Firebase for production
- [ ] Set up proper signing certificates

## 🚀 Pre-Release Commands

### 1. Clean and Get Dependencies
```bash
flutter clean
flutter pub get
```

### 2. Run Code Analysis
```bash
flutter analyze
```

### 3. Generate App Icons
```bash
flutter pub run flutter_launcher_icons
```

### 4. Generate Splash Screens
```bash
flutter pub run flutter_native_splash:create
```

### 5. Build Release (Android)
```bash
flutter build apk --release
flutter build appbundle --release
```

### 6. Build Release (iOS)
```bash
flutter build ios --release
```

## 📝 Notes

### Debug Helper Usage
Replace all `print()` statements with:
- `DebugHelper.log('message')` - General logs
- `DebugHelper.logError('message', error: e)` - Errors
- `DebugHelper.logSuccess('message')` - Success messages
- `DebugHelper.logWarning('message')` - Warnings
- `DebugHelper.logInfo('message')` - Info messages

### Custom Widgets Available
- `OdluaLoadingIndicator(message: 'Loading...')` - Loading states
- `EmptyStateWidget(title: 'No Items', message: '...')` - Empty states
- `ErrorStateWidget(message: 'Error', onRetry: () {})` - Error states
- `showSuccessSnackbar(context, 'Success!')` - Success messages
- `showErrorSnackbar(context, 'Error!')` - Error messages
- `showConfirmationDialog(context, ...)` - Confirmation dialogs

### Onboarding Helper
- `OnboardingHelper.hasSeenOnboarding()` - Check if seen
- `OnboardingHelper.markOnboardingComplete()` - Mark as complete
- `OnboardingHelper.resetOnboarding()` - Reset (for testing)

## 🔍 Search for Issues

### Find all print statements
```bash
grep -r "print(" lib/ --include="*.dart"
```

### Find TODO comments
```bash
grep -r "TODO" lib/ --include="*.dart"
```

### Find FIXME comments
```bash
grep -r "FIXME" lib/ --include="*.dart"
```

### Find hardcoded strings (not perfect but helps)
```bash
grep -r "Text('" lib/ --include="*.dart" | grep -v ".tr()"
```

## 🎯 Final Steps Before Submission

1. Test app thoroughly on real devices (both iOS and Android)
2. Verify all Firebase services work in production
3. Test push notifications end-to-end
4. Verify payment processing (if applicable)
5. Test chat functionality between real users
6. Verify location services work accurately
7. Test order flow from start to finish
8. Create demo video/screenshots for store listing
9. Write compelling app store description
10. Submit for review!

---

**Last Updated:** $(date)
**App Version:** 1.0.0+1
**Status:** 🚧 In Progress
