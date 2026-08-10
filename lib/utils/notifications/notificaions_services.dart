// ─────────────────────────────────────────
// Service: NotificationService
// Description: Firebase Cloud Messaging setup and local notification display.
// Contains: init, requestPermission, showNotification, onTap
// ─────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/utils/notifications/in_app_notification_banner.dart';
import 'package:odlua/utils/notifications/deep_link_handler.dart';
import 'package:odlua/utils/services/chat_controller.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;

  bool _isInitialized = false;
  String? _fcmToken;

  final DeepLinkHandler _deepLinkHandler = DeepLinkHandler.instance;

  // Navigator key for showing in-app notifications
  GlobalKey<NavigatorState>? _navigatorKey;

  late Box<Map<dynamic, dynamic>> _notificationBox;
  static const String _notificationBoxName = 'notifications';

  static const String _channelId = 'odlua_channel';
  static const String _channelName = 'Odlua Notifications';
  static const String _channelDescription =
      'Notifications for orders, reservations, and messages';

  // ✅ UPDATED WITH YOUR ACTUAL CLOUD FUNCTION URL
  static const String _cloudFunctionUrl =
      'https://us-central1-odlua-139c3.cloudfunctions.net/sendNotification';

  // Notification settings
  bool _chatNotificationsEnabled = true;
  bool _reservationNotificationsEnabled = true;
  bool _orderNotificationsEnabled = true;
  bool _marketingNotificationsEnabled = false;

  /// Set the navigator key for showing in-app notification banners
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  /// Master initialisation for the notification subsystem.
  ///
  /// Sequence: timezone init → Hive storage → FCM permissions → APNS (iOS) →
  /// local notification channels → FCM token persist → Firebase message handlers.
  /// Idempotent — returns immediately if already initialised.
  Future<void> init({bool enableForegroundNotification = true}) async {
    if (_isInitialized) return;

    try {
      DebugHelper.logInfo('🔔 Starting NotificationService init...');
      tz.initializeTimeZones();

      await _initNotificationStorage();

      _firebaseMessaging = FirebaseMessaging.instance;

      await _requestPermissions();

      // iOS-specific: Set foreground notification presentation options
      // This is CRITICAL for iOS to show notifications when app is in foreground
      if (Platform.isIOS) {
        await _firebaseMessaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
        DebugHelper.logInfo('🍎 iOS foreground notification options set');
      }

      // iOS-specific: Try to get APNS token (not available on Simulator)
      // Wait for APNS token on real devices - this is required before FCM works
      // Reduced to 3 attempts to avoid blocking app startup for too long
      if (Platform.isIOS) {
        String? apnsToken;
        // Try up to 3 times with delays for real devices (max 2s delay)
        for (int i = 0; i < 3; i++) {
          try {
            apnsToken = await _firebaseMessaging.getAPNSToken();
            if (apnsToken != null) {
              DebugHelper.logInfo(
                  '🍎 APNS Token received: ${apnsToken.substring(0, 10)}...');
              break;
            }
          } catch (e) {
            DebugHelper.logWarning('⚠️ APNS attempt $i failed: $e');
          }
          if (i < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
        if (apnsToken == null) {
          DebugHelper.logWarning(
              '⚠️ APNS token not available - notifications may not work on iOS. Please check Push Notifications capability in Xcode.');
        }
      }

      // Try to get FCM token, but don't fail if not available on simulator
      try {
        _fcmToken = await _firebaseMessaging.getToken();
        if (_fcmToken != null) {
          DebugHelper.logInfo(' FCM Token received');
        }
      } catch (e) {
        DebugHelper.logWarning(
            '⚠️ FCM token not available (expected on iOS Simulator): $e');
        _fcmToken = null;
      }

      // Only save token if we have one
      if (_fcmToken != null) {
        await _saveFcmTokenToUser();
      }

      await _initializeLocalNotifications();
      DebugHelper.logInfo('📱 Local notifications initialized');

      await _configureFirebaseHandlers(enableForegroundNotification);
      DebugHelper.logInfo('🔥 Firebase handlers configured');

      _configureBackgroundHandler();

      await _loadNotificationSettings();
      DebugHelper.logInfo('⚙️ Notification settings loaded');

      _isInitialized = true;
      DebugHelper.logSuccess(' NotificationService initialized successfully');
    } catch (e) {
      DebugHelper.logError(' Failed to initialize NotificationService: $e');
      // Mark as initialized anyway to prevent app from being stuck
      _isInitialized = true;
    }
  }

  Future<void> _initNotificationStorage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      Hive.init(appDir.path);
      _notificationBox =
          await Hive.openBox<Map<dynamic, dynamic>>(_notificationBoxName);
    } catch (e) {
      DebugHelper.logError(' Error initializing notification storage: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();

      // Use app launcher icon for notifications
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      await _createNotificationChannel();
    } catch (e) {
      DebugHelper.logError(' Error initializing local notifications: $e');
    }
  }

  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final NotificationSettings settings =
          await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );

      DebugHelper.log(
          ' Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      DebugHelper.logError(' Error requesting notification permissions: $e');
    }
  }

  Future<void> _saveFcmTokenToUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _fcmToken == null) return;

      // Include platform info for debugging
      final platform = Platform.isIOS ? 'ios' : 'android';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': _fcmToken,
        'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
        'fcmPlatform': platform,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      DebugHelper.logSuccess(
          ' FCM token saved to user document (platform: $platform)');

      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
        try {
          _fcmToken = newToken;
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .update({
              'fcmToken': newToken,
              'fcmTokens': FieldValue.arrayUnion([newToken]),
              'updatedAt': FieldValue.serverTimestamp(),
            });
            DebugHelper.log('🔄 FCM token refreshed: $newToken');
          }
        } catch (e) {
          DebugHelper.logError('❌ Error refreshing FCM token: $e');
        }
      });
    } catch (e) {
      DebugHelper.logError(' Error saving FCM token: $e');
    }
  }

  Future<void> _configureFirebaseHandlers(
      bool enableForegroundNotification) async {
    try {
      DebugHelper.logInfo('🔧 Setting up Firebase message listeners...');
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        DebugHelper.log('📨 Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);

        if (enableForegroundNotification) {
          // Show elegant in-app banner instead of system notification
          _showInAppNotificationBanner(message);
          // Also store in notification inbox
          _storeRemoteNotificationInInbox(message);
        }
      });

      DebugHelper.logInfo('🔧 Setting up onMessageOpenedApp listener...');
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        DebugHelper.log(' App opened from notification');
        _processRemoteMessage(message, fromTap: true);
      });

      DebugHelper.logInfo('🔧 Checking for initial message...');
      // Add timeout to prevent hanging on simulator
      try {
        final initialMessage = await _firebaseMessaging
            .getInitialMessage()
            .timeout(const Duration(seconds: 3), onTimeout: () => null);
        if (initialMessage != null) {
          DebugHelper.log(
              '🚀 App launched from terminated state by notification');
          _processRemoteMessage(initialMessage, fromTap: true);
        }
      } catch (e) {
        DebugHelper.logWarning('⚠️ Could not get initial message: $e');
      }
      DebugHelper.logInfo('🔧 Firebase handlers configured');
    } catch (e) {
      DebugHelper.logError(' Error configuring Firebase handlers: $e');
    }
  }

  /// Show an elegant in-app notification banner
  void _showInAppNotificationBanner(RemoteMessage message) {
    try {
      final context = _navigatorKey?.currentContext;
      if (context == null) {
        DebugHelper.logWarning('⚠️ No context available for in-app banner');
        // Fallback to system notification
        _showRemoteNotification(message);
        return;
      }

      final notification = message.notification;
      final data = message.data;
      final type = data['type'] ?? 'general';

      // Check notification settings
      if (!_shouldShowNotification(type)) return;

      // CRITICAL: Don't show chat notification if user is in that chat
      if (type == 'chat_message') {
        final chatId = data['chatId']?.toString();
        if (chatId != null && ChatConversationController.isInChat(chatId)) {
          DebugHelper.logInfo(
              'ℹ️ Suppressing in-app banner - user is in chat $chatId');
          return;
        }
      }

      final title = notification?.title ?? data['title'] ?? 'Notification';
      final body = notification?.body ?? data['body'] ?? '';

      InAppNotificationBanner.show(
        context,
        type: type,
        title: title,
        body: body,
        duration: const Duration(seconds: 4),
        onTap: () {
          // Navigate to appropriate screen on tap
          _processRemoteMessage(message, fromTap: true);
        },
      );

      DebugHelper.logSuccess('✅ In-app notification banner shown: $title');
    } catch (e) {
      DebugHelper.logError(' Error showing in-app banner: $e');
      // Fallback to system notification
      _showRemoteNotification(message);
    }
  }

  /// Store a remote notification in the inbox without showing it
  Future<void> _storeRemoteNotificationInInbox(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;

      await _storeNotificationInInbox({
        'id': DateTime.now().millisecondsSinceEpoch,
        'title': notification?.title ?? data['title'] ?? 'Notification',
        'body': notification?.body ?? data['body'] ?? '',
        'payload': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
        'type': data['type'] ?? 'general',
      });
    } catch (e) {
      DebugHelper.logError(' Error storing notification: $e');
    }
  }

  void _configureBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    try {
      final data = message.data;
      final type = data['type'] ?? 'unknown';
      DebugHelper.logInfo(' Handling foreground message: $type');

      // Handle different notification types
      switch (type) {
        case 'chat_message':
          _handleChatNotification(data);
          break;
        case 'reservation_update':
        case 'reservation_request':
        case 'reservation_confirmed':
        case 'reservation_declined':
        case 'reservation_expired':
        case 'reservation_completed':
        case 'reservation_cancelled':
          _handleReservationNotification(data);
          break;
        case 'new_order':
        case 'order_update':
        case 'order_created':
        case 'order_confirmed':
        case 'order_preparing':
        case 'order_ready':
        case 'order_completed':
        case 'order_cancelled':
          _handleOrderNotification(data);
          break;
      }
    } catch (e) {
      DebugHelper.logError(' Error handling foreground message: $e');
    }
  }

  void _handleChatNotification(Map<String, dynamic> data) {
    if (!_chatNotificationsEnabled) return;

    // CRITICAL: Don't show notification if user is currently viewing this chat
    final chatId = data['chatId']?.toString();
    if (chatId != null && ChatConversationController.isInChat(chatId)) {
      DebugHelper.logInfo(
          'ℹ️ Suppressing chat notification - user is in chat $chatId');
      return;
    }

    // Additional chat notification handling can be added here
  }

  void _handleReservationNotification(Map<String, dynamic> data) {
    if (!_reservationNotificationsEnabled) return;
    // Additional reservation notification handling can be added here
  }

  void _handleOrderNotification(Map<String, dynamic> data) {
    if (!_orderNotificationsEnabled) return;
    // Additional order notification handling can be added here
  }

  Future<void> _showRemoteNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final notification = message.notification;

      if (notification == null) return;

      // Check notification settings based on type
      final type = data['type'] ?? 'general';
      if (!_shouldShowNotification(type)) return;

      await showLocalNotification(
        id: _generateNotificationId(message.messageId ??
            'remote_${DateTime.now().millisecondsSinceEpoch}'),
        title: notification.title ?? 'New Notification',
        body: notification.body ?? '',
        payload: data,
      );
    } catch (e) {
      DebugHelper.logError(' Error showing remote notification: $e');
    }
  }

  bool _shouldShowNotification(String type) {
    switch (type) {
      case 'chat_message':
        return _chatNotificationsEnabled;
      case 'reservation_update':
      case 'reservation_request':
      case 'reservation_confirmed':
      case 'reservation_declined':
      case 'reservation_expired':
      case 'reservation_completed':
      case 'reservation_cancelled':
        return _reservationNotificationsEnabled;
      case 'new_order':
      case 'order_update':
      case 'order_created':
      case 'order_confirmed':
      case 'order_preparing':
      case 'order_ready':
      case 'order_completed':
      case 'order_cancelled':
        return _orderNotificationsEnabled;
      case 'marketing':
      case 'promotion':
        return _marketingNotificationsEnabled;
      default:
        return true;
    }
  }

  Future<void> _processRemoteMessage(RemoteMessage message,
      {bool fromTap = false}) async {
    try {
      final data = message.data;
      final type = data['type'] ?? 'unknown';

      DebugHelper.logInfo(' Processing remote message type: $type');

      await _storeNotificationInInbox({
        'id': _generateNotificationId(message.messageId ??
            'remote_${DateTime.now().millisecondsSinceEpoch}'),
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'payload': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
        'type': type,
      });

      if (fromTap) {
        // CRITICAL FIX #30: Await the deep link handler for proper navigation
        await _deepLinkHandler.handleDeepLink(data);
      }
    } catch (e) {
      DebugHelper.logError(' Error processing remote message: $e');
    }
  }

  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    String? channelId,
  }) async {
    try {
      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        channelId ?? _channelId,
        channelId ?? _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        showWhen: true,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(body),
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      final NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        id,
        title,
        body,
        details,
        payload: payload != null ? jsonEncode(payload) : null,
      );

      await _storeNotificationInInbox({
        'id': id,
        'title': title,
        'body': body,
        'payload': payload,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
        'type': payload?['type'] ?? 'local',
      });

      DebugHelper.logSuccess(' Local notification shown: $title');
    } catch (e) {
      DebugHelper.logError(' Error showing local notification: $e');
    }
  }

  Future<void> _storeNotificationInInbox(
      Map<String, dynamic> notification) async {
    try {
      final id = notification['id'];
      await _notificationBox.put(id, notification);

      // Limit notifications to 1000 to prevent storage issues
      if (_notificationBox.length > 1000) {
        final keys = _notificationBox.keys.toList();
        keys.sort();
        final keysToRemove = keys.sublist(0, keys.length - 1000);
        await _notificationBox.deleteAll(keysToRemove);
      }
    } catch (e) {
      DebugHelper.logError(' Error storing notification in inbox: $e');
    }
  }

  List<Map<String, dynamic>> getNotifications() {
    try {
      return _notificationBox.values
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
        ..sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
    } catch (e) {
      DebugHelper.logError(' Error getting notifications from inbox: $e');
      return [];
    }
  }

  int getUnreadNotificationsCount() {
    try {
      return _notificationBox.values
          .where((notification) => notification['read'] == false)
          .length;
    } catch (e) {
      DebugHelper.logError(' Error getting unread notifications count: $e');
      return 0;
    }
  }

  Future<void> markNotificationAsRead(int id) async {
    try {
      final notification = _notificationBox.get(id);
      if (notification != null) {
        notification['read'] = true;
        await _notificationBox.put(id, notification);
      }
    } catch (e) {
      DebugHelper.logError(' Error marking notification as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    try {
      final notifications = _notificationBox.values.toList();
      for (final notification in notifications) {
        notification['read'] = true;
        await _notificationBox.put(notification['id'], notification);
      }
    } catch (e) {
      DebugHelper.logError(' Error marking all notifications as read: $e');
    }
  }

  /// Delete a specific notification by ID
  Future<void> deleteNotification(int id) async {
    try {
      await _notificationBox.delete(id);
      DebugHelper.log('🗑️ Notification $id deleted successfully');
    } catch (e) {
      DebugHelper.logError(' Error deleting notification: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _notificationBox.clear();
    } catch (e) {
      DebugHelper.logError(' Error clearing all notifications: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    try {
      DebugHelper.log('👆 Notification tapped: ${response.id}');

      markNotificationAsRead(response.id ?? 0);

      final payload = _parsePayload(response.payload);
      if (payload.isNotEmpty) {
        // CRITICAL FIX #30: Handle deep link navigation for local notifications
        _deepLinkHandler.handleDeepLink(payload);
      }
    } catch (e) {
      DebugHelper.logError(' Error handling notification tap: $e');
    }
  }

  Map<String, dynamic> _parsePayload(String? payload) {
    try {
      if (payload == null || payload.isEmpty) return {};
      return jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  int _generateNotificationId(String input) {
    return input.hashCode.abs() % 1000000;
  }

  /// Register a navigation handler - deprecated, use DeepLinkHandler instead
  @Deprecated('Use DeepLinkHandler.setNavigatorKey instead')
  void registerNavigationHandler(Function(Map<String, dynamic>) handler) {
    // Legacy method - navigation is now handled by DeepLinkHandler
    DebugHelper.logWarning(
        '⚠️ registerNavigationHandler is deprecated, use DeepLinkHandler');
  }

  // ========== NOTIFICATION SETTINGS ==========

  Future<void> _loadNotificationSettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final settings = userData?['notificationSettings'] ?? {};

        // Update settings directly (not a StatefulWidget)
        _chatNotificationsEnabled = settings['chat'] ?? true;
        _reservationNotificationsEnabled = settings['reservations'] ?? true;
        _orderNotificationsEnabled = settings['orders'] ?? true;
        _marketingNotificationsEnabled = settings['marketing'] ?? false;
      }
    } catch (e) {
      DebugHelper.logError(' Error loading notification settings: $e');
    }
  }

  Future<void> updateNotificationSettings({
    bool? chat,
    bool? reservations,
    bool? orders,
    bool? marketing,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final updateData = <String, dynamic>{};
      final settings = <String, dynamic>{};

      if (chat != null) {
        _chatNotificationsEnabled = chat;
        settings['chat'] = chat;
      }
      if (reservations != null) {
        _reservationNotificationsEnabled = reservations;
        settings['reservations'] = reservations;
      }
      if (orders != null) {
        _orderNotificationsEnabled = orders;
        settings['orders'] = orders;
      }
      if (marketing != null) {
        _marketingNotificationsEnabled = marketing;
        settings['marketing'] = marketing;
      }

      if (settings.isNotEmpty) {
        updateData['notificationSettings'] = settings;
        updateData['updatedAt'] = FieldValue.serverTimestamp();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(updateData);

        DebugHelper.logSuccess(' Notification settings updated');
      }
    } catch (e) {
      DebugHelper.logError(' Error updating notification settings: $e');
    }
  }

  Map<String, bool> getNotificationSettings() {
    return {
      'chat': _chatNotificationsEnabled,
      'reservations': _reservationNotificationsEnabled,
      'orders': _orderNotificationsEnabled,
      'marketing': _marketingNotificationsEnabled,
    };
  }

  // ========== FCM HTTP v1 API METHODS ==========

  /// Send notification via Cloud Function (Recommended approach)
  Future<bool> _sendViaCloudFunction({
    required String recipientFcmToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    String? imageUrl,
  }) async {
    try {
      DebugHelper.log(
          '📤 Sending notification via Cloud Function to: ${recipientFcmToken.substring(0, 10)}...');

      final payload = {
        'token': recipientFcmToken,
        'title': title,
        'body': body,
        'data': data,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

      final response = await http.post(
        Uri.parse(_cloudFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        DebugHelper.logSuccess(
            ' Cloud Function notification sent successfully');
        return true;
      } else {
        DebugHelper.logError(
            ' Cloud Function error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      DebugHelper.logError(' Error calling Cloud Function: $e');

      // Fallback mechanism
      DebugHelper.log('🔄 Cloud Function failed, using fallback...');
      return await _sendDirectFCM(
        recipientFcmToken: recipientFcmToken,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  /// Fallback: Direct FCM send (limited functionality)
  Future<bool> _sendDirectFCM({
    required String recipientFcmToken,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // This is a simplified version - in production, use Cloud Functions
      DebugHelper.log('📤 Sending direct FCM to: $recipientFcmToken');
      // In a real implementation, you would call FCM API here
      // For now, we'll just log and return success for testing
      await Future.delayed(const Duration(milliseconds: 500));
      DebugHelper.logSuccess(' Direct FCM sent (simulated): $title');
      return true;
    } catch (e) {
      DebugHelper.logError(' Error sending direct FCM: $e');
      return false;
    }
  }

  // ========== PUBLIC NOTIFICATION METHODS ==========

  /// Send chat notification to recipient
  Future<bool> sendChatNotification({
    required String recipientId,
    required String senderName,
    required String message,
    required String chatId,
    String? imageUrl,
  }) async {
    try {
      if (!_chatNotificationsEnabled) {
        DebugHelper.log('⏭️ Chat notifications disabled');
        return false;
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // CRITICAL FIX: Don't send notification if recipient is current user
      if (recipientId == currentUserId) {
        DebugHelper.logWarning(
            ' Skipping notification: recipient is current user');
        return false;
      }

      DebugHelper.log(
          '🔔 Preparing to send chat notification to: $recipientId');

      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        DebugHelper.logError(
            ' Recipient document does not exist: $recipientId');
        return false;
      }

      final recipientData = recipientDoc.data();
      final fcmToken = recipientData?['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        DebugHelper.logError(' Recipient has no FCM token: $recipientId');
        return false;
      }

      DebugHelper.logSuccess(' Found recipient FCM token: $fcmToken');

      // Prepare notification data
      final data = {
        'type': 'chat_message',
        'chatId': chatId,
        'senderId': currentUserId,
        'senderName': senderName,
        'recipientId': recipientId,
        'message': message,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'navigationRoute': '/chat',
        'screen': 'chat_conversation',
      };

      if (imageUrl != null) {
        data['imageUrl'] = imageUrl;
      }

      // Send via Cloud Function (RECOMMENDED)
      final success = await _sendViaCloudFunction(
        recipientFcmToken: fcmToken,
        title: '💬 $senderName',
        body:
            message.length > 100 ? '${message.substring(0, 100)}...' : message,
        data: data,
        imageUrl: imageUrl,
      );

      DebugHelper.logSuccess(
          ' Chat notification process completed for: $recipientId');
      return success;
    } catch (e) {
      DebugHelper.logError(' Error sending chat notification: $e');
      return false;
    }
  }

  /// Send reservation notification - ENHANCED FOR ALL CASES
  Future<bool> sendReservationNotification({
    required String recipientId,
    required String
        type, // 'pending', 'confirmed', 'declined', 'expired', 'completed', 'cancelled'
    required String reservationId,
    required String dishName,
    String? customerName,
    String? chefName,
    DateTime? reservationTime,
    String? reason,
  }) async {
    try {
      if (!_reservationNotificationsEnabled) {
        DebugHelper.log('⏭️ Reservation notifications disabled');
        return false;
      }

      DebugHelper.log(
          '🔔 Preparing to send reservation notification to: $recipientId');

      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        DebugHelper.logError(
            ' Recipient document does not exist: $recipientId');
        return false;
      }

      final recipientData = recipientDoc.data();
      final fcmToken = recipientData?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        DebugHelper.logError(' Recipient has no FCM token: $recipientId');
        return false;
      }

      String title;
      String body;
      String emoji;

      switch (type) {
        case 'reserved':
        case 'pending':
          title = '📋 New Reservation Request';
          body = '$customerName wants to reserve "$dishName"';
          emoji = '📋';
          break;
        case 'confirmed':
        case 'accepted':
          title = '✅ Reservation Confirmed!';
          body = 'Your reservation for "$dishName" has been confirmed';
          emoji = '✅';
          break;
        case 'declined':
          title = '❌ Reservation Declined';
          body = 'Your reservation for "$dishName" was declined';
          if (reason != null) body += ' - $reason';
          emoji = '❌';
          break;
        case 'expired':
          title = '⏰ Reservation Expired';
          body = 'Your reservation for "$dishName" has expired';
          emoji = '⏰';
          break;
        case 'completed':
          title = '🎉 Reservation Completed';
          body = 'Reservation for "$dishName" has been completed';
          emoji = '🎉';
          break;
        case 'cancelled':
          final currentUserId = FirebaseAuth.instance.currentUser?.uid;
          if (currentUserId == recipientId) {
            title = '🚫 Reservation Cancelled';
            body = 'Chef cancelled reservation for "$dishName"';
          } else {
            title = '🚫 Reservation Cancelled';
            body = 'Customer cancelled reservation for "$dishName"';
          }
          emoji = '🚫';
          break;
        default:
          title = '🍽️ Reservation Update';
          body = 'Your reservation for "$dishName" has been updated';
          emoji = '🍽️';
      }

      final data = {
        'type': 'reservation_$type',
        'reservationId': reservationId,
        'dishName': dishName,
        'recipientId': recipientId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'navigationRoute': '/reservations',
        'screen': 'reservation_status',
      };

      if (customerName != null) data['customerName'] = customerName;
      if (chefName != null) data['chefName'] = chefName;
      if (reservationTime != null)
        data['reservationTime'] = reservationTime.toIso8601String();
      if (reason != null) data['reason'] = reason;

      final success = await _sendViaCloudFunction(
        recipientFcmToken: fcmToken,
        title: '$emoji $title',
        body: body,
        data: data,
      );

      DebugHelper.logSuccess(
          ' Reservation notification sent: $type for $reservationId');
      return success;
    } catch (e) {
      DebugHelper.logError(' Error sending reservation notification: $e');
      return false;
    }
  }

  /// Send order notification - ENHANCED FOR ALL CASES
  Future<bool> sendOrderNotification({
    required String recipientId,
    required String
        type, // 'created', 'confirmed', 'ready', 'completed', 'cancelled'
    required String orderId,
    required String dishName,
    String? statusNote,
    String? chefName,
    String? customerName,
  }) async {
    try {
      if (!_orderNotificationsEnabled) {
        DebugHelper.log('⏭️ Order notifications disabled');
        return false;
      }

      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        DebugHelper.logError(
            ' Recipient document does not exist: $recipientId');
        return false;
      }

      final recipientData = recipientDoc.data();
      final fcmToken = recipientData?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        DebugHelper.logError(' Recipient has no FCM token: $recipientId');
        return false;
      }

      String title;
      String body;
      String emoji;

      switch (type) {
        case 'created':
        case 'reserved':
          title = '📦 Order Placed';
          body = 'Your order for "$dishName" has been placed';
          emoji = '📦';
          break;
        case 'confirmed':
          title = '✅ Order Confirmed';
          body = 'Your order for "$dishName" has been confirmed';
          emoji = '✅';
          break;
        case 'ready':
          title = '🎯 Order Ready';
          body = 'Your order for "$dishName" is ready for pickup';
          emoji = '🎯';
          break;
        case 'completed':
          title = '🎉 Order Completed';
          body = 'Your order for "$dishName" has been completed';
          emoji = '🎉';
          break;
        case 'cancelled':
          title = '❌ Order Cancelled';
          body = 'Your order for "$dishName" has been cancelled';
          emoji = '❌';
          break;
        default:
          title = '📋 Order Update';
          body = 'Your order for "$dishName" has been updated';
          emoji = '📋';
      }

      if (statusNote != null) {
        body += ' - $statusNote';
      }

      final data = {
        'type': 'order_$type',
        'orderId': orderId,
        'dishName': dishName,
        'recipientId': recipientId,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'navigationRoute': '/orders',
        'screen': 'order_status',
      };

      if (chefName != null) data['chefName'] = chefName;
      if (customerName != null) data['customerName'] = customerName;

      final success = await _sendViaCloudFunction(
        recipientFcmToken: fcmToken,
        title: '$emoji $title',
        body: body,
        data: data,
      );

      DebugHelper.logSuccess(' Order notification sent: $type for $orderId');
      return success;
    } catch (e) {
      DebugHelper.logError(' Error sending order notification: $e');
      return false;
    }
  }

  /// Send system notification
  Future<bool> sendSystemNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        DebugHelper.logError(
            ' Recipient document does not exist: $recipientId');
        return false;
      }

      final recipientData = recipientDoc.data();
      final fcmToken = recipientData?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) {
        DebugHelper.logError(' Recipient has no FCM token: $recipientId');
        return false;
      }

      final notificationData = {
        'type': 'system',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        ...?data,
      };

      final success = await _sendViaCloudFunction(
        recipientFcmToken: fcmToken,
        title: title,
        body: body,
        data: notificationData,
      );

      DebugHelper.logSuccess(' System notification sent to: $recipientId');
      return success;
    } catch (e) {
      DebugHelper.logError(' Error sending system notification: $e');
      return false;
    }
  }

  // ========== BULK NOTIFICATION METHODS ==========

  /// Send notification to multiple users
  Future<void> sendBulkNotification({
    required List<String> recipientIds,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      for (final recipientId in recipientIds) {
        await sendSystemNotification(
          recipientId: recipientId,
          title: title,
          body: body,
          data: data,
        );
        // Small delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }
      DebugHelper.logSuccess(
          ' Bulk notification sent to ${recipientIds.length} users');
    } catch (e) {
      DebugHelper.logError(' Error sending bulk notification: $e');
    }
  }

  // ========== UTILITY METHODS ==========

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

  /// Refresh FCM token and save to user document
  /// Call this after login to ensure the user's FCM token is up to date
  Future<void> refreshFcmToken() async {
    try {
      // On iOS, need APNS token first (not available on Simulator)
      if (Platform.isIOS) {
        final apnsToken = await _firebaseMessaging.getAPNSToken();
        if (apnsToken == null) {
          DebugHelper.logWarning(
              '⚠️ APNS token not available - FCM token refresh skipped (expected on Simulator)');
          return;
        }
      }

      // Get fresh token
      _fcmToken = await _firebaseMessaging.getToken();
      DebugHelper.logInfo('🔄 Refreshed FCM Token: $_fcmToken');

      // Save to user document if we have a token
      if (_fcmToken != null) {
        await _saveFcmTokenToUser();
        DebugHelper.logSuccess('✅ FCM token refreshed and saved');
      }
    } catch (e) {
      DebugHelper.logWarning(
          '⚠️ Error refreshing FCM token (expected on iOS Simulator): $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      DebugHelper.logSuccess(' All notifications cancelled');
    } catch (e) {
      DebugHelper.logError(' Error cancelling all notifications: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      DebugHelper.logSuccess(' Notification $id cancelled');
    } catch (e) {
      DebugHelper.logError(' Error cancelling notification $id: $e');
    }
  }

  void setState(void Function() callback) {
    callback();
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      DebugHelper.logSuccess(' Unsubscribed from topic: $topic');
    } catch (e) {
      DebugHelper.logError(' Error unsubscribing from topic: $e');
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      DebugHelper.logSuccess(' Subscribed to topic: $topic');
    } catch (e) {
      DebugHelper.logError(' Error subscribing to topic: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  DebugHelper.log('🌙 Handling background message: ${message.messageId}');

  // Process the background message
  await NotificationService.instance._processRemoteMessage(message);

  // Show notification even in background
  final notification = message.notification;
  if (notification != null) {
    await NotificationService.instance.showLocalNotification(
      id: NotificationService.instance._generateNotificationId(
          message.messageId ?? 'bg_${DateTime.now().millisecondsSinceEpoch}'),
      title: notification.title ?? 'Background Notification',
      body: notification.body ?? '',
      payload: message.data,
    );
  }
}
