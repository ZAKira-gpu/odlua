// ─────────────────────────────────────────
// Widget: LoginForm
// Description: Email and password form fields for the login screen.
// Contains: Email field, password field, validation
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/authentication/widgets/auth_widgets.dart';
import 'package:odlua/layout/authentication/forgot_password/forgot_password_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
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
    // Validate form
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign in with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Save FCM token for push notifications after successful login
      await NotificationService.instance.refreshFcmToken();

      // Success - The AuthWrapper will automatically redirect to the main app
      // No need to navigate manually here
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase auth errors
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

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // Handle generic errors
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('login_error'.tr()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              if (value == null || value.isEmpty) {
                return 'please_enter_email'.tr();
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                return 'invalid_email'.tr();
              }
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
              if (value == null || value.isEmpty) {
                return 'please_enter_password'.tr();
              }
              if (value.length < 6) {
                return 'password_min_length'.tr();
              }
              return null;
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 24),

          // Login Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'login'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Forgot Password Link
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
            child: Text(
              'forgot_password'.tr(),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
