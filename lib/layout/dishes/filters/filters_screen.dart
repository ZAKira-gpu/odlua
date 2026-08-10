// ─────────────────────────────────────────
// Screen: FiltersScreen
// Description: Bottom-sheet or full-page filter panel for narrowing
//              dish results by category, price range, rating, etc.
// Contains: Filter chips, range sliders, apply/reset buttons
// ─────────────────────────────────────────

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:geolocator/geolocator.dart';
import '../../../utils/theme/custom_themes/main_colors.dart';
import '../../../utils/helpers/debug_helper.dart';

class FiltersScreen extends StatefulWidget {
  final double currentMaxDistance;

  const FiltersScreen({
    super.key,
    required this.currentMaxDistance,
  });

  @override
  State<FiltersScreen> createState() => _FiltersScreenState();
}

class _FiltersScreenState extends State<FiltersScreen> {
  late double _maxDistance;

  @override
  void initState() {
    super.initState();
    DebugHelper.log(
        '🔧 FiltersScreen: Initializing with maxDistance=${widget.currentMaxDistance}');
    // Clamp maxDistance to valid slider range (1.0 - 50.0)
    _maxDistance = widget.currentMaxDistance == double.infinity
        ? 50.0
        : widget.currentMaxDistance.clamp(1.0, 50.0);
    DebugHelper.log(
        '🔧 FiltersScreen: Initialized successfully with clamped maxDistance=$_maxDistance');
  }

  /// Reset all filters to default values
  void _resetFilters() {
    DebugHelper.log('🔧 FiltersScreen: Resetting filters to defaults');
    setState(() {
      _maxDistance = 10.0;
    });
    DebugHelper.log(
        '🔧 FiltersScreen: Filters reset - maxDistance=$_maxDistance');
  }

  /// Check if filters have been changed from initial values
  bool get _hasChanges {
    return _maxDistance != widget.currentMaxDistance;
  }

  /// Check if any filters are active (non-default)
  bool get _hasActiveFilters {
    return _maxDistance < 50.0; // Check against 50km max
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Active Filters Indicator
          if (_hasActiveFilters) _buildActiveFiltersIndicator(),

          // Filters Content
          Expanded(
            child: _buildFiltersContent(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  /// Build app bar with modern design
  AppBar _buildAppBar() {
    return AppBar(
      title: Text(
        'filters'.tr(),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      actions: [
        if (_hasChanges)
          IconButton(
            onPressed: _resetFilters,
            icon: Icon(
              Iconsax.refresh,
              color: Colors.red.shade600,
              size: 22,
            ),
            tooltip: 'filters.reset_all'.tr(),
          ),
      ],
    );
  }

  /// Build active filters indicator with modern chips
  Widget _buildActiveFiltersIndicator() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: mainColor.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(color: mainColor.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.filter, size: 18, color: mainColor),
              const SizedBox(width: 8),
              Text(
                'filters.active_filters'.tr(),
                style: TextStyle(
                  color: mainColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildActiveFilterChips(),
          ),
        ],
      ),
    );
  }

  /// Build individual active filter chips
  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];

    if (_maxDistance < 50.0) {
      chips.add(_buildActiveChip('${_maxDistance.toStringAsFixed(0)}km'));
    }

    return chips;
  }

  /// Build individual active chip
  Widget _buildActiveChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: mainColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mainColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: mainColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.close, size: 14, color: mainColor),
        ],
      ),
    );
  }

  /// Build main filters content
  Widget _buildFiltersContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GPS Permission Section
          _buildGpsPermissionSection(),
          const SizedBox(height: 20),
          // Distance Filter Section
          _buildDistanceFilterSection(),
        ],
      ),
    );
  }

  /// Build GPS permission request section
  Widget _buildGpsPermissionSection() {
    return FutureBuilder<LocationPermission>(
      future: Geolocator.checkPermission(),
      builder: (context, snapshot) {
        final permission = snapshot.data;
        final isGranted = permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;

        if (isGranted) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              Icon(Iconsax.location_slash,
                  size: 40, color: Colors.orange.shade700),
              const SizedBox(height: 12),
              Text(
                'filters.location_required'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'filters.location_description'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.orange.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final permission = await Geolocator.checkPermission();
                    if (permission == LocationPermission.deniedForever) {
                      await Geolocator.openAppSettings();
                    } else {
                      await Geolocator.requestPermission();
                    }
                    setState(() {});
                  },
                  icon: const Icon(Iconsax.location, size: 18),
                  label: Text('filters.enable_location'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build distance filter section with modern design
  Widget _buildDistanceFilterSection() {
    return _buildFilterCard(
      icon: Iconsax.location,
      title: 'filters.max_distance'.tr(),
      value: '${_maxDistance.toStringAsFixed(0)} km',
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 14,
                elevation: 3,
              ),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: 24,
              ),
              activeTrackColor: mainColor,
              inactiveTrackColor: Colors.grey.shade300,
              thumbColor: Colors.white,
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
            ),
            child: Slider(
              value: _maxDistance,
              min: 1,
              max: 50,
              divisions: 49, // 1 to 50 in 1 steps
              label: '${_maxDistance.round()} km',
              onChanged: (value) {
                DebugHelper.log(
                    '🔧 FiltersScreen: Max distance changed to ${value.toStringAsFixed(0)}km');
                setState(() {
                  _maxDistance = value;
                });
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '1 km',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '50 km',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Reusable filter card component
  Widget _buildFilterCard({
    required IconData icon,
    required String title,
    required String value,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: mainColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: mainColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: mainColor.withValues(alpha: 0.2)),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: mainColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          child,
        ],
      ),
    );
  }

  /// Build bottom action bar
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Cancel Button
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'filters.cancel'.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Apply Button
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  // Return filter results with type safety
                  final results = {
                    'maxDistance': _maxDistance,
                  };
                  DebugHelper.log(
                      '🔧 FiltersScreen: Applying filters: $results');
                  Navigator.pop(context, results);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 3,
                  shadowColor: mainColor.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.filter, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'filters.apply_filters'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
