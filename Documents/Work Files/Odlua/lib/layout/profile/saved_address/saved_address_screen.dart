import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  final List<Map<String, dynamic>> _addresses = [];
  bool _isLoading = true;
  bool _isGettingLocation = false;
  final int _maxAddresses = 10;
  Map<String, dynamic>? _lastDeletedAddress;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseAndLoadAddresses();
  }

  Future<void> _initializeFirebaseAndLoadAddresses() async {
    try {
      // Ensure Firebase is initialized
      await Firebase.initializeApp();
      _loadAddresses();
    } catch (e) {
      DebugHelper.log('Firebase initialization error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAddresses() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DebugHelper.log('Loading addresses for user: ${user.uid}');

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          setState(() {
            if (data.containsKey('addresses') && data['addresses'] is List) {
              _addresses.clear();
              final addresses =
                  List<Map<String, dynamic>>.from(data['addresses'])
                    ..sort((a, b) {
                      if (a['isDefault'] == true && b['isDefault'] != true)
                        return -1;
                      if (a['isDefault'] != true && b['isDefault'] == true)
                        return 1;
                      return (a['name'] ?? '').compareTo(b['name'] ?? '');
                    });
              _addresses.addAll(addresses);
              DebugHelper.log('Loaded ${_addresses.length} addresses');
            }
            _isLoading = false;
          });
        } else {
          DebugHelper.log('No addresses found for user');
          setState(() => _isLoading = false);
        }
      } else {
        DebugHelper.log('No user logged in');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      DebugHelper.log('Error loading addresses: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAddressesToFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DebugHelper.log(
            'Saving ${_addresses.length} addresses for user: ${user.uid}');

        // Prepare addresses for Firebase - convert any server timestamps to regular timestamps
        final addressesToSave = _addresses.map((address) {
          final cleanedAddress = Map<String, dynamic>.from(address);

          // Convert server timestamps to regular timestamps
          if (cleanedAddress['createdAt'] is Timestamp) {
            // Keep as is - it's already a timestamp
          } else if (cleanedAddress['createdAt'] == null) {
            cleanedAddress['createdAt'] = Timestamp.now();
          }

          if (cleanedAddress['updatedAt'] is Timestamp) {
            // Keep as is
          } else {
            cleanedAddress['updatedAt'] = Timestamp.now();
          }

          return cleanedAddress;
        }).toList();

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'addresses': addressesToSave,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        DebugHelper.log('Addresses saved successfully');
      } else {
        throw Exception('No user authenticated');
      }
    } catch (e) {
      DebugHelper.log('Error saving addresses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('save_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  // Helper method to create a new address with proper timestamps
  Map<String, dynamic> _createNewAddress({
    required String id,
    required String name,
    required String address,
    required String details,
    required String type,
    required bool isDefault,
    double? lat,
    double? lng,
    Timestamp? createdAt,
  }) {
    return {
      'id': id,
      'name': name,
      'address': address,
      'details': details,
      'type': type,
      'isDefault': isDefault,
      'lat': lat,
      'lng': lng,
      'createdAt': createdAt ?? Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'archived': false,
    };
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showErrorSnackbar('location_services_disabled'.tr());
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showErrorSnackbar('location_permission_denied'.tr());
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showErrorSnackbar('location_permanent_denied'.tr());
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final address = _formatAddress(placemark);

        _showAddEditAddressDialog(
          address: address,
          lat: position.latitude,
          lng: position.longitude,
        );
      }
    } catch (e) {
      DebugHelper.log('Location error: $e');
      _showErrorSnackbar('location_error'.tr());
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  void _showErrorSnackbar(String message,
      {bool showUndo = false, Function()? onUndo}) {
    if (!mounted) return;

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
      action: showUndo
          ? SnackBarAction(
              label: 'undo'.tr(),
              textColor: Colors.white,
              onPressed: () {
                if (onUndo != null) onUndo();
              },
            )
          : null,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  String _formatAddress(Placemark placemark) {
    final street = placemark.street ?? '';
    final locality = placemark.locality ?? '';
    final country = placemark.country ?? '';

    if (context.locale.languageCode == 'ar') {
      List<String> addressParts = [];
      if (country.isNotEmpty) addressParts.add(country);
      if (locality.isNotEmpty) addressParts.add(locality);
      if (street.isNotEmpty) addressParts.add(street);
      return addressParts.join('، ');
    } else {
      List<String> addressParts = [];
      if (street.isNotEmpty) addressParts.add(street);
      if (locality.isNotEmpty) addressParts.add(locality);
      if (country.isNotEmpty) addressParts.add(country);
      return addressParts.join(', ');
    }
  }

  void _showAddEditAddressDialog({
    Map<String, dynamic>? addressData,
    String? address,
    double? lat,
    double? lng,
  }) {
    if (_addresses.length >= _maxAddresses && addressData == null) {
      _showErrorSnackbar('max_address_limit_reached'.tr());
      return;
    }

    final TextEditingController nameController = TextEditingController(
        text: addressData?['name'] ?? 'home_address'.tr());
    final TextEditingController addressController =
        TextEditingController(text: addressData?['address'] ?? address ?? '');
    final TextEditingController detailsController =
        TextEditingController(text: addressData?['details'] ?? '');

    String addressType = addressData?['type'] ?? 'home';
    bool isDefault = addressData?['isDefault'] ?? false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              insetPadding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: mainColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.location,
                            size: 30,
                            color: mainColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          addressData == null
                              ? 'add_new_address'.tr()
                              : 'edit_address'.tr(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'address_name'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          hintText: 'home_work_etc'.tr(),
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
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          counterText: '',
                        ),
                        maxLength: 30,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'full_address'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          hintText: 'enter_complete_address'.tr(),
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
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          counterText: '',
                        ),
                        maxLines: 3,
                        maxLength: 200,
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'additional_details'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: detailsController,
                        decoration: InputDecoration(
                          hintText: 'apartment_floor_etc'.tr(),
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
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'address_type'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: addressType,
                        decoration: InputDecoration(
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
                            borderSide: BorderSide(color: mainColor, width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'home',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Iconsax.home,
                                      size: 20, color: mainColor),
                                  const SizedBox(width: 12),
                                  Text('home'.tr(),
                                      style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'work',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Iconsax.building,
                                      size: 20, color: mainColor),
                                  const SizedBox(width: 12),
                                  Text('work'.tr(),
                                      style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Icon(Iconsax.location,
                                      size: 20, color: mainColor),
                                  const SizedBox(width: 12),
                                  Text('other'.tr(),
                                      style: const TextStyle(fontSize: 15)),
                                ],
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => addressType = value!);
                        },
                      ),
                      const SizedBox(height: 20),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            setDialogState(() => isDefault = !isDefault);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isDefault
                                        ? mainColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isDefault
                                          ? mainColor
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: isDefault
                                      ? const Icon(Icons.check,
                                          size: 16, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'set_as_default_address'.tr(),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'cancel'.tr(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final addressText =
                                    addressController.text.trim();

                                if (name.isEmpty) {
                                  _showErrorSnackbar('please_enter_name'.tr());
                                  return;
                                }

                                if (addressText.isEmpty) {
                                  _showErrorSnackbar(
                                      'please_enter_address'.tr());
                                  return;
                                }

                                final isDuplicate = _addresses.any((addr) =>
                                    addr['id'] != addressData?['id'] &&
                                    addr['address'] == addressText);

                                if (isDuplicate) {
                                  _showErrorSnackbar('duplicate_address'.tr());
                                  return;
                                }

                                try {
                                  // Create new address with proper timestamps
                                  final newAddress = _createNewAddress(
                                    id: addressData?['id'] ??
                                        DateTime.now()
                                            .millisecondsSinceEpoch
                                            .toString(),
                                    name: name,
                                    address: addressText,
                                    details: detailsController.text.trim(),
                                    type: addressType,
                                    isDefault: isDefault,
                                    lat: lat ?? addressData?['lat'],
                                    lng: lng ?? addressData?['lng'],
                                    createdAt:
                                        addressData?['createdAt'] is Timestamp
                                            ? addressData!['createdAt']
                                            : null,
                                  );

                                  // Update the state
                                  setState(() {
                                    if (isDefault) {
                                      for (var addr in _addresses) {
                                        addr['isDefault'] = false;
                                      }
                                    }

                                    if (addressData == null) {
                                      _addresses.add(newAddress);
                                    } else {
                                      final index = _addresses.indexWhere(
                                          (a) => a['id'] == addressData['id']);
                                      if (index != -1)
                                        _addresses[index] = newAddress;
                                    }

                                    _addresses.sort((a, b) {
                                      if (a['isDefault'] == true &&
                                          b['isDefault'] != true) return -1;
                                      if (a['isDefault'] != true &&
                                          b['isDefault'] == true) return 1;
                                      return (a['name'] ?? '')
                                          .compareTo(b['name'] ?? '');
                                    });
                                  });

                                  // Save to Firebase
                                  await _saveAddressesToFirebase();

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(addressData == null
                                            ? 'address_added'.tr()
                                            : 'address_updated'.tr()),
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(16),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  DebugHelper.log('Error saving address: $e');
                                  if (mounted) {
                                    _showErrorSnackbar('save_failed'.tr());
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                              ),
                              child: Text(
                                'save'.tr(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setDefaultAddress(String addressId) async {
    try {
      setState(() {
        for (var address in _addresses) {
          address['isDefault'] = address['id'] == addressId;
          // Update the updatedAt timestamp
          if (address['id'] == addressId) {
            address['updatedAt'] = Timestamp.now();
          }
        }

        _addresses.sort((a, b) {
          if (a['isDefault'] == true && b['isDefault'] != true) return -1;
          if (a['isDefault'] != true && b['isDefault'] == true) return 1;
          return (a['name'] ?? '').compareTo(b['name'] ?? '');
        });
      });

      await _saveAddressesToFirebase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('default_address_updated'.tr()),
            backgroundColor: Colors.green,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      DebugHelper.log('Error setting default address: $e');
      if (mounted) {
        _showErrorSnackbar('update_failed'.tr());
      }
    }
  }

  void _deleteAddress(String addressId) async {
    try {
      final addressToDelete =
          _addresses.firstWhere((addr) => addr['id'] == addressId);
      final wasDefault = addressToDelete['isDefault'] == true;

      _lastDeletedAddress = Map<String, dynamic>.from(addressToDelete);

      setState(() {
        final index = _addresses.indexWhere((addr) => addr['id'] == addressId);
        if (index != -1) {
          _addresses[index]['archived'] = true;
          _addresses[index]['isDefault'] = false;
          _addresses[index]['updatedAt'] = Timestamp.now();

          if (wasDefault && _addresses.isNotEmpty) {
            final nonArchived = _addresses.firstWhere(
              (addr) => addr['archived'] != true,
              orElse: () => _addresses[0],
            );
            nonArchived['isDefault'] = true;
            nonArchived['updatedAt'] = Timestamp.now();
          }
        }
      });

      await _saveAddressesToFirebase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('address_deleted'.tr()),
            backgroundColor: Colors.green,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            action: SnackBarAction(
              label: 'undo'.tr(),
              onPressed: () {
                if (_lastDeletedAddress != null) {
                  setState(() {
                    final index = _addresses.indexWhere(
                        (addr) => addr['id'] == _lastDeletedAddress!['id']);
                    if (index != -1) {
                      _addresses[index] = _lastDeletedAddress!;
                    } else {
                      _addresses.add(_lastDeletedAddress!);
                    }
                    _lastDeletedAddress = null;
                  });
                  _saveAddressesToFirebase();
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      DebugHelper.log('Error deleting address: $e');
      if (mounted) {
        _showErrorSnackbar('delete_failed'.tr());
      }
    }
  }

  void _reorderAddress(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    setState(() {
      final item = _addresses.removeAt(oldIndex);
      _addresses.insert(newIndex, item);
    });

    _saveAddressesToFirebase();
  }

  List<Map<String, dynamic>> get _filteredAddresses {
    return _addresses.where((addr) => addr['archived'] != true).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAddresses = _filteredAddresses;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'saved_addresses'.tr(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.grey.shade800),
        actions: [
          if (filteredAddresses.isNotEmpty)
            IconButton(
              icon: const Icon(Iconsax.search_normal),
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: AddressSearchDelegate(
                    addresses: filteredAddresses,
                    onAddressSelected: (address) {
                      _showAddEditAddressDialog(addressData: address);
                    },
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: mainColor,
              ),
            )
          : Column(
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'manage_your_addresses'.tr(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isGettingLocation
                                  ? null
                                  : _getCurrentLocation,
                              icon: _isGettingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(Iconsax.location, size: 20),
                              label: Text(_isGettingLocation
                                  ? 'getting_location'.tr()
                                  : 'use_current_location'.tr()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mainColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                elevation: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Addresses List
                Expanded(
                  child: filteredAddresses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.location_slash,
                                size: 72,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'no_addresses_found'.tr(),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 40),
                                child: Text(
                                  'add_your_first_address_location'.tr(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: filteredAddresses.length,
                          itemBuilder: (context, index) {
                            final address = filteredAddresses[index];
                            final actualIndex = _addresses.indexWhere(
                                (addr) => addr['id'] == address['id']);
                            return _buildAddressCard(address, actualIndex);
                          },
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }

                            final actualOldIndex = _addresses.indexWhere(
                                (addr) =>
                                    addr['id'] ==
                                    filteredAddresses[oldIndex]['id']);
                            final actualNewIndex = _addresses.indexWhere(
                                (addr) =>
                                    addr['id'] ==
                                    filteredAddresses[newIndex]['id']);

                            if (actualOldIndex != -1 && actualNewIndex != -1) {
                              _reorderAddress(actualOldIndex, actualNewIndex);
                            }
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildAddressCard(Map<String, dynamic> address, int index) {
    return Container(
      key: Key(address['id']),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showAddEditAddressDialog(addressData: address),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _getAddressTypeColor(address['type']),
                              borderRadius: BorderRadius.circular(14),
                              gradient: LinearGradient(
                                colors: [
                                  _getAddressTypeColor(address['type']),
                                  _getAddressTypeColor(address['type'])
                                      .withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Icon(
                              _getAddressTypeIcon(address['type']),
                              size: 22,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  address['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (address['isDefault'] == true) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'default'.tr(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(Iconsax.more,
                          color: Colors.grey.shade600, size: 22),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading:
                                Icon(Iconsax.edit, size: 20, color: mainColor),
                            title: Text('edit'.tr(),
                                style: const TextStyle(fontSize: 14)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        if (!address['isDefault'])
                          PopupMenuItem(
                            value: 'set_default',
                            child: ListTile(
                              leading: const Icon(Iconsax.star,
                                  size: 20, color: Colors.amber),
                              title: Text('set_as_default'.tr(),
                                  style: const TextStyle(fontSize: 14)),
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: const Icon(Iconsax.trash,
                                size: 20, color: Colors.red),
                            title: Text('delete'.tr(),
                                style: const TextStyle(
                                    fontSize: 14, color: Colors.red)),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showAddEditAddressDialog(addressData: address);
                        } else if (value == 'set_default') {
                          _setDefaultAddress(address['id']);
                        } else if (value == 'delete') {
                          _deleteAddress(address['id']);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  address['address'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                if (address['details'] != null &&
                    address['details'].isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    address['details'],
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Iconsax.copy, size: 18, color: mainColor),
                      onPressed: () {
                        final addressText =
                            '${address['name']}\n${address['address']}${address['details'] != null && address['details'].isNotEmpty ? '\n${address['details']}' : ''}';
                        Clipboard.setData(ClipboardData(text: addressText));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('address_copied'.tr()),
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'copy_address'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: mainColor,
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

  IconData _getAddressTypeIcon(String type) {
    switch (type) {
      case 'home':
        return Iconsax.home;
      case 'work':
        return Iconsax.building;
      default:
        return Iconsax.location;
    }
  }

  Color _getAddressTypeColor(String type) {
    switch (type) {
      case 'home':
        return Colors.blue.shade600;
      case 'work':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}

class AddressSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> addresses;
  final Function(Map<String, dynamic>) onAddressSelected;

  AddressSearchDelegate(
      {required this.addresses, required this.onAddressSelected});

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final results = addresses.where((address) {
      final name = (address['name'] ?? '').toLowerCase();
      final addressText = (address['address'] ?? '').toLowerCase();
      final type = (address['type'] ?? '').toLowerCase();
      final searchQuery = query.toLowerCase();

      return name.contains(searchQuery) ||
          addressText.contains(searchQuery) ||
          type.contains(searchQuery);
    }).toList();

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final address = results[index];
        return ListTile(
          leading: Icon(
            _getAddressTypeIcon(address['type']),
            color: _getAddressTypeColor(address['type']),
          ),
          title: Text(address['name']),
          subtitle: Text(address['address']),
          trailing: address['isDefault'] == true
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'default'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                    ),
                  ),
                )
              : null,
          onTap: () {
            onAddressSelected(address);
            close(context, null);
          },
        );
      },
    );
  }

  IconData _getAddressTypeIcon(String type) {
    switch (type) {
      case 'home':
        return Iconsax.home;
      case 'work':
        return Iconsax.building;
      default:
        return Iconsax.location;
    }
  }

  Color _getAddressTypeColor(String type) {
    switch (type) {
      case 'home':
        return Colors.blue.shade600;
      case 'work':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
  }
}
