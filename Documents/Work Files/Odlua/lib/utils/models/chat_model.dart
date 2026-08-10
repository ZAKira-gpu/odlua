import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio, file }
enum MessageStatus { sending, sent, delivered, read, failed }

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String? text;
  final MessageType type;
  final List<String>? mediaUrls;
  final DateTime timestamp;
  final MessageStatus status;
  final bool isDeleted;
  final String? replyTo;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.text,
    required this.type,
    this.mediaUrls,
    required this.timestamp,
    required this.status,
    this.isDeleted = false,
    this.replyTo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'type': type.toString().split('.').last,
      'mediaUrls': mediaUrls,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'isDeleted': isDeleted,
      'replyTo': replyTo,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'],
      type: _parseMessageType(map['type']),
      mediaUrls: map['mediaUrls'] != null ? List<String>.from(map['mediaUrls']) : null,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
      status: _parseMessageStatus(map['status']),
      isDeleted: map['isDeleted'] ?? false,
      replyTo: map['replyTo'],
    );
  }

  static MessageType _parseMessageType(String type) {
    switch (type) {
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'audio':
        return MessageType.audio;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }

  static MessageStatus _parseMessageStatus(String status) {
    switch (status) {
      case 'sending':
        return MessageStatus.sending;
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.sent;
    }
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    MessageType? type,
    List<String>? mediaUrls,
    DateTime? timestamp,
    MessageStatus? status,
    bool? isDeleted,
    String? replyTo,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      type: type ?? this.type,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      replyTo: replyTo ?? this.replyTo,
    );
  }
}

class ChatRoom {
  final String id;
  final List<String> participants;
  final Map<String, dynamic> participantData;
  final ChatMessage? lastMessage;
  final DateTime lastActivity;
  final int unreadCount;
  final bool isGroup;
  final String? groupName;
  final String? groupPhoto;
  final List<String>? admins;
  final Map<String, dynamic>? settings;
  final Map<String, bool> blockedUsers;

  ChatRoom({
    required this.id,
    required this.participants,
    required this.participantData,
    this.lastMessage,
    required this.lastActivity,
    required this.unreadCount,
    this.isGroup = false,
    this.groupName,
    this.groupPhoto,
    this.admins,
    this.settings,
    this.blockedUsers = const {},
  });
}

class ChatUser {
  final String uid;
  final String name;
  final String? phoneNumber;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final String? fcmToken;

  ChatUser({
    required this.uid,
    required this.name,
    this.phoneNumber,
    this.photoUrl,
    this.isOnline = false,
    this.lastSeen,
    this.fcmToken,
  });

  factory ChatUser.fromMap(String id, Map<String, dynamic> map) {
    // Handle lastSeen field - it can be Timestamp or int
    DateTime? lastSeen;
    final lastSeenData = map['lastSeen'];
    if (lastSeenData != null) {
      if (lastSeenData is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenData);
      } else if (lastSeenData is Timestamp) {
        lastSeen = lastSeenData.toDate();
      }
    }

    return ChatUser(
      uid: id,
      name: map['name'] ?? map['displayName'] ?? map['username'] ?? map['fullName'] ?? 'Unknown User',
      phoneNumber: map['phone'] ?? map['phoneNumber'] ?? map['mobile'] ?? '',
      photoUrl: map['photoURL'] ?? map['photoUrl'] ?? map['profilePicture'] ?? map['avatar'] ?? map['imageUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: lastSeen,
      fcmToken: map['fcmToken'],
    );
  }
}