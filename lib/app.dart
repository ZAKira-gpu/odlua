// ─────────────────────────────────────────
// Screen: App (Root Widget)
// Description: Orchestrates the full app lifecycle — splash → version
//              gate → onboarding → auth check → main layout.
// Contains: App, AuthWrapper, OdluaLayout (bottom-nav shell),
//           _VersionCheckResult, _UserDataLoader, deep-link handler
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odlua/layout/authentication/login/login.dart';
import 'package:odlua/layout/authentication/account_type/account_type_screen.dart';
import 'package:odlua/layout/authentication/chef_application/chef_application_screen.dart';
import 'package:odlua/layout/force_update_screen.dart';
import 'package:odlua/layout/onboarding/onboarding.dart';
import 'package:odlua/layout/splash/static_splash_screen.dart';
import 'package:odlua/utils/cubit/cubit.dart';
import 'package:odlua/utils/cubit/states.dart';
import 'package:odlua/utils/theme/theme.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/onboarding_helper.dart';
import 'package:odlua/utils/notifications/deep_link_handler.dart';
import 'package:odlua/utils/services/daily_quantity_refresh_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _showSplash = true;
  bool _initComplete = false;
  _VersionCheckResult? _versionResult;
  bool _hasSeenOnboarding = false;

  /// Called once when the splash animation finishes.
  /// Kicks off all async checks sequentially and writes state exactly once.
  void _onSplashComplete() {
    setState(() => _showSplash = false);
    _runPostSplashInit();
  }

  Future<void> _runPostSplashInit() async {
    DebugHelper.logInfo('🚀 _runPostSplashInit started');
    // 1. Version check
    try {
      DebugHelper.logInfo('📦 Starting version check...');
      _versionResult = await _checkVersionRequirement().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
      DebugHelper.logInfo(
          '✅ Version check done: ${_versionResult?.requiresForceUpdate}');
    } catch (e) {
      DebugHelper.logError('Version check error: $e');
      _versionResult = null;
    }

    // If force-update required, show immediately — skip onboarding check
    if (_versionResult?.requiresForceUpdate == true) {
      if (mounted) setState(() => _initComplete = true);
      return;
    }

    // 2. Onboarding check
    try {
      DebugHelper.logInfo('📦 Starting onboarding check...');
      _hasSeenOnboarding = await OnboardingHelper.hasSeenOnboarding().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      DebugHelper.logInfo('✅ Onboarding check done: $_hasSeenOnboarding');
    } catch (e) {
      DebugHelper.logError('Onboarding check error: $e');
      _hasSeenOnboarding = false;
    }

    DebugHelper.logInfo(
        '🏁 _runPostSplashInit complete, setting _initComplete = true');
    if (mounted) setState(() => _initComplete = true);
  }

  Future<_VersionCheckResult?> _checkVersionRequirement() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Fetch version control config from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('version_control')
          .get()
          .timeout(const Duration(seconds: 3));

      if (!doc.exists) {
        DebugHelper.logWarning('Version control document does not exist');
        return null; // No restriction if doc doesn't exist
      }

      final data = doc.data()!;
      final forceUpdate = data['forceUpdate'] as bool? ?? false;

      if (!forceUpdate) {
        return null; // No force update required
      }

      // Get platform-specific minimum version
      String? minimumVersion;
      if (Platform.isAndroid) {
        minimumVersion = data['minimumAndroidVersion'] as String?;
      } else if (Platform.isIOS) {
        minimumVersion = data['minimumIOSVersion'] as String?;
      }

      if (minimumVersion == null) {
        return null; // No minimum version set for this platform
      }

      // Simple version comparison (assumes format like "2.1.0")
      // Split by dots and compare each part numerically
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final minimumParts = minimumVersion.split('.').map(int.parse).toList();

      // Compare version parts
      for (int i = 0; i < minimumParts.length; i++) {
        if (i >= currentParts.length) {
          // Current version has fewer parts, so it's lower
          return _VersionCheckResult(
            requiresForceUpdate: true,
            updateMessage: _getLocalizedUpdateMessage(data),
            storeUrl: _getStoreUrl(data),
          );
        }
        if (currentParts[i] < minimumParts[i]) {
          return _VersionCheckResult(
            requiresForceUpdate: true,
            updateMessage: _getLocalizedUpdateMessage(data),
            storeUrl: _getStoreUrl(data),
          );
        }
        if (currentParts[i] > minimumParts[i]) {
          return null; // Current version is higher, no update needed
        }
      }

      // All parts equal, no update needed
      return null;
    } catch (e) {
      DebugHelper.logWarning('Version check failed: $e');
      return null; // On any error, allow app to proceed
    }
  }

  String _getLocalizedUpdateMessage(Map<String, dynamic> data) {
    final updateMessage = data['updateMessage'] as Map<String, dynamic>?;
    if (updateMessage == null) {
      return 'A new version is available. Please update to continue.';
    }

    // Get current locale
    final locale = context.locale.languageCode;
    return updateMessage[locale] as String? ??
        updateMessage['en'] as String? ??
        'A new version is available. Please update to continue.';
  }

  String _getStoreUrl(Map<String, dynamic> data) {
    final storeUrls = data['storeUrls'] as Map<String, dynamic>?;
    if (storeUrls == null) {
      return '';
    }

    if (Platform.isAndroid) {
      return storeUrls['android'] as String? ?? '';
    } else if (Platform.isIOS) {
      return storeUrls['ios'] as String? ?? '';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    DebugHelper.logInfo(
        'BUILD: _showSplash=$_showSplash, _initComplete=$_initComplete');
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: StaticSplashScreen(
          onComplete: _onSplashComplete,
        ),
      );
    }

    // Still loading version / onboarding checks
    if (!_initComplete) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF197533),
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      );
    }

    // Force update required
    if (_versionResult?.requiresForceUpdate == true) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ForceUpdateScreen(
          updateMessage: _versionResult!.updateMessage,
          storeUrl: _versionResult!.storeUrl,
        ),
      );
    }

    // Normal app launch
    DebugHelper.logSuccess(
        'BUILD: Rendering main app, hasSeenOnboarding=$_hasSeenOnboarding');
    return BlocProvider(
      create: (context) => OdluaCubit()..getUserData(),
      child: _MainAppWithDeepLinkHandler(
        hasSeenOnboarding: _hasSeenOnboarding,
      ),
    );
  }
}

class _VersionCheckResult {
  final bool requiresForceUpdate;
  final String updateMessage;
  final String storeUrl;

  _VersionCheckResult({
    required this.requiresForceUpdate,
    required this.updateMessage,
    required this.storeUrl,
  });
}

/// Wrapper widget to handle deep link processing after navigator is ready
class _MainAppWithDeepLinkHandler extends StatefulWidget {
  final bool hasSeenOnboarding;

  const _MainAppWithDeepLinkHandler({required this.hasSeenOnboarding});

  @override
  State<_MainAppWithDeepLinkHandler> createState() =>
      _MainAppWithDeepLinkHandlerState();
}

class _MainAppWithDeepLinkHandlerState
    extends State<_MainAppWithDeepLinkHandler> {
  @override
  void initState() {
    super.initState();
    // Re-trigger pending deep links after first frame (when navigator is ready)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This ensures the navigatorKey is now attached to a MaterialApp
      // The DeepLinkHandler will automatically process any pending deep links
      DeepLinkHandler.instance.setNavigatorKey(navigatorKey);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Odlua',
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      themeMode: ThemeMode.light,
      theme: AppTheme.lightTheme,
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/home':
            return MaterialPageRoute(
              builder: (_) => const OdluaLayout(),
            );
          case '/account_type':
            final userData = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => AccountTypeScreen(userData: userData ?? {}),
            );
          case '/chef_application':
            final userData = settings.arguments as Map<String, dynamic>?;
            return MaterialPageRoute(
              builder: (_) => ChefApplicationScreen(userData: userData),
            );
          case '/login':
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );
          default:
            return null;
        }
      },
      home: widget.hasSeenOnboarding
          ? const AuthWrapper()
          : OnboardingScreen(
              onFinished: () async {
                await OnboardingHelper.markOnboardingComplete();
                navigatorKey.currentState?.pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const AuthWrapper(),
                  ),
                );
              },
            ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _timedOut = false;
  late final Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream so it's stable across rebuilds
    _authStream = FirebaseAuth.instance.authStateChanges();
    // Timeout fallback: if auth check takes too long, proceed with current state
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        DebugHelper.logInfo(
            'AuthWrapper: connState=${snapshot.connectionState}, hasData=${snapshot.hasData}, timedOut=$_timedOut');
        // If stream hasn't emitted yet but we've timed out, check current user directly
        if (snapshot.connectionState == ConnectionState.waiting && !_timedOut) {
          DebugHelper.logInfo('AuthWrapper: showing loading spinner');
          return Scaffold(
            backgroundColor: mainColor,
            body: Center(
              child: CircularProgressIndicator(
                  color: Colors.white.withValues(alpha: 0.9)),
            ),
          );
        }

        if (snapshot.hasError) {
          DebugHelper.logError('AuthWrapper: stream error=${snapshot.error}');
          // On auth error, try to proceed with current user if available
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            return const OdluaLayout();
          }
          return const LoginScreen();
        }

        // Use stream data if available, otherwise check current user (offline support)
        final user = snapshot.data ??
            (_timedOut ? FirebaseAuth.instance.currentUser : null);
        if (user != null) {
          DebugHelper.logSuccess(
              'AuthWrapper: user logged in uid=${user.uid}, showing UserDataLoader');
          // User is logged in - go directly to main app
          // Skip the Firestore user document check that could hang
          return _UserDataLoader(userId: user.uid);
        }

        DebugHelper.logInfo('AuthWrapper: no user, showing LoginScreen');
        // User not logged in
        return const LoginScreen();
      },
    );
  }
}

/// Separate widget to load user data with timeout
class _UserDataLoader extends StatefulWidget {
  final String userId;
  const _UserDataLoader({required this.userId});

  @override
  State<_UserDataLoader> createState() => _UserDataLoaderState();
}

class _UserDataLoaderState extends State<_UserDataLoader> {
  bool _loadingComplete = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Hard safety timeout: ALWAYS proceed after 5 seconds no matter what
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_loadingComplete) {
        DebugHelper.logWarning('_UserDataLoader: safety timeout triggered');
        setState(() => _loadingComplete = true);
      }
    });
  }

  Future<void> _loadUserData() async {
    try {
      // Try to load user data with timeout
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      // Timeout or error - proceed anyway, cubit will handle data loading
      DebugHelper.logWarning('User data preload failed: $e');
    }

    // Silently reset dish stock once per day for chef users (fire-and-forget)
    DailyQuantityRefreshService.runIfNeeded();

    if (mounted) {
      setState(() => _loadingComplete = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    DebugHelper.logInfo('_UserDataLoader: _loadingComplete=$_loadingComplete');
    // Show branded loading, proceed to main app once data ready
    if (!_loadingComplete) {
      return Scaffold(
        backgroundColor: mainColor,
        body: Center(
          child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.9)),
        ),
      );
    }
    DebugHelper.logSuccess('_UserDataLoader: showing OdluaLayout');
    return const OdluaLayout();
  }
}

class OdluaLayout extends StatefulWidget {
  final String? focusTab;
  final String? focusedMessageId;

  const OdluaLayout({
    super.key,
    this.focusTab,
    this.focusedMessageId,
  });

  @override
  State<OdluaLayout> createState() => _OdluaLayoutState();
}

class _OdluaLayoutState extends State<OdluaLayout> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OdluaCubit, OdluaStates>(
      listener: (context, state) {},
      builder: (context, state) {
        final cubit = OdluaCubit.get(context);
        final isGuest = FirebaseAuth.instance.currentUser == null;

        return Scaffold(
          body: cubit.screens[cubit.currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            // Use theme-aware colors so dark mode is applied automatically
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            selectedItemColor: mainColor,
            unselectedItemColor: Colors.grey,
            currentIndex: cubit.currentIndex,
            type: BottomNavigationBarType.fixed,
            items: cubit.getBottomItems(),
            onTap: (index) {
              // Guest users can only access Home (0) and Menu (1)
              if (isGuest && index >= 2) {
                Navigator.pushNamed(context, '/login');
                return;
              }
              // Any logged-in user can add dishes directly — no application required
              if (index == 2) {
                if (state is OdluaGetUserLoadingState ||
                    cubit.userModel == null) {
                  return;
                }
              }
              cubit.changeBottomNavBar(index);
            },
          ),
        );
      },
    );
  }
}
