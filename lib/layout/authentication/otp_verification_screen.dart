// ─────────────────────────────────────────
// Screen: OtpVerificationScreen
// Description: 6-digit OTP entry for phone verification. Supports
//              both login and signup flows with email+phone linking,
//              3-attempt limit, 5 min session expiry, and auto-submit.
// Contains: OTP fields, timer, attempt guard, Firestore user creation
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/app.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';

/// OTP Verification States for clear state management
enum OtpState {
  idle, // Waiting for user input
  entering, // User is typing OTP
  verifying, // Verification in progress
  success, // Verification successful
  error, // Verification failed
  resending, // Resending OTP
  locked, // Too many attempts
  expired, // Session expired
}

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

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // State management
  OtpState _otpState = OtpState.idle;
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 60;
  String _errorMessage = '';
  String _currentVerificationId = '';
  int? _currentResendToken;
  Timer? _countdownTimer;

  // OTP attempt limiting
  int _otpAttempts = 0;
  static const int _maxOtpAttempts = 3;

  // Verification session expiry tracking (Firebase sessions expire in ~5 min)
  DateTime? _verificationStartTime;
  static const Duration _verificationSessionDuration = Duration(minutes: 5);
  Timer? _sessionExpiryTimer;
  int _sessionSecondsRemaining = 300; // 5 minutes in seconds

  // Animation controllers
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _currentResendToken = widget.resendToken;
    _verificationStartTime = DateTime.now();

    // Initialize shake animation for error feedback
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController);

    _setupOtpFocus();
    _startResendCountdown();
    _startSessionExpiryTimer();
    _checkAutoVerification();

    DebugHelper.log('OTP Screen initialized for phone: ${widget.phone}');
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
    _sessionExpiryTimer?.cancel();
    _shakeController.dispose();
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

  void _startSessionExpiryTimer() {
    _sessionExpiryTimer?.cancel();
    _verificationStartTime = DateTime.now();
    _sessionSecondsRemaining = _verificationSessionDuration.inSeconds;

    // Update session countdown every second for smooth UI
    _sessionExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(_verificationStartTime!);
      final remaining = _verificationSessionDuration - elapsed;

      setState(() {
        _sessionSecondsRemaining = remaining.inSeconds.clamp(0, 300);
      });

      // Session expired
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        timer.cancel();
        setState(() {
          _otpState = OtpState.expired;
          _errorMessage = 'verification_session_expired'.tr();
        });
      }
    });
  }

  String _formatSessionTime() {
    final minutes = _sessionSecondsRemaining ~/ 60;
    final seconds = _sessionSecondsRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool _isSessionExpiringSoon() {
    return _sessionSecondsRemaining <= 60 && _sessionSecondsRemaining > 0;
  }

  bool _isSessionValid() {
    if (_verificationStartTime == null) return false;
    final elapsed = DateTime.now().difference(_verificationStartTime!);
    return elapsed < _verificationSessionDuration;
  }

  Future<void> _handleCredential(PhoneAuthCredential credential) async {
    try {
      if (widget.isLogin) {
        // LOGIN FLOW: Sign in with phone credential
        final UserCredential userCredential =
            await _auth.signInWithCredential(credential);
        _triggerHapticSuccess();
        setState(() {
          _otpState = OtpState.success;
          _showSuccess = true;
        });
        await _handleLoginSuccess(userCredential.user!);
      } else {
        // SIGNUP FLOW: Create user with both email/password AND phone
        await _createUserWithBothProviders(credential);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _otpState = OtpState.error;
        _isLoading = false;
      });
      _handleAuthError(e);
    } catch (e) {
      setState(() {
        _otpState = OtpState.error;
        _isLoading = false;
      });
      _handleGenericError(e);
    }
  }

  Future<void> _verifyOtp() async {
    // Check if max attempts reached
    if (_otpAttempts >= _maxOtpAttempts) {
      setState(() {
        _otpState = OtpState.locked;
        _errorMessage = 'too_many_otp_attempts'.tr();
      });
      _triggerHapticError();
      return;
    }

    // Check if session is still valid
    if (!_isSessionValid() || _otpState == OtpState.expired) {
      setState(() {
        _otpState = OtpState.expired;
        _errorMessage = 'verification_session_expired'.tr();
      });
      _triggerHapticError();
      return;
    }

    final otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      setState(() => _errorMessage = 'please_enter_complete_otp'.tr());
      _triggerShakeAnimation();
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _errorMessage = 'invalid_otp_format'.tr());
      _triggerShakeAnimation();
      return;
    }

    setState(() {
      _isLoading = true;
      _otpState = OtpState.verifying;
      _errorMessage = '';
    });

    // Increment attempt counter
    _otpAttempts++;

    final credential = PhoneAuthProvider.credential(
      verificationId: _currentVerificationId,
      smsCode: otp,
    );

    await _handleCredential(credential);
  }

  void _triggerShakeAnimation() {
    _shakeController.forward().then((_) => _shakeController.reset());
    _triggerHapticError();
  }

  void _triggerHapticError() {
    HapticFeedback.heavyImpact();
  }

  void _triggerHapticSuccess() {
    HapticFeedback.mediumImpact();
  }

  void _triggerHapticLight() {
    HapticFeedback.lightImpact();
  }

  Future<void> _createUserWithBothProviders(
      PhoneAuthCredential phoneCredential) async {
    try {
      DebugHelper.log('Creating user with both providers...', tag: 'OTP');
      DebugHelper.log('Signup Data Keys: ${widget.signupData.keys.join(", ")}',
          tag: 'OTP');

      // Extract email and password with null safety
      final email = widget.signupData['email']?.toString().trim() ?? '';
      final password = widget.signupData['password']?.toString().trim() ?? '';

      DebugHelper.log('Email: $email', tag: 'OTP');
      DebugHelper.log('Password length: ${password.length}', tag: 'OTP');

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
      _triggerHapticSuccess();
      setState(() {
        _otpState = OtpState.success;
        _showSuccess = true;
      });
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

    // Save FCM token for push notifications after successful login
    await NotificationService.instance.refreshFcmToken();

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

      // Save FCM token for push notifications after successful registration
      await NotificationService.instance.refreshFcmToken();

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

    DebugHelper.log('OTP: Preparing user data...', tag: 'OTP');
    DebugHelper.log('signupData keys: ${widget.signupData.keys.join(", ")}',
        tag: 'OTP');

    // Check for structured address (exactLocation)
    final exactLoc = widget.signupData['exactLocation'];
    final loc = widget.signupData['location'];

    if (exactLoc != null) {
      DebugHelper.logSuccess('exactLocation found in signupData', tag: 'OTP');
    } else if (loc != null) {
      DebugHelper.logSuccess('legacy location found in signupData', tag: 'OTP');
    } else {
      DebugHelper.logWarning('NO LOCATION DATA in signupData!', tag: 'OTP');
    }

    final data = {
      "uid": userId,
      "name": widget.signupData['name']?.toString().trim() ?? '',
      "email": widget.signupData['email']?.toString().trim() ?? '',
      "phone": widget.phone,
      "photoURL": photoUrl,

      // NEW: Include structured address (exactLocation)
      if (exactLoc is Map<String, dynamic>) ...{
        "exactLocation": exactLoc,
        // Also populate legacy top-level fields from exactLocation
        "city": exactLoc['city'],
        "postalCode": exactLoc['postalCode'],
        "country": exactLoc['country'],
        "countryCode": exactLoc['countryCode'],
        "formattedAddress": exactLoc['formattedAddress'],
        "latitude": exactLoc['coordinates'] is GeoPoint
            ? (exactLoc['coordinates'] as GeoPoint).latitude
            : exactLoc['coordinates']['latitude'],
        "longitude": exactLoc['coordinates'] is GeoPoint
            ? (exactLoc['coordinates'] as GeoPoint).longitude
            : exactLoc['coordinates']['longitude'],
      } else if (loc is Map<String, dynamic>) ...{
        // Fallback to legacy location
        "location": loc,
        "city": loc['city'],
        "postalCode": loc['postalCode'],
        "country": loc['country'],
        "countryCode": loc['countryCode'],
        "formattedAddress": loc['formattedAddress'],
        "latitude": loc['latitude'],
        "longitude": loc['longitude'],
      } else ...{
        // No location data
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

    if (exactLoc != null || loc is Map<String, dynamic>) {
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

    DebugHelper.logSuccess(
        'OTP: User data prepared with ${data.keys.length} fields',
        tag: 'OTP');
    if (data['latitude'] != null && data['longitude'] != null) {
      DebugHelper.logSuccess(
          'Coordinates: ${data['latitude']}, ${data['longitude']}',
          tag: 'OTP');
    } else {
      DebugHelper.logWarning('NO COORDINATES in prepared data!', tag: 'OTP');
    }

    return data;
  }

  Future<void> _saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      DebugHelper.log('OTP: Saving user data to Firestore...', tag: 'OTP');
      DebugHelper.log('User ID: $userId', tag: 'OTP');
      DebugHelper.log('Data keys: ${userData.keys.join(", ")}', tag: 'OTP');
      if (userData['exactLocation'] != null) {
        DebugHelper.logSuccess('exactLocation field present', tag: 'OTP');
      }
      if (userData['city'] != null) {
        DebugHelper.logSuccess('Legacy city field: ${userData['city']}',
            tag: 'OTP');
      }
      if (userData['latitude'] != null && userData['longitude'] != null) {
        DebugHelper.logSuccess(
            'Legacy coordinates: ${userData['latitude']}, ${userData['longitude']}');
      }

      DebugHelper.log('Saving user data to Firestore for user: $userId');
      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      DebugHelper.logSuccess('OTP: User data saved successfully to Firestore',
          tag: 'OTP');
      DebugHelper.log('User data saved successfully');
    } catch (e) {
      DebugHelper.logError('OTP: Error saving user data: $e');
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
          if (mounted) {
            setState(() {
              _isLoading = true;
              _errorMessage = '';
            });
            await _handleCredential(credential);
          }
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
            // Reset attempt counter and session timer on successful resend
            _otpAttempts = 0;
            _startSessionExpiryTimer();

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
          // This is NOT an error - it just means auto-retrieval stopped
          // User can still enter the OTP manually
          if (mounted) {
            setState(() {
              _isResending = false;
            });
            // Update verification ID in case it changed
            if (verificationId.isNotEmpty) {
              _currentVerificationId = verificationId;
            }
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
    // Handle paste - if user pastes full OTP
    if (value.length > 1) {
      _handleOtpPaste(value);
      return;
    }

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

  void _handleOtpPaste(String pastedValue) {
    // Extract only digits from pasted value
    final digits = pastedValue.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.isEmpty) return;

    // Fill OTP fields with pasted digits
    for (int i = 0; i < _otpControllers.length && i < digits.length; i++) {
      _otpControllers[i].text = digits[i];
    }

    // If we have 6 digits, auto-verify
    if (digits.length >= 6) {
      _focusNodes.last.unfocus();
      _verifyOtp();
    } else {
      // Focus on the next empty field
      final nextIndex = digits.length < 6 ? digits.length : 5;
      if (nextIndex < _focusNodes.length) {
        _focusNodes[nextIndex].requestFocus();
      }
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
      body: Stack(
        children: [
          SafeArea(
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
                  _buildVerifyButton(),
                  const SizedBox(height: 24),

                  // Resend OTP Section
                  _buildResendSection(),
                ],
              ),
            ),
          ),
          // Success overlay
          if (_showSuccess) _buildSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return AnimatedOpacity(
      opacity: _showSuccess ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: Colors.white.withValues(alpha: 0.95),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'verification_successful'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'setting_up_account'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    final bool isLocked = _otpState == OtpState.locked;
    final bool isExpired = _otpState == OtpState.expired;
    final bool isDisabled = _isLoading || isLocked || isExpired;

    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ElevatedButton(
          onPressed: isDisabled ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isLocked || isExpired ? Colors.grey.shade400 : mainColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isDisabled ? 0 : 4,
            disabledBackgroundColor: isLocked || isExpired
                ? Colors.grey.shade300
                : mainColor.withValues(alpha: 0.5),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLocked) ...[
                      const Icon(Icons.lock_outline, size: 18),
                      const SizedBox(width: 8),
                    ] else if (isExpired) ...[
                      const Icon(Icons.timer_off_outlined, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      isLocked
                          ? 'locked'.tr()
                          : isExpired
                              ? 'session_expired'.tr()
                              : 'verify_continue'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _otpState == OtpState.locked
                ? Icons.lock_outline
                : _otpState == OtpState.expired
                    ? Icons.timer_off_outlined
                    : Icons.verified_user_rounded,
            size: 40,
            color: _otpState == OtpState.locked || _otpState == OtpState.expired
                ? Colors.red
                : mainColor,
          ),
        ),
        // Session timer badge
        _buildSessionTimerBadge(),
      ],
    );
  }

  Widget _buildSessionTimerBadge() {
    final isExpiringSoon = _isSessionExpiringSoon();
    final isExpired = _otpState == OtpState.expired;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isExpired
            ? Colors.red.withValues(alpha: 0.1)
            : isExpiringSoon
                ? Colors.orange.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpired
              ? Colors.red.withValues(alpha: 0.3)
              : isExpiringSoon
                  ? Colors.orange.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isExpired ? Icons.timer_off : Icons.timer_outlined,
            size: 16,
            color: isExpired
                ? Colors.red
                : isExpiringSoon
                    ? Colors.orange
                    : Colors.grey.shade600,
          ),
          const SizedBox(width: 6),
          Text(
            isExpired ? 'expired'.tr() : _formatSessionTime(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isExpired
                  ? Colors.red
                  : isExpiringSoon
                      ? Colors.orange
                      : Colors.grey.shade600,
            ),
          ),
        ],
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
    final bool isLocked = _otpState == OtpState.locked;
    final bool isExpired = _otpState == OtpState.expired;
    final bool isDisabled = isLocked || isExpired;

    return Column(
      children: [
        // Attempt counter
        if (_otpAttempts > 0 && !isLocked)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: _otpAttempts >= 2 ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  'attempts_remaining'
                      .tr(args: [(_maxOtpAttempts - _otpAttempts).toString()]),
                  style: TextStyle(
                    fontSize: 13,
                    color: _otpAttempts >= 2
                        ? Colors.orange
                        : Colors.grey.shade600,
                    fontWeight:
                        _otpAttempts >= 2 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

        // OTP fields with shake animation
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                  _shakeAnimation.value *
                      ((_shakeController.value * 10).toInt() % 2 == 0 ? 1 : -1),
                  0),
              child: child,
            );
          },
          child: Row(
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
                  enabled: !isDisabled,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDisabled ? Colors.grey : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _otpControllers[index].text.isNotEmpty
                            ? mainColor
                            : Colors.grey.shade300,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: mainColor, width: 2),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    filled: true,
                    fillColor: isDisabled ? Colors.grey.shade100 : Colors.white,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    _triggerHapticLight();
                    _handleOtpInput(index, value);
                  },
                  onTap: () {
                    _otpControllers[index].selection = TextSelection.collapsed(
                        offset: _otpControllers[index].text.length);
                  },
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    final bool isLocked = _otpState == OtpState.locked;
    final bool isExpired = _otpState == OtpState.expired;

    Color bgColor;
    Color borderColor;
    Color iconColor;
    Color textColor;
    IconData icon;

    if (isLocked) {
      bgColor = Colors.red.withValues(alpha: 0.1);
      borderColor = Colors.red.withValues(alpha: 0.3);
      iconColor = Colors.red.shade700;
      textColor = Colors.red.shade700;
      icon = Icons.lock_outline;
    } else if (isExpired) {
      bgColor = Colors.orange.withValues(alpha: 0.1);
      borderColor = Colors.orange.withValues(alpha: 0.3);
      iconColor = Colors.orange.shade700;
      textColor = Colors.orange.shade700;
      icon = Icons.timer_off_outlined;
    } else {
      bgColor = Colors.red.withValues(alpha: 0.1);
      borderColor = Colors.red.withValues(alpha: 0.3);
      iconColor = Colors.red.shade700;
      textColor = Colors.red.shade700;
      icon = Icons.error_outline;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isLocked || isExpired) ...[
                  const SizedBox(height: 4),
                  Text(
                    isLocked
                        ? 'please_resend_otp_to_try_again'.tr()
                        : 'session_expired_resend_otp'.tr(),
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
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
