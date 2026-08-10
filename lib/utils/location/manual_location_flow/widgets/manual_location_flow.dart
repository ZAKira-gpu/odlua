// ─────────────────────────────────────────
// Widget: ManualLocationFlowWidget
// Description: Stepper UI wrapper for the manual location flow.
// Contains: StepProgressIndicator, step content
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import '../controllers/manual_location_controller.dart';
import '../models/manual_location_data.dart';
import '../services/location_validation_service.dart';
import '../../location_config.dart';
import 'steps/continent_selection_step.dart';
import 'steps/country_selection_step.dart';
import 'steps/city_selection_step.dart';
import 'steps/street_selection_step.dart';

/// Main wrapper for the 4-step manual location selection flow
/// Million-dollar UI: Clean, minimal, elegant
class ManualLocationFlow extends StatefulWidget {
  final Function(ManualLocationData) onLocationComplete;
  final VoidCallback? onCancel;

  const ManualLocationFlow({
    super.key,
    required this.onLocationComplete,
    this.onCancel,
  });

  @override
  State<ManualLocationFlow> createState() => _ManualLocationFlowState();
}

class _ManualLocationFlowState extends State<ManualLocationFlow>
    with SingleTickerProviderStateMixin {
  late ManualLocationController _controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _initController();
  }

  Future<void> _initController() async {
    final geoapifyKey = await LocationConfig.geoapifyKey();
    final googleKey = await LocationConfig.googlePlacesKey();

    _controller = ManualLocationController(
      validationService: LocationValidationService(
        geoapifyKey: geoapifyKey,
        googlePlacesKey: googleKey,
      ),
    );
    _controller.addListener(_onControllerUpdate);

    setState(() => _isInitialized = true);
    _animationController.forward();
  }

  void _onControllerUpdate() {
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onBack() {
    HapticFeedback.lightImpact();
    if (_controller.canGoBack) {
      _animateTransition(() => _controller.goBack());
    } else {
      widget.onCancel?.call();
    }
  }

  void _onNext() {
    HapticFeedback.lightImpact();
    if (_controller.currentStep == 3 && _controller.isComplete) {
      // Complete the flow
      final location = _controller.getLocationData();
      if (location != null) {
        HapticFeedback.mediumImpact();
        widget.onLocationComplete(location);
      }
    } else {
      _animateTransition(() => _controller.goNext());
    }
  }

  void _animateTransition(VoidCallback action) {
    _animationController.reverse().then((_) {
      action();
      _animationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),

            // Progress Indicator
            _buildProgressIndicator(),

            // Step Content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: _onBack,
            icon: Icon(
              _controller.canGoBack ? Icons.arrow_back_ios : Icons.close,
              color: Colors.black87,
              size: 22,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Spacer(),
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: mainColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step ${_controller.currentStep + 1} of ${_controller.totalSteps}',
              style: TextStyle(
                color: mainColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: List.generate(_controller.totalSteps, (index) {
          final isActive = index <= _controller.currentStep;
          final isCurrent = index == _controller.currentStep;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              height: isCurrent ? 6 : 4,
              decoration: BoxDecoration(
                color: isActive ? mainColor : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_controller.currentStep) {
      case 0:
        return ContinentSelectionStep(
          controller: _controller,
          onContinentSelected: (continent) {
            _controller.selectContinent(continent);
            _animateTransition(() => _controller.goNext());
          },
        );
      case 1:
        return CountrySelectionStep(
          controller: _controller,
          onCountrySelected: (country) {
            _controller.selectCountry(country);
            _animateTransition(() => _controller.goNext());
          },
        );
      case 2:
        return CitySelectionStep(
          controller: _controller,
          onCityValidated: () {
            _animateTransition(() => _controller.goNext());
          },
        );
      case 3:
        return StreetSelectionStep(
          controller: _controller,
          onComplete: _onNext,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
