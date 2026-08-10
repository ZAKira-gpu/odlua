import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:odlua/firebase_options.dart';
import 'package:odlua/layout/authentication/login/login.dart';
import 'package:odlua/layout/authentication/otp_verification_screen.dart';
import 'package:odlua/layout/onboarding/onboarding.dart';
import 'package:odlua/utils/cubit/cubit.dart';
import 'package:odlua/utils/cubit/states.dart';
import 'package:odlua/utils/theme/theme.dart';
import 'package:odlua/utils/helpers/onboarding_helper.dart';
import 'package:easy_localization/easy_localization.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      // Initialize Firebase first
      future: Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      builder: (context, snapshot) {
        // Check for Firebase initialization errors
        if (snapshot.hasError) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('firebase_init_failed_error'
                    .tr(args: [snapshot.error.toString()])),
              ),
            ),
          );
        }

        // Wait for Firebase to initialize
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // Firebase is initialized, now check onboarding
        return FutureBuilder<bool>(
          future: OnboardingHelper.hasSeenOnboarding(),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return const MaterialApp(
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final hasSeenOnboarding = onboardingSnapshot.data ?? false;
            return BlocProvider(
              create: (context) => OdluaCubit(),
              child: MaterialApp(
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                title: 'Odlua',
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                locale: context.locale,
                // Force light mode for the whole app
                themeMode: ThemeMode.light,
                theme: AppTheme.lightTheme,
                home: hasSeenOnboarding
                    ? const AuthWrapper()
                    : OnboardingScreen(
                        onFinished: () async {
                          await OnboardingHelper.markOnboardingComplete();

                          // Use navigatorKey for navigation
                          navigatorKey.currentState?.pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const AuthWrapper(),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('auth_error'.tr())),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // User is logged in, check if phone is verified
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userSnapshot.hasError) {
                return Scaffold(
                  body: Center(child: Text('data_error'.tr())),
                );
              }

              final userData =
                  userSnapshot.data?.data() as Map<String, dynamic>?;
              final isPhoneVerified = userData?['phoneVerified'] ?? false;
              final phoneNumber = userData?['phone'] ?? '';

              if (!isPhoneVerified && phoneNumber.isNotEmpty) {
                // Phone not verified, go to OTP screen
                return OtpVerificationScreen(
                  phone: phoneNumber,
                  verificationId: 'resend', // Special flag for re-verification
                  signupData: const {}, // Provide the required signupData argument
                );
              }

              // Phone verified or no phone, go to main app
              return const OdluaLayout();
            },
          );
        }

        // User not logged in
        return const LoginScreen();
      },
    );
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

        return Scaffold(
          body: cubit.screens[cubit.currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            // Use theme-aware colors so dark mode is applied automatically
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            currentIndex: cubit.currentIndex,
            type: BottomNavigationBarType.fixed,
            items: cubit.bottomItems,
            onTap: (index) {
              cubit.changeBottomNavBar(index);
            },
          ),
        );
      },
    );
  }
}
