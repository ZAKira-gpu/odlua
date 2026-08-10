import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import 'package:odlua/utils/location/widgets/location_autocomplete_field.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../../otp_verification_screen.dart';
import '../../widgets/auth_widgets.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _chefNameController = TextEditingController();
  final _bioController = TextEditingController();

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
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _chefNameController.dispose();
    _bioController.dispose();
    _specialtiesController.dispose();
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
      final geoKey = await LocationConfig.geoapifyKey();
      final gKey = await LocationConfig.googlePlacesKey();
      final service = LocationAutocompleteService(
        geoapify: geoKey.isNotEmpty ? GeoapifyService(apiKey: geoKey) : null,
        google: gKey.isNotEmpty ? GooglePlacesService(apiKey: gKey) : null,
      );
      setState(() {
        _locationController = LocationController(service: service);
      });
    } catch (e) {
      DebugHelper.log('Init location autocomplete failed: $e');
    }
  }

  // Legacy error handler removed (GPS flow deprecated in Phase 2A)

  bool _validateForm() {
    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (!_agreeToTerms) {
      _showErrorSnackbar('please_agree_to_terms'.tr());
      return false;
    }

    if (!_puzzleSolved) {
      _showErrorSnackbar('please_verify_you_are_human'.tr());
      return false;
    }

    if (_locationController?.selected.value == null) {
      _showErrorSnackbar('please_select_location'.tr());
      return false;
    }

    // Seller-specific validation
    if (_isSeller) {
      if (_chefNameController.text.trim().isEmpty) {
        _showErrorSnackbar('please_enter_chef_name'.tr());
        return false;
      }
      if (_bioController.text.trim().isEmpty) {
        _showErrorSnackbar('please_enter_chef_bio'.tr());
        return false;
      }
      if (_selectedSpecialties.isEmpty) {
        _showErrorSnackbar('please_select_specialties'.tr());
        return false;
      }
    }

    return true;
  }

  Future<bool> _checkEmailExists(String email) async {
    try {
      print('Checking if email exists: $email');
      final methods = await _auth
          .fetchSignInMethodsForEmail(email)
          .timeout(const Duration(seconds: 10));
      print('Email check complete. Methods found: ${methods.length}');
      if (methods.isNotEmpty) {
        print('Email already in use: $email');
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
      print(
          'Network error during email check - skipping pre-validation: ${e.code}');
      return false; // Couldn't verify, but continue anyway
    } catch (e) {
      // For any other error (timeout, network), skip the check
      print('Error checking email existence (will skip): $e');
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
      final phone = _phoneController.text.trim();

      print('Starting registration for email: $email, phone: $phone');

      // Validate email format
      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
        print('Invalid email format: $email');
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'invalid_email_format'.tr(),
        );
      }

      print('Email format validated');

      // Check if email already exists (skip if network unavailable)
      print('Checking if email already exists...');
      final emailAvailable = await _checkEmailExists(email);
      if (emailAvailable) {
        print('Email check passed - email is available');
      } else {
        print(
            'Email check skipped due to network issues - will verify during phone auth');
      }

      // Prepare signup data WITH email and password
      print('Collecting signup data...');
      final signupData = await _collectSignupData(null);

      // Add email and password explicitly to ensure they're passed
      signupData['email'] = email;
      signupData['password'] = password;
      signupData['photoFile'] = _photoFile; // Pass the actual file

      print('Signup data collected. Starting phone verification...');
      // Verify phone number and navigate to OTP
      await _verifyPhoneNumber(phone, signupData);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      _phoneVerificationRetryCount++;
      _handleFirebaseError(e);
      print('FirebaseAuthException during registration: '
          'code: \\${e.code}, message: \\${e.message}, details: \\${e.toString()}');
    } catch (e, stack) {
      setState(() => _isLoading = false);
      _phoneVerificationRetryCount++;
      _showErrorSnackbar('registration_failed'.tr());
      DebugHelper.log('Registration error: $e');
      print('Registration error: $e');
      print('Stack trace: $stack');
    }
  }

  Future<Map<String, dynamic>> _collectSignupData(String? photoUrl) async {
    final timestamp = FieldValue.serverTimestamp();
    final sel = _locationController?.selected.value;

    final data = {
      "name": _nameController.text.trim(),
      "email": _emailController.text.trim(), // Make sure this is included
      "password": _passwordController.text.trim(), // Make sure this is included
      "phone": _phoneController.text.trim(),
      "photoURL": photoUrl,
      // New nested location map
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
    }

    return data;
  }

  void _navigateToOtpVerification(String phone, String verificationId,
      Map<String, dynamic> signupData, int? resendToken) {
    // Ensure all critical data is included
    final completeSignupData = Map<String, dynamic>.from(signupData);
    completeSignupData['email'] = _emailController.text.trim();
    completeSignupData['password'] = _passwordController.text.trim();
    completeSignupData['photoFile'] = _photoFile;

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
    print('Verifying phone number: $phoneNumber');
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        print('Phone verification completed automatically');
        // Auto-sign-in if verification completes automatically
        try {
          print('Attempting auto sign-in with credential...');
          final UserCredential userCredential =
              await _auth.signInWithCredential(credential);
          print('Auto sign-in successful. Completing user registration...');
          await _completeUserRegistration(userCredential.user!, signupData);
        } catch (e, stack) {
          setState(() => _isLoading = false);
          _showErrorSnackbar('auto_verification_failed'.tr());
          print('Auto verification failed: $e');
          print('Stack trace: $stack');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        print(
            'Phone verification failed: code: ${e.code}, message: ${e.message}');
        setState(() => _isLoading = false);
        _phoneVerificationRetryCount++;
        _handleFirebaseError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        print('OTP code sent. Verification ID: $verificationId');
        setState(() => _isLoading = false);
        _navigateToOtpVerification(
            phoneNumber, verificationId, signupData, resendToken);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print('Code auto retrieval timeout. Verification ID: $verificationId');
        setState(() => _isLoading = false);
        _showErrorSnackbar('verification_timeout'.tr());
      },
      timeout: const Duration(seconds: 60),
    );
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
      print('Error completing user registration: $e');
      print('Stack trace: $stack');
      // Delete user if registration fails
      await user.delete();
      rethrow;
    }
  }

  Future<void> _saveUserData(
      String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .set(userData, SetOptions(merge: true));
    } catch (e, stack) {
      DebugHelper.log('Error saving user data: $e');
      print('Error saving user data: $e');
      print('Stack trace: $stack');
      rethrow;
    }
  }

  void _navigateToSuccessScreen() {
    // Navigate to success screen or home screen
    Navigator.pushReplacementNamed(context, '/home');
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
        title: Text(
          'terms_of_service'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'terms_intro'.tr(),
                style: const TextStyle(fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 16),
              _buildTermsSection(
                  '1. ${'acceptance_of_terms'.tr()}', 'terms_section_1'.tr()),
              _buildTermsSection(
                  '2. ${'user_accounts'.tr()}', 'terms_section_2'.tr()),
              _buildTermsSection(
                  '3. ${'user_responsibilities'.tr()}', 'terms_section_3'.tr()),
              _buildTermsSection(
                  '4. ${'prohibited_activities'.tr()}', 'terms_section_4'.tr()),
              _buildTermsSection(
                  '5. ${'content_ownership'.tr()}', 'terms_section_5'.tr()),
              _buildTermsSection('6. ${'limitation_of_liability'.tr()}',
                  'terms_section_6'.tr()),
              const SizedBox(height: 16),
              Text(
                'terms_contact'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontStyle: FontStyle.italic,
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

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'privacy_policy'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTermsSection('pp_section1'.tr(), 'pp_paragraph1'.tr()),
              _buildTermsSection('pp_section2'.tr(), 'pp_paragraph2'.tr()),
              _buildTermsSection('pp_section3'.tr(), 'pp_paragraph3'.tr()),
              _buildTermsSection('pp_section4'.tr(), 'pp_paragraph4'.tr()),
              _buildTermsSection('pp_section5'.tr(), 'pp_paragraph5'.tr()),
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
            color: Colors.black.withOpacity(0.08),
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
                      ? Colors.green.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
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
                            ? mainColor.withOpacity(0.08)
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
                          color: mainColor.withOpacity(0.15),
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
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
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
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                color: Colors.black.withOpacity(0.08),
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
                      color: mainColor.withOpacity(0.1),
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
                                color: mainColor.withOpacity(0.1),
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
                              color: mainColor.withOpacity(0.3),
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
                            color: mainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: mainColor.withOpacity(0.3), width: 1.5),
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
            color: Colors.black.withOpacity(0.08),
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
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
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
          if (_locationController == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            LocationAutocompleteField(
              controller: _locationController!,
              decoration: InputDecoration(
                labelText: 'location_search_hint'.tr(),
                hintText: 'location_search_hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onSelected: (sel) {
                setState(() {
                  _locationRequired = false;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_locationController!.selected.value != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _locationController!.selected.value!.formattedAddress,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${'latitude'.tr()}: ${_locationController!.selected.value!.latitude.toStringAsFixed(5)}'),
                    Text(
                        '${'longitude'.tr()}: ${_locationController!.selected.value!.longitude.toStringAsFixed(5)}'),
                  ],
                ),
              ),
            if (_locationController!.selected.value == null &&
                _locationRequired)
              Text(
                'location_required'.tr(),
                style: TextStyle(
                    color: Colors.red.shade600, fontWeight: FontWeight.w500),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                      color: Colors.black.withOpacity(0.08),
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
                                  color: Colors.black.withOpacity(0.15),
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
                                      color: Colors.black.withOpacity(0.2),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
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
                          color: mainColor.withOpacity(0.1),
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

                  // Phone Number (Required)
                  TextFormField(
                    controller: _phoneController,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      labelText: 'phone'.tr(),
                      hintText: 'phone_placeholder'.tr(),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'please_enter_phone'.tr();
                      }
                      if (!value.startsWith('+')) {
                        return 'phone_must_start_with_plus'.tr();
                      }
                      if (value.length < 9) {
                        return 'invalid_phone_number'.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'phone_required_hint'.tr(),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Location Section
            _buildLocationSection(),
            const SizedBox(height: 24),

            // Seller Toggle
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
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
                      color: mainColor.withOpacity(0.1),
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
            _buildHumanVerificationSection(),

            // Terms and Conditions
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _agreeToTerms
                      ? mainColor.withOpacity(0.3)
                      : Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                                fontSize: 15,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(text: 'agree_with'.tr()),
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
                    color: mainColor.withOpacity(0.3),
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
