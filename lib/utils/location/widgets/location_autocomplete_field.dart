// ─────────────────────────────────────────
// Widget: LocationAutocompleteField
// Description: Text field with dropdown address suggestions.
// Contains: Autocomplete input, suggestion list, selection
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/location_controller.dart';
import '../models/location_models.dart';

class LocationAutocompleteField extends StatefulWidget {
  final LocationController controller;
  final String? countryCode;
  final InputDecoration? decoration;
  final void Function(LocationData data)? onSelected;

  const LocationAutocompleteField(
      {super.key,
      required this.controller,
      this.countryCode,
      this.decoration,
      this.onSelected});

  @override
  State<LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState extends State<LocationAutocompleteField> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Listen to selected location and update text field
    widget.controller.selected.listen((data) {
      if (data != null && mounted) {
        // Update text to show only city, postal code, and country (no coordinates)
        final displayText = [
          if (data.city != null && data.city!.isNotEmpty) data.city,
          if (data.postalCode != null && data.postalCode!.isNotEmpty)
            data.postalCode,
          if (data.country != null && data.country!.isNotEmpty) data.country,
        ].join(', ');
        _textController.text = displayText.isNotEmpty
            ? displayText
            : data.formattedAddress.split('(').first.trim();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _textController,
          focusNode: _focusNode,
          decoration: widget.decoration ??
              const InputDecoration(
                labelText: 'Location',
                hintText: 'Search for a city or address...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
          onChanged: (v) => widget.controller
              .onQueryChanged(v, countryCode: widget.countryCode),
        ),
        const SizedBox(height: 8),
        Obx(() {
          final hasQuery = _textController.text.trim().isNotEmpty;

          if (widget.controller.loading.value) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Searching locations...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          if (widget.controller.error.isNotEmpty) {
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Connection Error',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unable to search locations. Please check your internet connection and try again.',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      widget.controller.onQueryChanged(_textController.text,
                          countryCode: widget.countryCode);
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // Show empty state if user has typed something but no results
          if (hasQuery && widget.controller.suggestions.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 40,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No locations found',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try searching with a different city name or address',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          if (widget.controller.suggestions.isEmpty) {
            return const SizedBox.shrink();
          }
          return Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: widget.controller.suggestions.length,
                separatorBuilder: (context, index) => Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade200,
                ),
                itemBuilder: (context, i) {
                  final s = widget.controller.suggestions[i];
                  return InkWell(
                    onTap: () async {
                      await widget.controller.choose(s);
                      final sel = widget.controller.selected.value;
                      if (sel != null) {
                        // Clear suggestions after selection
                        widget.controller.suggestions.clear();
                        // Unfocus to close keyboard
                        _focusNode.unfocus();
                        // Call onSelected callback
                        widget.onSelected?.call(sel);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.location_on,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (s.subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    s.subtitle,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                                // Show additional info from raw data
                                if (s.raw['postcode'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Postal Code: ${s.raw['postcode']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        })
      ],
    );
  }
}
