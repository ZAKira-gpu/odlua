// ─────────────────────────────────────────
// Screen: StaticSplashScreen
// Description: Branded splash with logo + fade animation. Calls
//              onComplete after a 2–3 s delay to trigger app init.
// Contains: Logo image, fade animation, status-bar styling
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple static splash screen showing the branded logo
class StaticSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const StaticSplashScreen({super.key, required this.onComplete});

  @override
  State<StaticSplashScreen> createState() => _StaticSplashScreenState();
}

class _StaticSplashScreenState extends State<StaticSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Brand color matching the logo
  static const Color _brandColor = Color(0xFF197533);

  @override
  void initState() {
    super.initState();
    // Hide status bar for immersive splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward();

    // Complete after animation + display time
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        // Restore system UI before transitioning
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _brandColor,
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: SizedBox.expand(
                child: Image.asset(
                  'assets/logos/odlua_branded_splash.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          size: 100,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
