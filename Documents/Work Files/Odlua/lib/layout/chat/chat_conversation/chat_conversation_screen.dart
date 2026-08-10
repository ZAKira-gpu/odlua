import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:odlua/utils/models/chat_model.dart';
import 'package:odlua/utils/notifications/notificaions_services.dart';
import 'package:uuid/uuid.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final NotificationService _notificationService = NotificationService();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<DocumentSnapshot>? _chatSubscription;
  StreamSubscription<DocumentSnapshot>? _typingSubscription;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isTyping = false;
  bool _isBlocked = false;
  bool _hasBlockedYou = false;
  String _currentUserId = '';
  Timer? _typingTimer;
  Timer? _scrollTimer;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
      _updateUserPresence(true);
    } else if (state == AppLifecycleState.paused) {
      _updateUserPresence(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messagesSubscription?.cancel();
    _chatSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _scrollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _updateUserPresence(false);
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;
    await _setupChatListeners();
    await _markMessagesAsRead();
    await _updateUserPresence(true);
  }

  Future<void> _setupChatListeners() async {
    try {
      _messagesSubscription = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots()
          .listen(_onMessagesUpdate, onError: _onChatError);

      _chatSubscription = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .snapshots()
          .listen(_onChatUpdate, onError: _onChatError);

      _typingSubscription = _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('typing')
          .doc(widget.recipientId)
          .snapshots()
          .listen(_onTypingUpdate, onError: _onChatError);
    } catch (e) {
      DebugHelper.log('❌ Error setting up chat listeners: $e');
      _showErrorSnackBar('failed_to_load_chat'.tr());
    }
  }

  void _onMessagesUpdate(QuerySnapshot snapshot) {
    try {
      final messages = snapshot.docs.map((doc) {
        return ChatMessage.fromMap(
            {...doc.data() as Map<String, dynamic>, 'id': doc.id});
      }).toList();

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }

      _scrollToBottom();
      _markMessagesAsRead();

      _firestore.collection('chats').doc(widget.chatId).update({
        'lastActivity': FieldValue.serverTimestamp(),
      }).catchError((e) =>
          DebugHelper.logError('Error updating last activity', error: e));
    } catch (e) {
      DebugHelper.log('❌ Error parsing messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onChatUpdate(DocumentSnapshot snapshot) {
    if (snapshot.exists && mounted) {
      final data = snapshot.data() as Map<String, dynamic>;
      final blockedUsers = Map<String, bool>.from(data['blockedUsers'] ?? {});

      setState(() {
        _isBlocked = blockedUsers[_currentUserId] == true;
        _hasBlockedYou = blockedUsers[widget.recipientId] == true;
      });
    }
  }

  void _onTypingUpdate(DocumentSnapshot snapshot) {
    if (snapshot.exists && mounted) {
      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _isTyping = data['isTyping'] == true;
      });

      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isTyping = false);
        }
      });
    } else if (mounted) {
      setState(() => _isTyping = false);
    }
  }

  void _onChatError(error) {
    DebugHelper.log('❌ Chat stream error: $error');
    if (mounted) {
      _showErrorSnackBar('chat_connection_error'.tr());
    }
  }

  Future<void> _updateUserPresence(bool isOnline) async {
    try {
      await _firestore.collection('users').doc(_currentUserId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DebugHelper.log('❌ Error updating presence: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final unreadMessages = _messages
          .where((msg) =>
              msg.senderId != _currentUserId &&
              msg.status != MessageStatus.read)
          .toList();

      if (unreadMessages.isEmpty) return;

      final batch = _firestore.batch();

      for (final message in unreadMessages) {
        final messageRef = _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc(message.id);

        batch.update(messageRef, {
          'status': 'read',
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      await _firestore.collection('chats').doc(widget.chatId).update({
        'unreadCounts.$_currentUserId': 0,
        'lastRead.$_currentUserId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      DebugHelper.log('❌ Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_isBlocked || _hasBlockedYou) {
      _showErrorSnackBar('cannot_send_message_blocked'.tr());
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final messageId = const Uuid().v4();
      final message = ChatMessage(
        id: messageId,
        chatId: widget.chatId,
        senderId: _currentUserId,
        text: text,
        type: MessageType.text,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': message.toMap(),
        'lastActivity': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.recipientId}': FieldValue.increment(1),
      });

      _messageController.clear();
      _stopTyping();

      await _sendPushNotification(text);
    } catch (e) {
      DebugHelper.log('❌ Error sending message: $e');
      _showErrorSnackBar('failed_to_send_message'.tr());

      _showRetryDialog(text);
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showRetryDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('send_failed'.tr(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        content: Text('message_send_failed_retry'.tr(),
            style: TextStyle(color: textColor.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: TextStyle(color: textColor.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _messageController.text = message;
              _sendMessage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: mainColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('retry'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPushNotification(String message) async {
    try {
      if (widget.recipientId == _currentUserId) return;

      final sender = _auth.currentUser;
      if (sender == null) return;

      final senderName =
          sender.displayName ?? sender.email?.split('@').first ?? 'User';

      await _notificationService.sendChatNotification(
        recipientId: widget.recipientId,
        senderName: senderName,
        message: message,
        chatId: widget.chatId,
        imageUrl: sender.photoURL,
      );
    } catch (e) {
      DebugHelper.log('❌ Error sending push notification: $e');
    }
  }

  Future<void> _sendImageMessage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        await _uploadMediaMessage(File(image.path), MessageType.image);
      }
    } catch (e) {
      DebugHelper.log('❌ Error picking image: $e');
      _showErrorSnackBar('failed_to_pick_image'.tr());
    }
  }

  Future<void> _uploadMediaMessage(File file, MessageType type) async {
    final messageId = const Uuid().v4();
    setState(() => _isSending = true);

    try {
      final tempMessage = ChatMessage(
        id: messageId,
        chatId: widget.chatId,
        senderId: _currentUserId,
        type: type,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );

      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .set(tempMessage.toMap());

      final fileName = '${type.toString().split('.').last}s/$messageId';
      final task = await _storage.ref().child(fileName).putFile(file);
      final downloadUrl = await task.ref.getDownloadURL();

      final message = tempMessage.copyWith(
        mediaUrls: [downloadUrl],
        status: MessageStatus.sent,
      );

      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(messageId)
          .update(message.toMap());

      await _firestore.collection('chats').doc(widget.chatId).update({
        'lastMessage': message.toMap(),
        'lastActivity': FieldValue.serverTimestamp(),
        'unreadCounts.${widget.recipientId}': FieldValue.increment(1),
      });

      final mediaText =
          type == MessageType.image ? '📷 Sent a photo' : '🎥 Sent a video';
      await _sendPushNotification(mediaText);
    } catch (e) {
      DebugHelper.log('❌ Error uploading media: $e');
      _showErrorSnackBar('failed_to_upload_media'.tr());

      try {
        await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .doc(messageId)
            .delete();
      } catch (deleteError) {
        DebugHelper.log('❌ Error deleting failed message: $deleteError');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _startTyping() {
    if (_isBlocked || _hasBlockedYou) return;

    _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('typing')
        .doc(_currentUserId)
        .set({
      'isTyping': true,
      'timestamp': FieldValue.serverTimestamp(),
    }).catchError(
            (e) => DebugHelper.logError('Error starting typing', error: e));

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (!mounted) return;

    _typingTimer?.cancel();
    _firestore
        .collection('chats')
        .doc(widget.chatId)
        .collection('typing')
        .doc(_currentUserId)
        .delete()
        .catchError(
            (e) => DebugHelper.logError('Error stopping typing', error: e));
  }

  void _scrollToBottom() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients && mounted) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('message_options'.tr(),
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
            ),
            Divider(color: textColor.withOpacity(0.1), height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.reply_rounded, color: mainColor, size: 20),
              ),
              title: Text('reply'.tr(), style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _replyToMessage(message);
              },
            ),
            if (message.text != null && message.text!.isNotEmpty)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.copy_rounded, color: mainColor, size: 20),
                ),
                title: Text('copy'.tr(), style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(context);
                  _copyMessage(message);
                },
              ),
            if (message.senderId == _currentUserId)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.delete_rounded,
                      color: Colors.red, size: 20),
                ),
                title: Text('delete'.tr(),
                    style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.flag_rounded,
                    color: Colors.orange, size: 20),
              ),
              title: Text('report'.tr(),
                  style: const TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(context);
                _reportMessage(message);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _replyToMessage(ChatMessage message) {
    _messageController.text = 'Replying to: ${message.text}\n';
    _messageFocusNode.requestFocus();
  }

  void _copyMessage(ChatMessage message) {
    if (message.text != null) {
      Clipboard.setData(ClipboardData(text: message.text!));
      _showSuccessSnackBar('message_copied'.tr());
    }
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      await _firestore
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(message.id)
          .update({
        'isDeleted': true,
        'text': 'This message was deleted',
      });

      _showSuccessSnackBar('message_deleted'.tr());
    } catch (e) {
      _showErrorSnackBar('failed_to_delete_message'.tr());
    }
  }

  void _reportMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('report_message'.tr(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        content: Text('report_message_confirmation'.tr(),
            style: TextStyle(color: textColor.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: TextStyle(color: textColor.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitReport(message);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('report'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport(ChatMessage message) async {
    try {
      await _firestore.collection('reports').add({
        'reporterId': _currentUserId,
        'reportedUserId': message.senderId,
        'messageId': message.id,
        'chatId': widget.chatId,
        'reason': 'Inappropriate message',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _showSuccessSnackBar('message_reported'.tr());
    } catch (e) {
      _showErrorSnackBar('failed_to_report_message'.tr());
    }
  }

  void _blockUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('block_user'.tr(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        content: Text(
            'block_user_confirmation'.tr(args: [widget.recipientName]),
            style: TextStyle(color: textColor.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: TextStyle(color: textColor.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmBlockUser();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('block'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBlockUser() async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).update({
        'blockedUsers.$_currentUserId': true,
      });

      setState(() => _isBlocked = true);
      _showSuccessSnackBar('user_blocked'.tr());
    } catch (e) {
      _showErrorSnackBar('failed_to_block_user'.tr());
    }
  }

  Future<void> _unblockUser() async {
    try {
      await _firestore.collection('chats').doc(widget.chatId).update({
        'blockedUsers.$_currentUserId': FieldValue.delete(),
      });

      setState(() => _isBlocked = false);
      _showSuccessSnackBar('user_unblocked'.tr());
    } catch (e) {
      _showErrorSnackBar('failed_to_unblock_user'.tr());
    }
  }

  Widget _buildAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 3))
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Back Button
              Container(
                decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.2), shape: BoxShape.circle),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      color: mainColor, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),

              // User Info
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: mainColor.withOpacity(0.3), width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: widget.recipientImage != null
                            ? CachedNetworkImage(
                                imageUrl: widget.recipientImage!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) =>
                                    _buildDefaultAvatar(),
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.recipientName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          StreamBuilder<DocumentSnapshot>(
                            stream: _firestore
                                .collection('users')
                                .doc(widget.recipientId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final data = snapshot.data!.data()
                                    as Map<String, dynamic>?;
                                final isOnline = data?['isOnline'] ?? false;
                                final lastSeen = data?['lastSeen'] != null
                                    ? (data!['lastSeen'] as Timestamp).toDate()
                                    : null;

                                return Text(
                                  isOnline
                                      ? 'online'.tr()
                                      : lastSeen != null
                                          ? 'last_seen'.tr(
                                              args: [_formatLastSeen(lastSeen)])
                                          : 'offline'.tr(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.7)),
                                );
                              }
                              return const SizedBox();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Menu
              PopupMenuButton<String>(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 6,
                shadowColor: Colors.black26,
                icon: Container(
                  decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.15),
                      shape: BoxShape.circle),
                  padding: const EdgeInsets.all(8),
                  child:
                      Icon(Icons.more_vert_rounded, color: mainColor, size: 22),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'block':
                      _isBlocked ? _unblockUser() : _blockUser();
                      break;
                    case 'report':
                      _reportUser();
                      break;
                    case 'clear':
                      _clearChat();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(
                            _isBlocked
                                ? Icons.lock_open_rounded
                                : Icons.block_rounded,
                            color: _isBlocked ? Colors.green : Colors.red,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(
                            _isBlocked
                                ? 'unblock_user'.tr()
                                : 'block_user'.tr(),
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 8),
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_rounded,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        Text('report_user'.tr(),
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(height: 8),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_sweep_rounded,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Text('clear_chat'.tr(),
                            style: TextStyle(
                                color: textColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: mainColor.withOpacity(0.1),
      child: Icon(Icons.person, color: mainColor, size: 20),
    );
  }

  Widget _buildBlockedMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text('you_have_blocked_this_user'.tr(),
                  style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w500))),
          TextButton(
            onPressed: _unblockUser,
            child: Text('unblock'.tr(),
                style:
                    TextStyle(color: mainColor, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedByUserMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text('you_are_blocked_by_this_user'.tr(),
                  style: TextStyle(
                      color: Colors.red.shade800,
                      fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
            child: CircularProgressIndicator(strokeWidth: 3, color: mainColor),
          ),
          const SizedBox(height: 20),
          Text('loading_messages'.tr(),
              style: TextStyle(
                  color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
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
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 64, color: textColor.withOpacity(0.3)),
            ),
            const SizedBox(height: 24),
            Text('no_messages_yet'.tr(),
                style: TextStyle(
                    fontSize: 20,
                    color: textColor,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('send_first_message'.tr(),
                style:
                    TextStyle(fontSize: 14, color: textColor.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isSender = message.senderId == _currentUserId;
        final showAvatar =
            index == 0 || _messages[index - 1].senderId != message.senderId;

        return Column(
          children: [
            if (index == 0 ||
                _isNewDay(_messages[index - 1].timestamp, message.timestamp))
              _buildDateSeparator(message.timestamp),
            _buildMessageBubble(message, isSender, showAvatar),
          ],
        );
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: mainColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_formatDate(date),
          style: TextStyle(
              fontSize: 12, color: mainColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMessageBubble(
      ChatMessage message, bool isSender, bool showAvatar) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment:
              isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isSender && showAvatar)
              _buildAvatar(widget.recipientImage, false),
            if (!isSender && !showAvatar) const SizedBox(width: 40),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSender ? mainColor : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isSender ? 20 : 8),
                    bottomRight: Radius.circular(isSender ? 8 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.isDeleted)
                      Text('this_message_was_deleted'.tr(),
                          style: TextStyle(
                              color: isSender
                                  ? Colors.white70
                                  : textColor.withOpacity(0.5),
                              fontStyle: FontStyle.italic,
                              fontSize: 14))
                    else
                      _buildMessageContent(message, isSender),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_formatTime(message.timestamp),
                            style: TextStyle(
                                fontSize: 11,
                                color: isSender
                                    ? Colors.white70
                                    : textColor.withOpacity(0.4))),
                        if (isSender) ...[
                          const SizedBox(width: 6),
                          _buildMessageStatus(message.status),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isSender && showAvatar)
              _buildAvatar(_auth.currentUser?.photoURL, true),
            if (isSender && !showAvatar) const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? imageUrl, bool isSender) {
    return Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(left: isSender ? 8 : 0, right: isSender ? 0 : 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: mainColor.withOpacity(0.1), width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
              )
            : _buildDefaultSmallAvatar(),
      ),
    );
  }

  Widget _buildDefaultSmallAvatar() {
    return Container(
      color: mainColor.withOpacity(0.1),
      child: Icon(Icons.person, color: mainColor, size: 16),
    );
  }

  Widget _buildMessageContent(ChatMessage message, bool isSender) {
    switch (message.type) {
      case MessageType.image:
        return _buildImageMessage(message);
      case MessageType.video:
        return _buildVideoMessage(message);
      default:
        return Text(message.text ?? '',
            style: TextStyle(
                color: isSender ? Colors.white : textColor,
                fontSize: 15,
                height: 1.4));
    }
  }

  Widget _buildImageMessage(ChatMessage message) {
    return GestureDetector(
      onTap: () => _showMediaViewer(message.mediaUrls!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: message.mediaUrls!.first,
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 200,
            height: 150,
            color: Colors.grey.shade200,
            child: const Icon(Icons.photo, color: Colors.grey, size: 40),
          ),
          errorWidget: (context, url, error) => Container(
            width: 200,
            height: 150,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(ChatMessage message) {
    return GestureDetector(
      onTap: () => _showMediaViewer(message.mediaUrls!),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _getVideoThumbnailUrl(message.mediaUrls!.first),
              width: 200,
              height: 150,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  width: 200, height: 150, color: Colors.grey.shade200),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: const Icon(Icons.play_circle_filled_rounded,
                  color: Colors.white, size: 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStatus(MessageStatus status) {
    IconData icon;

    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time_rounded;
        break;
      case MessageStatus.sent:
        icon = Icons.done_rounded;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all_rounded;
        break;
      case MessageStatus.read:
        icon = Icons.done_all_rounded;
        break;
      case MessageStatus.failed:
        icon = Icons.error_rounded;
        break;
    }

    return Icon(icon, size: 14, color: mainColor);
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                _buildTypingDot(0),
                _buildTypingDot(1),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
          color: mainColor.withOpacity(0.6), shape: BoxShape.circle),
    ).animate(onPlay: (controller) => controller.repeat()).scale(
        duration: 600.ms, delay: (index * 200).ms, curve: Curves.easeInOut);
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
            child: IconButton(
              icon: Icon(Icons.attach_file_rounded, color: mainColor, size: 22),
              onPressed: _showAttachmentOptions,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(20)),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                decoration: InputDecoration(
                  hintText: 'type_message'.tr(),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                ),
                style: TextStyle(color: textColor, fontSize: 15),
                maxLines: 3,
                minLines: 1,
                onChanged: (text) =>
                    text.isNotEmpty ? _startTyping() : _stopTyping(),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: mainColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: mainColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
              onPressed: _isSending ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('share_content'.tr(),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    icon: Icons.photo_rounded,
                    label: 'photo'.tr(),
                    onTap: () {
                      Navigator.pop(context);
                      _sendImageMessage();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.video_library_rounded,
                    label: 'video'.tr(),
                    onTap: () {
                      Navigator.pop(context);
                      _showInfoSnackBar('Video upload coming soon');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
                color: mainColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: mainColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showMediaViewer(List<String> mediaUrls) {
    _showInfoSnackBar('Media viewer coming soon');
  }

  String _getVideoThumbnailUrl(String videoUrl) {
    return videoUrl.replaceAll('.mp4', '.jpg');
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) return 'today'.tr();
    if (messageDate == yesterday) return 'yesterday'.tr();
    return DateFormat('MMM dd, yyyy').format(dateTime);
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'just_now'.tr();
    if (difference.inHours < 1) {
      return 'minutes_ago'.tr(args: [difference.inMinutes.toString()]);
    }
    if (difference.inDays < 1) {
      return 'hours_ago'.tr(args: [difference.inHours.toString()]);
    }
    return 'days_ago'.tr(args: [difference.inDays.toString()]);
  }

  bool _isNewDay(DateTime previous, DateTime current) {
    return previous.day != current.day ||
        previous.month != current.month ||
        previous.year != current.year;
  }

  void _showInfoSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: mainColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _reportUser() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('report_user'.tr(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        content: Text(
            'report_user_confirmation'.tr(args: [widget.recipientName]),
            style: TextStyle(color: textColor.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr(),
                style: TextStyle(color: textColor.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitUserReport();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('report'.tr()),
          ),
        ],
      ),
    );
  }

  Future<void> _submitUserReport() async {
    try {
      await _firestore.collection('user_reports').add({
        'reporterId': _currentUserId,
        'reportedUserId': widget.recipientId,
        'reason': 'Inappropriate behavior',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _showSuccessSnackBar('user_reported'.tr());
    } catch (e) {
      _showErrorSnackBar('failed_to_report_user'.tr());
    }
  }

  Future<void> _clearChat() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('clear_chat'.tr(),
            style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
        content: Text('clear_chat_confirmation'.tr(),
            style: TextStyle(color: textColor.withOpacity(0.7))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr(),
                style: TextStyle(color: textColor.withOpacity(0.6))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('clear'.tr()),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final messages = await _firestore
            .collection('chats')
            .doc(widget.chatId)
            .collection('messages')
            .get();
        final batch = _firestore.batch();
        for (final doc in messages.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        _showSuccessSnackBar('chat_cleared'.tr());
      } catch (e) {
        _showErrorSnackBar('failed_to_clear_chat'.tr());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          _buildAppBar(),
          if (_isBlocked) _buildBlockedMessage(),
          if (_hasBlockedYou) _buildBlockedByUserMessage(),
          Expanded(
            child: _isLoading
                ? _buildLoadingState()
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
          ),
          if (_isTyping) _buildTypingIndicator(),
          if (!_isBlocked && !_hasBlockedYou) _buildMessageInput(),
        ],
      ),
    );
  }
}
