// ─────────────────────────────────────────
// Widget: HomeHeaderWidget
// Description: Top section of the home screen — greeting, user
//              location display, avatar, and notification bell.
// Contains: Location label, avatar, notification badge
// ─────────────────────────────────────────

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:odlua/utils/theme/custom_themes/app_spacing.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';
import 'package:odlua/layout/chat/chat_list_screen.dart';

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
      final unreadCount = (unreadCounts[_currentUserId] as num? ?? 0).toInt();
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

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('select_language'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', const Locale('en')),
            _buildLanguageOption(context, 'العربية', const Locale('ar')),
            _buildLanguageOption(context, 'Deutsch', const Locale('de')),
            _buildLanguageOption(context, 'Français', const Locale('fr')),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
      BuildContext context, String name, Locale locale) {
    final isSelected = context.locale == locale;
    return ListTile(
      title: Text(name),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
      onTap: () async {
        await context.setLocale(locale);
        if (!context.mounted) return;
        Navigator.pop(context);
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.screenMarginLarge),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo removed per user request
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'header_app_title'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'header_app_subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _buildModernIconButton(
                  context, Icons.language, () => _showLanguageDialog(context)),
              const SizedBox(width: AppSpacing.s8),
              _buildModernIconButton(
                context,
                Iconsax.message,
                () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  ).then((_) {
                    // Refresh unread count when returning from chat screen
                    // The stream will automatically update the count
                  });
                },
                badgeCount: _totalUnreadCount,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernIconButton(
      BuildContext context, IconData icon, VoidCallback onTap,
      {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusM),
              boxShadow: AppSpacing.softShadow,
            ),
            child: Icon(
              icon,
              size: 22,
              color: Colors.black87,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: mainColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
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
