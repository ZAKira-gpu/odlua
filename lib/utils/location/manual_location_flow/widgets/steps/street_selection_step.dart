// ─────────────────────────────────────────
// Widget: StreetSelectionStep
// Description: Street/address input step in the manual location flow.
// Contains: Text field, optional geocoding
// ─────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../../controllers/manual_location_controller.dart';
import '../../services/location_validation_service.dart';

/// Step 4: Street Selection with Validation
/// Final step - street name with autocomplete and coordinate validation
class StreetSelectionStep extends StatefulWidget {
  final ManualLocationController controller;
  final VoidCallback onComplete;

  const StreetSelectionStep({
    super.key,
    required this.controller,
    required this.onComplete,
  });

  @override
  State<StreetSelectionStep> createState() => _StreetSelectionStepState();
}

class _StreetSelectionStepState extends State<StreetSelectionStep> {
  final TextEditingController _streetController = TextEditingController();
  final FocusNode _streetFocus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _streetController.text = widget.controller.selectedStreet;
    _streetFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _streetController.dispose();
    _streetFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  void _onStreetChanged(String value) {
    widget.controller.setStreetManually(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.controller.searchStreets(value);
    });
  }

  void _onStreetSelected(StreetSuggestion street) {
    HapticFeedback.lightImpact();
    _streetController.text = street.name;
    widget.controller.selectStreet(street);
    _streetFocus.unfocus();
  }

  Future<void> _onValidate() async {
    HapticFeedback.lightImpact();
    _streetFocus.unfocus();
    await widget.controller.validateStreet(_streetController.text);
  }

  void _onComplete() {
    if (widget.controller.isComplete) {
      HapticFeedback.mediumImpact();
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cityName = widget.controller.selectedCity;
    final countryFlag = widget.controller.selectedCountry?.flag ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Title
          Text(
            'location_enter_street'.tr(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(countryFlag, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$cityName, ${widget.controller.selectedCountry?.name ?? ''}',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Street input
          _buildStreetInput(),
          const SizedBox(height: 8),

          // Suggestions or validation
          Expanded(
            child: _buildSuggestionsOrValidation(),
          ),

          // Complete button
          _buildCompleteButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStreetInput() {
    final hasError = widget.controller.errorMessage != null;
    final isValid = widget.controller.isStreetValid;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? Colors.red.shade300
              : isValid
                  ? Colors.green.shade300
                  : _streetFocus.hasFocus
                      ? mainColor
                      : Colors.grey.shade200,
          width: _streetFocus.hasFocus || isValid ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _streetController,
        focusNode: _streetFocus,
        onChanged: _onStreetChanged,
        style: const TextStyle(fontSize: 16),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _onValidate(),
        decoration: InputDecoration(
          hintText: 'location_street_placeholder'.tr(),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(
            Icons.add_road_rounded,
            color: isValid
                ? Colors.green
                : hasError
                    ? Colors.red
                    : Colors.grey.shade400,
          ),
          suffixIcon: widget.controller.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : isValid
                  ? Icon(Icons.check_circle_rounded,
                      color: Colors.green.shade600)
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsOrValidation() {
    final suggestions = widget.controller.streetSuggestions;
    final error = widget.controller.errorMessage;
    final isValid = widget.controller.isStreetValid;

    // Show error
    if (error != null) {
      return _buildErrorState(error);
    }

    // Show complete validation
    if (isValid) {
      return _buildCompleteState();
    }

    // Show suggestions
    if (suggestions.isNotEmpty) {
      return ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final street = suggestions[index];
          return _StreetSuggestionTile(
            street: street,
            onTap: () => _onStreetSelected(street),
          );
        },
      );
    }

    // Show hint
    return _buildHintState();
  }

  Widget _buildHintState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_road_rounded,
            size: 64,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'location_street_hint'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'location_street_no_building'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade300,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => widget.controller.clearError(),
              child: Text(
                'try_again'.tr(),
                style: TextStyle(color: mainColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompleteState() {
    final location = widget.controller.getLocationData();

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'location_ready'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 24),

            // Location summary
            _buildSummaryRow(
              icon: Icons.public,
              label: 'Continent',
              value: location?.continent ?? '',
            ),
            _buildSummaryRow(
              icon: Icons.flag,
              label: 'Country',
              value:
                  '${widget.controller.selectedCountry?.flag ?? ''} ${location?.country ?? ''}',
            ),
            _buildSummaryRow(
              icon: Icons.location_city,
              label: 'City',
              value: location?.city ?? '',
            ),
            _buildSummaryRow(
              icon: Icons.add_road,
              label: 'Street',
              value: location?.street ?? '',
            ),

            const Divider(height: 32),

            // Coordinates
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.gps_fixed_rounded,
                    size: 18,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${location?.latitude.toStringAsFixed(6)}, ${location?.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteButton() {
    final isValid = widget.controller.isStreetValid;
    final hasInput = _streetController.text.trim().isNotEmpty;
    final isLoading = widget.controller.isLoading;
    final isComplete = widget.controller.isComplete;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : isComplete
                ? _onComplete
                : hasInput
                    ? _onValidate
                    : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isComplete ? Colors.green : mainColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          disabledBackgroundColor: Colors.grey.shade200,
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isComplete) ...[
                    const Icon(Icons.check_rounded, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isComplete
                        ? 'location_complete'.tr()
                        : isValid
                            ? 'continue'.tr()
                            : 'location_validate_street'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _StreetSuggestionTile extends StatefulWidget {
  final StreetSuggestion street;
  final VoidCallback onTap;

  const _StreetSuggestionTile({
    required this.street,
    required this.onTap,
  });

  @override
  State<_StreetSuggestionTile> createState() => _StreetSuggestionTileState();
}

class _StreetSuggestionTileState extends State<_StreetSuggestionTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isPressed ? mainColor.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isPressed
                ? mainColor.withValues(alpha: 0.3)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: mainColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.add_road_rounded,
                color: mainColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.street.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.street.fullAddress.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.street.fullAddress,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
