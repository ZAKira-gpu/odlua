// ─────────────────────────────────────────
// Screen: ChatListScreen
// Description: Displays all conversations for the current user,
//              sorted by last message. Supports search, empty state,
//              and navigation to conversation or user search.
// Contains: Chat list, real-time Firestore stream, search bar
// ─────────────────────────────────────────
// Clean, calm, and private feeling chat list with smooth animations
// and proper state management.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:odlua/utils/models/chat_models.dart';
import 'package:odlua/utils/services/chat_controller.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/layout/chat/chat_user_search_screen/chat_user_search_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with WidgetsBindingObserver {
  late final ChatListController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ChatListController();
    _controller.addListener(_onStateChange);
    _controller.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.onResume();
    } else if (state == AppLifecycleState.paused) {
      _controller.onPause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onStateChange);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _navigateToSearch() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const ChatUserSearchScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _openChat(ChatRoom chat) {
    HapticFeedback.selectionClick();

    final otherParticipantId =
        chat.getOtherParticipantId(_controller.currentUserId);
    final participant = chat.getParticipant(otherParticipantId);

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChatConversationScreen(
          chatId: chat.id,
          recipientId: otherParticipantId,
          recipientName: participant?.name ?? 'Chat',
          recipientImage: participant?.photoUrl,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.05, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 280),
      ),
    ).then((_) {
      // Refresh chat list to update unread counts
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: textColor,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'messages'.tr(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getSubtitle(),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          _buildSearchButton(),
        ],
      ),
    );
  }

  String _getSubtitle() {
    final state = _controller.state;
    if (state.isLoading) return 'loading'.tr();
    final count = state.chats.length;
    if (count == 0) return 'no_conversations'.tr();
    return '$count ${count == 1 ? 'conversation'.tr() : 'conversations'.tr()}';
  }

  Widget _buildSearchButton() {
    return Container(
      decoration: BoxDecoration(
        color: mainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _navigateToSearch,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              Icons.search_rounded,
              color: mainColor,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final state = _controller.state;

    if (state.hasError) {
      return _buildErrorState();
    }

    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.chats.isEmpty) {
      return _buildEmptyState();
    }

    return _buildChatList();
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) => _buildShimmerItem(index),
    );
  }

  Widget _buildShimmerItem(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 180,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(delay: (index * 80).ms)
        .shimmer(duration: 1200.ms, color: Colors.grey.shade300)
        .fadeIn(duration: 300.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: mainColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: mainColor.withValues(alpha: 0.6),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 28),
            Text(
              'start_a_conversation'.tr(),
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 12),
            Text(
              'connect_with_chefs'.tr(),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.2),
            const SizedBox(height: 36),
            _buildStartChatButton()
                .animate(delay: 300.ms)
                .fadeIn()
                .slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildStartChatButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: mainColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _navigateToSearch,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  'new_message'.tr(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'connection_error'.tr(),
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'check_connection_try_again'.tr(),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            TextButton.icon(
              onPressed: () => _controller.refresh(),
              icon: const Icon(Icons.refresh_rounded),
              label: Text('retry'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: mainColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    final chats = _controller.state.chats;

    return RefreshIndicator(
      onRefresh: () => _controller.refresh(),
      color: mainColor,
      backgroundColor: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          return _buildChatItem(chat, index);
        },
      ),
    );
  }

  Widget _buildChatItem(ChatRoom chat, int index) {
    final currentUserId = _controller.currentUserId;
    final otherParticipantId = chat.getOtherParticipantId(currentUserId);
    final participant = chat.getParticipant(otherParticipantId);
    final isBlockedByOther = chat.isBlockedBy(otherParticipantId);
    final hasBlocked = chat.hasBlocked(currentUserId);
    final unreadCount = chat.getUnreadCount(currentUserId);

    if (isBlockedByOther) {
      return _buildBlockedByOtherItem(chat, participant, index);
    }

    final userName = participant?.name ?? 'Unknown';
    final userPhoto = participant?.photoUrl;
    final lastMessage = chat.lastMessage;
    final isOnline = participant?.isOnline ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasBlocked ? null : () => _openChat(chat),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with online indicator
                _buildAvatar(userPhoto, isOnline, unreadCount),
                const SizedBox(width: 14),

                // Content
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
                                color: hasBlocked
                                    ? textColor.withValues(alpha: 0.4)
                                    : textColor,
                                fontSize: 16,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(chat.lastActivity),
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? mainColor
                                  : textColor.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _buildMessagePreview(
                          lastMessage, hasBlocked, unreadCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: (index * 40).ms)
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.02);
  }

  Widget _buildAvatar(String? photoUrl, bool isOnline, int unreadCount) {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: mainColor.withValues(alpha: 0.08),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: photoUrl != null && photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => _buildAvatarPlaceholder(),
                    errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                  )
                : _buildAvatarPlaceholder(),
          ),
        ),

        // Online indicator
        if (isOnline)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFF4ADE80),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),

        // Unread badge
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: mainColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: mainColor.withValues(alpha: 0.08),
      child: Icon(Icons.person_rounded, color: mainColor, size: 26),
    );
  }

  Widget _buildMessagePreview(
    ChatMessage? lastMessage,
    bool hasBlocked,
    int unreadCount,
  ) {
    String text;
    TextStyle style;

    if (hasBlocked) {
      text = 'you_blocked_this_user'.tr();
      style = TextStyle(
        color: Colors.orange.shade600,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      );
    } else if (lastMessage == null) {
      text = 'no_messages_yet'.tr();
      style = TextStyle(
        color: textColor.withValues(alpha: 0.4),
        fontSize: 14,
        fontStyle: FontStyle.italic,
      );
    } else if (lastMessage.isDeleted) {
      text = 'message_deleted'.tr();
      style = TextStyle(
        color: textColor.withValues(alpha: 0.4),
        fontSize: 14,
        fontStyle: FontStyle.italic,
      );
    } else {
      text = lastMessage.type == MessageType.text
          ? lastMessage.text ?? ''
          : _getMediaPreviewText(lastMessage.type);
      style = TextStyle(
        color: unreadCount > 0
            ? textColor.withValues(alpha: 0.8)
            : textColor.withValues(alpha: 0.5),
        fontSize: 14,
        fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
      );
    }

    return Text(
      text,
      style: style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getMediaPreviewText(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 ${'photo'.tr()}';
      case MessageType.video:
        return '🎥 ${'video'.tr()}';
      case MessageType.audio:
        return '🎵 ${'audio'.tr()}';
      case MessageType.file:
        return '📎 ${'file'.tr()}';
      default:
        return '';
    }
  }

  Widget _buildBlockedByOtherItem(
    ChatRoom chat,
    ParticipantData? participant,
    int index,
  ) {
    return Opacity(
      opacity: 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.block_rounded, color: Colors.grey.shade400),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    participant?.name ?? 'Unknown',
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.4),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'blocked_by_user'.tr(),
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate(delay: (index * 40).ms).fadeIn(duration: 300.ms),
    );
  }

  Widget _buildFAB() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: _navigateToSearch,
        backgroundColor: mainColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 400.ms)
        .scale(begin: const Offset(0.8, 0.8));
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr();
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(dateTime);
    } else {
      return DateFormat('d MMM').format(dateTime);
    }
  }
}
