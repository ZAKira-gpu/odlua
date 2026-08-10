# SETUP.md — Developer Onboarding Guide

> **Goal:** A new engineer clones this repo, follows these steps, and is running the app within 30 minutes.

---

## Prerequisites

| Tool | Version | Check |
|---|---|---|
| Flutter SDK | ≥ 3.1.5 < 4.0.0 | `flutter --version` |
| Dart | comes with Flutter | `dart --version` |
| Xcode | latest stable (iOS) | `xcode-select -p` |
| CocoaPods | latest | `pod --version` |
| Android Studio | latest stable | `android` → SDK Manager |
| Java / JDK | 17 | `java -version` |
| Node.js | ≥ 18 (for Cloud Functions) | `node -v` |
| Firebase CLI | latest | `firebase --version` |

---

## 1. Clone & Install

```bash
git clone <repo-url> && cd Odlua

# Flutter deps
flutter pub get

# iOS pods
cd ios && pod install --repo-update && cd ..

# Cloud Functions deps (optional, for backend work)
cd functions && npm install && cd ..
```

---

## 2. Firebase Configuration

The app uses Firebase project **`odlua-139c3`**. Three platform-config files are **gitignored** and must be obtained from the project owner or regenerated:

| File | Platform | Where to place it |
|---|---|---|
| `lib/firebase_options.dart` | Flutter (all) | Already in the correct location |
| `android/app/google-services.json` | Android | `android/app/` |
| `ios/Runner/GoogleService-Info.plist` | iOS | `ios/Runner/` |

### Option A: Get files from team lead
Ask the project owner for the three files above and drop them into their respective paths.

### Option B: Regenerate with FlutterFire CLI

```bash
# Install FlutterFire CLI (one-time)
dart pub global activate flutterfire_cli

# Login to Firebase
firebase login

# Generate config (select project odlua-139c3)
flutterfire configure --project=odlua-139c3
```

This generates all three files automatically.

### Firebase services to enable

In the [Firebase Console](https://console.firebase.google.com/project/odlua-139c3):

- **Authentication** → Email/Password + Phone
- **Cloud Firestore** → Rules are in `firestore.rules`
- **Storage** → For dish images, chat media, profile photos
- **Remote Config** → API keys: `geoapify_api_key`, `google_places_api_key`
- **Cloud Messaging** → Push notifications (handled automatically)

---

## 3. API Keys

### Geoapify (address autocomplete)
The Geoapify key is resolved in this priority order:
1. **Firebase Remote Config** → key: `geoapify_api_key`
2. **Build-time `--dart-define`** → `GEOAPIFY_API_KEY=<key>`
3. **Hardcoded fallback** in `lib/utils/location/location_config.dart`

For development, the fallback key works. For production, set the key in Remote Config.

### Google Maps / Places
- Android: Add your key to `android/app/src/main/AndroidManifest.xml` under `com.google.android.geo.API_KEY`
- iOS: Add your key to `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey`)
- Remote Config: Set `google_places_api_key` for the Places API autocomplete fallback

---

## 4. Android Signing (Release Builds Only)

For release builds, create `android/key.properties` (gitignored):

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=<path-to-keystore.jks>
```

Debug builds use the Flutter debug keystore automatically.

---

## 5. Environment Variables

Pass secrets at build time with `--dart-define`:

```bash
flutter run --dart-define=GEOAPIFY_API_KEY=your_key_here
```

These are read in `lib/config/env.dart`.

---

## 6. Run the App

```bash
# Debug (hot-reload enabled)
flutter run

# Specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Build for release

```bash
# Android AAB
flutter build appbundle --release

# Android APK
flutter build apk --release

# iOS IPA (requires Xcode & signing)
flutter build ipa --release
```

---

## 7. Project Conventions

### File Organisation
- **Screens** live in `lib/layout/<feature>/` (one folder per feature)
- **Shared utilities** live in `lib/utils/<category>/`
- Every Dart file has a 5-line header comment block describing its purpose

### State Management
- **Cubit/BLoC** for global app state (`lib/utils/cubit/`)
- **GetX** for routing and reactive controllers
- **Provider + ChangeNotifier** for screen-scoped controllers (chat)

### Localisation
- Strings are in `assets/i18n/{en,ar,de,fr}.json`
- Use `'key'.tr()` in code (EasyLocalization)
- Add new strings to all 4 JSON files

### Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/methods: `camelCase`
- Private members: `_prefixed`

---

## 8. Firestore Collections

| Collection | Purpose | Key Fields |
|---|---|---|
| `users` | User profiles | `name`, `email`, `isChef`, `allergies`, `location`, `fcmToken` |
| `dishes` | Food listings | `name`, `price`, `chefID`, `category`, `availabilityType`, `exactLocation` |
| `chats` | Conversations | `participants`, `lastMessage`, `lastMessageAt` |
| `chats/{id}/messages` | Chat messages | `senderId`, `text`, `mediaUrls`, `createdAt`, `status` |
| `orders` | Orders | `buyerId`, `sellerId`, `dishId`, `status`, `totalPrice` |
| `reports` | Abuse reports | `reporterId`, `reportedUserId`, `type`, `reason` |
| `version_control` | Force update gate | `minimumVersion`, `latestVersion` |

---

## 9. Common Tasks

### Add a new screen
1. Create `lib/layout/<feature>/<feature>_screen.dart`
2. Add a header comment block (copy the format from any existing screen)
3. Register the route in the appropriate navigation handler

### Add a new Firestore model
1. Create `lib/utils/models/<model>_model.dart`
2. Implement `fromFirestore(DocumentSnapshot)` and `toMap()`
3. Add safe-casting for all fields (see `dish_model.dart` as reference)

### Add a new language
1. Create `assets/i18n/<code>.json` (copy from `en.json`)
2. Add the locale to `supportedLocales` in `main.dart` (EasyLocalization wrapper)

### Deploy Cloud Functions
```bash
cd functions
firebase deploy --only functions
```

---

## 10. Troubleshooting

| Problem | Solution |
|---|---|
| `firebase_options.dart` not found | Run `flutterfire configure --project=odlua-139c3` |
| `google-services.json` missing | Download from Firebase Console → Project Settings → Android app |
| CocoaPods install fails | `cd ios && rm -rf Pods Podfile.lock && pod install --repo-update` |
| Gradle build fails | Ensure JDK 17: `export JAVA_HOME=$(/usr/libexec/java_home -v 17)` |
| FCM not working on iOS | Check APNS key/cert in Firebase Console → Cloud Messaging |
| Location permissions denied | Check `Info.plist` (iOS) and `AndroidManifest.xml` for correct permission strings |
| Hot reload broken | Run `flutter clean && flutter pub get` then restart |
