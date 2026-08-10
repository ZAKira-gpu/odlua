// ─────────────────────────────────────────
// Screen: SavedAddressesScreen
// Description: Manage saved delivery addresses — add, edit, delete,
//              and set a default. Stored in Firestore subcollection.
// Contains: Address list, add form, default selector
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/location/models/location_models.dart';
import 'package:odlua/utils/location/widgets/location_selector_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  bool _loading = true;
  String? _error;
  LocationData? _currentUserLocation;
  List<LocationData> _savedAddresses = [];
  Map<int, String> _addressDocIds = {}; // Map index to Firestore doc ID

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Initialize location controller - not needed for Phase 2B widget
      // Phase 2B: StructuredLocationInputWidget manages its own service

      // Load current user location
      await _loadUserLocation();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadUserLocation() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        DebugHelper.logInfo('No user authenticated');
        return;
      }

      DebugHelper.logInfo('Loading user location for uid: $uid');
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        DebugHelper.logInfo('User document does not exist');
        return;
      }

      final data = doc.data();
      if (data == null) {
        DebugHelper.logInfo('User document data is null');
        return;
      }

      DebugHelper.logInfo('User data loaded: ${data.keys.join(", ")}');

      if (data['latitude'] != null && data['longitude'] != null) {
        _currentUserLocation = LocationData(
          city: data['city'] ?? '',
          postalCode: data['postalCode'] ?? '',
          country: data['country'] ?? '',
          countryCode: data['countryCode'] ?? '',
          formattedAddress: data['formattedAddress'] ?? '',
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
        );
        DebugHelper.logInfo(
            '✅ Primary location loaded: ${_currentUserLocation?.city}');
      } else {
        DebugHelper.logInfo('⚠️ No latitude/longitude in user document');
      }

      // Try to load from subcollection first
      final subcollectionSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_addresses')
          .get();

      if (subcollectionSnapshot.docs.isNotEmpty) {
        // Load from subcollection
        DebugHelper.logInfo(
            'Found ${subcollectionSnapshot.docs.length} addresses in subcollection');

        _savedAddresses.clear();
        _addressDocIds.clear();

        for (var i = 0; i < subcollectionSnapshot.docs.length; i++) {
          final doc = subcollectionSnapshot.docs[i];
          final addr = doc.data();

          _savedAddresses.add(LocationData(
            city: addr['city'] ?? '',
            postalCode: addr['postalCode'] ?? '',
            country: addr['country'] ?? '',
            countryCode: addr['countryCode'] ?? '',
            formattedAddress: addr['formattedAddress'] ?? '',
            latitude: (addr['latitude'] as num).toDouble(),
            longitude: (addr['longitude'] as num).toDouble(),
          ));

          _addressDocIds[i] = doc.id;
        }

        DebugHelper.logInfo(
            '✅ Loaded ${_savedAddresses.length} addresses from subcollection');
      } else {
        // Migrate from old array format
        final addresses = data['savedAddresses'] as List<dynamic>? ?? [];
        DebugHelper.logInfo(
            'Found ${addresses.length} addresses in old array format - migrating...');

        if (addresses.isNotEmpty) {
          _savedAddresses = addresses.map((addr) {
            return LocationData(
              city: addr['city'] ?? '',
              postalCode: addr['postalCode'] ?? '',
              country: addr['country'] ?? '',
              countryCode: addr['countryCode'] ?? '',
              formattedAddress: addr['formattedAddress'] ?? '',
              latitude: (addr['latitude'] as num).toDouble(),
              longitude: (addr['longitude'] as num).toDouble(),
            );
          }).toList();

          // Migrate to subcollection
          for (var i = 0; i < _savedAddresses.length; i++) {
            final addressData = _savedAddresses[i].toMap();
            addressData['isPrimary'] = i == 0; // First address is primary

            final docRef = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('saved_addresses')
                .add(addressData);

            _addressDocIds[i] = docRef.id;
          }

          // Remove old array field
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'savedAddresses': FieldValue.delete(),
          });

          DebugHelper.logInfo(
              '✅ Migrated ${_savedAddresses.length} addresses to subcollection');
        }
      }
    } catch (e) {
      DebugHelper.logError('Error loading user location', error: e);
    }
  }

  Future<void> _saveAddress(LocationData location) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      // Save to Firestore subcollection with isPrimary field
      final addressData = location.toMap();
      final isFirstAddress = _savedAddresses.isEmpty;
      addressData['isPrimary'] = isFirstAddress; // First address is primary

      final docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_addresses')
          .add(addressData);

      // Add to saved addresses list and store doc ID
      final newIndex = _savedAddresses.length;
      _savedAddresses.add(location);
      _addressDocIds[newIndex] = docRef.id;

      // If this is the first address, also set it as the user's primary location
      if (isFirstAddress) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'city': location.city,
          'postalCode': location.postalCode,
          'country': location.country,
          'countryCode': location.countryCode,
          'formattedAddress': location.formattedAddress,
          'latitude': location.latitude,
          'longitude': location.longitude,
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('last_latitude', location.latitude);
        await prefs.setDouble('last_longitude', location.longitude);

        _currentUserLocation = location;
      }

      // Update UI
      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'address_saved_successfully'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      DebugHelper.logError('Error saving address', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'failed_to_save_address'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(int index, String docId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_addresses')
          .doc(docId)
          .delete();

      _savedAddresses.removeAt(index);

      // Rebuild the doc ID map after removal
      final oldMap = Map<int, String>.from(_addressDocIds);
      _addressDocIds.clear();
      for (var i = 0; i < _savedAddresses.length; i++) {
        final oldIndex = i < index ? i : i + 1;
        _addressDocIds[i] = oldMap[oldIndex]!;
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'address_deleted_successfully'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      DebugHelper.logError('Error deleting address', error: e);
    }
  }

  Future<void> _setAsPrimary(LocationData location, String docId) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // First, unmark all addresses as non-primary
      final addressesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_addresses')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in addressesSnapshot.docs) {
        batch.update(doc.reference, {'isPrimary': false});
      }

      // Mark the selected address as primary
      final selectedDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('saved_addresses')
          .doc(docId);
      batch.update(selectedDocRef, {'isPrimary': true});

      await batch.commit();

      // Also update user's primary location fields for backward compatibility
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'city': location.city,
        'postalCode': location.postalCode,
        'country': location.country,
        'countryCode': location.countryCode,
        'formattedAddress': location.formattedAddress,
        'latitude': location.latitude,
        'longitude': location.longitude,
      });

      // Update SharedPreferences for legacy location service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_latitude', location.latitude);
      await prefs.setDouble('last_longitude', location.longitude);

      setState(() {
        _currentUserLocation = location;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'primary_address_updated'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      DebugHelper.logError('Error setting primary address', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text(
            'saved_addresses'.tr(),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading addresses...',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          title: Text(
            'saved_addresses'.tr(),
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.black87),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'error_loading_addresses'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Something went wrong. Please try again.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _init();
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('retry'.tr()),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'saved_addresses'.tr(),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
              ),
              onPressed: _showAddAddressDialog,
              tooltip: 'add_new_address'.tr(),
            ),
          ),
        ],
      ),
      body: _savedAddresses.isEmpty && _currentUserLocation == null
          ? _buildEmptyState()
          : _buildAddressesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_rounded,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'no_saved_addresses'.tr(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your first address to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddAddressDialog,
              icon: const Icon(Icons.add_rounded),
              label: Text('add_first_address'.tr()),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressesList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Current/Primary Address
        if (_currentUserLocation != null) ...[
          Row(
            children: [
              Icon(
                Icons.stars_rounded,
                size: 20,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'primary_address'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAddressCard(
            _currentUserLocation!,
            isPrimary: true,
            onDelete: null,
            onSetAsPrimary: null,
          ),
          const SizedBox(height: 28),
        ],

        // Saved Addresses
        if (_savedAddresses.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                Icons.bookmarks_rounded,
                size: 20,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                'saved_addresses'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                '${_savedAddresses.length} ${_savedAddresses.length == 1 ? "address" : "addresses"}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._savedAddresses.asMap().entries.map((entry) {
            final docId = _addressDocIds[entry.key];
            if (docId == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildAddressCard(
                entry.value,
                isPrimary: false,
                onDelete: () => _deleteAddress(entry.key, docId),
                onSetAsPrimary: () => _setAsPrimary(entry.value, docId),
              ),
            );
          }).toList(),
        ],

        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _showAddAddressDialog,
          icon: const Icon(Icons.add_location_alt_rounded, size: 20),
          label: Text('add_new_address'.tr()),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: Colors.grey.shade300, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddressCard(
    LocationData location, {
    required bool isPrimary,
    VoidCallback? onDelete,
    VoidCallback? onSetAsPrimary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isPrimary ? Theme.of(context).primaryColor : Colors.grey.shade200,
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: isPrimary ? 12 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPrimary ? Icons.home_rounded : Icons.location_on_rounded,
                    color: isPrimary
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context)
                                    .primaryColor
                                    .withValues(alpha: 0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'primary'.tr().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        location.city ?? 'Unknown City',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPrimary)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) => _buildActionSheet(
                            location,
                            onSetAsPrimary,
                            onDelete,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _buildInfoRow(
                    Icons.location_city_rounded,
                    location.city ?? 'N/A',
                  ),
                  if (location.postalCode != null &&
                      location.postalCode!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.mail_rounded, location.postalCode!),
                  ],
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.public_rounded,
                    location.country ?? 'N/A',
                  ),
                  if (location.formattedAddress.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Divider(height: 1, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.map_rounded,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location.formattedAddress,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSheet(
    LocationData location,
    VoidCallback? onSetAsPrimary,
    VoidCallback? onDelete,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.home_rounded, color: Colors.blue.shade700),
              ),
              title: Text('set_as_primary'.tr()),
              subtitle: Text('set_primary_address_desc'.tr()),
              onTap: () {
                Navigator.pop(context);
                onSetAsPrimary?.call();
              },
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.delete_rounded, color: Colors.red.shade700),
              ),
              title: Text(
                'delete'.tr(),
                style: TextStyle(color: Colors.red.shade700),
              ),
              subtitle: Text('remove_address_desc'.tr()),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(onDelete);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(VoidCallback? onDelete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Text('confirm_delete'.tr()),
          ],
        ),
        content: Text(
          'confirm_delete_address'.tr(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'cancel'.tr(),
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete?.call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddAddressDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_location_alt_rounded,
                        color: Theme.of(context).primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'add_new_address'.tr(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Use GPS or enter manually',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.close_rounded,
                            color: Colors.grey.shade700),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: Colors.grey.shade200),

              // Content with LocationSelectorWidget
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  child: LocationSelectorWidget(
                    onAddressComplete: (address) {
                      Navigator.pop(context);
                      // Convert to LocationData for legacy _saveAddress method
                      final locationData = LocationData(
                        formattedAddress: address.formattedAddress,
                        city: address.city,
                        postalCode: address.postalCode,
                        country: address.country,
                        countryCode: address.countryCode,
                        latitude: address.coordinates.latitude,
                        longitude: address.coordinates.longitude,
                      );
                      _saveAddress(locationData);
                    },
                  ),
                ),
              ),
              // Safe area padding at bottom
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
