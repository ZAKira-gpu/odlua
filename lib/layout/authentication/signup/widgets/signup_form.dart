// ─────────────────────────────────────────
// Widget: SignupForm
// Description: Registration form — name, email, phone,
//              password, human verification, accept conditions.
// ─────────────────────────────────────────

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/phone_helper.dart';
import '../../otp_verification_screen.dart';
import '../../widgets/auth_widgets.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/cubit/cubit.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  // FocusNodes for auto-scrolling to first empty field
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();

  // GlobalKeys for scrolling to sections
  final _basicInfoKey = GlobalKey();
  final _puzzleKey = GlobalKey();
  final _termsKey = GlobalKey();

  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _isLoading = false;

  // Retry mechanisms
  int _phoneVerificationRetryCount = 0;
  static const int _maxPhoneRetries = 2;

  // Human verification puzzle
  List<int> _puzzleNumbers = [];
  int _selectedNumber = 0;
  bool _puzzleSolved = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _generatePuzzle();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _generatePuzzle() {
    try {
      _puzzleNumbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle();
      _selectedNumber = _puzzleNumbers[0];
      _puzzleSolved = false;
      if (mounted) setState(() {});
    } catch (e) {
      _showErrorSnackbar('failed_to_generate_puzzle'.tr());
    }
  }

  bool _verifyPuzzle() {
    try {
      final largest = _puzzleNumbers.reduce((a, b) => a > b ? a : b);
      return _selectedNumber == largest;
    } catch (e) {
      return false;
    }
  }

  /// Scrolls to and focuses the first empty/invalid field
  void _scrollToAndFocus(GlobalKey key, [FocusNode? focusNode]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: 0.3,
        );
      }
      focusNode?.requestFocus();
    });
  }

  bool _validateForm() {
    // Check basic fields first and scroll to first empty one
    if (_nameController.text.trim().isEmpty) {
      _formKey.currentState!.validate();
      _scrollToAndFocus(_basicInfoKey, _nameFocus);
      return false;
    }
    if (_emailController.text.trim().isEmpty ||
        !RegExp(r'^[^@]+@[^@]+\.[^@]+')
            .hasMatch(_emailController.text.trim())) {
      _formKey.currentState!.validate();
      _scrollToAndFocus(_basicInfoKey, _emailFocus);
      return false;
    }
    if (_passwordController.text.trim().isEmpty ||
        _passwordController.text.trim().length < 6) {
      _formKey.currentState!.validate();
      _scrollToAndFocus(_basicInfoKey, _passwordFocus);
      return false;
    }

    // Phone validation (optional but if entered, must be valid)
    final phone = _phoneController.text.trim();
    if (phone.isNotEmpty) {
      if (!phone.startsWith('+')) {
        _formKey.currentState!.validate();
        _scrollToAndFocus(_basicInfoKey, _phoneFocus);
        return false;
      }
      if (phone.length < 9 || phone.length > 16) {
        _formKey.currentState!.validate();
        _scrollToAndFocus(_basicInfoKey, _phoneFocus);
        return false;
      }
    }

    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (!_puzzleSolved) {
      _showErrorSnackbar('please_verify_you_are_human'.tr());
      _scrollToAndFocus(_puzzleKey);
      return false;
    }

    if (!_agreeToTerms) {
      _showErrorSnackbar('please_agree_to_terms'.tr());
      _scrollToAndFocus(_termsKey);
      return false;
    }

    return true;
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      DebugHelper.log('Checking if email exists: $email');
      final methods = await _auth
          .fetchSignInMethodsForEmail(email)
          .timeout(const Duration(seconds: 10));
      DebugHelper.log('Email check complete. Methods found: ${methods.length}');
      if (methods.isNotEmpty) {
        DebugHelper.log('Email already in use: $email');
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'email_already_registered'.tr(),
        );
      }
      return true; // Email is available
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        rethrow;
      }
      DebugHelper.log(
          'Network error during email check - skipping pre-validation: ${e.code}');
      return false;
    } catch (e) {
      DebugHelper.log('Error checking email existence (will skip): $e');
      return false;
    }
  }

  Future<void> _registerUser() async {
    if (!_validateForm()) return;

    if (_phoneVerificationRetryCount >= _maxPhoneRetries) {
      _showErrorSnackbar('too_many_attempts_try_later'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final rawPhone = _phoneController.text.trim();
      final phone =
          rawPhone.isNotEmpty ? PhoneHelper.formatPhoneNumber(rawPhone) : '';

      DebugHelper.log('Starting registration for email: $email, phone: $phone');

      // Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        DebugHelper.log('Invalid email format: $email');
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'invalid_email_format'.tr(),
        );
      }

      DebugHelper.log('Email format validated');

      // Check if email already exists (skip if network unavailable)
      DebugHelper.log('Checking if email already exists...');
      final emailAvailable = await _checkEmailExists(email);
      if (emailAvailable) {
        DebugHelper.log('Email check passed - email is available');
      } else {
        DebugHelper.log(
            'Email check skipped due to network issues - will verify during phone auth');
      }

      // Prepare signup data
      DebugHelper.log('Collecting signup data...');
      final signupData = await _collectSignupData(null);

      signupData['email'] = email;
      signupData['password'] = password;

      DebugHelper.log('Signup data collected.');

      // If phone number is provided, verify it. Otherwise, register directly with email
      if (phone.isNotEmpty) {
        DebugHelper.log('Starting phone verification...');
        await _verifyPhoneNumber(phone, signupData);
      } else {
        DebugHelper.log('No phone provided. Registering with email only...');
        await _registerWithEmailOnly(email, password, signupData);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _phoneVerificationRetryCount++;
      _handleFirebaseError(e);
      DebugHelper.log('FirebaseAuthException during registration: '
          'code: \\${e.code}, message: \\${e.message}, details: \\${e.toString()}');
    } catch (e, stack) {
      setState(() => _isLoading = false);
      _phoneVerificationRetryCount++;
      _showErrorSnackbar('registration_failed'.tr());
      DebugHelper.log('Registration error: $e');
      DebugHelper.log('Stack trace: $stack');
    }
  }

  Future<Map<String, dynamic>> _collectSignupData(String? photoUrl) async {
    final timestamp = FieldValue.serverTimestamp();

    DebugHelper.log('Collecting signup data...');
    DebugHelper.log('   Name: ${_nameController.text.trim()}');
    DebugHelper.log('   Email: ${_emailController.text.trim()}');
    DebugHelper.log('   Phone: ${_phoneController.text.trim()}');

    final data = {
      "name": _nameController.text.trim(),
      "email": _emailController.text.trim(),
      "password": _passwordController.text.trim(),
      "phone": _phoneController.text.trim(),
      "photoURL": photoUrl,
      "userType": "customer",
      "isChef": false,
      "isHumanVerified": true,
      "createdAt": timestamp,
      "updatedAt": timestamp,
      "lastLogin": timestamp,
      "accountStatus": "active",
      "emailVerified": false,
      "phoneVerified": false,
      "profileCompleted": true,
    };

    return data;
  }

  void _navigateToOtpVerification(String phone, String verificationId,
      Map<String, dynamic> signupData, int? resendToken) {
    final completeSignupData = Map<String, dynamic>.from(signupData);

    if (completeSignupData['email'] == null ||
        completeSignupData['email'].toString().isEmpty) {
      completeSignupData['email'] = _emailController.text.trim();
    }

    if (completeSignupData['password'] == null ||
        completeSignupData['password'].toString().isEmpty) {
      completeSignupData['password'] = _passwordController.text.trim();
    }

    DebugHelper.log('Navigating to OTP Screen');
    DebugHelper.log(
        '   Email present: ${completeSignupData['email']?.toString().isNotEmpty}');
    DebugHelper.log(
        '   Password present: ${completeSignupData['password']?.toString().isNotEmpty}');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OtpVerificationScreen(
          phone: phone,
          verificationId: verificationId,
          signupData: completeSignupData,
          resendToken: resendToken,
          isLogin: false,
        ),
      ),
    );
  }

  Future<void> _verifyPhoneNumber(
      String phoneNumber, Map<String, dynamic> signupData) async {
    DebugHelper.log('Verifying phone number: $phoneNumber');
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        DebugHelper.log(
            'Auto-verification completed, navigating to OTP screen for proper account creation');
        setState(() => _isLoading = false);
        _navigateToOtpVerification(
          phoneNumber,
          'auto-verified',
          signupData,
          null,
        );
      },
      verificationFailed: (FirebaseAuthException e) {
        DebugHelper.log('Phone verification failed: ${e.code} - ${e.message}');
        setState(() => _isLoading = false);
        _phoneVerificationRetryCount++;
        _handleFirebaseError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        DebugHelper.log('OTP code sent successfully');
        setState(() => _isLoading = false);
        _navigateToOtpVerification(
            phoneNumber, verificationId, signupData, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        DebugHelper.log('Auto-retrieval timeout, user can enter OTP manually');
      },
      timeout: const Duration(seconds: 120),
    );
  }

  Future<void> _registerWithEmailOnly(
      String email, String password, Map<String, dynamic> signupData) async {
    try {
      DebugHelper.log('Creating user with email and password...');

      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      DebugHelper.log(
          'User created successfully with UID: ${userCredential.user!.uid}');

      await _completeUserRegistration(userCredential.user!, signupData);

      setState(() => _isLoading = false);
    } catch (e, stack) {
      setState(() => _isLoading = false);
      DebugHelper.log('Error in email-only registration: $e');
      DebugHelper.log('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> _completeUserRegistration(
      User user, Map<String, dynamic> userData) async {
    try {
      // Save user data to Firestore
      await _saveUserData(user.uid, userData);

      // Update user profile in Auth
      await user.updateDisplayName(_nameController.text.trim());

      // Send email verification
      await user.sendEmailVerification();

      _navigateToSuccessScreen();
    } catch (e, stack) {
      DebugHelper.log('Error completing user registration: $e');
      DebugHelper.log('Stack trace: $stack');
      await user.delete();
      rethrow;
    }
  }

  Future<void> _saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      DebugHelper.log('Saving user data to Firestore...');
      DebugHelper.log('   User ID: $userId');
      DebugHelper.log('   Data keys: ${userData.keys.join(", ")}');

      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      DebugHelper.logSuccess('User data saved successfully to Firestore');

      DebugHelper.log('User data saved for $userId');
    } catch (e, stack) {
      DebugHelper.logError('Error saving user data: $e');
      DebugHelper.log('Stack trace: $stack');
      DebugHelper.log('Error saving user data: $e');
      rethrow;
    }
  }

  void _navigateToSuccessScreen() {
    if (mounted) {
      OdluaCubit.get(context).getUserData();
    }
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  void _handleFirebaseError(FirebaseAuthException e) {
    String errorMessage;

    switch (e.code) {
      case 'invalid-phone-number':
        errorMessage = 'invalid_phone_number'.tr();
        break;
      case 'too-many-requests':
        errorMessage = 'too_many_attempts'.tr();
        break;
      case 'email-already-in-use':
        errorMessage = 'email_already_registered'.tr();
        break;
      case 'network-request-failed':
        errorMessage = 'network_error'.tr();
        break;
      case 'quota-exceeded':
        errorMessage = 'quota_exceeded'.tr();
        break;
      case 'invalid-email':
        errorMessage = 'invalid_email_format'.tr();
        break;
      case 'weak-password':
        errorMessage = 'password_too_short'.tr();
        break;
      default:
        errorMessage = e.message ?? 'authentication_failed'.tr();
    }

    _showErrorSnackbar(errorMessage);
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'tos_title'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'tos_header'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: mainColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildTermsSection(
                  '1. ${'tos_nature_title'.tr()}', 'tos_nature_summary'.tr()),
              _buildTermsSection('2. ${'tos_eligibility_title'.tr()}',
                  'tos_eligibility_summary'.tr()),
              _buildTermsSection(
                  '3. ${'tos_allowed_title'.tr()}', 'tos_allowed_summary'.tr()),
              _buildTermsSection('4. ${'tos_prohibited_title'.tr()}',
                  'tos_prohibited_summary'.tr()),
              _buildTermsSection('5. ${'tos_responsibility_title'.tr()}',
                  'tos_responsibility_summary'.tr()),
              _buildTermsSection('6. ${'tos_allergens_title'.tr()}',
                  'tos_allergens_summary'.tr()),
              _buildTermsSection('7. ${'tos_communication_title'.tr()}',
                  'tos_communication_summary'.tr()),
              _buildTermsSection(
                  '8. ${'tos_conduct_title'.tr()}', 'tos_conduct_content'.tr()),
              _buildTermsSection(
                  '9. ${'tos_changes_title'.tr()}', 'tos_changes_content'.tr()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _agreeToTerms = true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: mainColor),
            child: Text('i_agree'.tr()),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'privacy_policy'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrivacySection(
                'pp_section1'.tr(),
                null,
                [
                  'pp_bullet1_1'.tr(),
                  'pp_bullet1_2'.tr(),
                  'pp_bullet1_3'.tr(),
                  'pp_bullet1_4'.tr(),
                ],
              ),
              _buildPrivacySection(
                'pp_section2'.tr(),
                null,
                [
                  'pp_bullet2_1'.tr(),
                  'pp_bullet2_2'.tr(),
                  'pp_bullet2_3'.tr(),
                  'pp_bullet2_4'.tr(),
                ],
              ),
              _buildPrivacySection(
                'pp_section3'.tr(),
                'pp_paragraph3'.tr(),
                [
                  'pp_bullet3_1'.tr(),
                  'pp_bullet3_2'.tr(),
                ],
              ),
              _buildPrivacySection(
                'pp_section4'.tr(),
                'pp_paragraph4'.tr(),
                null,
              ),
              _buildPrivacySection(
                'pp_section5'.tr(),
                'pp_paragraph5'.tr(),
                null,
              ),
              _buildPrivacySection(
                'pp_section6'.tr(),
                'pp_paragraph6'.tr(),
                null,
              ),
              _buildPrivacySection(
                'pp_section7'.tr(),
                'pp_paragraph7'.tr(),
                null,
              ),
              _buildPrivacySection(
                'pp_section8'.tr(),
                'pp_paragraph8'.tr(),
                null,
              ),
              const SizedBox(height: 16),
              Text(
                'pp_paragraph9'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _agreeToTerms = true);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: mainColor),
            child: Text('i_agree'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySection(
      String title, String? paragraph, List<String>? bullets) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (paragraph != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                paragraph,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
          if (bullets != null)
            ...bullets.map((bullet) => Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          bullet,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHumanVerificationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _puzzleSolved
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: _puzzleSolved ? Colors.green : Colors.orange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'human_verification'.tr(),
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'select_largest_number'.tr(),
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemCount: _puzzleNumbers.length,
            itemBuilder: (context, index) {
              final number = _puzzleNumbers[index];
              final isSelected = _selectedNumber == number;
              final isCorrect = _puzzleSolved && isSelected;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedNumber = number;
                    _puzzleSolved = _verifyPuzzle();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: isCorrect
                        ? Colors.green.shade50
                        : isSelected
                            ? mainColor.withValues(alpha: 0.08)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCorrect
                          ? Colors.green
                          : isSelected
                              ? mainColor
                              : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: mainColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      number.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isCorrect
                            ? Colors.green
                            : isSelected
                                ? mainColor
                                : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          if (_puzzleSolved)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'verification_successful'.tr(),
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'please_select_largest_number'.tr(),
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _generatePuzzle,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('generate_new_puzzle'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: mainColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic Information Section
            Container(
              key: _basicInfoKey,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.person_outline_rounded,
                            color: mainColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'basic_information'.tr(),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Name
                  AuthTextField(
                    label: 'full_name'.tr(),
                    hintText: 'enter_full_name'.tr(),
                    controller: _nameController,
                    focusNode: _nameFocus,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_enter_name'.tr();
                      }
                      if (value.length < 2) {
                        return 'name_too_short'.tr();
                      }
                      return null;
                    },
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 20),

                  // Email
                  AuthTextField(
                    label: 'email'.tr(),
                    hintText: 'enter_email'.tr(),
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                    focusNode: _emailFocus,
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
                  const SizedBox(height: 20),

                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'phone'.tr(),
                      hintText: '+1234567890',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: mainColor, width: 2.5),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      prefixIcon:
                          const Icon(Icons.phone_rounded, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 16,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                      _PhonePlusFormatter(),
                    ],
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        if (!value.startsWith('+')) {
                          return 'phone_must_start_with_plus'.tr();
                        }
                        final digits =
                            value.replaceAll(RegExp(r'[^\d]'), '');
                        if (digits.length < 7) {
                          return 'invalid_phone_number'.tr();
                        }
                        if (digits.length > 15) {
                          return 'phone_number_too_long'.tr();
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'phone_optional_hint'.tr(),
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),

                  // Password
                  AuthTextField(
                    label: 'password'.tr(),
                    hintText: 'enter_password'.tr(),
                    keyboardType: TextInputType.visiblePassword,
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_enter_password'.tr();
                      }
                      if (value.length < 6) {
                        return 'password_too_short'.tr();
                      }
                      return null;
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'password_min_hint'.tr(),
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Human Verification
            Container(
              key: _puzzleKey,
              child: _buildHumanVerificationSection(),
            ),

            // Terms and Conditions
            const SizedBox(height: 24),
            Container(
              key: _termsKey,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreeToTerms
                      ? mainColor.withValues(alpha: 0.3)
                      : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: _agreeToTerms,
                          onChanged: (value) {
                            setState(() {
                              _agreeToTerms = value ?? false;
                            });
                          },
                          activeColor: mainColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 14,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(text: 'tos_checkbox_text'.tr()),
                                const TextSpan(text: ' '),
                                TextSpan(
                                  text: 'terms_of_service'.tr(),
                                  style: TextStyle(
                                    color: mainColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _showTermsDialog();
                                    },
                                ),
                                TextSpan(text: ' ${'and'.tr()} '),
                                TextSpan(
                                  text: 'privacy_policy'.tr(),
                                  style: TextStyle(
                                    color: mainColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      _showPrivacyPolicyDialog();
                                    },
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!_agreeToTerms)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, left: 48),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.orange.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'please_agree_to_continue'.tr(),
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Register Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AuthButton(
                text: 'register'.tr(),
                onPressed: _registerUser,
                isLoading: _isLoading,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Phone formatter: ensures '+' is always the first character ───
class _PhonePlusFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Strip all '+' first, then re-add one at start
    final digits = text.replaceAll('+', '');
    final formatted = '+$digits';

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
