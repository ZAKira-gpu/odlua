// ─────────────────────────────────────────
// Widget: ContinentSelectionStep
// Description: Continent picker step in the manual location flow.
// Contains: Continent tiles, selection callback
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../../controllers/manual_location_controller.dart';
import '../../models/manual_location_data.dart';

/// Step 1: Continent Selection
/// Beautiful grid of continent cards with subtle animations
class ContinentSelectionStep extends StatelessWidget {
  final ManualLocationController controller;
  final Function(ContinentData) onContinentSelected;

  const ContinentSelectionStep({
    super.key,
    required this.controller,
    required this.onContinentSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'location_select_continent'.tr(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'location_continent_subtitle'.tr(),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Continent Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: controller.continents
                  .map((continent) => _ContinentCard(
                        continent: continent,
                        isSelected: controller.selectedContinent == continent,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onContinentSelected(continent);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinentCard extends StatefulWidget {
  final ContinentData continent;
  final bool isSelected;
  final VoidCallback onTap;

  const _ContinentCard({
    required this.continent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ContinentCard> createState() => _ContinentCardState();
}

class _ContinentCardState extends State<_ContinentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? mainColor.withValues(alpha: 0.08)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? mainColor
                  : _isPressed
                      ? mainColor.withValues(alpha: 0.5)
                      : Colors.grey.shade200,
              width: widget.isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _isPressed || widget.isSelected
                    ? mainColor.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: _isPressed ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji
              Text(
                widget.continent.emoji,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                widget.continent.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? mainColor : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Country count
              Text(
                '${widget.continent.countries.length} countries',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
