// ─────────────────────────────────────────
// Widget: SignupForm
// Description: Multi-field registration form — name, email, phone,
//              password, location. Validates and triggers OTP flow.
// Contains: Form fields, phone input, location selector, validation
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
// Legacy geocoding/geolocator removed in favor of manual location selection (Phase 2A)
// import 'package:geocoding/geocoding.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:odlua/utils/location/controllers/location_controller.dart';
import 'package:odlua/utils/location/services/geoapify_service.dart';
import 'package:odlua/utils/location/services/google_places_service.dart';
import 'package:odlua/utils/location/services/location_autocomplete_service.dart';
import 'package:odlua/utils/location/location_config.dart';
import 'package:odlua/utils/location/widgets/location_selector_widget.dart';
import 'package:odlua/utils/models/structured_address_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _chefNameController = TextEditingController();
  final _bioController = TextEditingController();

  // FocusNodes for auto-scrolling to first empty field
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _chefNameFocus = FocusNode();
  final _bioFocus = FocusNode();

  // GlobalKeys for scrolling to sections
  final _basicInfoKey = GlobalKey();
  final _locationKey = GlobalKey();
  final _sellerKey = GlobalKey();
  final _puzzleKey = GlobalKey();
  final _termsKey = GlobalKey();

  bool _obscurePassword = true;
  bool _agreeToTerms = false;
  bool _isSeller = false;
  bool _isLoading = false;
  // Deprecated GPS flow removed
  bool _isUploadingImage = false;
  bool _locationRequired =
      true; // will flip false when user selects manual location

  File? _photoFile;
  // Deprecated: was used for raw address string
  LocationController? _locationController;
  StructuredAddress? _structuredAddress; // NEW: Phase 2B structured address
  final List<String> _selectedSpecialties = [];
  final TextEditingController _specialtiesController = TextEditingController();
  int _yearsExperience = 1;

  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Retry mechanisms
  // Deprecated GPS retry state removed
  int _phoneVerificationRetryCount = 0;
  static const int _maxPhoneRetries = 2;

  // Human verification puzzle
  List<int> _puzzleNumbers = [];
  int _selectedNumber = 0;
  bool _puzzleSolved = false;

  @override
  void initState() {
    super.initState();
    _generatePuzzle();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationAutocomplete();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _chefNameController.dispose();
    _bioController.dispose();
    _specialtiesController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _phoneFocus.dispose();
    _chefNameFocus.dispose();
    _bioFocus.dispose();
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

  // Legacy error handler now unused after migration; safe to remove.
  // Removed legacy _handleLocationError (unused after migration)

  bool _verifyPuzzle() {
    try {
      final largest = _puzzleNumbers.reduce((a, b) => a > b ? a : b);
      return _selectedNumber == largest;
    } catch (e) {
      return false;
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker
          .pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
            maxWidth: 800,
          )
          .timeout(const Duration(seconds: 30));

      if (picked != null) {
        setState(() {
          _photoFile = File(picked.path);
        });
        _showSuccessSnackbar('image_selected_successfully'.tr());
      }
    } on TimeoutException {
      _showErrorSnackbar('image_selection_timeout'.tr());
    } catch (e) {
      _showErrorSnackbar('failed_to_pick_image'.tr());
      DebugHelper.log('Image pick error: $e');
    }
  }

  Future<String?> _uploadImageToStorage(String userId) async {
    if (_photoFile == null) return null;

    try {
      setState(() => _isUploadingImage = true);

      final ref = _storage.ref().child('user_profiles/$userId.jpg');
      final uploadTask = await ref.putFile(_photoFile!);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      setState(() => _isUploadingImage = false);
      return downloadUrl;
    } catch (e) {
      setState(() => _isUploadingImage = false);
      DebugHelper.log('Image upload error: $e');
      return null;
    }
  }

  Future<void> _initLocationAutocomplete() async {
    try {
      final remoteGeoKey = await LocationConfig.geoapifyKey();
      // Temporary dev fallback using provided key; replace with Remote Config in production
      final geoKey = remoteGeoKey.isNotEmpty
          ? remoteGeoKey
          : '5518b2bedddd4602abb5e88c46cfda15';
      final gKey = await LocationConfig.googlePlacesKey();

      DebugHelper.log('Location API Keys loaded:');
      DebugHelper.log(
          '   Geoapify: ${geoKey.isNotEmpty ? "✅ ${geoKey.substring(0, 10)}..." : "❌ MISSING"}');
      DebugHelper.log(
          '   Google Places: ${gKey.isNotEmpty ? "✅ ${gKey.substring(0, 10)}..." : "❌ MISSING"}');

      final service = LocationAutocompleteService(
        geoapify: geoKey.isNotEmpty ? GeoapifyService(apiKey: geoKey) : null,
        google: gKey.isNotEmpty ? GooglePlacesService(apiKey: gKey) : null,
      );
      setState(() {
        _locationController = LocationController(service: service);
      });

      DebugHelper.logSuccess('LocationController initialized successfully');
    } catch (e) {
      DebugHelper.logError('Init location autocomplete failed: $e');
      DebugHelper.log('Init location autocomplete failed: $e');
    }
  }

  // Legacy error handler removed (GPS flow deprecated in Phase 2A)

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

    // Phase 2B: Check structured address OR legacy location controller
    if (_structuredAddress == null &&
        _locationController?.selected.value == null) {
      _showErrorSnackbar('please_select_location'.tr());
      _scrollToAndFocus(_locationKey);
      return false;
    }

    // Seller-specific validation
    if (_isSeller) {
      if (_chefNameController.text.trim().isEmpty) {
        _showErrorSnackbar('please_enter_chef_name'.tr());
        _scrollToAndFocus(_sellerKey, _chefNameFocus);
        return false;
      }
      if (_bioController.text.trim().isEmpty) {
        _showErrorSnackbar('please_enter_chef_bio'.tr());
        _scrollToAndFocus(_sellerKey, _bioFocus);
        return false;
      }
      if (_selectedSpecialties.isEmpty) {
        _showErrorSnackbar('please_select_specialties'.tr());
        _scrollToAndFocus(_sellerKey);
        return false;
      }
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
      // If it's email-already-in-use, rethrow it
      if (e.code == 'email-already-in-use') {
        rethrow;
      }
      // For network errors, skip the check and continue
      DebugHelper.log(
          'Network error during email check - skipping pre-validation: ${e.code}');
      return false; // Couldn't verify, but continue anyway
    } catch (e) {
      // For any other error (timeout, network), skip the check
      DebugHelper.log('Error checking email existence (will skip): $e');
      return false; // Couldn't verify, but continue anyway
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

      // Prepare signup data WITH email and password
      DebugHelper.log('Collecting signup data...');
      final signupData = await _collectSignupData(null);

      // Add email and password explicitly to ensure they're passed
      signupData['email'] = email;
      signupData['password'] = password;
      signupData['photoFile'] = _photoFile; // Pass the actual file

      DebugHelper.log('Signup data collected.');
      DebugHelper.log('Signup data keys: ${signupData.keys.join(", ")}');
      if (signupData['exactLocation'] != null) {
        DebugHelper.log('   exactLocation is present in signupData');
      } else if (signupData['location'] != null) {
        DebugHelper.log('   legacy location is present in signupData');
      } else {
        DebugHelper.log('   NO LOCATION in signupData!');
      }

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
    final sel = _locationController?.selected.value;

    DebugHelper.log('Collecting signup data...');
    DebugHelper.log('   Name: ${_nameController.text.trim()}');
    DebugHelper.log('   Email: ${_emailController.text.trim()}');
    DebugHelper.log('   Phone: ${_phoneController.text.trim()}');
    DebugHelper.log('   User type: ${_isSeller ? "chef" : "customer"}');

    final data = {
      "name": _nameController.text.trim(),
      "email": _emailController.text.trim(), // Make sure this is included
      "password": _passwordController.text.trim(), // Make sure this is included
      "phone": _phoneController.text.trim(),
      "photoURL": photoUrl,

      // Phase 2B: New structured address (priority)
      if (_structuredAddress != null)
        "exactLocation": _structuredAddress!.toFirestore(),

      // New nested location map (legacy support)
      if (sel != null)
        "location": {
          "city": sel.city,
          "postalCode": sel.postalCode,
          "country": sel.country,
          "countryCode": sel.countryCode,
          "formattedAddress": sel.formattedAddress,
          "latitude": sel.latitude,
          "longitude": sel.longitude,
        },
      // Legacy top-level fields for backward compatibility during migration
      if (sel != null) ...{
        "city": sel.city,
        "postalCode": sel.postalCode,
        "country": sel.country,
        "countryCode": sel.countryCode,
        "formattedAddress": sel.formattedAddress,
        "latitude": sel.latitude,
        "longitude": sel.longitude,
      },
      // If using structured address, also populate legacy fields from it
      if (_structuredAddress != null) ...{
        "city": _structuredAddress!.city,
        "postalCode": _structuredAddress!.postalCode,
        "country": _structuredAddress!.country,
        "countryCode": _structuredAddress!.countryCode,
        "formattedAddress": _structuredAddress!.formattedAddress,
        "latitude": _structuredAddress!.coordinates.latitude,
        "longitude": _structuredAddress!.coordinates.longitude,
      },
      "userType": _isSeller ? "chef" : "customer",
      "isHumanVerified": true,
      "createdAt": timestamp,
      "updatedAt": timestamp,
      "lastLogin": timestamp,
      "accountStatus": "active",
      "emailVerified": false,
      "phoneVerified": false,
      "profileCompleted": true,
    };

    if (_structuredAddress != null) {
      DebugHelper.logSuccess('Structured address included in signup data:');
      DebugHelper.log('   City: ${_structuredAddress!.city}');
      DebugHelper.log(
          '   Street: ${_structuredAddress!.streetName} ${_structuredAddress!.buildingNumber}');
      DebugHelper.log(
          '   Coordinates: ${_structuredAddress!.coordinates.latitude}, ${_structuredAddress!.coordinates.longitude}');
    } else if (sel != null) {
      DebugHelper.logSuccess('Legacy location included in signup data:');
      DebugHelper.log('   City: ${sel.city}');
      DebugHelper.log('   Coordinates: ${sel.latitude}, ${sel.longitude}');
    } else {
      DebugHelper.logWarning('NO LOCATION DATA in signup data!');
    }

    // Add seller-specific data
    if (_isSeller) {
      data.addAll({
        "chefName": _chefNameController.text.trim(),
        "bio": _bioController.text.trim(),
        "specialties": _selectedSpecialties,
        "yearsExperience": _yearsExperience,
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
      DebugHelper.log('   Chef data added: ${_chefNameController.text.trim()}');
    }

    return data;
  }

  void _navigateToOtpVerification(String phone, String verificationId,
      Map<String, dynamic> signupData, int? resendToken) {
    // Ensure all critical data is included
    final completeSignupData = Map<String, dynamic>.from(signupData);

    // Use existing data if available, otherwise fallback to controllers
    if (completeSignupData['email'] == null ||
        completeSignupData['email'].toString().isEmpty) {
      completeSignupData['email'] = _emailController.text.trim();
    }

    if (completeSignupData['password'] == null ||
        completeSignupData['password'].toString().isEmpty) {
      completeSignupData['password'] = _passwordController.text.trim();
    }

    completeSignupData['photoFile'] = _photoFile;

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
          signupData: completeSignupData, // Pass the complete data
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
        // Auto-verification completed (common on Android with SMS Retriever)
        // For SIGNUP flow, we need to create email+phone account, not just phone
        DebugHelper.log(
            'Auto-verification completed, navigating to OTP screen for proper account creation');

        // Even with auto-verification, navigate to OTP screen to ensure
        // proper email+phone account creation flow
        // The OTP screen will detect the credential and complete registration
        setState(() => _isLoading = false);

        // Create a temporary verification ID for the credential
        // The OTP screen will use the auto-retrieved credential
        _navigateToOtpVerification(
          phoneNumber,
          'auto-verified', // Special marker
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
        // This is NOT an error - just means auto-retrieval stopped
        // User can still enter OTP manually
        DebugHelper.log('Auto-retrieval timeout, user can enter OTP manually');
        // Don't show error or set loading to false here - the codeSent callback handles that
      },
      timeout: const Duration(seconds: 120), // Standardized to 120 seconds
    );
  }

  Future<void> _registerWithEmailOnly(
      String email, String password, Map<String, dynamic> signupData) async {
    try {
      DebugHelper.log('Creating user with email and password...');

      // Create user with email and password
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      DebugHelper.log(
          'User created successfully with UID: ${userCredential.user!.uid}');

      // Complete user registration (upload photo, save data, send verification email)
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
      // Upload image if exists
      final photoUrl = await _uploadImageToStorage(user.uid);
      if (photoUrl != null) {
        userData['photoURL'] = photoUrl;
      }

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
      // Delete user if registration fails
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
      if (userData['exactLocation'] != null) {
        DebugHelper.log('   exactLocation field present');
      }
      if (userData['city'] != null) {
        DebugHelper.log('   Legacy city field: ${userData['city']}');
      }
      if (userData['latitude'] != null && userData['longitude'] != null) {
        DebugHelper.log(
            '   Legacy coordinates: ${userData['latitude']}, ${userData['longitude']}');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));

      DebugHelper.logSuccess('User data saved successfully to Firestore');

      // Save location to SharedPreferences for legacy location service
      if (userData['latitude'] != null && userData['longitude'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('last_latitude', userData['latitude'] as double);
        await prefs.setDouble(
            'last_longitude', userData['longitude'] as double);
        DebugHelper.logSuccess('Location saved to SharedPreferences');
      }

      DebugHelper.log('User data saved for $userId');
    } catch (e, stack) {
      DebugHelper.logError('Error saving user data: $e');
      DebugHelper.log('Stack trace: $stack');
      DebugHelper.log('Error saving user data: $e');
      rethrow;
    }
  }

  void _navigateToSuccessScreen() {
    // #Ref3: Refresh User Data in Cubit on Signup Success
    // This ensures isChef status is known immediately
    if (mounted) {
      OdluaCubit.get(context).getUserData();
    }

    // #Ref3: Lazy Upgrade - Skip AccountType, go straight to Home (Buyer Mode)
    // Users are Customers by default. They can become Chefs later via "Add Dish".
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

  // Removed legacy retry dialog (GPS flow deprecated)

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

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
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
              // Section 1: Information We Collect
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
              // Section 2: Use of Information
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
              // Section 3: Sharing of Information
              _buildPrivacySection(
                'pp_section3'.tr(),
                'pp_paragraph3'.tr(),
                [
                  'pp_bullet3_1'.tr(),
                  'pp_bullet3_2'.tr(),
                ],
              ),
              // Section 4: Data Retention
              _buildPrivacySection(
                'pp_section4'.tr(),
                'pp_paragraph4'.tr(),
                null,
              ),
              // Section 5: Your Rights
              _buildPrivacySection(
                'pp_section5'.tr(),
                'pp_paragraph5'.tr(),
                null,
              ),
              // Section 6: Children's Privacy
              _buildPrivacySection(
                'pp_section6'.tr(),
                'pp_paragraph6'.tr(),
                null,
              ),
              // Section 7: Security
              _buildPrivacySection(
                'pp_section7'.tr(),
                'pp_paragraph7'.tr(),
                null,
              ),
              // Section 8: Changes to This Policy
              _buildPrivacySection(
                'pp_section8'.tr(),
                'pp_paragraph8'.tr(),
                null,
              ),
              // Section 9: Contact Us
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

  Widget _buildSellerSection() {
    if (!_isSeller) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Container(
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
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: mainColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'seller_information'.tr(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'tell_us_about_your_culinary_skills'.tr(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),

              // Chef Display Name
              AuthTextField(
                label: 'chef_display_name'.tr(),
                hintText: 'enter_chef_display_name'.tr(),
                controller: _chefNameController,
                validator: (value) {
                  if (_isSeller && (value == null || value.isEmpty)) {
                    return 'please_enter_chef_name'.tr();
                  }
                  if (_isSeller && value != null && value.length < 2) {
                    return 'chef_name_too_short'.tr();
                  }
                  return null;
                },
                prefixIcon: Icons.restaurant_menu_rounded,
              ),
              const SizedBox(height: 20),

              // Chef Bio
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  labelText: 'chef_bio'.tr(),
                  hintText: 'tell_us_about_your_cooking_experience'.tr(),
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
                  alignLabelWithHint: true,
                  prefixIcon:
                      const Icon(Icons.description_rounded, color: Colors.grey),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                validator: (value) {
                  if (_isSeller && (value == null || value.isEmpty)) {
                    return 'please_enter_chef_bio'.tr();
                  }
                  if (_isSeller && value != null && value.length < 10) {
                    return 'chef_bio_too_short'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Years of Experience
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'years_of_experience'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Slider(
                          value: _yearsExperience.toDouble(),
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: '$_yearsExperience ${'years'.tr()}',
                          onChanged: (value) {
                            setState(() {
                              _yearsExperience = value.toInt();
                            });
                          },
                          activeColor: mainColor,
                          inactiveColor: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 ${'year'.tr()}',
                                style: TextStyle(color: Colors.grey.shade600)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: mainColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_yearsExperience ${'years'.tr()}',
                                style: TextStyle(
                                  color: mainColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text('50 ${'years'.tr()}',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Specialties - Enhanced UI
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'culinary_specialties'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'enter_your_cooking_specialties'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Text field for entering specialty
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _specialtiesController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'e.g. Italian, Pasta, Pizza, Sushi...'.tr(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide:
                                  BorderSide(color: mainColor, width: 2.5),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: const Icon(Icons.restaurant_rounded,
                                color: Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 16),
                          ),
                          onFieldSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              setState(() {
                                _selectedSpecialties.add(value.trim());
                                _specialtiesController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: mainColor.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed: () {
                            if (_specialtiesController.text.trim().isNotEmpty) {
                              setState(() {
                                _selectedSpecialties
                                    .add(_specialtiesController.text.trim());
                                _specialtiesController.clear();
                              });
                            }
                          },
                          icon: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 28),
                          tooltip: 'add_specialty'.tr(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Display added specialties as chips
                  if (_selectedSpecialties.isNotEmpty)
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _selectedSpecialties.map((specialty) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: mainColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: mainColor.withValues(alpha: 0.3),
                                width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.restaurant_menu_rounded,
                                  color: mainColor, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                specialty,
                                style: TextStyle(
                                  color: mainColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSpecialties.remove(specialty);
                                  });
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  color: mainColor,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),

                  if (_selectedSpecialties.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.orange.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'add_at_least_one_specialty'.tr(),
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
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _locationController?.selected.value == null
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_searching_rounded,
                  color: _locationController?.selected.value == null
                      ? Colors.orange
                      : Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'select_location'.tr(),
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
          const SizedBox(height: 8),
          Text(
            'location_search_hint'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          // Phase 2B: Use new location selector widget (GPS + Manual)
          LocationSelectorWidget(
            initialAddress: _structuredAddress,
            onAddressComplete: (address) {
              setState(() {
                _structuredAddress = address;
                _locationRequired = false;
              });
              DebugHelper.logSuccess('Address received in signup form:');
              DebugHelper.log('   City: ${address.city}');
              DebugHelper.log('   Street: ${address.streetName}');
              DebugHelper.log('   Building: ${address.buildingNumber}');
              DebugHelper.log(
                  '   Coordinates: ${address.coordinates.latitude}, ${address.coordinates.longitude}');
              DebugHelper.log('   Formatted: ${address.formattedAddress}');
              _showSuccessSnackbar('address_saved_successfully'.tr());
            },
          ),
          const SizedBox(height: 16),
          if (_structuredAddress == null && _locationRequired)
            Text(
              'location_required'.tr(),
              style: TextStyle(
                  color: Colors.red.shade600, fontWeight: FontWeight.w500),
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
            // Profile Photo Section (centered)
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
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
                alignment: Alignment.center,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: mainColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 64,
                              backgroundColor: Colors.grey.shade100,
                              backgroundImage: _photoFile != null
                                  ? FileImage(_photoFile!)
                                  : null,
                              child: _isUploadingImage
                                  ? CircularProgressIndicator(
                                      color: mainColor, strokeWidth: 3)
                                  : _photoFile == null
                                      ? Icon(
                                          Icons.camera_alt_rounded,
                                          size: 40,
                                          color: Colors.grey.shade600,
                                        )
                                      : null,
                            ),
                          ),
                          if (_photoFile != null && !_isUploadingImage)
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: mainColor,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.check,
                                    size: 18, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'add_profile_photo'.tr(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),

                  // Phone Number (Optional)
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
                      prefixText: _phoneController.text.isEmpty ? '+' : null,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 16),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 16, // +  up to 15 digits (E.164 max)
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                      _PhonePlusFormatter(), // ensures + is always first char
                    ],
                    validator: (value) {
                      // Phone is now optional
                      if (value != null && value.isNotEmpty) {
                        if (!value.startsWith('+')) {
                          return 'phone_must_start_with_plus'.tr();
                        }
                        // Must have at least 8 digits after +
                        final digits = value.replaceAll(RegExp(r'[^\d]'), '');
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
                  const SizedBox(height: 8),
                  Text(
                    'phone_optional_hint'
                        .tr(), // Changed from required to optional
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Location Section
            Container(
              key: _locationKey,
              child: _buildLocationSection(),
            ),
            const SizedBox(height: 24),

            // Seller Toggle
            Container(
              key: _sellerKey,
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.restaurant_rounded,
                      color: mainColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'i_want_to_sell_food'.tr(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'register_as_chef_seller'.tr(),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isSeller,
                    onChanged: (value) {
                      setState(() {
                        _isSeller = value;
                      });
                    },
                    activeColor: mainColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),

            // Seller Information (conditionally shown)
            _buildSellerSection(),

            // Human Verification
            const SizedBox(height: 24),
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

/// Input formatter that ensures phone numbers always start with +
class _PhonePlusFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // If empty, allow it
    if (text.isEmpty) return newValue;

    // Remove any + that isn't at position 0
    if (text.contains('+')) {
      final firstPlus = text.indexOf('+');
      text = '+${text.replaceAll('+', '')}';
      if (firstPlus != 0) {
        // + was typed in the middle, keep it at start
      }
    }

    // If user starts typing digits without +, prepend +
    if (text.isNotEmpty && !text.startsWith('+')) {
      text = '+$text';
    }

    // Only allow + at position 0 and digits after
    text = '+${text.substring(1).replaceAll(RegExp(r'[^\d]'), '')}';

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
