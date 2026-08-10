// ─────────────────────────────────────────
// Widget: CitySelectionStep
// Description: City picker step in the manual location flow.
// Contains: Search field, city list, selection callback
// ─────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../../controllers/manual_location_controller.dart';
import '../../services/location_validation_service.dart';

/// Step 3: City Selection with Validation
/// Search-as-you-type with autocomplete suggestions
/// Must resolve to valid coordinates
class CitySelectionStep extends StatefulWidget {
  final ManualLocationController controller;
  final VoidCallback onCityValidated;

  const CitySelectionStep({
    super.key,
    required this.controller,
    required this.onCityValidated,
  });

  @override
  State<CitySelectionStep> createState() => _CitySelectionStepState();
}

class _CitySelectionStepState extends State<CitySelectionStep> {
  final TextEditingController _cityController = TextEditingController();
  final FocusNode _cityFocus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _cityController.text = widget.controller.selectedCity;
    _cityFocus.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _cityController.dispose();
    _cityFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {});
  }

  void _onCityChanged(String value) {
    widget.controller.setCityManually(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      widget.controller.searchCities(value);
    });
  }

  void _onCitySelected(CitySuggestion city) {
    HapticFeedback.lightImpact();
    _cityController.text = city.name;
    widget.controller.selectCity(city);
    _cityFocus.unfocus();
  }

  Future<void> _onValidate() async {
    HapticFeedback.lightImpact();
    _cityFocus.unfocus();
    await widget.controller.validateCity(_cityController.text);

    if (widget.controller.isCityValid) {
      HapticFeedback.mediumImpact();
      widget.onCityValidated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final countryName = widget.controller.selectedCountry?.name ?? '';
    final countryFlag = widget.controller.selectedCountry?.flag ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Title
          Text(
            'location_select_city'.tr(),
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
              Text(countryFlag, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                countryName,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // City input
          _buildCityInput(),
          const SizedBox(height: 8),

          // Suggestions
          Expanded(
            child: _buildSuggestionsOrValidation(),
          ),

          // Continue button
          _buildContinueButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCityInput() {
    final hasError = widget.controller.errorMessage != null;
    final isValid = widget.controller.isCityValid;

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError
              ? Colors.red.shade300
              : isValid
                  ? Colors.green.shade300
                  : _cityFocus.hasFocus
                      ? mainColor
                      : Colors.grey.shade200,
          width: _cityFocus.hasFocus || isValid ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _cityController,
        focusNode: _cityFocus,
        onChanged: _onCityChanged,
        style: const TextStyle(fontSize: 16),
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _onValidate(),
        decoration: InputDecoration(
          hintText: 'location_city_placeholder'.tr(),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(
            Icons.location_city_rounded,
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
    final suggestions = widget.controller.citySuggestions;
    final error = widget.controller.errorMessage;
    final isValid = widget.controller.isCityValid;

    // Show error
    if (error != null) {
      return _buildErrorState(error);
    }

    // Show validation success
    if (isValid) {
      return _buildValidatedState();
    }

    // Show suggestions
    if (suggestions.isNotEmpty) {
      return ListView.builder(
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final city = suggestions[index];
          return _CitySuggestionTile(
            city: city,
            onTap: () => _onCitySelected(city),
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
            Icons.search_rounded,
            size: 64,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'location_city_hint'.tr(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade400,
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

  Widget _buildValidatedState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                size: 40,
                color: Colors.green.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.controller.selectedCity,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'location_city_validated'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '📍 ${widget.controller.cityLatitude.toStringAsFixed(4)}, ${widget.controller.cityLongitude.toStringAsFixed(4)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final isValid = widget.controller.isCityValid;
    final hasInput = _cityController.text.trim().isNotEmpty;
    final isLoading = widget.controller.isLoading;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : isValid
                ? widget.onCityValidated
                : hasInput
                    ? _onValidate
                    : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isValid ? Colors.green : mainColor,
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
                  if (isValid) ...[
                    const Icon(Icons.check_rounded, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    isValid ? 'continue'.tr() : 'location_validate_city'.tr(),
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

class _CitySuggestionTile extends StatefulWidget {
  final CitySuggestion city;
  final VoidCallback onTap;

  const _CitySuggestionTile({
    required this.city,
    required this.onTap,
  });

  @override
  State<_CitySuggestionTile> createState() => _CitySuggestionTileState();
}

class _CitySuggestionTileState extends State<_CitySuggestionTile> {
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
                Icons.location_city_rounded,
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
                    widget.city.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  if (widget.city.fullName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.city.fullName,
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
