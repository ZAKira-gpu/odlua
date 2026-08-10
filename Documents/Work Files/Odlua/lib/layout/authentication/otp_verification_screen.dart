import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/app.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final String verificationId;
  final Map<String, dynamic> signupData;
  final int? resendToken;
  final bool isLogin;
  final VoidCallback? onVerificationSuccess;

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    required this.verificationId,
    required this.signupData,
    this.resendToken,
    this.isLogin = false,
    this.onVerificationSuccess,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  String _errorMessage = '';
  String _currentVerificationId = '';
  int? _currentResendToken;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _currentResendToken = widget.resendToken;
    _setupOtpFocus();
    _startResendCountdown();
    _checkAutoVerification();

    // Debug: Print signup data to verify email and password are passed
    DebugHelper.log('Signup Data Received: ${widget.signupData}');
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _checkAutoVerification() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNodes.isNotEmpty && mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  void _setupOtpFocus() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus && _otpControllers[i].text.isEmpty) {
          _otpControllers[i].selection =
              const TextSelection.collapsed(offset: 0);
        }
      });
    }
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() => _resendCountdown--);
        } else {
          timer.cancel();
        }
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'please_enter_complete_otp'.tr());
      _shakeOtpFields();
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'invalid_otp_format'.tr());
      _shakeOtpFields();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: otp,
      );

      if (widget.isLogin) {
        // LOGIN FLOW: Sign in with phone credential
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        await _handleLoginSuccess(userCredential.user!);
      } else {
        // SIGNUP FLOW: Create user with both email/password AND phone
        await _createUserWithBothProviders(credential);
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      _handleGenericError(e);
    }
  }

  Future<void> _createUserWithBothProviders(
      PhoneAuthCredential phoneCredential) async {
    try {
      // Extract email and password with null safety
      final email = widget.signupData['email']?.toString().trim() ?? '';
      final password = widget.signupData['password']?.toString().trim() ?? '';

      DebugHelper.log(
          'Creating account with email: $email and phone: ${widget.phone}');

      if (email.isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
            code: 'invalid-credential',
            message:
                'Email and password are required for registration. Email: $email, Password: ${password.isNotEmpty ? "***" : "empty"}');
      }

      // STEP 1: Create user with email and password
      DebugHelper.log('Step 1: Creating email/password account...');
      final UserCredential emailUserCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User user = emailUserCredential.user!;
      DebugHelper.log(
          'Step 1: Email/password account created for UID: ${user.uid}');

      // STEP 2: Link phone credential to the same user
      DebugHelper.log('Step 2: Linking phone credential...');
      await user.linkWithCredential(phoneCredential);
      DebugHelper.log('Step 2: Phone credential linked successfully');

      // STEP 3: Complete user registration
      DebugHelper.log('Step 3: Completing user registration...');
      await _completeUserRegistration(user);
      DebugHelper.log('Step 3: User registration completed');
    } on FirebaseAuthException catch (e) {
      DebugHelper.log(
          'Firebase error during registration: ${e.code} - ${e.message}');

      if (e.code == 'email-already-in-use') {
        // Email already exists - try to link phone to existing account
        await _linkPhoneToExistingAccount(phoneCredential);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _linkPhoneToExistingAccount(
      PhoneAuthCredential phoneCredential) async {
    try {
      final email = widget.signupData['email']?.toString().trim() ?? '';
      final password = widget.signupData['password']?.toString().trim() ?? '';

      DebugHelper.log('Linking phone to existing account with email: $email');

      // Sign in with existing email/password
      final UserCredential emailUserCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      DebugHelper.log('Signed in with existing account, linking phone...');

      // Link phone to existing account
      await emailUserCredential.user!.linkWithCredential(phoneCredential);
      DebugHelper.log('Phone linked to existing account successfully');

      // Update user data
      await _completeUserRegistration(emailUserCredential.user!);
    } on FirebaseAuthException catch (e) {
      DebugHelper.log(
          'Error linking phone to existing account: ${e.code} - ${e.message}');

      if (e.code == 'provider-already-linked') {
        // Phone already linked - just update user data
        DebugHelper.log('Phone already linked, updating user data...');
        final UserCredential emailUserCredential =
            await _auth.signInWithEmailAndPassword(
          email: widget.signupData['email']!.toString().trim(),
          password: widget.signupData['password']!.toString().trim(),
        );
        await _completeUserRegistration(emailUserCredential.user!);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _handleLoginSuccess(User user) async {
    // For login, just update last login and navigate
    await _firestore.collection('users').doc(user.uid).update({
      'lastLogin': FieldValue.serverTimestamp(),
      'phoneVerified': true,
    });

    _navigateToMainApp();
  }

  Future<void> _completeUserRegistration(User user) async {
    try {
      DebugHelper.log('Starting user registration for UID: ${user.uid}');

      // Upload image if exists
      String? photoUrl;
      if (widget.signupData['photoFile'] != null &&
          widget.signupData['photoFile'] is File) {
        DebugHelper.log('Uploading profile photo...');
        photoUrl = await _uploadProfilePhoto(
            user.uid, widget.signupData['photoFile'] as File);
        DebugHelper.log('Photo uploaded: $photoUrl');
      }

      // Prepare final user data
      final userData = _prepareUserData(user.uid, photoUrl);
      DebugHelper.log('User data prepared: ${userData.keys}');

      // Save user data to Firestore
      await _saveUserData(user.uid, userData);
      DebugHelper.log('User data saved to Firestore');

      // Update user profile in Auth
      await user.updateDisplayName(
          widget.signupData['name']?.toString().trim() ?? 'User');

      // Send email verification
      await user.sendEmailVerification();
      DebugHelper.log('Email verification sent');

      setState(() => _isLoading = false);
      _navigateToMainApp();
    } catch (e) {
      DebugHelper.log('Error completing registration: $e');
      setState(() => _isLoading = false);

      // Delete user if registration fails
      try {
        await user.delete();
        DebugHelper.log('User deleted due to registration failure');
      } catch (deleteError) {
        DebugHelper.log('Error deleting user: $deleteError');
      }

      _showErrorSnackbar('registration_failed'.tr());
    }
  }

  Map<String, dynamic> _prepareUserData(String userId, String? photoUrl) {
    final timestamp = FieldValue.serverTimestamp();

    final loc = widget.signupData['location'];
    final data = {
      "uid": userId,
      "name": widget.signupData['name']?.toString().trim() ?? '',
      "email": widget.signupData['email']?.toString().trim() ?? '',
      "phone": widget.phone,
      "photoURL": photoUrl,
      if (loc is Map<String, dynamic>) ...{
        "location": loc,
        // legacy top-level for compatibility if not already set
        "city": loc['city'],
        "postalCode": loc['postalCode'],
        "country": loc['country'],
        "countryCode": loc['countryCode'],
        "formattedAddress": loc['formattedAddress'],
        "latitude": loc['latitude'],
        "longitude": loc['longitude'],
      } else ...{
        // Fallback: keep any prior string location
        "location": widget.signupData['location']?.toString() ?? '',
      },
      "userType": widget.signupData['userType']?.toString() ?? 'customer',
      "isHumanVerified": true,
      "phoneVerified": true,
      "emailVerified": false,
      "accountStatus": "active",
      "createdAt": timestamp,
      "updatedAt": timestamp,
      "lastLogin": timestamp,
      "profileCompleted": true,
      "authProviders": ["email", "phone"],
    };
    if (loc is Map<String, dynamic>) {
      data["locationUpdatedAt"] = timestamp;
    }

    // Add seller-specific data
    if (widget.signupData['userType'] == 'chef') {
      data.addAll({
        "chefName": widget.signupData['chefName']?.toString().trim() ?? '',
        "bio": widget.signupData['bio']?.toString().trim() ?? '',
        "specialties": widget.signupData['specialties'] ?? [],
        "yearsExperience": widget.signupData['yearsExperience'] ?? 1,
        "isChef": true,
        "chefVerified": false,
        "chefStatus": "pending",
        "rating": 0.0,
        "reviewCount": 0,
        "dishCount": 0,
        "orderCount": 0,
        "completionRate": 100,
        "responseRate": 100,
        "isOnline": true,
        "earnings": 0.0,
        "totalSales": 0,
      });
    }

    return data;
  }

  Future<void> _saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      DebugHelper.log('Saving user data to Firestore for user: $userId');
      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));
      DebugHelper.log('User data saved successfully');
    } catch (e) {
      DebugHelper.log('Error saving user data to Firestore: $e');
      rethrow;
    }
  }

  Future<String?> _uploadProfilePhoto(String userId, File photoFile) async {
    try {
      DebugHelper.log('Uploading profile photo for user: $userId');
      final ref = _storage.ref().child('user_profiles/$userId.jpg');
      final uploadTask = await ref.putFile(photoFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      DebugHelper.log('Profile photo uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      DebugHelper.log('Error uploading profile photo: $e');
      return null;
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    DebugHelper.log('Firebase Auth Error: ${e.code} - ${e.message}');

    String errorMessage;
    bool shouldClearOtp = false;

    switch (e.code) {
      case 'invalid-verification-code':
        errorMessage = 'invalid_verification_code'.tr();
        _shakeOtpFields();
        break;
      case 'session-expired':
        errorMessage = 'session_expired'.tr();
        shouldClearOtp = true;
        break;
      case 'quota-exceeded':
        errorMessage = 'sms_quota_exceeded'.tr();
        break;
      case 'user-disabled':
        errorMessage = 'account_disabled'.tr();
        break;
      case 'invalid-verification-id':
        errorMessage = 'invalid_session'.tr();
        shouldClearOtp = true;
        break;
      case 'too-many-requests':
        errorMessage = 'too_many_attempts_blocked'.tr();
        shouldClearOtp = true;
        break;
      case 'email-already-in-use':
        errorMessage = 'email_already_registered'.tr();
        shouldClearOtp = true;
        break;
      case 'provider-already-linked':
        errorMessage = 'phone_already_linked_to_account'.tr();
        shouldClearOtp = true;
        break;
      case 'credential-already-in-use':
        errorMessage = 'phone_already_used_by_another_account'.tr();
        shouldClearOtp = true;
        break;
      case 'invalid-credential':
        errorMessage = 'registration_data_incomplete'.tr();
        shouldClearOtp = true;
        break;
      default:
        errorMessage = 'verification_failed'.tr();
    }

    if (shouldClearOtp) {
      _clearOtpFields();
    }

    setState(() {
      _errorMessage = errorMessage;
      _isLoading = false;
    });
  }

  void _handleGenericError(dynamic e) {
    DebugHelper.log('OTP Verification Generic Error: $e');
    setState(() {
      _errorMessage = 'unexpected_error_occurred'.tr();
      _isLoading = false;
    });
  }

  void _shakeOtpFields() {
    setState(() {
      _isLoading = false;
    });
  }

  void _clearOtpFields() {
    for (var controller in _otpControllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty && mounted) {
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: widget.phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification handled in main flow
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _errorMessage = _getResendErrorMessage(e);
              _isResending = false;
            });
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
              _currentResendToken = resendToken;
              _isResending = false;
              _resendCountdown = 60;
            });
          }

          _clearOtpFields();
          _startResendCountdown();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('new_otp_sent_successfully'.tr()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _isResending = false;
            });
          }
        },
        timeout: const Duration(seconds: 120),
        forceResendingToken: _currentResendToken,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'failed_to_resend_otp'.tr();
          _isResending = false;
        });
      }
    }
  }

  String _getResendErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'too-many-requests':
        return 'too_many_resend_attempts'.tr();
      case 'invalid-phone-number':
        return 'invalid_phone_number_format'.tr();
      case 'quota-exceeded':
        return 'sms_quota_exceeded_tomorrow'.tr();
      default:
        return 'resend_otp_failed'.tr();
    }
  }

  void _handleOtpInput(int index, String value) {
    // Allow only digits
    if (value.isNotEmpty && !RegExp(r'^\d$').hasMatch(value)) {
      _otpControllers[index].clear();
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _verifyOtp();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _navigateToMainApp() {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const OdluaLayout()),
        (route) => false,
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),
              const SizedBox(height: 24),

              // Title and description
              _buildTitleSection(),
              const SizedBox(height: 40),

              // OTP Input Fields
              _buildOtpInputFields(),
              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage.isNotEmpty) _buildErrorWidget(),
              const SizedBox(height: 24),

              // Verify Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    disabledBackgroundColor: mainColor.withOpacity(0.5),
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
                          'verify_continue'.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Resend OTP Section
              _buildResendSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.verified_user_rounded,
        size: 40,
        color: mainColor,
      ),
    );
  }

  Widget _buildTitleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'verify_your_phone'.tr(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            children: [
              TextSpan(text: 'verification_code_sent_to'.tr()),
              TextSpan(
                text: widget.phone,
                style: TextStyle(
                  color: mainColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!widget.isLogin) ...[
          const SizedBox(height: 8),
          Text(
            'creating_account_with_both_email_phone'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.green.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtpInputFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 60,
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _focusNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: mainColor, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (value) => _handleOtpInput(index, value),
            onTap: () {
              _otpControllers[index].selection = TextSelection.collapsed(
                  offset: _otpControllers[index].text.length);
            },
          ),
        );
      }),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResendSection() {
    return Center(
      child: Column(
        children: [
          Text(
            "didnt_receive_code".tr(),
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          if (_resendCountdown > 0)
            Text(
              'resend_in_seconds'.tr(args: [_resendCountdown.toString()]),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            TextButton(
              onPressed: _isResending ? null : _resendOtp,
              child: _isResending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'resend_otp'.tr(),
                      style: TextStyle(
                        color: mainColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
    );
  }
}
