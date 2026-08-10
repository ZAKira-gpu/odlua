import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:odlua/utils/models/dish_model.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class EditDishScreen extends StatefulWidget {
  final String? dishId;

  const EditDishScreen({super.key, this.dishId});

  @override
  State<EditDishScreen> createState() => _EditDishScreenState();
}

class _EditDishScreenState extends State<EditDishScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DishService _dishService = DishService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _expirationDateController =
      TextEditingController();

  // State variables
  String _locationAddress = 'edit_dish.fetching_location'.tr();
  double? _locationLat;
  double? _locationLng;
  String _selectedCategory = 'fresh_food';
  String _selectedType = 'sell';
  String _currency = 'EUR';
  bool _isSaving = false;
  bool _isLoading = false;
  bool _mounted = true;

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
    'fresh_food',
    'main_course',
    'dessert',
    'appetizer',
    'beverage',
    'salad',
    'soup',
    'breakfast',
    'snack',
    'other'
  ];
  final List<String> _types = ['sell', 'donate', 'exchange'];
  final List<String> _currencies = ['EUR', 'USD', 'GBP', 'JPY', 'CAD'];

  @override
  void initState() {
    super.initState();
    _mounted = true;
    _getCurrentLocation();
    if (widget.dishId != null) {
      _fetchDishData();
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _prepTimeController.dispose();
    _tagsController.dispose();
    _ingredientsController.dispose();
    _expirationDateController.dispose();
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
        if (_mounted) {
          _showErrorSnackBar('edit_dish.dish_not_found'.tr());
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      DebugHelper.log('Fetch dish error: $e');
      if (_mounted) {
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
    _priceController.text = dish.price.toString();
    _stockController.text = dish.stock.toString();
    _prepTimeController.text = dish.preparationTimeMins.toString();

    // Dropdown fields
    _selectedCategory = dish.category;
    _selectedType = dish.availabilityType;
    _currency = dish.currency;

    // Boolean fields
    _deliveryAvailable = dish.deliveryAvailable;
    _pickupAvailable = dish.pickupAvailable;
    _isFeatured = dish.isFeatured;
    _isRecommended = dish.isRecommended;

    // List fields
    _tags.addAll(dish.tags);
    _ingredients.addAll(dish.ingredients);

    // Dietary options
    final dietaryOptions = dish.dietaryOptions ?? {};
    _isHalal = dietaryOptions['halal'] ?? false;
    _isVegan = dietaryOptions['vegan'] ?? false;
    _isVegetarian = dietaryOptions['vegetarian'] ?? false;

    // Allergies
    final allergies = dish.allergies ?? {};
    _allergies = Map.from(_allergies)..addAll(allergies);

    // Location
    _handleLocation(dish.location);

    // Expiration Date
    final expirationDate = dish.expirationDate;
    if (expirationDate != null) {
      final date = expirationDate.toDate();
      _expirationDateController.text = _formatDate(date);
    }
  }

  void _handleLocation(dynamic locationData) {
    if (locationData is String) {
      _locationAddress = locationData;
    } else if (locationData is Map<String, dynamic>) {
      _locationAddress = locationData['address']?.toString() ??
          'edit_dish.unknown_location'.tr();
    } else {
      _locationAddress = 'edit_dish.unknown_location'.tr();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

      // Prepare location data
      final locationData = {
        'address': _locationAddress,
        if (_locationLat != null) 'lat': _locationLat,
        if (_locationLng != null) 'lng': _locationLng,
      };

      // Create dish data
      final user = _auth.currentUser;
      if (user == null)
        throw Exception('edit_dish.user_not_authenticated'.tr());

      final dishData = {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'quantityAvailable': int.tryParse(_stockController.text) ?? 0,
        'preparationTimeMins': int.tryParse(_prepTimeController.text) ?? 30,
        'category': _selectedCategory,
        'availabilityType': _selectedType,
        'currency': _currency,
        'tags': _tags,
        'ingredients': _ingredients,
        'dietaryOptions': dietaryOptions,
        'dietaryTags': [..._tags, ...dietaryTags],
        'allergies': _allergies,
        'deliveryAvailable': _deliveryAvailable,
        'pickupAvailable': _pickupAvailable,
        'isFeatured': _isFeatured,
        'isRecommended': _isRecommended,
        'location': locationData,
        'updatedAt': FieldValue.serverTimestamp(),
        if (expirationDate != null) 'expirationDate': expirationDate,
      };

      if (widget.dishId != null) {
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
          'imageURLs': [],
        };
        await _firestore.collection('dishes').add(newDishData);
      }

      if (_mounted) {
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

  Future<void> _getCurrentLocation() async {
    try {
      if (_mounted) {
        setState(() => _locationAddress = 'edit_dish.fetching_location'.tr());
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (_mounted) {
          setState(() =>
              _locationAddress = 'edit_dish.location_services_disabled'.tr());
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (_mounted) {
            setState(() =>
                _locationAddress = 'edit_dish.location_permission_denied'.tr());
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (_mounted) {
          setState(() => _locationAddress =
              'edit_dish.location_permission_permanently_denied'.tr());
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = [
          placemark.street,
          placemark.locality,
          placemark.country
        ].where((part) => part?.isNotEmpty ?? false).join(', ');

        if (_mounted) {
          setState(() {
            _locationAddress = address.isNotEmpty
                ? address
                : 'edit_dish.location_acquired'.tr();
            _locationLat = position.latitude;
            _locationLng = position.longitude;
          });
        }
      } else {
        if (_mounted) {
          setState(() {
            _locationAddress = 'edit_dish.location_acquired'.tr();
            _locationLat = position.latitude;
            _locationLng = position.longitude;
          });
        }
      }
    } catch (e) {
      DebugHelper.log('Error fetching location: $e');
      if (_mounted) {
        setState(
            () => _locationAddress = 'edit_dish.failed_to_get_location'.tr());
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
              const Icon(Icons.warning_amber_rounded,
                  size: 48, color: Colors.orange),
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
                          if (_mounted) Navigator.pop(context);
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
            color: Colors.black.withOpacity(0.08),
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
              icon: Icon(Icons.add_rounded, color: mainColor),
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
                      deleteIcon:
                          Icon(Icons.close_rounded, size: 16, color: mainColor),
                      onDeleted: () => onRemove(e.key),
                      backgroundColor: mainColor.withOpacity(0.1),
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
      selectedColor: mainColor.withOpacity(0.2),
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
      selectedColor: mainColor.withOpacity(0.2),
      checkmarkColor: mainColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: selected ? mainColor : Colors.grey.shade300,
            width: selected ? 1.5 : 1),
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
                  icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
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

              // Pricing & Stock
              _buildSection(
                title: 'edit_dish.pricing_stock',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _priceController,
                            decoration:
                                _buildInputDecoration('edit_dish.price'),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            validator: (value) {
                              if (value!.isEmpty)
                                return 'edit_dish.price_required'.tr();
                              if (double.tryParse(value) == null) {
                                return 'edit_dish.invalid_price'.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _currency,
                            items: _currencies
                                .map((currency) => DropdownMenuItem(
                                    value: currency, child: Text(currency)))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _currency = value!),
                            decoration:
                                _buildInputDecoration('edit_dish.currency'),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
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
                    TextFormField(
                      controller: _expirationDateController,
                      readOnly: true,
                      onTap: _selectExpirationDate,
                      decoration: _buildInputDecoration(
                              'edit_dish.expiration_date_optional')
                          .copyWith(
                        suffixIcon: Icon(Icons.calendar_today_rounded,
                            color: mainColor),
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

              // Location
              _buildSection(
                title: 'edit_dish.location',
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.location_on_rounded,
                              color: mainColor, size: 20),
                        ),
                        title: Text(_locationAddress,
                            style: const TextStyle(fontSize: 14)),
                        trailing: IconButton(
                          icon: Icon(Icons.refresh_rounded, color: mainColor),
                          onPressed: _getCurrentLocation,
                          tooltip: 'edit_dish.refresh'.tr(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'edit_dish.location_info_message'.tr(),
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
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
                    shadowColor: mainColor.withOpacity(0.3),
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
