// ─────────────────────────────────────────
// Screen: ChatConversationScreen
// Description: Real-time one-on-one messaging with text, images,
//              read receipts, typing indicators, and moderation.
// Contains: Message list, input bar, image viewer, block/report
// ─────────────────────────────────────────
// Private, calm, and safe feeling chat experience with smooth animations,
// proper message grouping, and clean state management.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:odlua/utils/models/chat_models.dart';
import 'package:odlua/utils/services/chat_controller.dart';
import 'package:odlua/utils/services/chat_repository.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/layout/chat/widgets/full_screen_image_viewer.dart';

class ChatConversationScreen extends StatefulWidget {
  final String chatId;
  final String recipientId;
  final String recipientName;
  final String? recipientImage;
  final bool isOrderChat;

  const ChatConversationScreen({
    super.key,
    required this.chatId,
    required this.recipientId,
    required this.recipientName,
    this.recipientImage,
    this.isOrderChat = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen>
    with WidgetsBindingObserver {
  late final ChatConversationController _controller;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ChatConversationController(
      chatId: widget.chatId,
      recipientId: widget.recipientId,
      recipientName: widget.recipientName,
      recipientImage: widget.recipientImage,
    );
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
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {});
      _scrollToBottomIfNeeded();
    }
  }

  void _scrollToBottomIfNeeded() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _onSendPressed() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _textController.clear();
    _controller.sendMessage(text);
  }

  void _onTextChanged(String text) {
    _controller.onTextChanged(text);
    setState(() {}); // Update send button state
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildAppBar(),
          if (!_controller.isOnline) _buildOfflineBanner(),
          if (state.isBlocked) _buildBlockedBanner(),
          if (state.isBlockedByOther) _buildBlockedByOtherBanner(),
          Expanded(child: _buildContent()),
          if (state.isTyping) _buildTypingIndicator(),
          if (!state.isBlocked && !state.isBlockedByOther) _buildMessageInput(),
        ],
      ),
    );
  }

  // ============================================================================
  // APP BAR
  // ============================================================================

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Back button
              _buildIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),

              // Avatar
              _buildHeaderAvatar(),
              const SizedBox(width: 12),

              // Name and status
              Expanded(child: _buildHeaderInfo()),

              // Menu
              _buildMenuButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: (color ?? mainColor).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color ?? mainColor, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: mainColor.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: widget.recipientImage != null
            ? CachedNetworkImage(
                imageUrl: widget.recipientImage!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarPlaceholder(size: 18),
                errorWidget: (_, __, ___) => _buildAvatarPlaceholder(size: 18),
              )
            : _buildAvatarPlaceholder(size: 18),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.recipientName,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        _buildOnlineStatus(),
      ],
    );
  }

  Widget _buildOnlineStatus() {
    return StreamBuilder<bool>(
      stream: ChatRepository().streamUserOnlineStatus(widget.recipientId),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;

        return Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isOnline
                    ? const Color(0xFF4ADE80)
                    : textColor.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOnline ? 'online'.tr() : 'offline'.tr(),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuButton() {
    final state = _controller.state;

    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: mainColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.more_vert_rounded, color: mainColor, size: 20),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 8,
      onSelected: _handleMenuAction,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: state.isBlocked ? 'unblock' : 'block',
          child: Row(
            children: [
              Icon(
                state.isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
                color: state.isBlocked ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(state.isBlocked ? 'unblock'.tr() : 'block_user'.tr()),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_rounded, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 12),
              Text('report_user'.tr()),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.delete_sweep_rounded,
                  color: Colors.red.shade400, size: 20),
              const SizedBox(width: 12),
              Text('clear_chat'.tr()),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    HapticFeedback.lightImpact();

    switch (action) {
      case 'block':
        _showBlockConfirmation();
        break;
      case 'unblock':
        _controller.unblockUser();
        _showSnackBar('user_unblocked'.tr(), isSuccess: true);
        break;
      case 'report':
        _showReportConfirmation();
        break;
      case 'clear':
        _showClearChatConfirmation();
        break;
    }
  }

  // ============================================================================
  // BANNERS
  // ============================================================================

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey.shade800,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'no_connection'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.5);
  }

  Widget _buildBlockedBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'you_blocked_this_user'.tr(),
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 14,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              _controller.unblockUser();
              _showSnackBar('user_unblocked'.tr(), isSuccess: true);
            },
            child: Text(
              'unblock'.tr(),
              style: TextStyle(
                color: mainColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedByOtherBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.block_rounded, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'blocked_by_user'.tr(),
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // CONTENT
  // ============================================================================

  Widget _buildContent() {
    final state = _controller.state;

    if (state.hasError) {
      return _buildErrorState();
    }

    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.messages.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMessageList();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: mainColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'loading_messages'.tr(),
            style: TextStyle(
              color: textColor.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
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
                color: mainColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                size: 36,
                color: mainColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'say_hello'.tr(),
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'start_conversation_with'.tr(args: [widget.recipientName]),
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'connection_error'.tr(),
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _controller.initialize(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // MESSAGE LIST
  // ============================================================================

  Widget _buildMessageList() {
    final messages = _controller.state.messages;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      physics: const BouncingScrollPhysics(),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final previousMessage = index > 0 ? messages[index - 1] : null;
        final nextMessage =
            index < messages.length - 1 ? messages[index + 1] : null;

        return _buildMessageItem(message, previousMessage, nextMessage, index);
      },
    );
  }

  Widget _buildMessageItem(
    ChatMessage message,
    ChatMessage? previousMessage,
    ChatMessage? nextMessage,
    int index,
  ) {
    final isSender = message.senderId == _controller.currentUserId;
    final showDateSeparator = previousMessage == null ||
        !_isSameDay(previousMessage.createdAt, message.createdAt);
    final isGroupStart = previousMessage == null ||
        previousMessage.senderId != message.senderId ||
        !_isSameMinute(previousMessage.createdAt, message.createdAt);
    final isGroupEnd = nextMessage == null ||
        nextMessage.senderId != message.senderId ||
        !_isSameMinute(message.createdAt, nextMessage.createdAt);

    return Column(
      children: [
        if (showDateSeparator) _buildDateSeparator(message.createdAt),
        _buildMessageBubble(
          message,
          isSender,
          isGroupStart: isGroupStart,
          isGroupEnd: isGroupEnd,
        )
            .animate(delay: (index * 20).ms)
            .fadeIn(duration: 200.ms)
            .slideX(begin: isSender ? 0.02 : -0.02),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: mainColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(date),
            style: TextStyle(
              color: mainColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    bool isSender, {
    required bool isGroupStart,
    required bool isGroupEnd,
  }) {
    final isFailed = message.status == MessageStatus.failed;
    final isSending = message.status.isInFlight;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      onTap: isFailed ? () => _retryMessage(message) : null,
      child: Padding(
        padding: EdgeInsets.only(
          top: isGroupStart ? 6 : 2,
          bottom: isGroupEnd ? 6 : 2,
        ),
        child: Row(
          mainAxisAlignment:
              isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isSender) const SizedBox(width: 8),
            Flexible(
              child: Opacity(
                opacity: isSending ? 0.7 : 1.0,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: (MediaQuery.of(context).size.width * 0.72)
                        .clamp(0.0, 480.0),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isFailed
                        ? Colors.red.shade50
                        : (isSender ? mainColor : Colors.white),
                    borderRadius: BorderRadius.only(
                      topLeft:
                          Radius.circular(isSender || !isGroupStart ? 18 : 4),
                      topRight:
                          Radius.circular(!isSender || !isGroupStart ? 18 : 4),
                      bottomLeft:
                          Radius.circular(isSender || !isGroupEnd ? 18 : 4),
                      bottomRight:
                          Radius.circular(!isSender || !isGroupEnd ? 18 : 4),
                    ),
                    border: isFailed
                        ? Border.all(color: Colors.red.shade200)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.isDeleted)
                        Text(
                          'message_deleted'.tr(),
                          style: TextStyle(
                            color: isSender
                                ? Colors.white.withValues(alpha: 0.7)
                                : textColor.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else
                        _buildMessageContent(message, isSender),
                      const SizedBox(height: 4),
                      _buildMessageFooter(
                          message, isSender, isFailed, isSending),
                    ],
                  ),
                ),
              ),
            ),
            if (isSender) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isSender) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent(message);
      case MessageType.video:
        return _buildVideoContent(message);
      default:
        return Text(
          message.text ?? '',
          style: TextStyle(
            color: isSender ? Colors.white : textColor,
            fontSize: 15,
            height: 1.4,
          ),
        );
    }
  }

  Widget _buildImageContent(ChatMessage message) {
    if (message.mediaUrls == null || message.mediaUrls!.isEmpty) {
      return const SizedBox();
    }

    return GestureDetector(
      onTap: () => _openImageViewer(message.mediaUrls!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrls!.first,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: 200,
            height: 150,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: mainColor,
              ),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            width: 200,
            height: 150,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(ChatMessage message) {
    return Stack(
      alignment: Alignment.center,
      children: [
        _buildImageContent(message),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ],
    );
  }

  Widget _buildMessageFooter(
    ChatMessage message,
    bool isSender,
    bool isFailed,
    bool isSending,
  ) {
    final statusTextColor = isSender
        ? Colors.white.withValues(alpha: 0.7)
        : textColor.withValues(alpha: 0.4);

    if (isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade600, size: 14),
          const SizedBox(width: 4),
          Text(
            'tap_to_retry'.tr(),
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          DateFormat('HH:mm').format(message.createdAt),
          style: TextStyle(
            color: statusTextColor,
            fontSize: 11,
          ),
        ),
        if (isSender) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(message.status, isSending),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(MessageStatus status, bool isSending) {
    if (isSending) {
      return SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      );
    }

    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sent:
        icon = Icons.done_rounded;
        color = Colors.white.withValues(alpha: 0.7);
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        color = Colors.white.withValues(alpha: 0.7);
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        color = const Color(0xFF7DD3FC); // Light blue for read
        break;
      default:
        icon = Icons.done_rounded;
        color = Colors.white.withValues(alpha: 0.7);
    }

    return Icon(icon, size: 14, color: color);
  }

  // ============================================================================
  // TYPING INDICATOR
  // ============================================================================

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: mainColor.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                  )
                      .animate(
                        onPlay: (controller) => controller.repeat(),
                      )
                      .scale(
                        delay: (index * 150).ms,
                        duration: 600.ms,
                        begin: const Offset(0.8, 0.8),
                        end: const Offset(1.2, 1.2),
                        curve: Curves.easeInOut,
                      )
                      .then()
                      .scale(
                        duration: 600.ms,
                        begin: const Offset(1.2, 1.2),
                        end: const Offset(0.8, 0.8),
                        curve: Curves.easeInOut,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ============================================================================
  // MESSAGE INPUT
  // ============================================================================

  Widget _buildMessageInput() {
    final hasText = _textController.text.trim().isNotEmpty;
    final isSending = _controller.state.isSending;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button
          _buildInputButton(
            icon: Icons.add_rounded,
            onTap: _showAttachmentOptions,
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _onSendPressed(),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textColor, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'type_message'.tr(),
                  hintStyle: TextStyle(
                    color: textColor.withValues(alpha: 0.4),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasText || isSending
                  ? mainColor
                  : mainColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(22),
              boxShadow: hasText
                  ? [
                      BoxShadow(
                        color: mainColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: (hasText && !isSending) ? _onSendPressed : null,
                child: Center(
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: mainColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Icon(icon, color: mainColor, size: 22),
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS & ACTIONS
  // ============================================================================

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'share'.tr(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library_rounded,
                      label: 'gallery'.tr(),
                      color: Colors.purple,
                      onTap: () {
                        Navigator.pop(context);
                        _controller.sendImageMessage();
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'camera'.tr(),
                      color: Colors.blue,
                      onTap: () {
                        Navigator.pop(context);
                        _controller.takeAndSendPhoto();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (message.text != null && message.text!.isNotEmpty)
                _buildOptionTile(
                  icon: Icons.copy_rounded,
                  label: 'copy'.tr(),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(ClipboardData(text: message.text!));
                    _showSnackBar('copied'.tr(), isSuccess: true);
                  },
                ),
              if (message.senderId == _controller.currentUserId)
                _buildOptionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'delete'.tr(),
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _controller.deleteMessage(message.id);
                  },
                ),
              _buildOptionTile(
                icon: Icons.flag_outlined,
                label: 'report'.tr(),
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  _controller.reportMessage(message.id, message.senderId);
                  _showSnackBar('message_reported'.tr(), isSuccess: true);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    Color? color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (color ?? mainColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? mainColor, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color ?? textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showBlockConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('block_user'.tr()),
        content:
            Text('block_user_confirmation'.tr(args: [widget.recipientName])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.blockUser();
              _showSnackBar('user_blocked'.tr(), isSuccess: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('block'.tr()),
          ),
        ],
      ),
    );
  }

  void _showReportConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('report_user'.tr()),
        content:
            Text('report_user_confirmation'.tr(args: [widget.recipientName])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.reportUser();
              _showSnackBar('user_reported'.tr(), isSuccess: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('report'.tr()),
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('clear_chat'.tr()),
        content: Text('clear_chat_confirmation'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _controller.clearChat();
              _showSnackBar('chat_cleared'.tr(), isSuccess: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('clear'.tr()),
          ),
        ],
      ),
    );
  }

  void _retryMessage(ChatMessage message) {
    HapticFeedback.lightImpact();
    _controller.retryMessage(message.id);
  }

  void _openImageViewer(List<String> urls) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(
          imageUrls: urls,
          initialIndex: 0,
        ),
      ),
    );
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  Widget _buildAvatarPlaceholder({double size = 24}) {
    return Container(
      color: mainColor.withValues(alpha: 0.08),
      child: Icon(Icons.person_rounded, color: mainColor, size: size),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isSameMinute(DateTime a, DateTime b) {
    return _isSameDay(a, b) && a.hour == b.hour && a.minute == b.minute;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) return 'today'.tr();
    if (messageDate == yesterday) return 'yesterday'.tr();
    return DateFormat('EEEE, MMM d').format(date);
  }
}
