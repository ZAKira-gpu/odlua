// ─────────────────────────────────────────
// Model: ChatModels
// Description: Data classes for chat conversations and messages.
// Contains: ChatConversation, ChatMessage, fromMap/toMap
// ─────────────────────────────────────────

// ============================================================================
// CHAT MODELS - Production-Grade Data Structures
// ============================================================================
// Clean, immutable models with proper serialization and lifecycle tracking
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// ============================================================================
// ENUMS
// ============================================================================

/// Message types supported in chat
enum MessageType {
  text,
  image,
  video,
  audio,
  file,
  system; // For system messages like "User joined", etc.

  String get value => name;

  static MessageType fromString(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Message delivery status - follows proper lifecycle
/// pending → sending → sent → delivered → read
enum MessageStatus {
  pending, // Queued locally, not yet attempted
  sending, // Currently being sent to server
  sent, // Confirmed written to server
  delivered, // Recipient's device received it
  read, // Recipient opened and viewed it
  failed; // Send attempt failed

  String get value => name;

  static MessageStatus fromString(String? value) {
    return MessageStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageStatus.sent,
    );
  }

  /// Check if message is in a terminal state
  bool get isTerminal => this == failed || this == read;

  /// Check if message can be retried
  bool get canRetry => this == failed;

  /// Check if message is still in flight
  bool get isInFlight => this == pending || this == sending;
}

// ============================================================================
// CHAT MESSAGE
// ============================================================================

/// Immutable chat message model with full lifecycle tracking
@immutable
class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final MessageType type;
  final List<String>? mediaUrls;
  final MessageStatus status;
  final bool isDeleted;
  final String? replyToId;
  final String? replyToText;

  // Timestamps - all use server time when available
  final DateTime createdAt; // When message was created
  final DateTime? sentAt; // When confirmed sent to server
  final DateTime? deliveredAt; // When delivered to recipient
  final DateTime? readAt; // When read by recipient

  // Idempotency key for safe retries
  final String? idempotencyKey;

  // Local-only flag (not persisted)
  final bool isLocal;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    required this.type,
    this.mediaUrls,
    required this.status,
    this.isDeleted = false,
    this.replyToId,
    this.replyToText,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    this.readAt,
    this.idempotencyKey,
    this.isLocal = false,
  });

  /// Create a new local message (optimistic UI)
  factory ChatMessage.local({
    required String id,
    required String chatId,
    required String senderId,
    required String text,
    String? replyToId,
    String? replyToText,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      text: text,
      type: MessageType.text,
      status: MessageStatus.pending,
      createdAt: DateTime.now(),
      idempotencyKey: id, // Use same ID for idempotency
      replyToId: replyToId,
      replyToText: replyToText,
      isLocal: true,
    );
  }

  /// Create a media message placeholder
  factory ChatMessage.mediaPlaceholder({
    required String id,
    required String chatId,
    required String senderId,
    required MessageType type,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
      idempotencyKey: id,
      isLocal: true,
    );
  }

  /// Create from Firestore document
  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage.fromMap({...data, 'id': doc.id});
  }

  /// Create from map (handles various timestamp formats)
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'],
      type: MessageType.fromString(map['type']),
      mediaUrls:
          map['mediaUrls'] != null ? List<String>.from(map['mediaUrls']) : null,
      status: MessageStatus.fromString(map['status']),
      isDeleted: map['isDeleted'] ?? false,
      replyToId: map['replyToId'],
      replyToText: map['replyToText'],
      createdAt: _parseTimestamp(map['createdAt']) ?? DateTime.now(),
      sentAt: _parseTimestamp(map['sentAt']),
      deliveredAt: _parseTimestamp(map['deliveredAt']),
      readAt: _parseTimestamp(map['readAt']),
      idempotencyKey: map['idempotencyKey'],
      isLocal: false,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type.value,
      'mediaUrls': mediaUrls,
      'status': status.value,
      'isDeleted': isDeleted,
      'replyToId': replyToId,
      'replyToText': replyToText,
      'createdAt': Timestamp.fromDate(createdAt),
      if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
      if (deliveredAt != null) 'deliveredAt': Timestamp.fromDate(deliveredAt!),
      if (readAt != null) 'readAt': Timestamp.fromDate(readAt!),
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
  }

  /// Create a copy with modified fields
  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    MessageType? type,
    List<String>? mediaUrls,
    MessageStatus? status,
    bool? isDeleted,
    String? replyToId,
    String? replyToText,
    DateTime? createdAt,
    DateTime? sentAt,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? idempotencyKey,
    bool? isLocal,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      createdAt: createdAt ?? this.createdAt,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      isLocal: isLocal ?? this.isLocal,
    );
  }

  /// Helper to parse various timestamp formats
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// ============================================================================
// CHAT ROOM
// ============================================================================

/// Chat room / conversation model
@immutable
class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, ParticipantData> participantData;
  final ChatMessage? lastMessage;
  final DateTime lastActivity;
  final DateTime createdAt;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime> lastReadAt;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final List<String>? admins;
  final Map<String, bool> blockedUsers;
  final Map<String, bool> mutedBy;
  final bool isArchived;

  const ChatRoom({
    required this.id,
    required this.participants,
    required this.participantData,
    this.lastMessage,
    required this.lastActivity,
    required this.createdAt,
    this.unreadCounts = const {},
    this.lastReadAt = const {},
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    this.admins,
    this.blockedUsers = const {},
    this.mutedBy = const {},
    this.isArchived = false,
  });

  /// Create from Firestore document
  factory ChatRoom.fromFirestore(DocumentSnapshot doc, String currentUserId) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatRoom.fromMap({...data, 'id': doc.id}, currentUserId);
  }

  /// Create from map
  factory ChatRoom.fromMap(Map<String, dynamic> map, String currentUserId) {
    // Parse participant data
    final rawParticipantData =
        Map<String, dynamic>.from(map['participantData'] ?? {});
    final participantData = <String, ParticipantData>{};
    rawParticipantData.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        participantData[key] = ParticipantData.fromMap(value);
      }
    });

    // Parse last message
    ChatMessage? lastMessage;
    if (map['lastMessage'] is Map<String, dynamic>) {
      lastMessage = ChatMessage.fromMap(map['lastMessage']);
    }

    // Parse unread counts
    final unreadCounts = <String, int>{};
    final rawUnreadCounts = map['unreadCounts'];
    if (rawUnreadCounts is Map) {
      rawUnreadCounts.forEach((key, value) {
        unreadCounts[key.toString()] = (value as num?)?.toInt() ?? 0;
      });
    }

    // Parse last read timestamps
    final lastReadAt = <String, DateTime>{};
    final rawLastReadAt = map['lastReadAt'];
    if (rawLastReadAt is Map) {
      rawLastReadAt.forEach((key, value) {
        final dt = ChatMessage._parseTimestamp(value);
        if (dt != null) {
          lastReadAt[key.toString()] = dt;
        }
      });
    }

    return ChatRoom(
      id: map['id'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      participantData: participantData,
      lastMessage: lastMessage,
      lastActivity:
          ChatMessage._parseTimestamp(map['lastActivity']) ?? DateTime.now(),
      createdAt:
          ChatMessage._parseTimestamp(map['createdAt']) ?? DateTime.now(),
      unreadCounts: unreadCounts,
      lastReadAt: lastReadAt,
      isGroup: map['isGroup'] ?? false,
      groupName: map['groupName'],
      groupPhoto: map['groupPhoto'],
      admins: map['admins'] != null ? List<String>.from(map['admins']) : null,
      blockedUsers: map['blockedUsers'] != null
          ? Map<String, bool>.from(map['blockedUsers'])
          : {},
      mutedBy:
          map['mutedBy'] != null ? Map<String, bool>.from(map['mutedBy']) : {},
      isArchived: map['isArchived'] ?? false,
    );
  }

  /// Get unread count for a specific user
  int getUnreadCount(String userId) => unreadCounts[userId] ?? 0;

  /// Check if user has blocked the other participant
  bool hasBlocked(String userId) => blockedUsers[userId] == true;

  /// Check if user is blocked by the other participant
  bool isBlockedBy(String otherUserId) => blockedUsers[otherUserId] == true;

  /// Check if user has muted this chat
  bool isMutedBy(String userId) => mutedBy[userId] == true;

  /// Get the other participant's ID (for 1:1 chats)
  String getOtherParticipantId(String currentUserId) {
    return participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : '',
    );
  }

  /// Get participant data for a user
  ParticipantData? getParticipant(String userId) => participantData[userId];

  ChatRoom copyWith({
    String? id,
    List<String>? participants,
    Map<String, ParticipantData>? participantData,
    ChatMessage? lastMessage,
    DateTime? lastActivity,
    DateTime? createdAt,
    Map<String, int>? unreadCounts,
    Map<String, DateTime>? lastReadAt,
    bool? isGroup,
    String? groupName,
    String? groupPhoto,
    List<String>? admins,
    Map<String, bool>? blockedUsers,
    Map<String, bool>? mutedBy,
    bool? isArchived,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      participantData: participantData ?? this.participantData,
      lastMessage: lastMessage ?? this.lastMessage,
      lastActivity: lastActivity ?? this.lastActivity,
      createdAt: createdAt ?? this.createdAt,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isGroup: isGroup ?? this.isGroup,
      groupName: groupName ?? this.groupName,
      groupPhoto: groupPhoto ?? this.groupPhoto,
      admins: admins ?? this.admins,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      mutedBy: mutedBy ?? this.mutedBy,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

// ============================================================================
// PARTICIPANT DATA
// ============================================================================

/// Data about a chat participant
@immutable
class ParticipantData {
  final String name;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;

  const ParticipantData({
    required this.name,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ParticipantData.fromMap(Map<String, dynamic> map) {
    return ParticipantData(
      name: map['name'] ?? 'Unknown',
      photoUrl: map['photoUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: ChatMessage._parseTimestamp(map['lastSeen']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      if (lastSeen != null) 'lastSeen': Timestamp.fromDate(lastSeen!),
    };
  }
}

// ============================================================================
// CHAT USER
// ============================================================================

/// User model for chat purposes
@immutable
class ChatUser {
  final String uid;
  final String name;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? fcmToken;

  const ChatUser({
    required this.uid,
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.fcmToken,
  });

  factory ChatUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatUser.fromMap(doc.id, data);
  }

  factory ChatUser.fromMap(String id, Map<String, dynamic> map) {
    return ChatUser(
      uid: map['uid'] ?? id,
      name: map['name'] ??
          map['displayName'] ??
          map['username'] ??
          map['fullName'] ??
          'Unknown User',
      phoneNumber: map['phone'] ?? map['phoneNumber'] ?? map['mobile'],
      photoUrl: map['photoURL'] ??
          map['photoUrl'] ??
          map['profilePicture'] ??
          map['avatar'] ??
          map['imageUrl'],
      isOnline: map['isOnline'] ?? false,
      lastSeen: ChatMessage._parseTimestamp(map['lastSeen']),
      fcmToken: map['fcmToken'],
    );
  }

  /// Convert to ParticipantData for chat room
  ParticipantData toParticipantData() {
    return ParticipantData(
      name: name,
      photoUrl: photoUrl,
      isOnline: isOnline,
      lastSeen: lastSeen,
    );
  }
}

// ============================================================================
// TYPING INDICATOR
// ============================================================================

/// Typing indicator state
@immutable
class TypingIndicator {
  final String oderId;
  final bool isTyping;
  final DateTime? timestamp;

  const TypingIndicator({
    required this.oderId,
    required this.isTyping,
    this.timestamp,
  });

  factory TypingIndicator.fromMap(String oderId, Map<String, dynamic> map) {
    return TypingIndicator(
      oderId: oderId,
      isTyping: map['isTyping'] ?? false,
      timestamp: ChatMessage._parseTimestamp(map['timestamp']),
    );
  }

  /// Check if typing indicator is still valid (within 5 seconds)
  bool get isValid {
    if (!isTyping || timestamp == null) return false;
    return DateTime.now().difference(timestamp!).inSeconds < 5;
  }
}

// ============================================================================
// CHAT STATE
// ============================================================================

/// Immutable state for a chat conversation
@immutable
class ChatState {
  final bool isLoading;
  final bool isSending;
  final bool hasError;
  final String? errorMessage;
  final List<ChatMessage> messages;
  final Set<String> pendingMessageIds;
  final Map<String, ChatMessage> failedMessages;
  final bool isTyping;
  final bool isBlocked;
  final bool isBlockedByOther;
  final bool hasMoreMessages;
  final DocumentSnapshot? lastDocument; // For pagination cursor

  const ChatState({
    this.isLoading = true,
    this.isSending = false,
    this.hasError = false,
    this.errorMessage,
    this.messages = const [],
    this.pendingMessageIds = const {},
    this.failedMessages = const {},
    this.isTyping = false,
    this.isBlocked = false,
    this.isBlockedByOther = false,
    this.hasMoreMessages = true,
    this.lastDocument,
  });

  const ChatState.initial() : this();

  ChatState copyWith({
    bool? isLoading,
    bool? isSending,
    bool? hasError,
    String? errorMessage,
    List<ChatMessage>? messages,
    Set<String>? pendingMessageIds,
    Map<String, ChatMessage>? failedMessages,
    bool? isTyping,
    bool? isBlocked,
    bool? isBlockedByOther,
    bool? hasMoreMessages,
    DocumentSnapshot? lastDocument,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasError: hasError ?? false,
      errorMessage: errorMessage,
      messages: messages ?? this.messages,
      pendingMessageIds: pendingMessageIds ?? this.pendingMessageIds,
      failedMessages: failedMessages ?? this.failedMessages,
      isTyping: isTyping ?? this.isTyping,
      isBlocked: isBlocked ?? this.isBlocked,
      isBlockedByOther: isBlockedByOther ?? this.isBlockedByOther,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }
}

// ============================================================================
// CHAT LIST STATE
// ============================================================================

/// Immutable state for chat list screen
@immutable
class ChatListState {
  final bool isLoading;
  final bool hasError;
  final String? errorMessage;
  final List<ChatRoom> chats;

  const ChatListState({
    this.isLoading = true,
    this.hasError = false,
    this.errorMessage,
    this.chats = const [],
  });

  const ChatListState.initial() : this();

  ChatListState copyWith({
    bool? isLoading,
    bool? hasError,
    String? errorMessage,
    List<ChatRoom>? chats,
  }) {
    return ChatListState(
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? false,
      errorMessage: errorMessage,
      chats: chats ?? this.chats,
    );
  }
}
