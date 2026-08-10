import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import '../../../chat/chat_screen.dart';

class HomeHeaderWidget extends StatefulWidget {
  const HomeHeaderWidget({super.key});

  @override
  State<HomeHeaderWidget> createState() => _HomeHeaderWidgetState();
}

class _HomeHeaderWidgetState extends State<HomeHeaderWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  int _totalUnreadCount = 0;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _initializeUnreadCount();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeUnreadCount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _currentUserId = user.uid;

    try {
      _chatsSubscription = _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .snapshots()
          .listen(_onChatsUpdate, onError: _onChatsError);
    } catch (e) {
      DebugHelper.logError('header.error_initializing_unread'.tr(), error: e);
    }
  }

  void _onChatsUpdate(QuerySnapshot snapshot) {
    int totalUnread = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final unreadCounts =
          Map<String, dynamic>.from(data['unreadCounts'] ?? {});
      final unreadCount = (unreadCounts[_currentUserId] ?? 0) as int;
      totalUnread += unreadCount;
    }

    if (mounted) {
      setState(() {
        _totalUnreadCount = totalUnread;
      });
    }
  }

  void _onChatsError(error) {
    DebugHelper.logError('header.error_unread_stream'.tr(), error: error);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              Text(
                'header_app_title'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'header_app_subtitle'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListScreen(),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        const Icon(Iconsax.message,
                            size: 26, color: Colors.black54),
                        if (_totalUnreadCount > 0)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 12,
                                minHeight: 12,
                              ),
                              child: Text(
                                _totalUnreadCount > 9
                                    ? '9+'
                                    : _totalUnreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                      ],
                    ),
                  )
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('header_widget'.tr())));
}
