import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/app.dart';
import 'package:odlua/layout/authentication/otp_verification_screen.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _errorMessage;
  int? _resendToken;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loginWithPhone() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Format phone number to E.164 format
      String phoneNumber = _formatPhoneNumber(_phoneController.text.trim());

      // First find user by phone number in Firestore
      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();

      if (users.docs.isEmpty) {
        throw FirebaseAuthException(
            code: 'user-not-found', message: 'user_not_found'.tr());
      }

      final userDoc = users.docs.first;
      final userData = userDoc.data();
      final isPhoneVerified = userData['phoneVerified'] ?? false;

      if (!isPhoneVerified) {
        // Phone not verified, send OTP
        await _verifyPhoneNumber(phoneNumber);
      } else {
        // Phone is already verified, send OTP for login
        await _verifyPhoneNumber(phoneNumber);
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _handleGenericError(e);
    }
  }

  Future<void> _verifyPhoneNumber(String phoneNumber) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _handleVerificationComplete(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          _handleVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          _handleCodeSent(verificationId, resendToken, phoneNumber);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _handleCodeTimeout(verificationId);
        },
        timeout: const Duration(seconds: 120),
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      _handleVerificationError(e);
    }
  }

  Future<void> _handleVerificationComplete(
      PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);
      _navigateToMainApp();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'auto_verification_failed'.tr();
          _isLoading = false;
        });
        _showErrorSnackBar('auto_verification_failed'.tr());
      }
    }
  }

  void _handleVerificationFailed(FirebaseAuthException e) {
    if (mounted) {
      setState(() {
        _errorMessage = _getVerificationErrorMessage(e);
        _isLoading = false;
      });
      _showErrorSnackBar(_errorMessage!);
    }
  }

  void _handleCodeSent(
      String verificationId, int? resendToken, String phoneNumber) {
    _resendToken = resendToken;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            phone: phoneNumber,
            verificationId: verificationId,
            resendToken: resendToken,
            isLogin: true,
            onVerificationSuccess: _onVerificationSuccess,
            signupData: const {}, // Empty for login flow
          ),
        ),
      ).then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    }
  }

  void _handleCodeTimeout(String verificationId) {
    if (mounted && _isLoading) {
      setState(() {
        _errorMessage = 'verification_timeout'.tr();
        _isLoading = false;
      });
      _showErrorSnackBar('verification_timeout'.tr());
    }
  }

  void _handleVerificationError(dynamic e) {
    if (mounted) {
      setState(() {
        _errorMessage = 'verification_error'.tr();
        _isLoading = false;
      });
      _showErrorSnackBar('verification_error'.tr());
    }
  }

  Future<void> _onVerificationSuccess() async {
    await _updatePhoneVerificationStatus(true);
    _navigateToMainApp();
  }

  Future<void> _updatePhoneVerificationStatus(bool isVerified) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'phoneVerified': isVerified,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        DebugHelper.log('Error updating phone verification status: $e');
      }
    }
  }

  void _navigateToMainApp() {
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OdluaLayout()),
        (route) => false,
      );
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    final errorMessage = _getAuthErrorMessage(e);
    if (mounted) {
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
      _showErrorSnackBar(errorMessage);
    }
  }

  void _handleGenericError(dynamic e) {
    final errorMessage = 'login_error'.tr();
    if (mounted) {
      setState(() {
        _errorMessage = errorMessage;
        _isLoading = false;
      });
      _showErrorSnackBar(errorMessage);
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'dismiss'.tr(),
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'user_not_found'.tr();
      case 'wrong-password':
        return 'wrong_password'.tr();
      case 'invalid-email':
        return 'invalid_email'.tr();
      case 'user-disabled':
        return 'account_disabled'.tr();
      case 'too-many-requests':
        return 'too_many_attempts'.tr();
      case 'network-request-failed':
        return 'network_error'.tr();
      case 'invalid-user-data':
        return e.message ?? 'user_data_incomplete'.tr();
      case 'email-already-in-use':
        return 'email_already_used'.tr();
      case 'weak-password':
        return 'weak_password'.tr();
      case 'operation-not-allowed':
        return 'operation_not_allowed'.tr();
      default:
        return e.message ?? 'login_failed'.tr();
    }
  }

  String _getVerificationErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'invalid_phone_number'.tr();
      case 'too-many-requests':
        return 'too_many_verification_attempts'.tr();
      case 'quota-exceeded':
        return 'verification_quota_exceeded'.tr();
      case 'app-not-authorized':
        return 'app_not_authorized'.tr();
      case 'missing-client-identifier':
        return 'missing_client_identifier'.tr();
      default:
        return e.message ?? 'verification_failed'.tr();
    }
  }

  String _formatPhoneNumber(String phone) {
    String digits = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (!digits.startsWith('+')) {
      digits = digits.replaceAll(RegExp(r'^0+'), '');

      if (digits.length == 10) {
        digits = '+1$digits';
      } else if (digits.length == 11 && digits.startsWith('1')) {
        digits = '+$digits';
      }
    }

    return digits;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'please_enter_phone'.tr();
    }

    final phone = _formatPhoneNumber(value);
    if (phone.length < 10) {
      return 'invalid_phone_length'.tr();
    }

    if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(phone)) {
      return 'invalid_phone_format'.tr();
    }

    return null;
  }

  void _clearError() {
    if (_errorMessage != null && mounted) {
      setState(() => _errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('phone_login'.tr()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Logo/Header
                  _buildHeader(),
                  const SizedBox(height: 40),

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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Title
                          Text(
                            'login_with_phone'.tr(),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Error message
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.error_outline,
                                        color: Colors.red.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red.shade800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (!_isLoading)
                                      IconButton(
                                        icon: Icon(Icons.close,
                                            size: 16,
                                            color: Colors.red.shade600),
                                        onPressed: _clearError,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ),
                            ),

                          // Phone input
                          TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'phone_number'.tr(),
                              hintText: 'phone_placeholder'.tr(),
                              prefixIcon:
                                  const Icon(Icons.phone, color: Colors.grey),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            validator: _validatePhone,
                            onChanged: (_) => _clearError(),
                            onFieldSubmitted: (_) => _loginWithPhone(),
                            enabled: !_isLoading,
                          ),
                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _loginWithPhone,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                                disabledBackgroundColor:
                                    mainColor.withOpacity(0.5),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'send_otp'.tr(),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Sign up Section
                  _buildSignupSection(),
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
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: mainColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.phone_iphone_rounded,
            size: 50,
            color: mainColor,
          ),
        ),
        const SizedBox(height: 16),
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
          'login_with_phone_to_continue'.tr(),
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSignupSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'dont_have_account'.tr(),
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
          child: Text(
            'create_account'.tr(),
            style: TextStyle(color: mainColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
