// ─────────────────────────────────────────
// Widget: InAppNotificationBanner
// Description: Top-of-screen notification banner for real-time alerts.
// Contains: Show/dismiss animation, tap handler
// ─────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// A professional in-app notification banner that slides down from the top
/// and auto-dismisses after a configurable duration.
class InAppNotificationBanner {
  static OverlayEntry? _currentOverlay;
  static Timer? _dismissTimer;

  /// Show a notification banner at the top of the screen
  ///
  /// [type] - The type of notification (chat, order, reservation, promo)
  /// [title] - The notification title
  /// [body] - The notification body text
  /// [onTap] - Callback when the banner is tapped
  /// [duration] - How long to show the banner (default: 4 seconds)
  static void show(
    BuildContext context, {
    required String type,
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Dismiss any existing banner
    dismiss();

    final overlay = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => _NotificationBannerWidget(
        type: type,
        title: title,
        body: body,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss after duration
    _dismissTimer = Timer(duration, dismiss);
  }

  /// Dismiss the current banner if one is showing
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final String type;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;

  const _NotificationBannerWidget({
    required this.type,
    required this.title,
    required this.body,
    this.onTap,
    required this.onDismiss,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case 'chat_message':
        return Iconsax.message;
      case 'new_order':
      case 'order_created':
      case 'order_confirmed':
      case 'order_preparing':
      case 'order_ready':
      case 'order_completed':
        return Iconsax.shopping_bag;
      case 'reservation_update':
      case 'reservation_request':
      case 'reservation_confirmed':
        return Iconsax.calendar;
      case 'promo':
        return Iconsax.tag;
      default:
        return Iconsax.notification;
    }
  }

  Color _getColor() {
    switch (widget.type) {
      case 'chat_message':
        return const Color(0xFF2196F3); // Blue
      case 'new_order':
      case 'order_created':
      case 'order_confirmed':
      case 'order_preparing':
      case 'order_ready':
      case 'order_completed':
        return const Color(0xFF4CAF50); // Green
      case 'reservation_update':
      case 'reservation_request':
      case 'reservation_confirmed':
        return const Color(0xFFFF9800); // Orange
      case 'promo':
        return const Color(0xFF9C27B0); // Purple
      default:
        return const Color(0xFF607D8B); // Blue Grey
    }
  }

  Future<void> _animateOut() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();
    final icon = _getIcon();
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Dismissible(
            key: const Key('notification_banner'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: GestureDetector(
              onTap: widget.onTap,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! < 0) {
                  _animateOut();
                }
              },
              child: Container(
                margin: EdgeInsets.only(
                  top: statusBarHeight + 8,
                  left: 12,
                  right: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: color,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Icon Container
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              icon,
                              color: color,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  widget.body,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Close button
                          GestureDetector(
                            onTap: () => _animateOut(),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Extension to show notifications more easily
extension InAppNotificationContext on BuildContext {
  void showNotificationBanner({
    required String type,
    required String title,
    required String body,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    InAppNotificationBanner.show(
      this,
      type: type,
      title: title,
      body: body,
      onTap: onTap,
      duration: duration,
    );
  }
}
