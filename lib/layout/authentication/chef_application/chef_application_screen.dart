// ─────────────────────────────────────────
// Screen: ChefApplicationScreen
// Description: Multi-section form for users applying to become chefs.
//              Collects name, bio, specialties, experience, location.
// Contains: Form validation, Firestore submission, specialty chips
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/location/widgets/location_selector_widget.dart';
import 'package:odlua/utils/models/structured_address_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/cubit/cubit.dart';
import '../widgets/auth_widgets.dart';

/// Screen for chef application after user has selected chef account type.
/// Collects chef-specific information: display name, bio, specialties, pickup address.
class ChefApplicationScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ChefApplicationScreen({super.key, this.userData});

  @override
  State<ChefApplicationScreen> createState() => _ChefApplicationScreenState();
}

class _ChefApplicationScreenState extends State<ChefApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _chefNameController = TextEditingController();
  final _bioController = TextEditingController();
  // #Ref5: Controller for existing "Other" specialty input
  final _otherSpecialtyController = TextEditingController();

  final List<String> _selectedSpecialties = [];
  int _yearsExperience = 1;
  StructuredAddress? _pickupAddress;
  bool _isSubmitting = false;
  String? _specialtiesError;
  String? _pickupAddressError;

  final List<String> _availableSpecialties = [
    'specialty_egyptian',
    'specialty_italian',
    'specialty_asian',
    'specialty_german',
    'specialty_middle_eastern',
    'specialty_desserts',
    'specialty_vegan',
    'specialty_vegetarian',
    'specialty_seafood',
    'specialty_bbq',
    'specialty_other',
  ];

  @override
  void initState() {
    super.initState();
    // Check if user is already a chef - if so, redirect to AddDishScreen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = OdluaCubit.get(context);
      final isChef = cubit.userModel?.isChef ?? false;
      if (isChef) {
        // User is already a chef, navigate to home and switch to Add tab
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
          // Also set the bottom nav to index 2 (Add tab) if needed
        }
      }
    });
  }

  @override
  void dispose() {
    _chefNameController.dispose();
    _bioController.dispose();
    _otherSpecialtyController.dispose();
    super.dispose();
  }

  Future<void> _submitApplication() async {
    // Clear previous errors
    setState(() {
      _specialtiesError = null;
      _pickupAddressError = null;
    });

    // Validate form fields - inline errors will show automatically
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check specialties with inline error
    if (_selectedSpecialties.isEmpty) {
      setState(() {
        _specialtiesError = 'chef_application.select_specialty'.tr();
      });
      return;
    }

    // Check pickup address with inline error
    if (_pickupAddress == null) {
      setState(() {
        _pickupAddressError = 'chef_application.select_pickup_address'.tr();
      });
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackbar('chef_application.not_authenticated'.tr());
        return;
      }

      // Update user document with chef data
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'isChef': true,
        'chefStatus': 'pending', // Requires admin approval
        'chefAppliedAt': FieldValue.serverTimestamp(),
        'chefName': _chefNameController.text.trim(),
        'bio': _bioController.text.trim(),
        // #Ref5: Merge "Other" custom text
        'specialties': _selectedSpecialties.map((s) {
          if (s == 'specialty_other' &&
              _otherSpecialtyController.text.isNotEmpty) {
            return _otherSpecialtyController.text.trim();
          }
          return s;
        }).toList(),
        'yearsExperience': _yearsExperience,
        'pickupAddress': _pickupAddress!.toFirestore(),
        'chefVerified': false,
        'rating': 0.0,
        'reviewCount': 0,
        'dishCount': 0,
        'orderCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessSnackbar('chef_application.submitted'.tr());

      // #Ref3: Refresh local user data so app knows we are now a Chef
      if (mounted) {
        OdluaCubit.get(context).getUserData();
      }

      // Navigate to home after brief delay - ONLY on success
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      DebugHelper.log('Chef application error: $e');
      _showErrorSnackbar('chef_application.failed'.tr());
      // Do NOT pop - stay on screen so user can retry
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('chef_application.title'.tr()),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0.5,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'chef_application.become_chef'.tr(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'chef_application.description'.tr(),
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Chef Display Name
              _buildSectionCard(
                title: 'chef_application.chef_name'.tr(),
                icon: Icons.restaurant_menu_rounded,
                child: AuthTextField(
                  label: 'chef_application.chef_display_name'.tr(),
                  hintText: 'chef_application.enter_chef_name'.tr(),
                  controller: _chefNameController,
                  prefixIcon: Icons.badge_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'chef_application.name_required'.tr();
                    }
                    if (value.length < 2) {
                      return 'chef_application.name_too_short'.tr();
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Bio
              _buildSectionCard(
                title: 'chef_application.bio'.tr(),
                icon: Icons.description_rounded,
                child: TextFormField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: 'chef_application.about_you'.tr(),
                    hintText: 'chef_application.bio_hint'.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    alignLabelWithHint: true,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'chef_application.bio_required'.tr();
                    }
                    if (value.length < 20) {
                      return 'chef_application.bio_too_short'.tr();
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Specialties
              // Specialties
              _buildSectionCard(
                title: 'chef_application.specialties'.tr(),
                icon: Icons.local_dining_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _availableSpecialties.map((specialty) {
                        final isSelected =
                            _selectedSpecialties.contains(specialty);
                        return FilterChip(
                          label: Text(specialty.tr()),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSpecialties.add(specialty);
                              } else {
                                _selectedSpecialties.remove(specialty);
                              }
                              // Clear error when user interacts
                              if (_specialtiesError != null) {
                                _specialtiesError = null;
                              }
                            });
                          },
                          selectedColor: mainColor.withValues(alpha: 0.2),
                          checkmarkColor: mainColor,
                          labelStyle: TextStyle(
                            color: isSelected ? mainColor : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color:
                                  isSelected ? mainColor : Colors.grey.shade300,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    if (_specialtiesError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _specialtiesError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),

                    // #Ref5: Show text field if "specialty_other" is selected
                    if (_selectedSpecialties.contains('specialty_other')) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherSpecialtyController,
                        decoration: InputDecoration(
                          labelText: 'chef_application.specify_specialty'.tr(),
                          hintText: 'e.g. Peruvian, Fusion, etc.',
                          prefixIcon: const Icon(Icons.edit, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        validator: (value) {
                          if (_selectedSpecialties
                                  .contains('specialty_other') &&
                              (value == null || value.trim().isEmpty)) {
                            return 'chef_application.please_specify_specialty'
                                .tr();
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Years of Experience
              _buildSectionCard(
                title: 'chef_application.experience'.tr(),
                icon: Icons.timeline_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'chef_application.years_experience'
                          .tr(args: [_yearsExperience.toString()]),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _yearsExperience.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      activeColor: mainColor,
                      label: _yearsExperience.toString(),
                      onChanged: (value) {
                        setState(() {
                          _yearsExperience = value.round();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Pickup Address
              _buildSectionCard(
                title: 'chef_application.pickup_location'.tr(),
                icon: Icons.location_on_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocationSelectorWidget(
                      initialAddress: _pickupAddress,
                      onAddressComplete: (address) {
                        setState(() {
                          _pickupAddress = address;
                          _pickupAddressError = null;
                        });
                      },
                    ),
                    if (_pickupAddressError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _pickupAddressError!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitApplication,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'chef_application.submit'.tr(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'chef_application.pending_approval'.tr(),
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 15,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: mainColor, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
