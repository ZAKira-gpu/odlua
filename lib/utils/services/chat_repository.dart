// ─────────────────────────────────────────
// Repository: ChatRepository
// Description: Firestore data layer for chat conversations and messages.
// Contains: getChats, getMessages, createChat
// ─────────────────────────────────────────

// ============================================================================
// CHAT REPOSITORY - Data Access Layer
// ============================================================================
// Handles all Firestore operations for chat with proper error handling,
// pagination, and real-time sync coordination.
// ============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/models/chat_models.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Repository for chat data operations
class ChatRepository {
  static final ChatRepository _instance = ChatRepository._internal();
  factory ChatRepository() => _instance;
  ChatRepository._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _firestore.collection('chats');

  DocumentReference<Map<String, dynamic>> _chatDoc(String chatId) =>
      _chatsRef.doc(chatId);

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chatDoc(chatId).collection('messages');

  CollectionReference<Map<String, dynamic>> _typingRef(String chatId) =>
      _chatDoc(chatId).collection('typing');

  // Current user ID getter
  String? get currentUserId => _auth.currentUser?.uid;

  // ============================================================================
  // CHAT ROOM OPERATIONS
  // ============================================================================

  /// Generate deterministic chat ID from two user IDs
  String generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Get chat ID without creating the document
  /// This is useful for navigating to a chat screen without creating the chat
  /// The chat document will be created on first message send
  String? getChatIdOnly({required String recipientId}) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      DebugHelper.logError('Cannot get chat ID: No authenticated user');
      return null;
    }

    final currentUserId = currentUser.uid;

    // Prevent self-chat
    if (currentUserId == recipientId) {
      DebugHelper.logWarning('Cannot create chat with self');
      return null;
    }

    return generateChatId(currentUserId, recipientId);
  }

  /// Get or create a chat room (idempotent)
  /// Uses set with merge to avoid permission issues on existing broken docs
  Future<String?> getOrCreateChat({
    required String recipientId,
    required String recipientName,
    String? recipientPhotoUrl,
    bool isOrderChat = false,
    String? orderId,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        DebugHelper.logError('Cannot create chat: No authenticated user');
        return null;
      }

      final currentUserId = currentUser.uid;

      // Prevent self-chat
      if (currentUserId == recipientId) {
        DebugHelper.logWarning('Cannot create chat with self');
        return null;
      }

      final chatId = generateChatId(currentUserId, recipientId);
      final chatRef = _chatDoc(chatId);

      DebugHelper.log(
          '🧩 getOrCreateChat -> chatId=$chatId, currentUserId=$currentUserId, recipientId=$recipientId');

      // Build the sorted participants array
      final participants = [currentUserId, recipientId]..sort();

      // Create chat data - always include participants to fix broken docs
      final chatData = <String, dynamic>{
        'id': chatId,
        'participants': participants, // Always set this to fix broken docs
        'participantData': {
          currentUserId: {
            'name': currentUser.displayName ?? 'User',
            'photoUrl': currentUser.photoURL,
          },
          recipientId: {
            'name': recipientName,
            'photoUrl': recipientPhotoUrl,
          },
        },
        'lastActivity': FieldValue.serverTimestamp(),
        'isGroup': false,
      };

      // Add creation-only fields if document doesn't exist
      // Using set with merge: true allows this to work for both create and update
      // BUT we need to handle the case where doc exists with broken data

      // First, try a simple set with merge - this will:
      // 1. Create the doc if it doesn't exist
      // 2. Update/fix the doc if it exists (including fixing participants)
      await chatRef.set({
        ...chatData,
        'blockedUsers': {},
        'mutedBy': {},
        'unreadCounts': {
          currentUserId: FieldValue.increment(0), // Creates field if missing
          recipientId: FieldValue.increment(0),
        },
        'lastReadAt': {},
        if (isOrderChat) 'isOrderChat': true,
        if (orderId != null) 'orderId': orderId,
      }, SetOptions(merge: true));

      // Set createdAt only if it doesn't exist (use update for this)
      try {
        await chatRef.update({
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Ignore - createdAt already exists
      }

      DebugHelper.logSuccess('✅ Chat ready: $chatId');
      return chatId;
    } catch (e) {
      if (e is FirebaseException) {
        DebugHelper.logError(
            '❌ Error creating chat (code=${e.code}): ${e.message}');
      } else {
        DebugHelper.logError('❌ Error creating chat: $e');
      }
      return null;
    }
  }

  /// Stream chat rooms for current user
  Stream<List<ChatRoom>> streamChatRooms() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _chatsRef
        .where('participants', arrayContains: userId)
        .orderBy('lastActivity', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatRoom.fromFirestore(doc, userId))
          .toList();
    });
  }

  /// Get single chat room
  Future<ChatRoom?> getChatRoom(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final doc = await _chatDoc(chatId).get();
      if (!doc.exists) return null;

      return ChatRoom.fromFirestore(doc, userId);
    } catch (e) {
      DebugHelper.logError('Error getting chat room: $e');
      return null;
    }
  }

  /// Stream single chat room
  Stream<ChatRoom?> streamChatRoom(String chatId) {
    final userId = currentUserId;
    if (userId == null) return Stream.value(null);

    return _chatDoc(chatId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatRoom.fromFirestore(doc, userId);
    });
  }

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Stream messages with real-time updates (limited for performance)
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 50}) {
    return _messagesRef(chatId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final messages =
          snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
      // Reverse to get chronological order
      return messages.reversed.toList();
    });
  }

  /// Load older messages (pagination)
  Future<List<ChatMessage>> loadMoreMessages(
    String chatId, {
    required DocumentSnapshot lastDocument,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _messagesRef(chatId)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastDocument)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      DebugHelper.logError('Error loading more messages: $e');
      return [];
    }
  }

  /// Send a text message with optimistic updates
  /// Creates the chat document if it doesn't exist (lazy creation)
  Future<bool> sendMessage({
    required String chatId,
    required String recipientId,
    required ChatMessage message,
    String? recipientName,
    String? recipientPhotoUrl,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      // Prepare message data
      final messageData = message
          .copyWith(
            status: MessageStatus.sent,
            sentAt: DateTime.now(),
          )
          .toMap();

      // Use server timestamp for createdAt
      messageData['createdAt'] = FieldValue.serverTimestamp();
      messageData['sentAt'] = FieldValue.serverTimestamp();

      // Check if chat document exists, create if not (lazy creation)
      final chatDoc = await _chatDoc(chatId).get();
      if (!chatDoc.exists) {
        // Create chat document on first message
        final participants = [userId, recipientId]..sort();
        await _chatDoc(chatId).set({
          'id': chatId,
          'participants': participants,
          'participantData': {
            userId: {
              'name': currentUser.displayName ?? 'User',
              'photoUrl': currentUser.photoURL,
            },
            recipientId: {
              'name': recipientName ?? 'User',
              'photoUrl': recipientPhotoUrl,
            },
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
          'isGroup': false,
          'blockedUsers': {},
          'mutedBy': {},
          'unreadCounts': {
            userId: 0,
            recipientId: 0,
          },
          'lastReadAt': {},
        });
        DebugHelper.log('📝 Chat document created on first message: $chatId');
      }

      // Batch write for atomicity
      final batch = _firestore.batch();

      // Write message
      batch.set(_messagesRef(chatId).doc(message.id), messageData);

      // Update chat metadata - use set with merge to be safe
      batch.set(
        _chatDoc(chatId),
        {
          'lastMessage': messageData,
          'lastActivity': FieldValue.serverTimestamp(),
          'unreadCounts': {recipientId: FieldValue.increment(1)},
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      DebugHelper.logSuccess('✅ Message sent: ${message.id}');
      return true;
    } catch (e) {
      DebugHelper.logError('Error sending message: $e');
      return false;
    }
  }

  /// Send media message
  /// Creates the chat document if it doesn't exist (lazy creation)
  Future<bool> sendMediaMessage({
    required String chatId,
    required String recipientId,
    required ChatMessage message,
    required List<String> mediaUrls,
    String? recipientName,
    String? recipientPhotoUrl,
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final updatedMessage = message.copyWith(
        mediaUrls: mediaUrls,
        status: MessageStatus.sent,
        sentAt: DateTime.now(),
      );

      final messageData = updatedMessage.toMap();
      messageData['createdAt'] = FieldValue.serverTimestamp();
      messageData['sentAt'] = FieldValue.serverTimestamp();

      // Check if chat document exists, create if not (lazy creation)
      final chatDoc = await _chatDoc(chatId).get();
      if (!chatDoc.exists) {
        // Create chat document on first message
        final participants = [userId, recipientId]..sort();
        await _chatDoc(chatId).set({
          'id': chatId,
          'participants': participants,
          'participantData': {
            userId: {
              'name': currentUser.displayName ?? 'User',
              'photoUrl': currentUser.photoURL,
            },
            recipientId: {
              'name': recipientName ?? 'User',
              'photoUrl': recipientPhotoUrl,
            },
          },
          'createdAt': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
          'isGroup': false,
          'blockedUsers': {},
          'mutedBy': {},
          'unreadCounts': {
            userId: 0,
            recipientId: 0,
          },
          'lastReadAt': {},
        });
        DebugHelper.log(
            '📝 Chat document created on first media message: $chatId');
      }

      final batch = _firestore.batch();

      batch.set(_messagesRef(chatId).doc(message.id), messageData);

      batch.set(
        _chatDoc(chatId),
        {
          'lastMessage': messageData,
          'lastActivity': FieldValue.serverTimestamp(),
          'unreadCounts': {recipientId: FieldValue.increment(1)},
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      return true;
    } catch (e) {
      DebugHelper.logError('Error sending media message: $e');
      return false;
    }
  }

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      final now = FieldValue.serverTimestamp();

      // ALWAYS reset unread count when entering the chat, even if no unread messages
      // This ensures the badge clears reliably
      await _chatDoc(chatId).update({
        'unreadCounts.$userId': 0,
        'lastReadAt.$userId': now,
      });

      // Get unread messages from other users
      final unreadQuery = await _messagesRef(chatId)
          .where('senderId', isNotEqualTo: userId)
          .where('status', whereIn: ['sent', 'delivered'])
          .limit(100)
          .get();

      if (unreadQuery.docs.isEmpty) {
        DebugHelper.log('📖 No unread messages, but unread count reset');
        return;
      }

      final batch = _firestore.batch();

      for (final doc in unreadQuery.docs) {
        batch.update(doc.reference, {
          'status': MessageStatus.read.value,
          'readAt': now,
        });
      }

      await batch.commit();
      DebugHelper.log('📖 Marked ${unreadQuery.docs.length} messages as read');
    } catch (e) {
      DebugHelper.logError('Error marking messages as read: $e');
    }
  }

  /// Delete a message (soft delete)
  Future<bool> deleteMessage(String chatId, String messageId) async {
    try {
      await _messagesRef(chatId).doc(messageId).update({
        'isDeleted': true,
        'text': null,
        'mediaUrls': null,
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error deleting message: $e');
      return false;
    }
  }

  // ============================================================================
  // TYPING INDICATOR
  // ============================================================================

  /// Set typing status
  Future<void> setTyping(String chatId, bool isTyping) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      if (isTyping) {
        await _typingRef(chatId).doc(userId).set({
          'isTyping': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await _typingRef(chatId).doc(userId).delete();
      }
    } catch (e) {
      // Silently fail - typing indicator is not critical
      DebugHelper.log('Typing indicator error: $e');
    }
  }

  /// Stream typing status of other user
  Stream<bool> streamTypingStatus(String chatId, String otherUserId) {
    return _typingRef(chatId).doc(otherUserId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data();
      if (data == null) return false;

      final isTyping = data['isTyping'] == true;
      final timestamp = data['timestamp'] as Timestamp?;

      // Check if typing indicator is stale (> 5 seconds)
      if (timestamp != null) {
        final age = DateTime.now().difference(timestamp.toDate());
        if (age.inSeconds > 5) return false;
      }

      return isTyping;
    });
  }

  // ============================================================================
  // BLOCKING
  // ============================================================================

  /// Block a user in chat
  Future<bool> blockUser(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _chatDoc(chatId).update({
        'blockedUsers.$userId': true,
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error blocking user: $e');
      return false;
    }
  }

  /// Unblock a user in chat
  Future<bool> unblockUser(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _chatDoc(chatId).update({
        'blockedUsers.$userId': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error unblocking user: $e');
      return false;
    }
  }

  // ============================================================================
  // MUTING
  // ============================================================================

  /// Mute chat
  Future<bool> muteChat(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _chatDoc(chatId).update({
        'mutedBy.$userId': true,
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error muting chat: $e');
      return false;
    }
  }

  /// Unmute chat
  Future<bool> unmuteChat(String chatId) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _chatDoc(chatId).update({
        'mutedBy.$userId': FieldValue.delete(),
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error unmuting chat: $e');
      return false;
    }
  }

  // ============================================================================
  // USER PRESENCE
  // ============================================================================

  /// Update user's online status
  Future<void> updatePresence(bool isOnline) async {
    try {
      final userId = currentUserId;
      if (userId == null) return;

      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DebugHelper.log('Error updating presence: $e');
    }
  }

  /// Stream user's online status
  Stream<bool> streamUserOnlineStatus(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return false;
      return doc.data()?['isOnline'] == true;
    });
  }

  // ============================================================================
  // REPORTING
  // ============================================================================

  /// Report a message
  Future<bool> reportMessage({
    required String chatId,
    required String messageId,
    required String reportedUserId,
    String reason = 'Inappropriate content',
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _firestore.collection('reports').add({
        'type': 'message',
        'reporterId': userId,
        'reportedUserId': reportedUserId,
        'messageId': messageId,
        'chatId': chatId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error reporting message: $e');
      return false;
    }
  }

  /// Report a user
  Future<bool> reportUser({
    required String reportedUserId,
    String reason = 'Inappropriate behavior',
  }) async {
    try {
      final userId = currentUserId;
      if (userId == null) return false;

      await _firestore.collection('user_reports').add({
        'reporterId': userId,
        'reportedUserId': reportedUserId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return true;
    } catch (e) {
      DebugHelper.logError('Error reporting user: $e');
      return false;
    }
  }

  // ============================================================================
  // CLEAR CHAT
  // ============================================================================

  /// Clear all messages in a chat (for current user only)
  Future<bool> clearChat(String chatId) async {
    try {
      final messages = await _messagesRef(chatId).get();

      if (messages.docs.isEmpty) return true;

      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Reset last message
      await _chatDoc(chatId).update({
        'lastMessage': null,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      DebugHelper.logError('Error clearing chat: $e');
      return false;
    }
  }

  // ============================================================================
  // USER SEARCH
  // ============================================================================

  /// Search users for chat
  Future<List<ChatUser>> searchUsers(String query) async {
    try {
      final userId = currentUserId;
      if (userId == null || query.trim().isEmpty) return [];

      final queryLower = query.toLowerCase().trim();

      // Get users with matching name (first 50 for performance)
      final snapshot = await _firestore.collection('users').limit(50).get();

      final results = <ChatUser>[];
      for (final doc in snapshot.docs) {
        if (doc.id == userId) continue; // Exclude current user

        final user = ChatUser.fromFirestore(doc);
        final nameLower = user.name.toLowerCase();
        final phoneLower = user.phoneNumber?.toLowerCase() ?? '';

        if (nameLower.contains(queryLower) || phoneLower.contains(queryLower)) {
          results.add(user);
        }
      }

      return results;
    } catch (e) {
      DebugHelper.logError('Error searching users: $e');
      return [];
    }
  }

  /// Get recent contacts (users with existing chats)
  Future<List<ChatUser>> getRecentContacts({int limit = 10}) async {
    try {
      final userId = currentUserId;
      if (userId == null) return [];

      // Get recent chats
      final chatsSnapshot = await _chatsRef
          .where('participants', arrayContains: userId)
          .orderBy('lastActivity', descending: true)
          .limit(limit)
          .get();

      // Extract other participant IDs
      final otherUserIds = <String>{};
      for (final chat in chatsSnapshot.docs) {
        final participants = List<String>.from(chat['participants'] ?? []);
        for (final id in participants) {
          if (id != userId) otherUserIds.add(id);
        }
      }

      if (otherUserIds.isEmpty) return [];

      // Fetch user data
      final usersSnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: otherUserIds.toList())
          .get();

      return usersSnapshot.docs
          .map((doc) => ChatUser.fromFirestore(doc))
          .toList();
    } catch (e) {
      DebugHelper.logError('Error getting recent contacts: $e');
      return [];
    }
  }
}
