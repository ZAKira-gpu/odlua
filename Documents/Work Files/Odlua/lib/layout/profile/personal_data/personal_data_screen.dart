import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../../../utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

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
  late TextEditingController _locationController;
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
  final List<String> _availableSpecialties = [
    'Italian', 'Chinese', 'Mexican', 'Japanese', 'Indian',
    'Mediterranean', 'American', 'French', 'Thai', 'Vietnamese',
    'Korean', 'Spanish', 'Greek', 'Lebanese', 'Turkish',
    'Vegetarian', 'Vegan', 'Gluten-Free', 'Healthy', 'Desserts',
    'BBQ', 'Seafood', 'Street Food', 'Fusion', 'Traditional'
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _initializeUserData();
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _locationController = TextEditingController();
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
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      
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
      _locationController.text = _userData?['location'] ?? '';
      _bioController.text = _userData?['bio'] ?? '';
      _yearsExperienceController.text = (_userData?['yearsExperience'] ?? 1).toString();
      _chefNameController.text = _userData?['chefName'] ?? '';
      _isOnline = _userData?['isOnline'] ?? true;
      _selectedSpecialties = List<String>.from(_userData?['specialties'] ?? []);
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;

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
        'location': _locationController.text.trim(),
        'bio': _bioController.text.trim(),
        'isOnline': _isOnline,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add photo URL if uploaded (correct field name is photoURL)
      if (photoUrl != null) {
        updateData['photoURL'] = photoUrl;
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
        'user_profiles/${_currentUser!.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
      );
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
    _locationController.dispose();
    _bioController.dispose();
    _yearsExperienceController.dispose();
    _chefNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Personal Data',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _buildContent(),
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

            // Account Status Section
            _buildAccountStatusSection(),
            const SizedBox(height: 28),

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
                  color: mainColor.withOpacity(0.3),
                  width: 4,
                ),
              ),
              child: ClipOval(
                child: _selectedImage != null
                    ? Image.file(_selectedImage!, fit: BoxFit.cover)
                    : (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty
                        ? Image.network(currentPhotoUrl, fit: BoxFit.cover)
                        : Container(
                            color: mainColor.withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: mainColor.withOpacity(0.6),
                            ),
                          )),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mainColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, size: 22, color: Colors.white),
                onPressed: _isSaving ? null : _pickImage,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                colors: [mainColor, mainColor.withOpacity(0.8)],
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
      icon: Icons.person_outline_rounded,
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
        _buildFormField(
          controller: _locationController,
          label: 'Location',
          icon: Icons.location_on_outlined,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Location is required';
            }
            return null;
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
      icon: Icons.restaurant_menu_rounded,
      title: 'Chef Information',
      children: [
        _buildFormField(
          controller: _chefNameController,
          label: 'Chef Display Name',
          icon: Icons.verified_user_outlined,
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
          icon: Icons.work_history_outlined,
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
        const SizedBox(height: 20),
        _buildSpecialtiesSection(),
      ],
    );
  }

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
              onChanged: _isSaving ? null : (value) {
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

  Widget _buildStatusItem(String label, String value, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'verified':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'suspended':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSpecialtiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specialties',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select your cooking specialties',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _availableSpecialties.map((specialty) {
            final isSelected = _selectedSpecialties.contains(specialty);
            return FilterChip(
              label: Text(specialty),
              selected: isSelected,
              onSelected: _isSaving ? null : (_) => _toggleSpecialty(specialty),
              checkmarkColor: Colors.white,
              selectedColor: mainColor,
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? mainColor : Colors.grey.shade300,
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedSpecialties.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: mainColor.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: mainColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Selected: ${_selectedSpecialties.join(', ')}',
                    style: TextStyle(
                      fontSize: 14,
                      color: mainColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                child: Icon(icon, color: mainColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(icon, color: mainColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: mainColor, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _isSaving ? null : _saveForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: mainColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, size: 22),
                    SizedBox(width: 12),
                    Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}