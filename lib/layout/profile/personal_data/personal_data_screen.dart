// ─────────────────────────────────────────
// Screen: PersonalDataScreen
// Description: Edit profile fields — name, phone, avatar, and bio.
//              Validates input and updates Firestore user doc.
// Contains: Avatar picker, form fields, Firestore update
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:odlua/utils/theme/custom_themes/app_spacing.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:iconsax/iconsax.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/location/widgets/location_selector_widget.dart';
import 'package:odlua/utils/models/structured_address_model.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Controllers
  late TextEditingController _nameController;
  StructuredAddress? _structuredAddress; // Phase 2B structured address
  late TextEditingController _bioController;
  late TextEditingController _yearsExperienceController;
  late TextEditingController _chefNameController;

  // State variables
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isOnline = true;
  File? _selectedImage;
  List<String> _selectedSpecialties = [];
  // ignore: unused_field
  final List<String> _availableSpecialties = [
    'Italian',
    'Chinese',
    'Mexican',
    'Japanese',
    'Indian',
    'Mediterranean',
    'American',
    'French',
    'Thai',
    'Vietnamese',
    'Korean',
    'Spanish',
    'Greek',
    'Lebanese',
    'Turkish',
    'Vegetarian',
    'Vegan',
    'Gluten-Free',
    'Healthy',
    'Desserts',
    'BBQ',
    'Seafood',
    'Street Food',
    'Fusion',
    'Traditional',
    'Other', // Added "Other" option for food specialty
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeUserData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _yearsExperienceController = TextEditingController();
    _chefNameController = TextEditingController();
  }

  Future<void> _initializeUserData() async {
    _currentUser = _auth.currentUser;
    if (_currentUser != null) {
      await _fetchUserData();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_currentUser!.uid).get();

      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
          _populateFormData();
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load user data');
    }
  }

  void _populateFormData() {
    if (_userData != null) {
      _nameController.text = _userData?['name'] ?? '';

      // Load primary address from saved_addresses subcollection
      _loadPrimaryAddress();

      _bioController.text = _userData?['bio'] ?? '';
      _yearsExperienceController.text =
          (_userData?['yearsExperience'] ?? 1).toString();
      _chefNameController.text = _userData?['chefName'] ?? '';
      _isOnline = _userData?['isOnline'] ?? true;
      _selectedSpecialties = List<String>.from(_userData?['specialties'] ?? []);
    }
  }

  Future<void> _loadPrimaryAddress() async {
    try {
      final uid = _currentUser?.uid;
      if (uid == null) {
        DebugHelper.logWarning('Cannot load address: user ID is null');
        return;
      }

      DebugHelper.log('Loading primary address for user: $uid');

      // Fallback: Load from exactLocation field (primary method now)
      final exactLocation = _userData?['exactLocation'];
      if (exactLocation != null && exactLocation is Map<String, dynamic>) {
        setState(() {
          _structuredAddress = StructuredAddress.fromFirestore(exactLocation);
        });
        DebugHelper.logSuccess('Loaded address from exactLocation field');
        DebugHelper.log('Address: ${_structuredAddress!.formattedAddress}');
        DebugHelper.log(
            'Coordinates: ${_structuredAddress!.coordinates.latitude}, ${_structuredAddress!.coordinates.longitude}');
        return;
      }

      // Alternative: Try to load primary address from saved_addresses subcollection
      // (This may fail with permission denied if Firestore rules aren't set up)
      try {
        final addressesSnapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('saved_addresses')
            .where('isPrimary', isEqualTo: true)
            .limit(1)
            .get();

        if (addressesSnapshot.docs.isNotEmpty) {
          final addressData = addressesSnapshot.docs.first.data();
          setState(() {
            _structuredAddress = StructuredAddress.fromFirestore(addressData);
          });
          DebugHelper.logSuccess(
              'Loaded primary address from saved_addresses subcollection');
          return;
        }
      } catch (e) {
        DebugHelper.logWarning(
            'Could not load from saved_addresses (may need Firestore rules): $e');
        // Continue to check other sources
      }

      // Last fallback: Check legacy latitude/longitude fields
      final lat = _userData?['latitude'];
      final lng = _userData?['longitude'];
      if (lat != null && lng != null) {
        DebugHelper.logWarning(
            'Found legacy lat/lng but no structured address');
        DebugHelper.log('Coordinates: $lat, $lng');
        // Could create a basic StructuredAddress from legacy data if needed
      } else {
        DebugHelper.logWarning('No address data found in user document');
      }
    } catch (e) {
      DebugHelper.logError('Error loading primary address: $e');
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;

    // Validate that location is selected
    if (_structuredAddress == null) {
      _showErrorSnackBar('Please select a location');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      String? photoUrl;

      // Upload new profile photo if selected
      if (_selectedImage != null) {
        photoUrl = await _uploadProfilePhoto(_selectedImage!);
      }

      // Prepare update data with correct field names
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'isOnline': _isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add photo URL if uploaded (correct field name is photoURL)
      if (photoUrl != null) {
        updateData['photoURL'] = photoUrl;
      }

      // Add location data if structured address exists
      if (_structuredAddress != null) {
        updateData['exactLocation'] = _structuredAddress!.toFirestore();
        updateData['city'] = _structuredAddress!.city;
        updateData['postalCode'] = _structuredAddress!.postalCode;
        updateData['country'] = _structuredAddress!.country;
        updateData['countryCode'] = _structuredAddress!.countryCode;
        updateData['formattedAddress'] = _structuredAddress!.formattedAddress;
        updateData['latitude'] = _structuredAddress!.coordinates.latitude;
        updateData['longitude'] = _structuredAddress!.coordinates.longitude;
      }

      // Add chef-specific data if user is a chef
      if (_isChefUser) {
        updateData.addAll({
          'chefName': _chefNameController.text.trim(),
          'yearsExperience': int.tryParse(_yearsExperienceController.text) ?? 1,
          'specialties': _selectedSpecialties,
        });
      }

      // Update in Firestore
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update(updateData);

      // Update display name in Firebase Auth
      await _currentUser!.updateDisplayName(_nameController.text.trim());

      _showSuccessSnackBar('Profile updated successfully');

      // Refresh data
      await _fetchUserData();
    } catch (e) {
      DebugHelper.logError('Error updating profile: $e');
      _showErrorSnackBar('Failed to update profile: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<String?> _uploadProfilePhoto(File imageFile) async {
    try {
      final ref = _storage.ref().child(
          'user_profiles/${_currentUser!.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      DebugHelper.log('Error uploading photo: $e');
      return null;
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick image');
    }
  }

  void _toggleSpecialty(String specialty) {
    setState(() {
      if (_selectedSpecialties.contains(specialty)) {
        _selectedSpecialties.remove(specialty);
      } else {
        _selectedSpecialties.add(specialty);
      }
    });
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool get _isChefUser {
    return _userData?['isChef'] == true || _userData?['userType'] == 'chef';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _yearsExperienceController.dispose();
    _chefNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'personal_data'.tr(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -1,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading ? _buildLoadingState() : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(mainColor),
            strokeWidth: 3,
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading your data...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Header Section
            _buildProfileHeader(),
            const SizedBox(height: 40),

            // Personal Information Section
            _buildPersonalInfoSection(),
            const SizedBox(height: 28),

            // Chef Information Section (if chef)
            if (_isChefUser) ...[
              _buildChefInfoSection(),
              const SizedBox(height: 28),
            ],

            // Account Status Section (commented out as per user request)
            // _buildAccountStatusSection(),
            // const SizedBox(height: 28),

            // Save Button
            _buildSaveButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final currentPhotoUrl = _userData?['photoURL'];

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: mainColor.withValues(alpha: 0.1),
                  width: 6,
                ),
                boxShadow: AppSpacing.softShadow,
              ),
              child: ClipOval(
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                        ? Image.network(currentPhotoUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey.shade50,
                            child: Icon(
                              Iconsax.user,
                              size: 60,
                              color: Colors.grey.shade300,
                            ),
                          )),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: mainColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: AppSpacing.softShadow,
              ),
              child: InkWell(
                onTap: _isSaving ? null : _pickImage,
                child:
                    const Icon(Iconsax.camera, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _userData?['name'] ?? 'No Name',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          _userData?['email'] ?? _currentUser?.email ?? 'No Email',
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        if (_isChefUser) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [mainColor, mainColor.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Professional Chef',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      icon: Iconsax.personalcard,
      title: 'Personal Information',
      children: [
        _buildFormField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        // Location - Phase 2B: Use location selector widget (GPS + Manual)
        LocationSelectorWidget(
          initialAddress: _structuredAddress,
          onAddressComplete: (address) async {
            setState(() {
              _structuredAddress = address;
            });

            // Update Firestore immediately
            try {
              final uid = _currentUser?.uid;
              if (uid != null) {
                await _firestore.collection('users').doc(uid).update({
                  'exactLocation': address.toFirestore(),
                  'city': address.city,
                  'postalCode': address.postalCode,
                  'country': address.country,
                  'countryCode': address.countryCode,
                  'formattedAddress': address.formattedAddress,
                  'latitude': address.coordinates.latitude,
                  'longitude': address.coordinates.longitude,
                });

                // Update SharedPreferences for legacy LocationService
                final prefs = await SharedPreferences.getInstance();
                await prefs.setDouble(
                    'last_latitude', address.coordinates.latitude);
                await prefs.setDouble(
                    'last_longitude', address.coordinates.longitude);

                DebugHelper.logSuccess(
                    'Location updated in Firestore and SharedPreferences');
                _showSuccessSnackBar('Location updated successfully');
              }
            } catch (e) {
              DebugHelper.logError('Failed to update location: $e');
              _showErrorSnackBar('Failed to update location');
            }
          },
        ),
        const SizedBox(height: 20),
        _buildFormField(
          controller: _bioController,
          label: 'Bio',
          icon: Icons.description_outlined,
          maxLines: 4,
          validator: (value) {
            if (value != null && value.length > 200) {
              return 'Bio should not exceed 200 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildChefInfoSection() {
    return _buildSection(
      icon: Iconsax.cake,
      title: 'Chef Information',
      children: [
        _buildFormField(
          controller: _chefNameController,
          label: 'Chef Display Name',
          icon: Iconsax.user_tick,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Chef name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildFormField(
          controller: _yearsExperienceController,
          label: 'Years of Experience',
          icon: Iconsax.award,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Experience is required';
            }
            final years = int.tryParse(value);
            if (years == null || years < 0 || years > 50) {
              return 'Please enter a valid number between 0-50';
            }
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.s20),
        _buildSpecialtiesSection(),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildAccountStatusSection() {
    return _buildSection(
      icon: Icons.verified_user_rounded,
      title: 'Account Status',
      children: [
        _buildStatusItem(
          'Account Status',
          _userData?['accountStatus'] ?? 'active',
          _getStatusColor(_userData?['accountStatus']),
        ),
        const SizedBox(height: 16),
        _buildStatusItem(
          'Chef Status',
          _userData?['chefStatus'] ?? 'pending',
          _getStatusColor(_userData?['chefStatus']),
        ),
        const SizedBox(height: 16),
        _buildStatusItem(
          'Human Verification',
          _userData?['isHumanVerified'] == true ? 'Verified' : 'Not Verified',
          _userData?['isHumanVerified'] == true ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildStatusItem(
          'Chef Verification',
          _userData?['chefVerified'] == true ? 'Verified' : 'Not Verified',
          _userData?['chefVerified'] == true ? Colors.green : Colors.orange,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.online_prediction_rounded, color: mainColor, size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Online Status',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            Switch(
              value: _isOnline,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _isOnline = value;
                      });
                    },
              activeColor: mainColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusM),
                ),
                child: Icon(icon, color: mainColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
      case 'suspended':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSpecialtiesSection() {
    final specialties = [
      'Italian',
      'Mexican',
      'Asian',
      'Indian',
      'Mediterranean',
      'American',
      'French',
      'Middle Eastern',
      'Vegan',
      'Desserts',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Specialties',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: specialties.map((specialty) {
            final isSelected = _selectedSpecialties.contains(specialty);
            return GestureDetector(
              onTap: () => _toggleSpecialty(specialty),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? mainColor : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? mainColor : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  specialty,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey.shade700,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedSpecialties.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Selected: ${_selectedSpecialties.join(', ')}',
            style: TextStyle(
              fontSize: 14,
              color: mainColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Enter your $label',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: mainColor, size: 20),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusL),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusL),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusL),
              borderSide: BorderSide(color: mainColor, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusL),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusL),
        gradient: LinearGradient(
          colors: [mainColor, mainColor.withValues(alpha: 0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusL),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Save Profile',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
