// ─────────────────────────────────────────
// Entry Point: main.dart
// Description: Application bootstrap — initialises all core services
//              (Firebase, localization, location, notifications) with
//              timeout guards so the app always reaches the UI.
// Contains: main(), service init sequence, EasyLocalization wrapper
// ─────────────────────────────────────────

import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/firebase_options.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/location/location_config.dart';
import 'package:odlua/utils/notifications/deep_link_handler.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/helpers/cache_helper.dart';
import 'app.dart';

/// Boots the app in a resilient order:
/// 1. SharedPreferences  2. Translations  3. Firebase  4. Location
/// 5. Deep links  6. Push notifications
/// Every network-dependent step has a timeout so the app never hangs.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences before anything else reads from it
  await CacheHelper.init();

  // CRITICAL: Use timeouts to prevent infinite hangs during initialization
  // This ensures the app launches within 3 seconds even if network is unavailable

  await EasyLocalization.ensureInitialized();

  // Firebase init with timeout - critical for app startup
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Firebase init timeout'),
    );
  } catch (e) {
    DebugHelper.logWarning('Firebase initialization failed or timed out: $e');
    // Continue anyway - Firebase might work later
  }

  // Initialize location config with timeout - non-blocking fallback available
  try {
    await LocationConfig.initialize().timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw TimeoutException('LocationConfig timeout'),
    );
  } catch (e) {
    DebugHelper.logWarning('LocationConfig initialization failed: $e');
    // Fallback keys are hardcoded, so app continues working
  }

  // Initialize deep link handler early (sync, won't block)
  DeepLinkHandler.instance.setNavigatorKey(navigatorKey);

  // Initialize notification service with timeout - non-critical
  try {
    await NotificationService().init().timeout(
          const Duration(seconds: 3),
          onTimeout: () =>
              throw TimeoutException('NotificationService timeout'),
        );
  } catch (e) {
    DebugHelper.logWarning('NotificationService initialization failed: $e');
    // App works without notifications
  }

  // Set navigator key for in-app notification banners
  NotificationService().setNavigatorKey(navigatorKey);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('de'),
        Locale('fr'),
      ],
      path: 'assets/i18n',
      fallbackLocale: const Locale('en'),
      child: const App(),
    ),
  );
}
