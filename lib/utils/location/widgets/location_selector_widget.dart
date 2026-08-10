// ─────────────────────────────────────────
// Widget: LocationSelectorWidget
// Description: GPS or manual location picker used in forms.
// Contains: GPS button, manual entry toggle, map preview
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import '../../../utils/models/structured_address_model.dart';
import '../../../utils/theme/custom_themes/main_colors.dart';
import '../manual_location_flow/manual_location_flow.dart';

/// Widget that provides two options for location selection:
/// 1. Get Current Location (GPS-based)
/// 2. Enter Address Manually (Structured address widget)
class LocationSelectorWidget extends StatefulWidget {
  final Function(StructuredAddress) onAddressComplete;
  final StructuredAddress? initialAddress;
  final String? getCurrentLocationText;
  final String? enterManuallyText;

  const LocationSelectorWidget({
    super.key,
    required this.onAddressComplete,
    this.initialAddress,
    this.getCurrentLocationText,
    this.enterManuallyText,
  });

  @override
  State<LocationSelectorWidget> createState() => _LocationSelectorWidgetState();
}

class _LocationSelectorWidgetState extends State<LocationSelectorWidget> {
  bool _isLoadingCurrentLocation = false;
  StructuredAddress? _currentAddress;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentAddress = widget.initialAddress;
  }

  @override
  void didUpdateWidget(LocationSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update address when initialAddress prop changes (e.g., async load completes)
    if (widget.initialAddress != oldWidget.initialAddress &&
        widget.initialAddress != null) {
      _currentAddress = widget.initialAddress;

      // Schedule callback after build phase completes to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAddressComplete(widget.initialAddress!);
        DebugHelper.log(
            'LocationSelector: Updated to new initial address: ${widget.initialAddress?.city}');
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
      _errorMessage = null;
    });

    try {
      DebugHelper.log('Starting location fetch process...');

      // Check for location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      DebugHelper.log('Current permission status: $permission');

      if (permission == LocationPermission.denied) {
        DebugHelper.log('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        DebugHelper.log('Permission after request: $permission');

        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'location_permission_denied'.tr();
            _isLoadingCurrentLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'location_permission_permanently_denied'.tr();
          _isLoadingCurrentLocation = false;
        });
        return;
      }

      // Check if location services are enabled (but don't block if check fails)
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        DebugHelper.log('Location service enabled check: $serviceEnabled');

        if (!serviceEnabled) {
          DebugHelper.logWarning(
              'Location services appear disabled, but will try to get position anyway');
          // Don't return - try to get position anyway as this check can be unreliable
        }
      } catch (e) {
        DebugHelper.logWarning('Error checking service status: $e - will proceed anyway');
      }

      // Get current position
      DebugHelper.log('Attempting to get current position...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      DebugHelper.log(
          'Position obtained: ${position.latitude}, ${position.longitude}');

      // Try to get address from coordinates using geocoding
      StructuredAddress address;

      try {
        DebugHelper.log('Attempting to reverse geocode coordinates...');
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        ).timeout(Duration(seconds: 5));

        if (placemarks.isEmpty) {
          throw Exception('No address found for current location');
        }

        Placemark place = placemarks.first;
        DebugHelper.log('Placemark obtained: ${place.locality}, ${place.country}');

        // Create formatted address
        final addressParts = <String>[];
        if (place.subThoroughfare != null &&
            place.subThoroughfare!.isNotEmpty) {
          addressParts.add(place.subThoroughfare!);
        }
        if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty) {
          addressParts.add(place.thoroughfare!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        } else if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          addressParts.add(place.country!);
        }

        // Create structured address from current location
        address = StructuredAddress(
          country: place.country ?? '',
          countryCode: place.isoCountryCode ?? '',
          city: place.locality ?? place.subLocality ?? '',
          postalCode: place.postalCode ?? '',
          streetName: place.thoroughfare ?? '',
          buildingNumber: place.subThoroughfare ?? '',
          floor: null,
          apartmentNumber: null,
          coordinates: GeoPoint(position.latitude, position.longitude),
          formattedAddress: addressParts.isNotEmpty
              ? addressParts.join(', ')
              : '${position.latitude}, ${position.longitude}',
          createdAt: DateTime.now(),
        );
      } catch (geocodingError) {
        DebugHelper.logWarning('Geocoding failed: $geocodingError');
        DebugHelper.log('Creating address with coordinates only...');

        // Fallback: Create address with just coordinates
        address = StructuredAddress(
          country: '',
          countryCode: '',
          city: '',
          postalCode: '',
          streetName: '',
          buildingNumber: '',
          floor: null,
          apartmentNumber: null,
          coordinates: GeoPoint(position.latitude, position.longitude),
          formattedAddress:
              'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}',
          createdAt: DateTime.now(),
        );

        DebugHelper.logSuccess('Created fallback address with coordinates');
      }

      DebugHelper.logSuccess('Created address from current location:');
      DebugHelper.log('${address.formattedAddress}');
      DebugHelper.log(
          'Coordinates: ${address.coordinates.latitude}, ${address.coordinates.longitude}');

      setState(() {
        _currentAddress = address;
        _isLoadingCurrentLocation = false;
      });

      // Call the callback
      widget.onAddressComplete(address);
    } catch (e) {
      DebugHelper.logError('Error getting current location: $e');
      setState(() {
        _errorMessage = 'error_getting_location'.tr();
        _isLoadingCurrentLocation = false;
      });
    }
  }

  void _showManualEntryWidget() {
    // Open the new elegant full-screen manual location flow
    Navigator.of(context).push(
      MaterialPageRoute<ManualLocationData>(
        fullscreenDialog: true,
        builder: (context) => ManualLocationFlow(
          onLocationComplete: (locationData) {
            final address = locationData.toStructuredAddress();
            setState(() {
              _currentAddress = address;
            });
            widget.onAddressComplete(address);
            Navigator.of(context).pop();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // _hideManualEntryWidget removed - no longer needed with full-screen flow

  @override
  Widget build(BuildContext context) {
    // Show option buttons and current address if available
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current address display (if available)
        if (_currentAddress != null)
          Container(
            padding: const EdgeInsets.all(18),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: mainColor.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: mainColor.withAlpha(77), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: mainColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'address_saved'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: mainColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on, color: mainColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentAddress!.formattedAddress,
                              style: TextStyle(
                                fontSize: 14,
                                color: textColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.my_location,
                                color: Colors.grey.shade600, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${_currentAddress!.coordinates.latitude.toStringAsFixed(4)}, ${_currentAddress!.coordinates.longitude.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: secondaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Error message
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: errorMessageColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: errorMessageColor.withAlpha(77), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: errorMessageColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      color: errorMessageColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Get Current Location button
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: mainColor.withAlpha(77),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: _isLoadingCurrentLocation ? null : _getCurrentLocation,
            icon: _isLoadingCurrentLocation
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.my_location, size: 22),
            label: Text(
              _isLoadingCurrentLocation
                  ? 'getting_location'.tr()
                  : (widget.getCurrentLocationText ??
                      'get_current_location'.tr()),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Divider with "OR"
        Row(
          children: [
            Expanded(
                child: Divider(thickness: 1.5, color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or'.tr().toUpperCase(),
                style: TextStyle(
                  color: secondaryTextColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
            Expanded(
                child: Divider(thickness: 1.5, color: Colors.grey.shade300)),
          ],
        ),

        const SizedBox(height: 24),

        // Enter Manually button
        OutlinedButton.icon(
          onPressed: _showManualEntryWidget,
          icon: Icon(Icons.edit_location_alt, size: 22, color: mainColor),
          label: Text(
            widget.enterManuallyText ?? 'enter_address_manually'.tr(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: mainColor,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            side: BorderSide(color: mainColor, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}
