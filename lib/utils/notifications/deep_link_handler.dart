// ─────────────────────────────────────────
// Service: DeepLinkHandler
// Description: Handles incoming deep links and routes to the correct screen.
// Contains: processLink, pendingLink, navigatorKey
// ─────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/layout/seller/chef_dashboard/chef_dashboard_screen.dart';
import 'package:odlua/layout/client_orders/client_orders_screen.dart';
import 'package:odlua/layout/notifications/notifications_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/services/chat_controller.dart';

class DeepLinkHandler {
  static final DeepLinkHandler _instance = DeepLinkHandler._internal();
  factory DeepLinkHandler() => _instance;
  DeepLinkHandler._internal();

  static DeepLinkHandler get instance => _instance;

  GlobalKey<NavigatorState>? _navigatorKey;

  // Store pending deep link for when app is still loading
  Map<String, dynamic>? _pendingDeepLink;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;

    // Process any pending deep link once navigator is set
    if (_pendingDeepLink != null) {
      DebugHelper.logInfo(
          '🔗 Processing pending deep link after navigator set');
      handleDeepLink(_pendingDeepLink!);
      _pendingDeepLink = null;
    }
  }

  /// Handle deep link navigation. Returns true if handled successfully.
  Future<bool> handleDeepLink(Map<String, dynamic> data) async {
    try {
      final type = data['type']?.toString();
      DebugHelper.logInfo('🔗 Handling deep link of type: $type');
      DebugHelper.logInfo('🔗 Deep link data: $data');

      // Wait for navigator to be ready with retry mechanism
      // This is critical for app opened from terminated state
      bool navigatorReady = await _waitForNavigator();

      if (!navigatorReady) {
        // Store for later processing if navigator not ready
        DebugHelper.logWarning(
            '⚠️ Navigator not ready, storing pending deep link');
        _pendingDeepLink = data;
        return false;
      }

      final navigator = _navigatorKey!.currentState!;

      switch (type) {
        case 'chat_message':
          return _navigateToChat(navigator, data);
        case 'new_order':
        case 'order_created':
        case 'order_update':
        case 'order_preparing':
        case 'order_ready':
        case 'order_completed':
        case 'order_cancelled':
          return _navigateToOrders(navigator, data);
        case 'general':
        case 'promo':
        case 'marketing':
        case 'notification':
          // For general notifications, navigate to notifications screen
          return _navigateToNotifications(navigator, data);
        default:
          // For unknown types, navigate to notifications as fallback
          DebugHelper.logWarning(
              '⚠️ Unknown deep link type: $type, navigating to notifications');
          return _navigateToNotifications(navigator, data);
      }
    } catch (e) {
      DebugHelper.logError('❌ Error handling deep link: $e');
      return false;
    }
  }

  /// Wait for navigator to be ready with retry mechanism
  Future<bool> _waitForNavigator() async {
    const maxRetries = 30; // Increased from 10 - app may take longer to load
    const retryDelay = Duration(milliseconds: 200);

    for (int i = 0; i < maxRetries; i++) {
      if (_navigatorKey != null && _navigatorKey!.currentState != null) {
        DebugHelper.logInfo('✅ Navigator ready after ${i + 1} attempts');
        return true;
      }
      if (i % 5 == 0) {
        // Log every 5 attempts to reduce noise
        DebugHelper.logInfo(
            '⏳ Waiting for navigator (attempt ${i + 1}/$maxRetries)');
      }
      await Future.delayed(retryDelay);
    }

    DebugHelper.logWarning(
        '⚠️ Navigator still not ready after $maxRetries attempts');
    return false;
  }

  bool _navigateToChat(NavigatorState navigator, Map<String, dynamic> data) {
    final chatId = data['chatId']?.toString();
    final recipientId =
        data['senderId']?.toString() ?? data['recipientId']?.toString();
    final recipientName = data['senderName']?.toString() ?? 'Chat';
    final recipientImage = data['senderImage']?.toString();

    if (chatId == null && recipientId == null) {
      DebugHelper.logWarning(
          '⚠️ Cannot navigate to chat: missing chatId and recipientId');
      return false;
    }

    // Check if user is already in this chat - skip navigation to prevent duplicates
    if (chatId != null && ChatConversationController.isInChat(chatId)) {
      DebugHelper.logInfo(
          'ℹ️ User already in chat $chatId, skipping navigation');
      return true;
    }

    // Use the new chat conversation screen
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: chatId ?? '',
          recipientId: recipientId ?? '',
          recipientName: recipientName,
          recipientImage: recipientImage,
        ),
      ),
    );
    DebugHelper.logSuccess('✅ Navigated to chat: $chatId');
    return true;
  }

  bool _navigateToOrders(NavigatorState navigator, Map<String, dynamic> data) {
    // Check if user is a chef (order notifications for chefs go to chef dashboard)
    // For now, navigate to client orders - could be enhanced to check user role
    final screen = data['screen']?.toString();

    if (screen == 'chef_order_management') {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const ChefDashboardScreen(),
        ),
      );
      DebugHelper.logSuccess('✅ Navigated to chef dashboard');
    } else {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => const ClientOrdersScreen(),
        ),
      );
      DebugHelper.logSuccess('✅ Navigated to client orders');
    }
    return true;
  }

  bool _navigateToNotifications(
      NavigatorState navigator, Map<String, dynamic> data) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
    DebugHelper.logSuccess('✅ Navigated to notifications');
    return true;
  }
}
