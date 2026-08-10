import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/layout/chat/chat_user_search_screen/chat_user_search_screen.dart';
import 'package:odlua/utils/models/chat_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<ChatRoom> _chats = [];
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState(); 
    WidgetsBinding.instance.addObserver(this);
    _initializeChats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUserOnlineStatus(true);
    } else if (state == AppLifecycleState.paused) {
      _updateUserOnlineStatus(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatsSubscription?.cancel();
    _updateUserOnlineStatus(false);
    super.dispose();
  }

  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DebugHelper.log('Error updating online status: $e');
    }
  }

  Future<void> _initializeChats() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    _currentUserId = user.uid;

    try {
      _chatsSubscription = _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastActivity', descending: true)
          .snapshots()
          .listen(_onChatsUpdate, onError: _onChatsError);

      await _updateUserOnlineStatus(true);
    } catch (e) {
      _onChatsError(e);
    }
  }

  void _onChatsUpdate(QuerySnapshot snapshot) {
    try {
      final chats = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        
        ChatMessage? lastMessage;
        final lastMessageData = data['lastMessage'];
        if (lastMessageData is Map<String, dynamic>) {
          lastMessage = ChatMessage.fromMap(lastMessageData);
        }

        DateTime lastActivity;
        if (data['lastActivity'] != null) {
          if (data['lastActivity'] is Timestamp) {
            lastActivity = (data['lastActivity'] as Timestamp).toDate();
          } else if (data['lastActivity'] is int) {
            lastActivity = DateTime.fromMillisecondsSinceEpoch(data['lastActivity']);
          } else {
            lastActivity = DateTime.now();
          }
        } else {
          lastActivity = DateTime.now();
        }

        final unreadCounts = Map<String, dynamic>.from(data['unreadCounts'] ?? {});
        final unreadCount = (unreadCounts[_currentUserId] ?? 0) as int;

        return ChatRoom(
          id: doc.id,
          participants: List<String>.from(data['participants'] ?? []),
          participantData: Map<String, dynamic>.from(data['participantData'] ?? {}),
          lastMessage: lastMessage,
          lastActivity: lastActivity,
          unreadCount: unreadCount,
          isGroup: data['isGroup'] ?? false,
          groupName: data['groupName'],
          groupPhoto: data['groupPhoto'],
          admins: data['admins'] != null ? List<String>.from(data['admins']) : null,
          settings: data['settings'] != null ? Map<String, dynamic>.from(data['settings']) : null,
          blockedUsers: data['blockedUsers'] != null ? Map<String, bool>.from(data['blockedUsers']) : {},
        );
      }).toList();

      setState(() {
        _chats = chats;
        _isLoading = false;
        _hasError = false;
      });
    } catch (e) {
      DebugHelper.log('Error parsing chats: $e');
      _onChatsError(e);
    }
  }

  void _onChatsError(error) {
    setState(() {
      _hasError = true;
      _errorMessage = error.toString();
      _isLoading = false;
    });
  }

  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatUserSearchScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('chats'.tr(), 
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 22),
              onPressed: _navigateToSearch,
              tooltip: 'search_users'.tr(),
            ),
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorState()
          : _isLoading
              ? _buildLoadingState()
              : _chats.isEmpty
                  ? _buildEmptyState()
                  : _buildChatList(),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton(
          onPressed: _navigateToSearch,
          backgroundColor: mainColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.chat, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            Text(
              'error_loading_chats'.tr(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeChats,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(
                'retry'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => _buildChatShimmer(),
    );
  }

  Widget _buildChatShimmer() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 80,
                color: mainColor.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'no_chats_yet'.tr(),
              style: TextStyle(
                fontSize: 24,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'start_conversation_hint'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _navigateToSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: mainColor.withOpacity(0.3),
              ),
              child: Text(
                'start_chatting'.tr(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView.separated(
        itemCount: _chats.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return _buildChatListItem(chat);
        },
      ),
    );
  }

  Widget _buildChatListItem(ChatRoom chat) {
    final otherParticipantId = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => chat.participants.isNotEmpty ? chat.participants.first : '',
    );
    
    final participantData = chat.participantData[otherParticipantId] as Map<String, dynamic>? ?? {};
    final isBlocked = chat.blockedUsers[_currentUserId] == true;
    final hasBlockedYou = chat.blockedUsers[otherParticipantId] == true;

    final userName = participantData['name'] ?? 'unknown_user'.tr();
    final userPhoto = participantData['photoUrl'];
    final lastMessage = chat.lastMessage?.text ?? 'no_messages_yet'.tr();

    if (hasBlockedYou) {
      return _buildBlockedChatListItem(chat, userName, userPhoto);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isBlocked ? null : () => _openChat(chat, userName, userPhoto),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: mainColor.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: userPhoto != null && userPhoto.isNotEmpty
                            ? Image.network(
                                userPhoto,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: mainColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: mainColor,
                                      size: 28,
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: mainColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: mainColor,
                                      size: 28,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: mainColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  color: mainColor,
                                  size: 28,
                                ),
                              ),
                      ),
                    ),
                    // Online indicator
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Unread count badge
                    if (chat.unreadCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Text(
                            chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                
                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isBlocked ? textColor.withOpacity(0.4) : textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(chat.lastActivity),
                            style: TextStyle(
                              color: textColor.withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBlocked ? 'you_have_blocked_this_user'.tr() : lastMessage,
                        style: TextStyle(
                          color: isBlocked ? Colors.orange.shade600 : textColor.withOpacity(0.6),
                          fontSize: 14,
                          fontStyle: isBlocked ? FontStyle.italic : FontStyle.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlockedChatListItem(ChatRoom chat, String userName, String? userPhoto) {
    return Opacity(
      opacity: 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: userPhoto != null && userPhoto.isNotEmpty
                      ? Image.network(
                          userPhoto,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.block, color: Colors.grey.shade500, size: 28);
                          },
                        )
                      : Icon(Icons.block, color: Colors.grey.shade500, size: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: textColor.withOpacity(0.4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'you_are_blocked_by_this_user'.tr(),
                      style: TextStyle(
                        color: Colors.red.shade600,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatTime(chat.lastActivity),
                style: TextStyle(
                  color: textColor.withOpacity(0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat(ChatRoom chat, String recipientName, String? recipientImage) {
    final otherParticipantId = chat.participants.firstWhere(
      (id) => id != _currentUserId,
      orElse: () => chat.participants.isNotEmpty ? chat.participants.first : '',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(
          chatId: chat.id,
          recipientId: otherParticipantId,
          recipientName: recipientName,
          recipientImage: recipientImage,
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 7) {
      return '${(difference.inDays / 7).floor()}w';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now'.tr();
    }
  }
}