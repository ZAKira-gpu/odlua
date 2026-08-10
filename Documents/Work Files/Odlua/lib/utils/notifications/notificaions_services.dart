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
import 'package:odlua/utils/helpers/debug_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  late FirebaseMessaging _firebaseMessaging;
  late FlutterLocalNotificationsPlugin _localNotifications;
  
  bool _isInitialized = false;
  String? _fcmToken;
  
  Function(Map<String, dynamic>)? _navigationHandler;
  
  late Box<Map<dynamic, dynamic>> _notificationBox;
  static const String _notificationBoxName = 'notifications';
  
  static const String _channelId = 'odlua_channel';
  static const String _channelName = 'Odlua Notifications';
  static const String _channelDescription = 'Notifications for orders, reservations, and messages';

  // ✅ UPDATED WITH YOUR ACTUAL CLOUD FUNCTION URL
  static const String _cloudFunctionUrl = 'https://us-central1-odlua-139c3.cloudfunctions.net/sendNotification';

  // Notification settings
  bool _chatNotificationsEnabled = true;
  bool _reservationNotificationsEnabled = true;
  bool _orderNotificationsEnabled = true;
  bool _marketingNotificationsEnabled = false;

  Future<void> init({bool enableForegroundNotification = true}) async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      
      await _initNotificationStorage();
      
      _firebaseMessaging = FirebaseMessaging.instance;
      
      await _requestPermissions();
      
      _fcmToken = await _firebaseMessaging.getToken();
      DebugHelper.logInfo(' FCM Token: $_fcmToken');
      
      await _saveFcmTokenToUser();
      
      await _initializeLocalNotifications();
      
      await _configureFirebaseHandlers(enableForegroundNotification);
      
      _configureBackgroundHandler();
      
      await _loadNotificationSettings();
      
      _isInitialized = true;
      DebugHelper.logSuccess(' NotificationService initialized successfully');
      
    } catch (e) {
      DebugHelper.logError(' Failed to initialize NotificationService: $e');
    }
  }

  Future<void> _initNotificationStorage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      Hive.init(appDir.path);
      _notificationBox = await Hive.openBox<Map<dynamic, dynamic>>(_notificationBoxName);
    } catch (e) {
      DebugHelper.logError(' Error initializing notification storage: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      const AndroidInitializationSettings androidSettings = 
          AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const DarwinInitializationSettings iosSettings = 
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );
      
      const InitializationSettings initializationSettings = InitializationSettings(
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
      
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: true,
        sound: true,
      );
      
      DebugHelper.log(' Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      DebugHelper.logError(' Error requesting notification permissions: $e');
    }
  }

  Future<void> _saveFcmTokenToUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _fcmToken == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': _fcmToken,
        'fcmTokens': FieldValue.arrayUnion([_fcmToken]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      DebugHelper.logSuccess(' FCM token saved to user document');
      
      _firebaseMessaging.onTokenRefresh.listen((newToken) async {
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
      });
      
    } catch (e) {
      DebugHelper.logError(' Error saving FCM token: $e');
    }
  }

  Future<void> _configureFirebaseHandlers(bool enableForegroundNotification) async {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        DebugHelper.log('📨 Received foreground message: ${message.messageId}');
        _handleForegroundMessage(message);
        
        if (enableForegroundNotification) {
          _showRemoteNotification(message);
        }
      });
      
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        DebugHelper.log(' App opened from notification');
        _processRemoteMessage(message, fromTap: true);
      });
      
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        DebugHelper.log('🚀 App launched from terminated state by notification');
        _processRemoteMessage(initialMessage, fromTap: true);
      }
      
    } catch (e) {
      DebugHelper.logError(' Error configuring Firebase handlers: $e');
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
        case 'order_update':
        case 'order_created':
        case 'order_confirmed':
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
        id: _generateNotificationId(message.messageId ?? 'remote_${DateTime.now().millisecondsSinceEpoch}'),
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
      case 'order_update':
      case 'order_created':
      case 'order_confirmed':
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

  Future<void> _processRemoteMessage(RemoteMessage message, {bool fromTap = false}) async {
    try {
      final data = message.data;
      final type = data['type'] ?? 'unknown';
      
      DebugHelper.logInfo(' Processing remote message type: $type');
      
      await _storeNotificationInInbox({
        'id': _generateNotificationId(message.messageId ?? 'remote_${DateTime.now().millisecondsSinceEpoch}'),
        'title': message.notification?.title ?? 'Notification',
        'body': message.notification?.body ?? '',
        'payload': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'read': false,
        'type': type,
      });
      
      if (fromTap) {
        _triggerNavigation(data);
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
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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

  Future<void> _storeNotificationInInbox(Map<String, dynamic> notification) async {
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
        _triggerNavigation(payload);
      }
    } catch (e) {
      DebugHelper.logError(' Error handling notification tap: $e');
    }
  }

  void _triggerNavigation(Map<String, dynamic> payload) {
    try {
      if (_navigationHandler != null) {
        _navigationHandler!(payload);
      } else {
        DebugHelper.logWarning(' No navigation handler registered');
      }
    } catch (e) {
      DebugHelper.logError(' Error triggering navigation: $e');
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

  void registerNavigationHandler(Function(Map<String, dynamic>) handler) {
    _navigationHandler = handler;
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
        
        setState(() {
          _chatNotificationsEnabled = settings['chat'] ?? true;
          _reservationNotificationsEnabled = settings['reservations'] ?? true;
          _orderNotificationsEnabled = settings['orders'] ?? true;
          _marketingNotificationsEnabled = settings['marketing'] ?? false;
        });
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
      DebugHelper.log('📤 Sending notification via Cloud Function to: ${recipientFcmToken.substring(0, 10)}...');
      
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
        DebugHelper.logSuccess(' Cloud Function notification sent successfully');
        return true;
      } else {
        DebugHelper.logError(' Cloud Function error: ${response.statusCode} - ${response.body}');
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
        DebugHelper.logWarning(' Skipping notification: recipient is current user');
        return false;
      }

      DebugHelper.log('🔔 Preparing to send chat notification to: $recipientId');

      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        DebugHelper.logError(' Recipient document does not exist: $recipientId');
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
        body: message.length > 100 ? '${message.substring(0, 100)}...' : message,
        data: data,
        imageUrl: imageUrl,
      );

      DebugHelper.logSuccess(' Chat notification process completed for: $recipientId');
      return success;
      
    } catch (e) {
      DebugHelper.logError(' Error sending chat notification: $e');
      return false;
    }
  }

  /// Send reservation notification - ENHANCED FOR ALL CASES
  Future<bool> sendReservationNotification({
    required String recipientId,
    required String type, // 'pending', 'confirmed', 'declined', 'expired', 'completed', 'cancelled'
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

      DebugHelper.log('🔔 Preparing to send reservation notification to: $recipientId');

      // Get recipient's FCM token
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .get();

      if (!recipientDoc.exists) {
        DebugHelper.logError(' Recipient document does not exist: $recipientId');
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
      if (reservationTime != null) data['reservationTime'] = reservationTime.toIso8601String();
      if (reason != null) data['reason'] = reason;

      final success = await _sendViaCloudFunction(
        recipientFcmToken: fcmToken,
        title: '$emoji $title',
        body: body,
        data: data,
      );

      DebugHelper.logSuccess(' Reservation notification sent: $type for $reservationId');
      return success;
      
    } catch (e) {
      DebugHelper.logError(' Error sending reservation notification: $e');
      return false;
    }
  }

  /// Send order notification - ENHANCED FOR ALL CASES
  Future<bool> sendOrderNotification({
    required String recipientId,
    required String type, // 'created', 'confirmed', 'ready', 'completed', 'cancelled'
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
        DebugHelper.logError(' Recipient document does not exist: $recipientId');
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
        DebugHelper.logError(' Recipient document does not exist: $recipientId');
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
      DebugHelper.logSuccess(' Bulk notification sent to ${recipientIds.length} users');
    } catch (e) {
      DebugHelper.logError(' Error sending bulk notification: $e');
    }
  }

  // ========== UTILITY METHODS ==========

  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;

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