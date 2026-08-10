// ─────────────────────────────────────────
// Controller: ChatController
// Description: Business logic for chat operations (send, mark read, block).
// Contains: sendMessage, markAsRead, blockUser
// ─────────────────────────────────────────

// ============================================================================
// CHAT CONTROLLER - State Management & Business Logic
// ============================================================================
// Clean separation of UI and business logic with proper state management,
// real-time sync coordination, and notification handling.
// ============================================================================

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:odlua/utils/models/chat_models.dart';
import 'package:odlua/utils/services/chat_repository.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

// ============================================================================
// CHAT CONVERSATION CONTROLLER
// ============================================================================

/// Controller for individual chat conversation
class ChatConversationController extends ChangeNotifier {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String? recipientImage;

  final ChatRepository _repository = ChatRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();
  final ImagePicker _imagePicker = ImagePicker();
  final Connectivity _connectivity = Connectivity();

  // State
  ChatState _state = const ChatState.initial();
  ChatState get state => _state;

  // Current user
  String get currentUserId => _auth.currentUser?.uid ?? '';
  String get currentUserName =>
      _auth.currentUser?.displayName ??
      _auth.currentUser?.email?.split('@').first ??
      'User';

  // Subscriptions
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _chatRoomSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _connectivitySubscription;

  // Typing debounce
  Timer? _typingDebounceTimer;
  Timer? _typingTimeoutTimer;
  bool _isCurrentlyTyping = false;

  // Connectivity state
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Track if we're in this chat (for notification suppression)
  static String? _activeChatId;
  static bool isInChat(String chatId) => _activeChatId == chatId;

  ChatConversationController({
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    this.recipientImage,
  });

  /// Initialize the controller and start listeners
  Future<void> initialize() async {
    _activeChatId = chatId;
    await _checkConnectivity();
    await _repository.updatePresence(true);
    _setupListeners();
    _setupConnectivityListener();
    _markAsRead();
  }

  /// Check initial connectivity
  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
  }

  /// Setup connectivity listener
  void _setupConnectivityListener() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      if (!wasOnline && _isOnline) {
        // Just came back online - retry failed messages
        _retryFailedMessages();
      }

      notifyListeners();
    });
  }

  /// Auto-retry failed messages when back online
  Future<void> _retryFailedMessages() async {
    final failedIds = _state.failedMessages.keys.toList();
    for (final id in failedIds) {
      await retryMessage(id);
      // Small delay between retries to avoid overwhelming
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Setup all real-time listeners
  void _setupListeners() {
    // Messages stream
    _messagesSubscription = _repository
        .streamMessages(chatId, limit: 50)
        .listen(_onMessagesUpdate, onError: _onError);

    // Chat room stream (for block status, etc.)
    _chatRoomSubscription = _repository
        .streamChatRoom(chatId)
        .listen(_onChatRoomUpdate, onError: _onError);

    // Typing indicator stream
    _typingSubscription = _repository
        .streamTypingStatus(chatId, recipientId)
        .listen(_onTypingUpdate, onError: _onError);
  }

  /// Handle messages update from stream
  void _onMessagesUpdate(List<ChatMessage> serverMessages) {
    // Merge server messages with pending/failed local messages
    final mergedMessages = _mergeMessages(serverMessages);

    _state = _state.copyWith(
      isLoading: false,
      messages: mergedMessages,
      hasError: false,
    );
    notifyListeners();

    // Mark as read when we receive messages
    _markAsRead();
  }

  /// Merge server messages with local pending/failed messages
  List<ChatMessage> _mergeMessages(List<ChatMessage> serverMessages) {
    final serverIds = serverMessages.map((m) => m.id).toSet();

    // Remove pending messages that have arrived from server
    final updatedPending =
        _state.pendingMessageIds.where((id) => !serverIds.contains(id)).toSet();

    // Remove failed messages that somehow succeeded
    final updatedFailed = Map<String, ChatMessage>.from(_state.failedMessages)
      ..removeWhere((id, _) => serverIds.contains(id));

    // Merge all messages
    final allMessages = <ChatMessage>[...serverMessages];

    // Add remaining pending messages (showing as sending)
    for (final id in updatedPending) {
      final existing = _state.messages.firstWhere(
        (m) => m.id == id,
        orElse: () => ChatMessage.local(
          id: id,
          chatId: chatId,
          senderId: currentUserId,
          text: '',
        ),
      );
      if (!allMessages.any((m) => m.id == id)) {
        allMessages.add(existing);
      }
    }

    // Add failed messages
    for (final failed in updatedFailed.values) {
      if (!allMessages.any((m) => m.id == failed.id)) {
        allMessages.add(failed);
      }
    }

    // Sort by creation time
    allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Update state tracking
    _state = _state.copyWith(
      pendingMessageIds: updatedPending,
      failedMessages: updatedFailed,
    );

    return allMessages;
  }

  /// Handle chat room update
  void _onChatRoomUpdate(ChatRoom? chatRoom) {
    if (chatRoom == null) return;

    _state = _state.copyWith(
      isBlocked: chatRoom.hasBlocked(currentUserId),
      isBlockedByOther: chatRoom.isBlockedBy(recipientId),
    );
    notifyListeners();
  }

  /// Handle typing indicator update
  void _onTypingUpdate(bool isTyping) {
    _state = _state.copyWith(isTyping: isTyping);
    notifyListeners();
  }

  /// Handle stream errors
  void _onError(dynamic error) {
    DebugHelper.logError('Chat stream error: $error');
    _state = _state.copyWith(
      hasError: true,
      errorMessage: 'Connection error. Please try again.',
      isLoading: false,
    );
    notifyListeners();
  }

  /// Mark messages as read
  void _markAsRead() {
    _repository.markMessagesAsRead(chatId);
  }

  // ============================================================================
  // MESSAGE SENDING
  // ============================================================================

  /// Send a text message
  Future<bool> sendMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) return false;

    if (_state.isBlocked || _state.isBlockedByOther) {
      return false;
    }

    // Create optimistic message
    final messageId = const Uuid().v4();
    final optimisticMessage = ChatMessage.local(
      id: messageId,
      chatId: chatId,
      senderId: currentUserId,
      text: trimmedText,
    );

    // Add to UI immediately (optimistic)
    _state = _state.copyWith(
      messages: [..._state.messages, optimisticMessage],
      pendingMessageIds: {..._state.pendingMessageIds, messageId},
      isSending: true,
    );
    notifyListeners();

    // Stop typing indicator
    _stopTyping();

    try {
      // Send to server
      final success = await _repository.sendMessage(
        chatId: chatId,
        recipientId: recipientId,
        message: optimisticMessage,
        recipientName: recipientName,
        recipientPhotoUrl: recipientImage,
      );

      if (success) {
        // Send push notification
        await _sendPushNotification(trimmedText);

        _state = _state.copyWith(isSending: false);
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to send message');
      }
    } catch (e) {
      DebugHelper.logError('Error sending message: $e');

      // Mark as failed
      final failedMessage = optimisticMessage.copyWith(
        status: MessageStatus.failed,
      );

      final updatedPending = Set<String>.from(_state.pendingMessageIds)
        ..remove(messageId);
      final updatedFailed = Map<String, ChatMessage>.from(_state.failedMessages)
        ..[messageId] = failedMessage;

      // Update message in list
      final updatedMessages = _state.messages.map((m) {
        if (m.id == messageId) return failedMessage;
        return m;
      }).toList();

      _state = _state.copyWith(
        messages: updatedMessages,
        pendingMessageIds: updatedPending,
        failedMessages: updatedFailed,
        isSending: false,
      );
      notifyListeners();
      return false;
    }
  }

  /// Retry sending a failed message
  Future<bool> retryMessage(String messageId) async {
    final failedMessage = _state.failedMessages[messageId];
    if (failedMessage == null) return false;

    // Remove from failed
    final updatedFailed = Map<String, ChatMessage>.from(_state.failedMessages)
      ..remove(messageId);

    // Remove from messages list
    final updatedMessages =
        _state.messages.where((m) => m.id != messageId).toList();

    _state = _state.copyWith(
      messages: updatedMessages,
      failedMessages: updatedFailed,
    );
    notifyListeners();

    // Resend with same ID (idempotent)
    return await sendMessage(failedMessage.text ?? '');
  }

  /// Send an image message
  Future<bool> sendImageMessage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image == null) return false;

      return await _uploadAndSendMedia(File(image.path), MessageType.image);
    } catch (e) {
      DebugHelper.logError('Error picking image: $e');
      return false;
    }
  }

  /// Take a photo and send
  Future<bool> takeAndSendPhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo == null) return false;

      return await _uploadAndSendMedia(File(photo.path), MessageType.image);
    } catch (e) {
      DebugHelper.logError('Error taking photo: $e');
      return false;
    }
  }

  /// Upload and send media
  Future<bool> _uploadAndSendMedia(File file, MessageType type) async {
    final messageId = const Uuid().v4();

    // Create placeholder message
    final placeholderMessage = ChatMessage.mediaPlaceholder(
      id: messageId,
      chatId: chatId,
      senderId: currentUserId,
      type: type,
    );

    // Add to UI
    _state = _state.copyWith(
      messages: [..._state.messages, placeholderMessage],
      pendingMessageIds: {..._state.pendingMessageIds, messageId},
      isSending: true,
    );
    notifyListeners();

    try {
      // Upload to Firebase Storage
      final fileName = '${type.value}s/$chatId/$messageId';
      final task = await _storage.ref(fileName).putFile(file);
      final downloadUrl = await task.ref.getDownloadURL();

      // Send message with media URL
      final success = await _repository.sendMediaMessage(
        chatId: chatId,
        recipientId: recipientId,
        message: placeholderMessage,
        mediaUrls: [downloadUrl],
        recipientName: recipientName,
        recipientPhotoUrl: recipientImage,
      );

      if (success) {
        final mediaText =
            type == MessageType.image ? '📷 Sent a photo' : '🎥 Sent a video';
        await _sendPushNotification(mediaText);

        _state = _state.copyWith(isSending: false);
        notifyListeners();
        return true;
      } else {
        throw Exception('Failed to send media');
      }
    } catch (e) {
      DebugHelper.logError('Error sending media: $e');

      // Mark as failed
      final failedMessage = placeholderMessage.copyWith(
        status: MessageStatus.failed,
      );

      final updatedPending = Set<String>.from(_state.pendingMessageIds)
        ..remove(messageId);
      final updatedFailed = Map<String, ChatMessage>.from(_state.failedMessages)
        ..[messageId] = failedMessage;

      final updatedMessages = _state.messages.map((m) {
        if (m.id == messageId) return failedMessage;
        return m;
      }).toList();

      _state = _state.copyWith(
        messages: updatedMessages,
        pendingMessageIds: updatedPending,
        failedMessages: updatedFailed,
        isSending: false,
      );
      notifyListeners();
      return false;
    }
  }

  /// Send push notification to recipient
  Future<void> _sendPushNotification(String message) async {
    try {
      await _notificationService.sendChatNotification(
        recipientId: recipientId,
        senderName: currentUserName,
        message: message,
        chatId: chatId,
        imageUrl: _auth.currentUser?.photoURL,
      );
    } catch (e) {
      DebugHelper.log('Push notification error: $e');
    }
  }

  // ============================================================================
  // TYPING INDICATOR
  // ============================================================================

  /// Handle text input change (for typing indicator)
  void onTextChanged(String text) {
    _typingDebounceTimer?.cancel();

    if (text.isEmpty) {
      _stopTyping();
      return;
    }

    // Debounce - wait 300ms before sending typing indicator
    _typingDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _startTyping();
    });
  }

  void _startTyping() {
    if (_isCurrentlyTyping) return;
    if (_state.isBlocked || _state.isBlockedByOther) return;

    _isCurrentlyTyping = true;
    _repository.setTyping(chatId, true);

    // Auto-stop typing after 3 seconds of inactivity
    _typingTimeoutTimer?.cancel();
    _typingTimeoutTimer = Timer(const Duration(seconds: 3), _stopTyping);
  }

  void _stopTyping() {
    if (!_isCurrentlyTyping) return;

    _isCurrentlyTyping = false;
    _typingTimeoutTimer?.cancel();
    _repository.setTyping(chatId, false);
  }

  // ============================================================================
  // MESSAGE ACTIONS
  // ============================================================================

  /// Delete a message
  Future<bool> deleteMessage(String messageId) async {
    return await _repository.deleteMessage(chatId, messageId);
  }

  /// Report a message
  Future<bool> reportMessage(String messageId, String senderId) async {
    return await _repository.reportMessage(
      chatId: chatId,
      messageId: messageId,
      reportedUserId: senderId,
    );
  }

  // ============================================================================
  // BLOCKING
  // ============================================================================

  /// Block the other user
  Future<bool> blockUser() async {
    final success = await _repository.blockUser(chatId);
    if (success) {
      _state = _state.copyWith(isBlocked: true);
      notifyListeners();
    }
    return success;
  }

  /// Unblock the other user
  Future<bool> unblockUser() async {
    final success = await _repository.unblockUser(chatId);
    if (success) {
      _state = _state.copyWith(isBlocked: false);
      notifyListeners();
    }
    return success;
  }

  /// Report the other user
  Future<bool> reportUser() async {
    return await _repository.reportUser(reportedUserId: recipientId);
  }

  // ============================================================================
  // CLEAR CHAT
  // ============================================================================

  /// Clear all messages
  Future<bool> clearChat() async {
    return await _repository.clearChat(chatId);
  }

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  /// Called when screen becomes visible
  void onResume() {
    _activeChatId = chatId;
    _repository.updatePresence(true);
    _markAsRead();
  }

  /// Called when screen becomes hidden
  void onPause() {
    _stopTyping();
    _repository.updatePresence(false);
  }

  @override
  void dispose() {
    _activeChatId = null;
    _stopTyping();
    _typingDebounceTimer?.cancel();
    _typingTimeoutTimer?.cancel();
    _messagesSubscription?.cancel();
    _chatRoomSubscription?.cancel();
    _typingSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _repository.updatePresence(false);
    super.dispose();
  }
}

// ============================================================================
// CHAT LIST CONTROLLER
// ============================================================================

/// Controller for chat list screen
class ChatListController extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ChatListState _state = const ChatListState.initial();
  ChatListState get state => _state;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  StreamSubscription? _chatsSubscription;

  /// Initialize and start listening
  Future<void> initialize() async {
    await _repository.updatePresence(true);
    _setupListener();
  }

  void _setupListener() {
    _chatsSubscription = _repository.streamChatRooms().listen(
      (chats) {
        _state = _state.copyWith(
          isLoading: false,
          chats: chats,
          hasError: false,
        );
        notifyListeners();
      },
      onError: (error) {
        DebugHelper.logError('Chat list error: $error');
        _state = _state.copyWith(
          isLoading: false,
          hasError: true,
          errorMessage: 'Failed to load chats',
        );
        notifyListeners();
      },
    );
  }

  /// Refresh chats
  Future<void> refresh() async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    // Cancel and restart listener
    await _chatsSubscription?.cancel();
    _setupListener();
  }

  /// Called on resume
  void onResume() {
    _repository.updatePresence(true);
  }

  /// Called on pause
  void onPause() {
    _repository.updatePresence(false);
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _repository.updatePresence(false);
    super.dispose();
  }
}

// ============================================================================
// USER SEARCH CONTROLLER
// ============================================================================

/// Controller for user search screen
class UserSearchController extends ChangeNotifier {
  final ChatRepository _repository = ChatRepository();

  List<ChatUser> _searchResults = [];
  List<ChatUser> _recentContacts = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  List<ChatUser> get searchResults => _searchResults;
  List<ChatUser> get recentContacts => _recentContacts;
  bool get isSearching => _isSearching;
  bool get hasSearched => _hasSearched;
  bool get showRecentContacts => !_hasSearched && _recentContacts.isNotEmpty;

  /// Initialize and load recent contacts
  Future<void> initialize() async {
    _recentContacts = await _repository.getRecentContacts();
    notifyListeners();
  }

  /// Perform search
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _hasSearched = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    _hasSearched = true;
    notifyListeners();

    _searchResults = await _repository.searchUsers(query);

    _isSearching = false;
    notifyListeners();
  }

  /// Clear search
  void clearSearch() {
    _searchResults = [];
    _hasSearched = false;
    notifyListeners();
  }

  /// Start chat with user (lazy - doesn't create chat document)
  /// The chat document will be created on first message send
  String? startChat(ChatUser user) {
    if (user.uid.isEmpty) {
      DebugHelper.logError('startChat aborted: recipient uid is empty');
      return null;
    }

    // Just get the chat ID without creating the document
    // The document will be created when the first message is sent
    final chatId = _repository.getChatIdOnly(recipientId: user.uid);
    if (chatId == null) {
      DebugHelper.logError(
          '❌ startChat failed for user ${user.uid} (${user.name})');
    } else {
      DebugHelper.log('✅ startChat success chatId=$chatId (lazy creation)');
    }
    return chatId;
  }
}
