// ─────────────────────────────────────────
// Service: ChatService
// Description: High-level chat API with navigation helpers and notifications.
// Contains: openConversation, sendWithNotification
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Result of a chat operation
class ChatResult {
  final bool success;
  final String? chatId;
  final String? error;

  ChatResult({required this.success, this.chatId, this.error});
}

/// Centralized chat service for creating and managing chat conversations.
/// This ensures consistent chat creation across all entry points.
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Static method to navigate to chat - the primary entry point for chat initiation.
  /// Creates chat if needed and navigates to the conversation screen.
  static Future<ChatResult> navigateToChat({
    required BuildContext context,
    required String recipientId,
    required String recipientName,
    String? recipientImage,
    bool isOrderChat = false,
    String? orderId,
  }) async {
    try {
      final service = ChatService();

      final chatId = await service.getOrCreateChat(
        recipientId: recipientId,
        recipientName: recipientName,
        recipientPhotoUrl: recipientImage,
        isOrderChat: isOrderChat,
        orderId: orderId,
      );

      if (chatId == null) {
        return ChatResult(
          success: false,
          error: 'Failed to create chat',
        );
      }

      // Navigate to chat screen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              chatId: chatId,
              recipientId: recipientId,
              recipientName: recipientName,
              recipientImage: recipientImage,
              isOrderChat: isOrderChat,
            ),
          ),
        );
      }

      return ChatResult(success: true, chatId: chatId);
    } catch (e) {
      DebugHelper.logError('Error in navigateToChat: $e');
      return ChatResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Generate a deterministic chat ID from two user IDs.
  /// Always returns the same ID regardless of parameter order.
  String generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Get or create a chat conversation between two users.
  /// This is idempotent - calling multiple times will not create duplicates.
  ///
  /// Returns the chat ID on success, null on failure.
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
      DebugHelper.log(
          '🧩 ChatService.getOrCreateChat -> chatId=$chatId, currentUserId=$currentUserId, recipientId=$recipientId');
      final chatRef = _firestore.collection('chats').doc(chatId);

      // Build sorted participants array
      final participants = [currentUserId, recipientId]..sort();

      // Create chat data - always include participants to fix broken docs
      final chatData = <String, dynamic>{
        'id': chatId,
        'participants': participants,
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
        'blockedUsers': {},
        'unreadCounts': {
          currentUserId: 0,
          recipientId: 0,
        },
      };

      // Add order-specific fields if applicable
      if (isOrderChat) {
        chatData['isOrderChat'] = true;
        if (orderId != null) {
          chatData['orderId'] = orderId;
        }
      }

      // Use set with merge to create or update the document
      await chatRef.set(chatData, SetOptions(merge: true));

      // Set createdAt only if it doesn't exist
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
            '❌ ChatService error creating chat (code=${e.code}): ${e.message}');
      } else {
        DebugHelper.logError('❌ ChatService error creating chat: $e');
      }
      return null;
    }
  }

  /// Update participant data in an existing chat.
  /// Useful when user updates their profile.
  Future<void> updateParticipantData({
    required String chatId,
    required String userId,
    required String name,
    String? photoUrl,
  }) async {
    try {
      await _firestore.collection('chats').doc(chatId).update({
        'participantData.$userId': {
          'name': name,
          'photoUrl': photoUrl,
        },
      });
    } catch (e) {
      DebugHelper.logError('Error updating participant data: $e');
    }
  }

  /// Check if a chat exists between two users.
  Future<bool> chatExists(String userId1, String userId2) async {
    final chatId = generateChatId(userId1, userId2);
    final doc = await _firestore.collection('chats').doc(chatId).get();
    return doc.exists;
  }

  /// Get chat document by ID.
  Future<DocumentSnapshot?> getChat(String chatId) async {
    try {
      return await _firestore.collection('chats').doc(chatId).get();
    } catch (e) {
      DebugHelper.logError('Error getting chat: $e');
      return null;
    }
  }

  /// Migrate old chats to new schema (run once if needed).
  /// This updates chats that are missing the new required fields.
  Future<void> migrateChat(String chatId) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return;

      final data = chatDoc.data() as Map<String, dynamic>;
      final updates = <String, dynamic>{};

      // Ensure 'id' field exists
      if (!data.containsKey('id')) {
        updates['id'] = chatId;
      }

      // Migrate lastMessageTime to lastActivity
      if (data.containsKey('lastMessageTime') &&
          !data.containsKey('lastActivity')) {
        updates['lastActivity'] = data['lastMessageTime'];
      }

      // Ensure lastActivity exists
      if (!data.containsKey('lastActivity') &&
          !data.containsKey('lastMessageTime')) {
        updates['lastActivity'] = FieldValue.serverTimestamp();
      }

      // Migrate unreadCount to unreadCounts
      if (data.containsKey('unreadCount') &&
          !data.containsKey('unreadCounts')) {
        updates['unreadCounts'] = data['unreadCount'];
      }

      // Ensure blockedUsers exists
      if (!data.containsKey('blockedUsers')) {
        updates['blockedUsers'] = {};
      }

      // Apply updates if any
      if (updates.isNotEmpty) {
        await _firestore.collection('chats').doc(chatId).update(updates);
        DebugHelper.log(
            '🔧 Migrated chat $chatId with updates: ${updates.keys}');
      }
    } catch (e) {
      DebugHelper.logError('Error migrating chat: $e');
    }
  }
}
