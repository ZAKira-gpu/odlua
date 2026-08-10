// ─────────────────────────────────────────
// Screen: VideoSplashScreen
// Description: Alternative splash that plays a short video before
//              fading to the main app. Falls back to static splash.
// Contains: VideoPlayer controller, completion callback
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Video splash screen using the splash_video.mp4 asset
class VideoSplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const VideoSplashScreen({super.key, required this.onComplete});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;
  bool _isDisposed = false;
  bool _hasError = false;
  bool _isInitialized = false;

  // Brand color matching the logo
  static const Color _brandColor = Color(0xFF197533);

  @override
  void initState() {
    super.initState();
    // Hide status bar for immersive splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/splash_video.mp4');

      await _controller.initialize();

      if (_isDisposed) return;

      // Set video to play once and trigger completion when done
      _controller.addListener(_videoListener);

      setState(() => _isInitialized = true);
      _controller.play();
    } catch (e) {
      DebugHelper.logError('Video initialization error: $e');
      if (!_isDisposed && mounted) {
        setState(() => _hasError = true);
        // Fallback: complete after delay if video fails
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (!_isDisposed && mounted) {
            widget.onComplete();
          }
        });
      }
    }
  }

  void _videoListener() {
    if (_isDisposed) return;

    // Check if video has finished playing
    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      _controller.removeListener(_videoListener);
      if (mounted) {
        // Restore system UI before transitioning
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        widget.onComplete();
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (_isInitialized) {
      _controller.removeListener(_videoListener);
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show fallback if error or not initialized
    if (_hasError || !_isInitialized) {
      return Scaffold(
        backgroundColor: _brandColor,
        body: Center(
          child: Image.asset(
            'assets/logos/odlua_branded_splash.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.restaurant,
                size: 80,
                color: Colors.white,
              );
            },
          ),
        ),
      );
    }

    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    final videoSize = _controller.value.size;

    // Calculate aspect ratios
    final screenAspect = screenSize.width / screenSize.height;
    final videoAspect = videoSize.width / videoSize.height;

    return Scaffold(
      backgroundColor: _brandColor,
      body: Center(
        child: videoAspect > screenAspect
            // Video is wider - fit height, crop width
            ? SizedBox(
                height: screenSize.height,
                child: AspectRatio(
                  aspectRatio: videoAspect,
                  child: VideoPlayer(_controller),
                ),
              )
            // Video is taller - fit width, crop height
            : SizedBox(
                width: screenSize.width,
                child: AspectRatio(
                  aspectRatio: videoAspect,
                  child: VideoPlayer(_controller),
                ),
              ),
      ),
    );
  }
}
