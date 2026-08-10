// ─────────────────────────────────────────
// Screen: LoginScreen
// Description: Email/password login with guest-mode option.
//              Creates a basic Firestore user record on first sign-in
//              and saves the FCM token for push notifications.
// Contains: Auth form, guest flow, error handling, cubit refresh
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/app.dart';
import 'package:odlua/layout/authentication/widgets/auth_widgets.dart';
import 'package:odlua/layout/authentication/signup/signup.dart';
import 'package:odlua/layout/authentication/forgot_password/forgot_password_screen.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';

import 'package:odlua/utils/cubit/cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Check if user exists in Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // #Ref3: Refresh User Data in Cubit on Login
      if (mounted) {
        OdluaCubit.get(context).getUserData();
      }

      // Save FCM token for push notifications after successful login
      await NotificationService.instance.refreshFcmToken();

      if (userDoc.exists) {
        // For email login, we don't require phone verification
        // User can login directly with email/password
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OdluaLayout()),
            (route) => false,
          );
        }
      } else {
        // User doesn't exist in Firestore but authenticated - create basic record
        await _createBasicUserRecord(userCredential.user!);

        // Refresh again after creating record to ensure we have the data
        if (mounted) {
          OdluaCubit.get(context).getUserData();
        }

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OdluaLayout()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('login_error'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBasicUserRecord(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': user.displayName ?? 'User'.tr(),
        'email': user.email,
        'phone': '',
        'phoneVerified': false,
        'userType': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'accountStatus': 'active',
        'emailVerified': user.emailVerified,
      }, SetOptions(merge: true));
    } catch (e) {
      DebugHelper.log('Error creating user record: $e');
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    String errorMessage;
    switch (e.code) {
      case 'user-not-found':
        errorMessage = 'user_not_found'.tr();
        break;
      case 'wrong-password':
        errorMessage = 'wrong_password'.tr();
        break;
      case 'invalid-email':
        errorMessage = 'invalid_email'.tr();
        break;
      case 'user-disabled':
        errorMessage = 'account_disabled'.tr();
        break;
      case 'too-many-requests':
        errorMessage = 'too_many_attempts'.tr();
        break;
      default:
        errorMessage = 'login_failed'.tr();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
    );
  }

  void _navigateToSignup() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SignupScreen()));
  }

  void _navigateToForgotPassword() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top > 0 ? 20 : 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header (logo removed)
                  _buildHeader(),
                  const SizedBox(height: 32),

                  // Login Card
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        // Login Form - Email only
                        _buildEmailLoginForm(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Continue as Guest
                  _buildGuestSection(),
                  const SizedBox(height: 16),

                  // Sign up Section
                  _buildSignupSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo removed
        Text(
          'welcome_back'.tr(),
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'login_to_continue'.tr(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthTextField(
            label: 'email'.tr(),
            hintText: 'enter_email'.tr(),
            keyboardType: TextInputType.emailAddress,
            controller: _emailController,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'please_enter_email'.tr();
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!))
                return 'invalid_email'.tr();
              return null;
            },
            prefixIcon: Icons.email_outlined,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'password'.tr(),
            hintText: 'enter_password'.tr(),
            keyboardType: TextInputType.visiblePassword,
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (value) {
              if (value?.isEmpty ?? true) return 'please_enter_password'.tr();
              if (value!.length < 6) return 'password_min_length'.tr();
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _navigateToForgotPassword,
              child: Text(
                'forgot_password'.tr(),
                style: TextStyle(color: mainColor, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white))
                  : Text('login'.tr(),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  void _continueAsGuest() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OdluaLayout()),
      (route) => false,
    );
  }

  Widget _buildGuestSection() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _continueAsGuest,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'continue_as_guest'.tr(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  Widget _buildSignupSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('dont_have_account'.tr(),
            style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _navigateToSignup,
          child: Text('create_account'.tr(),
              style: TextStyle(color: mainColor, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
