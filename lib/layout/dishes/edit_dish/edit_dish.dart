// ─────────────────────────────────────────
// Screen: EditDishScreen
// Description: Pre-populated edit form for an existing dish listing.
//              Mirrors AddDishesScreen but loads existing data first.
// Contains: Image picker, form fields, Firestore update, delete
// ─────────────────────────────────────────

import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/location/widgets/location_selector_widget.dart';
import 'package:odlua/utils/models/structured_address_model.dart';

class EditDishScreen extends StatefulWidget {
  final String? dishId;

  const EditDishScreen({super.key, this.dishId});

  @override
  State<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends State<EditDishScreen> {
  // Helper methods

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DishService _dishService = DishService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _expirationDateController =
      TextEditingController();
  final TextEditingController _dailyQuantityController =
      TextEditingController();

  // State variables
  StructuredAddress? _structuredAddress;
  String _selectedCategory = 'fresh_food';
  String _selectedType =
      'donate'; // Changed from 'sell' - sell feature disabled
  bool _isSaving = false;
  bool _isLoading = false;
  bool _mounted = true;
  bool _isDaily = false;

  // Image management
  List<String> _imageUrls = [];
  final List<XFile> _newLocalImages = [];
  final ImagePicker _picker = ImagePicker();

  // Boolean fields
  bool _deliveryAvailable = true;
  bool _pickupAvailable = true;
  bool _isFeatured = false;
  bool _isRecommended = false;

  // Dietary options
  bool _isHalal = false;
  bool _isVegan = false;
  bool _isVegetarian = false;

  // Allergies
  Map<String, bool> _allergies = {
    'celery': false,
    'dairy': false,
    'eggs': false,
    'fish': false,
    'gluten': false,
    'lupin': false,
    'molluscs': false,
    'mustard': false,
    'peanuts': false,
    'sesame': false,
    'shellfish': false,
    'soy': false,
    'sulfites': false,
    'tree_nuts': false,
  };

  // Lists
  final List<String> _tags = [];
  final List<String> _ingredients = [];

  // Options
  final List<String> _categories = [
    'main_course',
    'appetizer',
    'dessert',
    'soup',
    'salad',
    'beverage',
    'snack',
    'fresh_food',
    'other'
  ];
  // SELL FEATURE DISABLED - Only donate and exchange available
  final List<String> _types = ['donate', 'exchange']; // Removed 'sell'

  @override
  void initState() {
    super.initState();
    _mounted = true;
    if (widget.dishId != null) {
      _fetchDishData();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _nameController.dispose();
    _descController.dispose();
    _stockController.dispose();
    _prepTimeController.dispose();
    _tagsController.dispose();
    _ingredientsController.dispose();
    _expirationDateController.dispose();
    _dailyQuantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchDishData() async {
    if (widget.dishId == null) return;

    if (_mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final dish = await _dishService.getDishById(widget.dishId!);
      if (dish != null) {
        _initializeForm(dish);
      } else {
        if (mounted) {
          _showErrorSnackBar('edit_dish.dish_not_found'.tr());
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      DebugHelper.log('Fetch dish error: $e');
      if (mounted) {
        _showErrorSnackBar('edit_dish.error_loading_dish'.tr());
        Navigator.of(context).pop();
      }
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeForm(Dish dish) {
    // Basic fields
    _nameController.text = dish.name;
    _descController.text = dish.description;
    _stockController.text = dish.stock.toString();
    _prepTimeController.text = dish.preparationTimeMins.toString();

    // Dropdown fields - validate values exist in lists
    _selectedCategory =
        _categories.contains(dish.category) ? dish.category : 'fresh_food';
    _selectedType = _types.contains(dish.availabilityType)
        ? dish.availabilityType
        : 'donate'; // Changed from 'sell' - sell feature disabled

    // Boolean fields
    _deliveryAvailable = dish.deliveryAvailable;
    _pickupAvailable = dish.pickupAvailable;
    _isFeatured = dish.isFeatured;
    _isRecommended = dish.isRecommended;

    // List fields
    _tags.addAll(dish.tags);
    _ingredients.addAll(dish.ingredients);

    // Image URLs - initialize from existing dish
    _imageUrls = List.from(dish.imageUrls);

    // Dietary options
    final dietaryOptions = dish.dietaryOptions ?? {};
    _isHalal = dietaryOptions['halal'] ?? false;
    _isVegan = dietaryOptions['vegan'] ?? false;
    _isVegetarian = dietaryOptions['vegetarian'] ?? false;

    // Allergies
    final allergies = dish.allergies ?? {};
    _allergies = Map.from(_allergies)..addAll(allergies);

    // Location - Phase 2B: Load from exactLocation if available
    if (dish.exactLocation != null) {
      _structuredAddress = dish.exactLocation;
    }

    // Expiration Date
    final expirationDate = dish.expirationDate;
    if (expirationDate != null) {
      final date = expirationDate.toDate();
      _expirationDateController.text = _formatDate(date);
    }

    // Daily refresh mode
    _isDaily = dish.isDaily;
    if (dish.dailyQuantity > 0) {
      _dailyQuantityController.text = dish.dailyQuantity.toString();
    }
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && _mounted) {
      setState(() {
        _expirationDateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_mounted) {
      setState(() => _isSaving = true);
    }

    try {
      // Upload new images first (if any)
      List<String> uploadedImageUrls = [];
      if (_newLocalImages.isNotEmpty) {
        uploadedImageUrls = await _uploadImages(_newLocalImages);
      }

      // Merge existing image URLs with newly uploaded ones
      final allImageUrls = [..._imageUrls, ...uploadedImageUrls];

      // Prepare data
      final dietaryOptions = {
        'halal': _isHalal,
        'vegan': _isVegan,
        'vegetarian': _isVegetarian,
      };

      final dietaryTags = <String>[];
      if (_isHalal) dietaryTags.add('halal');
      if (_isVegan) dietaryTags.add('vegan');
      if (_isVegetarian) dietaryTags.add('vegetarian');

      // Parse expiration date
      Timestamp? expirationDate;
      if (_expirationDateController.text.isNotEmpty) {
        final parts = _expirationDateController.text.split('/');
        if (parts.length == 3) {
          try {
            final date = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
            expirationDate = Timestamp.fromDate(date);
          } catch (e) {
            DebugHelper.log('Error parsing expiration date: $e');
          }
        }
      }

      // Prepare location data - Phase 2B: Use structured address
      Map<String, dynamic> locationData = {};

      if (_structuredAddress != null) {
        locationData = {
          'city': _structuredAddress!.city,
          'postalCode': _structuredAddress!.postalCode,
          'country': _structuredAddress!.country,
          'countryCode': _structuredAddress!.countryCode,
          'formattedAddress': _structuredAddress!.formattedAddress,
          'latitude': _structuredAddress!.coordinates.latitude,
          'longitude': _structuredAddress!.coordinates.longitude,
        };
      }

      // Create dish data
      final user = _auth.currentUser;
      if (user == null)
        throw Exception('edit_dish.user_not_authenticated'.tr());

      final dishData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'quantityAvailable': int.tryParse(_stockController.text) ?? 0,
        'preparationTimeMins': int.tryParse(_prepTimeController.text) ?? 30,
        'category': _selectedCategory,
        'availabilityType': _selectedType,
        'currency': 'EUR',
        'tags': _tags,
        'ingredients': _ingredients,
        'dietaryOptions': dietaryOptions,
        'dietaryTags': [..._tags, ...dietaryTags],
        'allergies': _allergies,
        'deliveryAvailable': _deliveryAvailable,
        'pickupAvailable': _pickupAvailable,
        'isFeatured': _isFeatured,
        'isRecommended': _isRecommended,
        'imageURLs': allImageUrls,

        // Phase 2B: New structured address (priority)
        if (_structuredAddress != null)
          'exactLocation': _structuredAddress!.toFirestore(),

        'location': locationData,
        'updatedAt': FieldValue.serverTimestamp(),
        'isDaily': _isDaily,
        if (_isDaily)
          'dailyQuantity': int.tryParse(_dailyQuantityController.text) ??
              int.tryParse(_stockController.text) ??
              0,
        if (expirationDate != null) 'expirationDate': expirationDate,
      };

      if (widget.dishId != null) {
        // For updates, also clear dailyQuantity when not daily
        if (!_isDaily) {
          dishData['dailyQuantity'] = FieldValue.delete();
        }
        await _firestore
            .collection('dishes')
            .doc(widget.dishId!)
            .update(dishData);
      } else {
        final newDishData = {
          ...dishData,
          'chefID': user.uid,
          'chefName': user.displayName ?? 'edit_dish.chef'.tr(),
          'createdAt': FieldValue.serverTimestamp(),
          'ratingsAverage': 0.0,
          'ratingsCount': 0,
          'reservedCount': 0,
          'distance': 0.0,
        };
        await _firestore.collection('dishes').add(newDishData);
      }

      if (mounted) {
        _showSuccessSnackBar(widget.dishId != null
            ? 'edit_dish.dish_updated_successfully'.tr()
            : 'edit_dish.dish_created_successfully'.tr());
        Navigator.of(context).pop();
      }
    } catch (e) {
      DebugHelper.log('Save error: $e');
      if (_mounted) {
        _showErrorSnackBar('edit_dish.failed_to_save_dish'.tr());
      }
    } finally {
      if (_mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _confirmDelete() {
    if (widget.dishId == null) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.warning_2, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              Text('edit_dish.confirm_delete_title'.tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('edit_dish.confirm_delete_message'.tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('edit_dish.cancel_action'.tr()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          await _firestore
                              .collection('dishes')
                              .doc(widget.dishId!)
                              .delete();
                          if (mounted) Navigator.pop(context);
                        } catch (e) {
                          DebugHelper.log('Delete error: $e');
                          if (_mounted) {
                            _showErrorSnackBar(
                                'edit_dish.failed_delete_dish'.tr());
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('edit_dish.delete_action'.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addTag() {
    final tag = _tagsController.text.trim();
    if (tag.isNotEmpty && _mounted) {
      setState(() {
        _tags.add(tag);
        _tagsController.clear();
      });
    }
  }

  void _removeTag(int index) {
    if (_mounted) {
      setState(() => _tags.removeAt(index));
    }
  }

  void _addIngredient() {
    final ingredient = _ingredientsController.text.trim();
    if (ingredient.isNotEmpty && _mounted) {
      setState(() {
        _ingredients.add(ingredient);
        _ingredientsController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    if (_mounted) {
      setState(() => _ingredients.removeAt(index));
    }
  }

  // Image handling methods
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      final totalImages =
          _imageUrls.length + _newLocalImages.length + images.length;
      if (totalImages > 6) {
        _showErrorSnackBar('Maximum 6 images allowed'.tr());
        return;
      }

      if (_mounted) {
        setState(() {
          _newLocalImages.addAll(images);
        });
      }
    } on PlatformException catch (e) {
      _showErrorSnackBar('${'failed_pick_images'.tr()} ${e.message}');
    } catch (e) {
      _showErrorSnackBar('failed_pick_images_generic'.tr());
    }
  }

  void _removeExistingImage(int index) {
    if (_mounted) {
      setState(() {
        _imageUrls.removeAt(index);
      });
    }
  }

  void _removeNewImage(int index) {
    if (_mounted) {
      setState(() {
        _newLocalImages.removeAt(index);
      });
    }
  }

  Future<List<String>> _uploadImages(List<XFile> images) async {
    List<String> imageUrls = [];

    for (var image in images) {
      try {
        final file = File(image.path);
        if (await file.exists()) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('dishes')
              .child('${DateTime.now().millisecondsSinceEpoch}_${image.name}');

          await ref.putFile(file);
          final url = await ref.getDownloadURL();
          imageUrls.add(url);
        }
      } catch (e) {
        DebugHelper.log('Error uploading image ${image.name}: $e');
        // Continue with other images even if one fails
      }
    }

    return imageUrls;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mainColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 25,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(0),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSection(
      {required String title, required Widget child, String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.tr(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle.tr(),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ],
          ),
        ),
        _buildGlassCard(padding: const EdgeInsets.all(20), child: child),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChipField({
    required String label,
    required List<String> items,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          onFieldSubmitted: (_) => onAdd(),
          decoration: InputDecoration(
            labelText: label.tr(),
            hintText: hintText?.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: mainColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: IconButton(
              icon: Icon(Iconsax.add, color: mainColor),
              onPressed: onAdd,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .asMap()
                .entries
                .map((e) => Chip(
                      label: Text(e.value),
                      deleteIcon: Icon(Iconsax.close_circle,
                          size: 16, color: mainColor),
                      onDeleted: () => onRemove(e.key),
                      backgroundColor: mainColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildToggleOption(
      String title, String subtitle, bool value, Function(bool) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        title: Text(title.tr(),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            Text(subtitle.tr(), style: TextStyle(color: Colors.grey.shade600)),
        value: value,
        onChanged: onChanged,
        activeColor: mainColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildDietaryChip(
      String label, bool selected, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label.tr()),
      selected: selected,
      onSelected: onChanged,
      selectedColor: mainColor.withValues(alpha: 0.2),
      checkmarkColor: mainColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildAllergyChip(
      String label, bool selected, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label.tr()),
      selected: selected,
      onSelected: onChanged,
      selectedColor: mainColor.withValues(alpha: 0.2),
      checkmarkColor: mainColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected ? mainColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageUrls.isEmpty && _newLocalImages.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Center(
          child: Text(
            'edit_dish.no_images'.tr(),
            style: const TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imageUrls.length + _newLocalImages.length,
        itemBuilder: (context, index) {
          final isNewImage = index >= _imageUrls.length;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: isNewImage
                          ? FileImage(File(
                              _newLocalImages[index - _imageUrls.length].path))
                          : NetworkImage(_imageUrls[index]) as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      if (isNewImage) {
                        _removeNewImage(index - _imageUrls.length);
                      } else {
                        _removeExistingImage(index);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.dishId != null
              ? 'edit_dish.edit_dish'.tr()
              : 'edit_dish.add_dish'.tr()),
          backgroundColor: backgroundColor,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
            widget.dishId != null
                ? 'edit_dish.edit_dish'.tr()
                : 'edit_dish.add_dish'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: widget.dishId != null
            ? [
                IconButton(
                  icon: Icon(Iconsax.trash, color: Colors.red.shade400),
                  onPressed: _confirmDelete,
                ),
              ]
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Basic Information
              _buildSection(
                title: 'edit_dish.basic_information',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: _buildInputDecoration('edit_dish.dish_name'),
                      validator: (value) => value!.isEmpty
                          ? 'edit_dish.dish_name_required'.tr()
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration:
                          _buildInputDecoration('edit_dish.description'),
                      maxLines: 3,
                      validator: (value) => value!.isEmpty
                          ? 'edit_dish.description_required'.tr()
                          : null,
                    ),
                  ],
                ),
              ),

              // Images Section
              _buildSection(
                title: 'edit_dish.images',
                subtitle: 'edit_dish.images_subtitle'.tr(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImages,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: mainColor.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo,
                                    color: mainColor, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  'edit_dish.add_photo'.tr(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mainColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Text(
                                  '${_imageUrls.length + _newLocalImages.length}/6',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildImagePreview(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Stock Section (Price field removed - all dishes are donation-based)
              _buildSection(
                title: 'edit_dish.pricing_stock',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stockController,
                            decoration:
                                _buildInputDecoration('edit_dish.quantity'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value!.isEmpty)
                                return 'edit_dish.quantity_required'.tr();
                              if (int.tryParse(value) == null) {
                                return 'edit_dish.invalid_quantity'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _prepTimeController,
                            decoration: _buildInputDecoration(
                                'edit_dish.prep_time_mins'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value!.isEmpty) {
                                return 'edit_dish.prep_time_required'.tr();
                              }
                              if (int.tryParse(value) == null) {
                                return 'edit_dish.invalid_prep_time'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Daily refresh toggle
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Iconsax.refresh, color: mainColor),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'daily_refresh'.tr(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'daily_refresh_hint'.tr(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isDaily,
                                activeColor: mainColor,
                                onChanged: (value) {
                                  setState(() {
                                    _isDaily = value;
                                    if (value &&
                                        _dailyQuantityController.text.isEmpty) {
                                      _dailyQuantityController.text =
                                          _stockController.text;
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                          if (_isDaily) ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _dailyQuantityController,
                              decoration:
                                  _buildInputDecoration('daily_quantity'),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (!_isDaily) return null;
                                if (value == null ||
                                    value.isEmpty ||
                                    int.tryParse(value) == null) {
                                  return 'edit_dish.invalid_quantity'.tr();
                                }
                                return null;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _expirationDateController,
                      readOnly: true,
                      onTap: _selectExpirationDate,
                      decoration: _buildInputDecoration(
                              'edit_dish.expiration_date_optional')
                          .copyWith(
                        suffixIcon: Icon(Iconsax.calendar_1, color: mainColor),
                      ),
                    ),
                  ],
                ),
              ),

              // Categories & Type
              _buildSection(
                title: 'edit_dish.categories',
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: _categories
                          .map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category.replaceAll('_', ' ')),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedCategory = value!),
                      decoration: _buildInputDecoration('edit_dish.category'),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      items: _types
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type == 'sell'
                                    ? 'edit_dish.sell'.tr()
                                    : type == 'donate'
                                        ? 'edit_dish.donate'.tr()
                                        : 'edit_dish.exchange'.tr()),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedType = value!),
                      decoration: _buildInputDecoration('edit_dish.type'),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ],
                ),
              ),

              // Delivery Options
              _buildSection(
                title: 'edit_dish.delivery_options',
                child: Column(
                  children: [
                    _buildToggleOption(
                      'edit_dish.delivery_available',
                      'edit_dish.allow_delivery',
                      _deliveryAvailable,
                      (value) => setState(() => _deliveryAvailable = value),
                    ),
                    const SizedBox(height: 12),
                    _buildToggleOption(
                      'edit_dish.pickup_available',
                      'edit_dish.allow_pickup',
                      _pickupAvailable,
                      (value) => setState(() => _pickupAvailable = value),
                    ),
                  ],
                ),
              ),

              // Dietary Preferences
              _buildSection(
                title: 'edit_dish.dietary_preferences',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildDietaryChip('edit_dish.halal', _isHalal,
                        (val) => setState(() => _isHalal = val)),
                    _buildDietaryChip('edit_dish.vegan', _isVegan,
                        (val) => setState(() => _isVegan = val)),
                    _buildDietaryChip('edit_dish.vegetarian', _isVegetarian,
                        (val) => setState(() => _isVegetarian = val)),
                  ],
                ),
              ),

              // Allergies
              _buildSection(
                title: 'edit_dish.allergies',
                subtitle: 'edit_dish.mark_allergens',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _allergies.entries
                      .map((entry) => _buildAllergyChip(entry.key, entry.value,
                          (v) => setState(() => _allergies[entry.key] = v)))
                      .toList(),
                ),
              ),

              // Tags
              _buildSection(
                title: 'edit_dish.tags',
                child: _buildChipField(
                  label: 'edit_dish.add_tag',
                  items: _tags,
                  controller: _tagsController,
                  onAdd: _addTag,
                  onRemove: _removeTag,
                  hintText: 'edit_dish.enter_tags',
                ),
              ),

              // Ingredients
              _buildSection(
                title: 'edit_dish.ingredients',
                child: _buildChipField(
                  label: 'edit_dish.add_ingredient',
                  items: _ingredients,
                  controller: _ingredientsController,
                  onAdd: _addIngredient,
                  onRemove: _removeIngredient,
                  hintText: 'edit_dish.enter_ingredients',
                ),
              ),

              // Location - Phase 2B: Use LocationSelectorWidget
              _buildSection(
                title: 'edit_dish.location',
                child: LocationSelectorWidget(
                  initialAddress: _structuredAddress,
                  onAddressComplete: (address) {
                    setState(() {
                      _structuredAddress = address;
                    });
                  },
                ),
              ),

              // Save Button
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mainColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: mainColor.withValues(alpha: 0.3),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.dishId != null
                              ? 'edit_dish.save_changes'.tr()
                              : 'edit_dish.create_dish'.tr(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label.tr(),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: mainColor, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }
}
