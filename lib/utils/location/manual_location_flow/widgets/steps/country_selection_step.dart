// ─────────────────────────────────────────
// Widget: CountrySelectionStep
// Description: Country picker step in the manual location flow.
// Contains: Country list, flag icons, selection callback
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../../controllers/manual_location_controller.dart';
import '../../models/manual_location_data.dart';

/// Step 2: Country Selection
/// Searchable list of countries with flags, alphabetically sorted
class CountrySelectionStep extends StatefulWidget {
  final ManualLocationController controller;
  final Function(CountryData) onCountrySelected;

  const CountrySelectionStep({
    super.key,
    required this.controller,
    required this.onCountrySelected,
  });

  @override
  State<CountrySelectionStep> createState() => _CountrySelectionStepState();
}

class _CountrySelectionStepState extends State<CountrySelectionStep> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.controller.countrySearchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final countries = widget.controller.availableCountries;
    final continentName = widget.controller.selectedContinent?.name ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          // Title
          Text(
            'location_select_country'.tr(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'location_country_subtitle'.tr(args: [continentName]),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Search bar
          _buildSearchBar(),
          const SizedBox(height: 16),

          // Country list
          Expanded(
            child: countries.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: countries.length,
                    itemBuilder: (context, index) {
                      final country = countries[index];
                      return _CountryTile(
                        country: country,
                        isSelected:
                            widget.controller.selectedCountry == country,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onCountrySelected(country);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: (value) {
          widget.controller.setCountrySearchQuery(value);
        },
        style: const TextStyle(fontSize: 16),
        decoration: InputDecoration(
          hintText: 'location_search_country'.tr(),
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.grey.shade400,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    widget.controller.setCountrySearchQuery('');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.grey.shade400,
                    size: 20,
                  ),
                )
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'location_no_countries_found'.tr(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryTile extends StatefulWidget {
  final CountryData country;
  final bool isSelected;
  final VoidCallback onTap;

  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CountryTile> createState() => _CountryTileState();
}

class _CountryTileState extends State<_CountryTile> {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? mainColor.withValues(alpha: 0.08)
              : _isPressed
                  ? Colors.grey.shade50
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected
                ? mainColor
                : _isPressed
                    ? mainColor.withValues(alpha: 0.3)
                    : Colors.grey.shade200,
            width: widget.isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Flag
            Text(
              widget.country.flag,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(width: 14),
            // Country name
            Expanded(
              child: Text(
                widget.country.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: widget.isSelected ? mainColor : Colors.black87,
                ),
              ),
            ),
            // Check mark
            if (widget.isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: mainColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
