// ─────────────────────────────────────────
// Widget: ManualLocationButton
// Description: CTA button that opens the manual location flow.
// Contains: Button with label, onTap callback
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/models/structured_address_model.dart';
import '../manual_location_flow.dart';

/// Button widget that opens the full manual location flow
/// Can be used in signup, profile, or anywhere location is needed
class ManualLocationButton extends StatefulWidget {
  final Function(ManualLocationData) onLocationComplete;
  final ManualLocationData? initialLocation;
  final String? buttonText;
  final bool showCoordinates;

  const ManualLocationButton({
    super.key,
    required this.onLocationComplete,
    this.initialLocation,
    this.buttonText,
    this.showCoordinates = false,
  });

  @override
  State<ManualLocationButton> createState() => _ManualLocationButtonState();
}

class _ManualLocationButtonState extends State<ManualLocationButton> {
  ManualLocationData? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  void _openLocationFlow() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ManualLocationFlow(
          onLocationComplete: (location) {
            setState(() => _selectedLocation = location);
            widget.onLocationComplete(location);
            Navigator.of(context).pop();
          },
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocation = _selectedLocation != null;

    return GestureDetector(
      onTap: _openLocationFlow,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hasLocation
              ? Colors.green.withValues(alpha: 0.05)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLocation ? Colors.green.shade300 : Colors.grey.shade200,
            width: hasLocation ? 2 : 1,
          ),
        ),
        child: hasLocation ? _buildSelectedState() : _buildEmptyState(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.add_location_alt_rounded,
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
                widget.buttonText ?? 'location_set_your_location'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'location_tap_to_select'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          size: 18,
          color: Colors.grey.shade400,
        ),
      ],
    );
  }

  Widget _buildSelectedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade600,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedLocation!.street,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedLocation!.city}, ${_selectedLocation!.country}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _openLocationFlow,
              icon: Icon(
                Icons.edit_rounded,
                color: mainColor,
                size: 20,
              ),
            ),
          ],
        ),
        if (widget.showCoordinates) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.gps_fixed_rounded,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Convert ManualLocationData to StructuredAddress for backward compatibility
extension ManualLocationToStructuredAddress on ManualLocationData {
  StructuredAddress toStructuredAddress() {
    return StructuredAddress(
      country: country,
      countryCode: countryCode,
      city: city,
      cityCode: '', // Not collected in manual flow
      streetName: street,
      streetType: '',
      buildingNumber: '',
      buildingName: '',
      floor: '',
      apartmentNumber: '',
      entrance: '',
      postalCode: '',
      landmark: '',
      additionalInfo: '',
      coordinates: GeoPoint(latitude, longitude),
      formattedAddress: formattedAddress,
      createdAt: createdAt,
    );
  }
}

/// Convert StructuredAddress to ManualLocationData
extension StructuredAddressToManualLocation on StructuredAddress {
  ManualLocationData toManualLocationData() {
    final code = countryCode ?? '';
    return ManualLocationData(
      continent: WorldData.getContinentForCountry(code) ?? 'Unknown',
      country: country,
      countryCode: code,
      city: city,
      street: streetName,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      formattedAddress: formattedAddress,
      createdAt: DateTime.now(),
    );
  }
}
