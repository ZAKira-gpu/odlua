# Firebase Network Error Fix - Registration Issue

## Problem Diagnosis
Your app registration is failing with `network-request-failed` because the Android emulator cannot reach Firebase services.

**Root Causes Identified:**
1. Firebase Installations Service unavailable
2. No App Check Provider installed (warning, not critical)
3. Network connectivity issues on Android emulator

## Solutions (Try in Order)

### Solution 1: Restart Emulator with Cold Boot ⭐ **RECOMMENDED**
1. Close the current emulator
2. Open Android Studio → AVD Manager
3. Click the dropdown menu (▼) next to your emulator
4. Select **"Cold Boot Now"**
5. Wait for emulator to fully start
6. Run `flutter run` again

### Solution 2: Configure Emulator Network Settings
1. While emulator is running, go to: **Settings → Network & Internet**
2. Toggle **Wi-Fi** OFF and then ON
3. Check if internet is working by opening Chrome in emulator
4. Try registration again

### Solution 3: Use iOS Simulator (Easier Alternative)
iOS simulators typically have better network connectivity:
```bash
# Run on iOS
flutter run -d apple_ios_simulator
```

### Solution 4: Test on Physical Device
Physical devices don't have network issues:
```bash
# Connect your phone via USB and run
flutter devices  # Check device is connected
flutter run      # It will auto-select your phone
```

### Solution 5: Add Network Security Config (For older Android APIs)
If using API < 28, add this to `android/app/src/main/AndroidManifest.xml`:
```xml
<application
    android:usesCleartextTraffic="true"
    ...>
```

### Solution 6: Check Firewall/VPN
- Disable any VPN or firewall temporarily
- Firebase needs access to these domains:
  - `firebaseapp.com`
  - `googleapis.com`
  - `firebase.googleapis.com`

### Solution 7: Update Emulator Network DNS
```bash
# Add to ~/.zshrc or run in terminal
export ANDROID_SDK_ROOT=$HOME/Library/Android/sdk
$ANDROID_SDK_ROOT/platform-tools/adb shell settings put global http_proxy :0
```

## Verification Steps
After applying any fix:
1. Run the app
2. Try to register a new user
3. Check terminal for these SUCCESS indicators:
   ```
   I/flutter: Starting registration for email: ...
   I/flutter: Email format validated
   I/flutter: Checking if email already exists...
   I/flutter: Email check passed - email is available
   I/flutter: Verifying phone number: ...
   I/flutter: OTP code sent. Verification ID: ...
   ```

## Current Debug Logging
The app now has comprehensive print statements for debugging:
- ✅ Email validation
- ✅ Email existence check
- ✅ Phone verification
- ✅ OTP code sending
- ✅ User registration completion
- ✅ Firestore data saving

All errors will be visible in the terminal with full stack traces.

## Quick Test Command
```bash
# iOS (Recommended for testing)
flutter run -d apple_ios_simulator

# Android (after fixing network)
flutter run -d sdk_gphone64_arm64

# Physical Device
flutter run
```

## Still Not Working?
If none of the above works:
1. Check Firebase Console → Authentication → Sign-in methods
2. Ensure **Email/Password** is ENABLED
3. Ensure **Phone** authentication is ENABLED
4. Check Firebase project billing (Phone auth requires Blaze plan)
5. Verify SHA-1/SHA-256 fingerprints are added to Firebase project

## Success Indicators in Terminal
When registration works, you'll see:
```
I/flutter: Starting registration for email: test@example.com, phone: +1234567890
I/flutter: Email format validated
I/flutter: Checking if email already exists...
I/flutter: Email check complete. Methods found: 0
I/flutter: Email check passed - email is available
I/flutter: Collecting signup data...
I/flutter: Signup data collected. Starting phone verification...
I/flutter: Verifying phone number: +1234567890
I/flutter: OTP code sent. Verification ID: xxxxx
```

## Additional Notes
- The geocoding timeout is normal and won't affect registration
- Missing localization keys are cosmetic and won't affect functionality
- App Check warning is non-critical (only affects abuse prevention)
