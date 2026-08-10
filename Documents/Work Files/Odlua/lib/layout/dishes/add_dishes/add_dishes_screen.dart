import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:odlua/app.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/location/controllers/location_controller.dart';
import 'package:odlua/utils/location/services/location_autocomplete_service.dart';
import 'package:odlua/utils/location/services/geoapify_service.dart';
import 'package:odlua/utils/location/services/google_places_service.dart';
import 'package:odlua/utils/location/location_config.dart';
import 'package:odlua/utils/location/widgets/location_autocomplete_field.dart';
import '../../../utils/theme/custom_themes/main_colors.dart' as AppColors;

class AddDishesScreen extends StatefulWidget {
  const AddDishesScreen({super.key});

  @override
  State<AddDishesScreen> createState() => _AddDishesScreenState();
}

class _AddDishesScreenState extends State<AddDishesScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _expirationController = TextEditingController();

  String _selectedCategory = 'dinner';
  String _selectedAvailabilityType = 'sell';
  String _selectedCurrency = 'EUR';

  // Dietary options
  bool _isHalal = false;
  bool _isVegan = false;
  bool _isVegetarian = false;

  // Allergy options
  bool _hasPeanuts = false;
  bool _hasTreeNuts = false;
  bool _hasDairy = false;
  bool _hasGluten = false;
  bool _hasShellfish = false;
  bool _hasEggs = false;
  bool _hasSoy = false;
  bool _hasFish = false;
  bool _hasSesame = false;
  bool _hasMustard = false;
  bool _hasSulfites = false;
  bool _hasCelery = false;
  bool _hasLupin = false;
  bool _hasMolluscs = false;

  bool _deliveryAvailable = true;
  bool _pickupAvailable = true;

  final List<String> _tags = [];
  final List<String> _ingredients = [];

  LocationController? _locationController;

  bool _isUploading = false;

  final List<Map<String, String>> _categories = [
    {'value': 'breakfast', 'display': 'breakfast'},
    {'value': 'lunch', 'display': 'lunch'},
    {'value': 'dinner', 'display': 'dinner'},
    {'value': 'dessert', 'display': 'dessert'},
    {'value': 'fresh_food', 'display': 'fresh_food'},
    {'value': 'appetizer', 'display': 'appetizer'},
  ];

  final List<Map<String, String>> _availabilityTypes = [
    {'value': 'sell', 'display': 'sell'},
    {'value': 'donate', 'display': 'donate'},
    {'value': 'exchange', 'display': 'exchange'},
    {'value': 'preorder', 'display': 'preorder'},
  ];

  final List<Map<String, String>> _currencies = [
    {'value': 'EUR', 'display': 'EUR'},
    {'value': 'USD', 'display': 'USD'},
    {'value': 'GBP', 'display': 'GBP'},
    {'value': 'EGP', 'display': 'EGP'},
  ];

  @override
  void initState() {
    super.initState();
    _initLocationAutocompleteAsync();
    _quantityController.text = '1';
  }

  Future<void> _initLocationAutocompleteAsync() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      
      final geoapifyKey = await LocationConfig.geoapifyKey();
      final googlePlacesKey = await LocationConfig.googlePlacesKey();

      if (geoapifyKey.isEmpty && googlePlacesKey.isEmpty) {
        DebugHelper.log('Warning: No location API keys configured');
        return;
      }

      final geoapifyService = geoapifyKey.isNotEmpty 
          ? GeoapifyService(apiKey: geoapifyKey)
          : null;
      final googleService = googlePlacesKey.isNotEmpty
          ? GooglePlacesService(apiKey: googlePlacesKey)
          : null;

      if (mounted) {
        setState(() {
          _locationController = LocationController(
            service: LocationAutocompleteService(
              geoapify: geoapifyService,
              google: googleService,
            ),
          );
        });
      }
    } catch (e) {
      DebugHelper.log('Error initializing location autocomplete: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _tagsController.dispose();
    _prepTimeController.dispose();
    _ingredientsController.dispose();
    _expirationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (images.isEmpty) return;

      if (images.length + _selectedImages.length > 5) {
        _showErrorSnackBar('max_images_error'.tr());
        return;
      }

      setState(() {
        _selectedImages.addAll(images);
      });
    } on PlatformException catch (e) {
      _showErrorSnackBar('${'failed_pick_images'.tr()}${e.message}');
    } catch (e) {
      _showErrorSnackBar('failed_pick_images_generic'.tr());
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _addTag() {
    if (_tagsController.text.trim().isNotEmpty) {
      setState(() {
        _tags.add(_tagsController.text.trim());
        _tagsController.clear();
      });
    }
  }

  void _removeTag(int index) {
    setState(() {
      _tags.removeAt(index);
    });
  }

  void _addIngredient() {
    if (_ingredientsController.text.trim().isNotEmpty) {
      setState(() {
        _ingredients.add(_ingredientsController.text.trim());
        _ingredientsController.clear();
      });
    }
  }

  void _removeIngredient(int index) {
    setState(() {
      _ingredients.removeAt(index);
    });
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

  Future<String?> _getChefName(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        if (userData['displayName'] != null &&
            userData['displayName'].toString().isNotEmpty) {
          return userData['displayName'];
        }
        if (userData['name'] != null &&
            userData['name'].toString().isNotEmpty) {
          return userData['name'];
        }
        if (userData['email'] != null) {
          final email = userData['email'].toString();
          return email.split('@').first;
        }
      }
    } catch (e) {
      DebugHelper.log('Error getting chef name: $e');
    }
    return 'Unknown Chef'.tr();
  }

  Future<void> _submitProduct() async {
    // Validate form first
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('please_fill_required_fields'.tr());
      return;
    }

    // Validate images are selected
    if (_selectedImages.isEmpty) {
      _showErrorSnackBar('images_required'.tr());
      return;
    }

    // Validate at least 5 ingredients
    if (_ingredients.length < 3) {
      _showErrorSnackBar('min_5_ingredients_required'.tr());
      return;
    }

    // Validate location
    if (_locationController?.selected.value == null) {
      _showErrorSnackBar('please_select_location'.tr());
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Get current user - must be authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showErrorSnackBar('authentication_required'.tr());
        setState(() => _isUploading = false);
        return;
      }

      // Upload images safely
      List<String> imageUrls = await _uploadImages(_selectedImages);

      // Get chef name safely
      final chefName = await _getChefName(user.uid);

      // Parse numeric values safely
      double price;
      try {
        price = double.parse(
            _priceController.text.isEmpty ? '0' : _priceController.text);
      } catch (e) {
        price = 0.0;
      }

      int quantity;
      try {
        quantity = int.parse(_quantityController.text);
      } catch (e) {
        quantity = 1;
      }

      int prepTime;
      try {
        prepTime = _prepTimeController.text.isEmpty
            ? 0
            : int.parse(_prepTimeController.text);
      } catch (e) {
        prepTime = 0;
      }

      // Parse expiration date safely
      Timestamp? expirationDate;
      if (_expirationController.text.isNotEmpty) {
        try {
          final date =
              DateFormat('yyyy-MM-dd').parse(_expirationController.text);
          expirationDate = Timestamp.fromDate(date);
        } catch (e) {
          DebugHelper.log('Error parsing expiration date: $e');
          // expirationDate remains null
        }
      }

      // Create dish data with nested location
      final selectedLocation = _locationController!.selected.value!;
      final dishData = {
        "chefID": user.uid,
        "chefName": chefName,
        "currency": _selectedCurrency,
        "name": _nameController.text.trim(),
        "description": _descController.text.trim(),
        "ingredients": _ingredients,
        "imageURLs": imageUrls,
        "price": price,
        "availabilityType": _selectedAvailabilityType,
        "category": _selectedCategory,
        "tags": _tags,
        "location": {
          "city": selectedLocation.city,
          "postalCode": selectedLocation.postalCode,
          "country": selectedLocation.country,
          "countryCode": selectedLocation.countryCode,
          "formattedAddress": selectedLocation.formattedAddress,
          "latitude": selectedLocation.latitude,
          "longitude": selectedLocation.longitude,
        },
        // Legacy top-level fields for backward compatibility
        "city": selectedLocation.city,
        "country": selectedLocation.country,
        "lat": selectedLocation.latitude,
        "lng": selectedLocation.longitude,
        "distanceKM": 0,
        "stock": quantity, // New: primary stock field
        "reservedCount": 0, // New: reservation counter
        "quantityAvailable": quantity, // Keep for backward compatibility
        "deliveryAvailable": _deliveryAvailable,
        "pickupAvailable": _pickupAvailable,
        "preparationTimeMins": prepTime,
        "ratingsAverage": 0.0,
        "ratingsCount": 0,
        "createdAt": FieldValue.serverTimestamp(),
        if (expirationDate != null) "expirationDate": expirationDate,
        "dietaryOptions": {
          "halal": _isHalal,
          "vegan": _isVegan,
          "vegetarian": _isVegetarian,
        },
        "allergies": {
          "peanuts": _hasPeanuts,
          "tree_nuts": _hasTreeNuts,
          "dairy": _hasDairy,
          "gluten": _hasGluten,
          "shellfish": _hasShellfish,
          "eggs": _hasEggs,
          "soy": _hasSoy,
          "fish": _hasFish,
          "sesame": _hasSesame,
          "mustard": _hasMustard,
          "sulfites": _hasSulfites,
          "celery": _hasCelery,
          "lupin": _hasLupin,
          "molluscs": _hasMolluscs,
        }
      };

      // Save to Firestore
      await FirebaseFirestore.instance.collection('dishes').add(dishData);

      _showSuccessSnackBar('product_added_success'.tr());

      // Wait a moment for user to see success message, then navigate back
      await Future.delayed(const Duration(seconds: 1));

      // Check if we can pop before attempting to navigate
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        // If we can't pop, navigate to a safe screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OdluaLayout(),
          ),
        );
      }
    } catch (e) {
      DebugHelper.log('Error submitting dish: $e');

      String errorMessage = 'upload_failed'.tr();
      if (e is FirebaseException) {
        errorMessage = 'firestore_error'.tr();
      } else if (e is PlatformException) {
        errorMessage = 'platform_error'.tr();
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _selectExpirationDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.mainColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogTheme: DialogTheme(
              backgroundColor: AppColors.backgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _expirationController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: Text('add_product'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: AppColors.backgroundColor,
        elevation: 0.5,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('product_images'.tr()),
              const SizedBox(height: 16),
              _buildImagePicker(),
              const SizedBox(height: 32),
              _buildSectionTitle('basic_information'.tr()),
              const SizedBox(height: 20),
              _buildWhiteCard([
                _buildFormField(
                  controller: _nameController,
                  label: 'dish_name'.tr(),
                  icon: Icons.fastfood_outlined,
                  validator: (value) =>
                      value!.isEmpty ? 'please_enter_dish_name'.tr() : null,
                ),
                const SizedBox(height: 24),
                _buildFormField(
                  controller: _descController,
                  label: 'description'.tr(),
                  icon: Icons.description_outlined,
                  maxLines: 3,
                  validator: (value) =>
                      value!.isEmpty ? 'please_enter_description'.tr() : null,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildDropdown(
                        value: _selectedCategory,
                        items: _categories,
                        label: 'category'.tr(),
                        onChanged: (value) =>
                            setState(() => _selectedCategory = value!),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildDropdown(
                        value: _selectedAvailabilityType,
                        items: _availabilityTypes,
                        label: 'availability_type'.tr(),
                        onChanged: (value) {
                          setState(() {
                            _selectedAvailabilityType = value!;
                            if (value == 'donate') _priceController.text = '0';
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildFormField(
                        controller: _priceController,
                        label: 'price'.tr(),
                        icon: Icons.attach_money_outlined,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        enabled: _selectedAvailabilityType != 'donate',
                        validator: (value) {
                          if (_selectedAvailabilityType != 'donate' &&
                              (value == null ||
                                  value.isEmpty ||
                                  double.tryParse(value) == null)) {
                            return 'please_enter_valid_price'.tr();
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 1,
                      child: _buildDropdown(
                        value: _selectedCurrency,
                        items: _currencies,
                        label: 'currency'.tr(),
                        onChanged: (value) =>
                            setState(() => _selectedCurrency = value!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        controller: _quantityController,
                        label: 'quantity'.tr(),
                        icon: Icons.format_list_numbered_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null ||
                                value.isEmpty ||
                                int.tryParse(value) == null
                            ? 'please_enter_valid_quantity'.tr()
                            : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: _buildFormField(
                        controller: _prepTimeController,
                        label: 'prep_time_mins'.tr(),
                        icon: Icons.timer_outlined,
                        keyboardType: TextInputType.number,
                        validator: (value) => value == null ||
                                value.isEmpty ||
                                int.tryParse(value) == null
                            ? 'please_enter_valid_prep_time'.tr()
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _expirationController,
                        readOnly: true,
                        onTap: _selectExpirationDate,
                        decoration: InputDecoration(
                          labelText: 'expiration_date'.tr(),
                          prefixIcon: Icon(Icons.calendar_today,
                              color: AppColors.mainColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month),
                            onPressed: _selectExpirationDate,
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundColor,
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'please_select_expiration'.tr()
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Delivery and Pickup Options - Updated to selector style
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'delivery_options'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDeliveryOptionCard(
                            'delivery_available'.tr(),
                            _deliveryAvailable,
                            (value) =>
                                setState(() => _deliveryAvailable = value!),
                            Icons.delivery_dining_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDeliveryOptionCard(
                            'pickup_available'.tr(),
                            _pickupAvailable,
                            (value) =>
                                setState(() => _pickupAvailable = value!),
                            Icons.storefront_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle('dietary_options'.tr()),
              const SizedBox(height: 16),
              _buildWhiteCard([
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildDietaryOptionCard('halal'.tr(), _isHalal,
                        (value) => setState(() => _isHalal = value!)),
                    _buildDietaryOptionCard('vegan'.tr(), _isVegan,
                        (value) => setState(() => _isVegan = value!)),
                    _buildDietaryOptionCard('vegetarian'.tr(), _isVegetarian,
                        (value) => setState(() => _isVegetarian = value!)),
                  ],
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle('allergies'.tr()),
              const SizedBox(height: 16),
              _buildWhiteCard([
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildAllergyOptionCard('peanuts'.tr(), _hasPeanuts,
                        (value) => setState(() => _hasPeanuts = value!)),
                    _buildAllergyOptionCard('tree_nuts'.tr(), _hasTreeNuts,
                        (value) => setState(() => _hasTreeNuts = value!)),
                    _buildAllergyOptionCard('dairy'.tr(), _hasDairy,
                        (value) => setState(() => _hasDairy = value!)),
                    _buildAllergyOptionCard('gluten'.tr(), _hasGluten,
                        (value) => setState(() => _hasGluten = value!)),
                    _buildAllergyOptionCard('shellfish'.tr(), _hasShellfish,
                        (value) => setState(() => _hasShellfish = value!)),
                    _buildAllergyOptionCard('eggs'.tr(), _hasEggs,
                        (value) => setState(() => _hasEggs = value!)),
                    _buildAllergyOptionCard('soy'.tr(), _hasSoy,
                        (value) => setState(() => _hasSoy = value!)),
                    _buildAllergyOptionCard('fish'.tr(), _hasFish,
                        (value) => setState(() => _hasFish = value!)),
                    _buildAllergyOptionCard('sesame'.tr(), _hasSesame,
                        (value) => setState(() => _hasSesame = value!)),
                    _buildAllergyOptionCard('mustard'.tr(), _hasMustard,
                        (value) => setState(() => _hasMustard = value!)),
                    _buildAllergyOptionCard('sulfites'.tr(), _hasSulfites,
                        (value) => setState(() => _hasSulfites = value!)),
                    _buildAllergyOptionCard('celery'.tr(), _hasCelery,
                        (value) => setState(() => _hasCelery = value!)),
                    _buildAllergyOptionCard('lupin'.tr(), _hasLupin,
                        (value) => setState(() => _hasLupin = value!)),
                    _buildAllergyOptionCard('molluscs'.tr(), _hasMolluscs,
                        (value) => setState(() => _hasMolluscs = value!)),
                  ],
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle('ingredients'.tr()),
              const SizedBox(height: 16),
              _buildWhiteCard([
                TextField(
                  controller: _ingredientsController,
                  decoration: InputDecoration(
                    hintText: 'add_ingredients_hint'.tr(),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add, color: AppColors.mainColor),
                      onPressed: _addIngredient,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: AppColors.backgroundColor,
                  ),
                  onSubmitted: (_) => _addIngredient(),
                ),
                const SizedBox(height: 16),
                if (_ingredients.isNotEmpty) ...[
                  Text('ingredients_list'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _ingredients.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeIngredient(entry.key),
                        backgroundColor: AppColors.mainColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_ingredients.length < 5) ...[
                  const SizedBox(height: 12),
                  Text(
                    'min_5_ingredients_required'.tr(),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle('tags'.tr()),
              const SizedBox(height: 16),
              _buildWhiteCard([
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'tags_explanation'.tr(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagsController,
                      decoration: InputDecoration(
                        hintText: 'add_tags_hint'.tr(),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.add, color: AppColors.mainColor),
                          onPressed: _addTag,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: AppColors.backgroundColor,
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _tags.asMap().entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => _removeTag(entry.key),
                        backgroundColor: AppColors.mainColor.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      );
                    }).toList(),
                  ),
                ],
              ]),
              const SizedBox(height: 32),
              _buildSectionTitle('location'.tr()),
              const SizedBox(height: 16),
              _buildWhiteCard([
                if (_locationController != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocationAutocompleteField(
                        controller: _locationController!,
                        onSelected: (location) {
                          // Location selected
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_locationController!.selected.value != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.mainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.mainColor.withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.location_on,
                                      color: AppColors.mainColor, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _locationController!.selected.value!
                                          .formattedAddress,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${'latitude'.tr()}: ${_locationController!.selected.value!.latitude.toStringAsFixed(6)}, ${'longitude'.tr()}: ${_locationController!.selected.value!.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          'upload_dish'.tr(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
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

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
      );

  Widget _buildWhiteCard(List<Widget> children) => Container(
        width: double.infinity,
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
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      );

  Widget _buildImagePicker() => SizedBox(
        height: 140,
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.mainColor.withOpacity(0.3), width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo,
                        color: AppColors.mainColor, size: 36),
                    const SizedBox(height: 12),
                    Text('add_photos'.tr(),
                        style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mainColor,
                            fontWeight: FontWeight.w600)),
                    Text('${_selectedImages.length}/5',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _selectedImages.isEmpty
                  ? Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.grey.shade300, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          'no_images_selected'.tr(),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _selectedImages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: Stack(
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: FileImage(
                                        File(_selectedImages[index].path)),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      );

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.mainColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.mainColor, width: 2),
        ),
        filled: true,
        fillColor: AppColors.backgroundColor,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<Map<String, String>> items,
    required String label,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.mainColor, width: 2),
        ),
        filled: true,
        fillColor: AppColors.backgroundColor,
      ),
      items: items.map((Map<String, String> item) {
        return DropdownMenuItem<String>(
          value: item['value'],
          child:
              Text(item['display']!.tr(), style: const TextStyle(fontSize: 16)),
        );
      }).toList(),
      onChanged: onChanged,
      borderRadius: BorderRadius.circular(16),
    );
  }

  // Updated selector-style cards for all options
  Widget _buildDeliveryOptionCard(
    String label,
    bool isSelected,
    void Function(bool?)? onChanged,
    IconData icon,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.mainColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.mainColor : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.mainColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged?.call(!isSelected),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? Colors.white : AppColors.mainColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDietaryOptionCard(
    String label,
    bool isSelected,
    void Function(bool?)? onChanged,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.mainColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.mainColor : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.mainColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged?.call(!isSelected),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 20,
                          key: ValueKey('selected'),
                        )
                      : Icon(
                          Icons.circle_outlined,
                          color: Colors.grey.shade400,
                          size: 20,
                          key: const ValueKey('not-selected'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllergyOptionCard(
    String label,
    bool isSelected,
    void Function(bool?)? onChanged,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.mainColor : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.mainColor : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.mainColor.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onChanged?.call(!isSelected),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                          key: ValueKey('selected'),
                        )
                      : Icon(
                          Icons.circle_outlined,
                          color: Colors.grey.shade400,
                          size: 18,
                          key: const ValueKey('not-selected'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
