import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:odlua/layout/chat/chat_conversation/chat_conversation_screen.dart';
import 'package:odlua/utils/models/chat_model.dart';
import 'package:odlua/utils/theme/custom_themes/main_colors.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

class ChatUserSearchScreen extends StatefulWidget {
  const ChatUserSearchScreen({super.key});

  @override
  State<ChatUserSearchScreen> createState() => _ChatUserSearchScreenState();
}

class _ChatUserSearchScreenState extends State<ChatUserSearchScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();

  List<ChatUser> _searchResults = [];
  List<ChatUser> _recentContacts = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser?.uid ?? '';
    _loadRecentContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentContacts() async {
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: _currentUserId)
          .orderBy('lastActivity', descending: true)
          .limit(10)
          .get();

      final recentUserIds = <String>{};
      for (final chat in chatsSnapshot.docs) {
        final participants = List<String>.from(chat['participants'] ?? []);
        for (final participant in participants) {
          if (participant != _currentUserId) {
            recentUserIds.add(participant);
          }
        }
      }

      if (recentUserIds.isNotEmpty) {
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: recentUserIds.toList())
            .get();

        setState(() {
          _recentContacts = usersSnapshot.docs
              .map((doc) => _normalizeUserData(doc.id, doc.data()))
              .toList();
        });
      }
    } catch (e) {
      DebugHelper.log('Error loading recent contacts: $e');
    }
  }

  void _performSearch(String query) async {
    final trimmedQuery = query.trim();
    
    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults.clear();
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final allUsers = await _firestore.collection('users').limit(50).get();
      
      List<ChatUser> searchResults = [];

      for (final doc in allUsers.docs) {
        final userData = doc.data();
        final userId = userData['uid'] ?? doc.id;
        
        if (userId == _currentUserId) continue;

        final normalizedUser = _normalizeUserData(doc.id, userData);
        final userName = normalizedUser.name.toLowerCase();
        final userPhone = normalizedUser.phoneNumber ?? '';
        final queryLower = trimmedQuery.toLowerCase();

        final matchesName = userName.contains(queryLower);
        final matchesPhone = userPhone.contains(trimmedQuery);

        if (matchesName || matchesPhone) {
          searchResults.add(normalizedUser);
        }
      }

      setState(() {
        _searchResults = searchResults;
        _isSearching = false;
      });

    } catch (e) {
      DebugHelper.log('Error searching users: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  ChatUser _normalizeUserData(String docId, Map<String, dynamic> data) {
    DateTime? lastSeen;
    final lastSeenData = data['lastSeen'];
    if (lastSeenData != null) {
      if (lastSeenData is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenData);
      } else if (lastSeenData is Timestamp) {
        lastSeen = lastSeenData.toDate();
      }
    }

    return ChatUser(
      uid: data['uid'] ?? docId,
      name: data['name'] ?? data['displayName'] ?? data['username'] ?? data['fullName'] ?? 'Unknown User',
      phoneNumber: data['phone'] ?? data['phoneNumber'] ?? data['mobile'] ?? '',
      photoUrl: data['photoURL'] ?? data['photoUrl'] ?? data['profilePicture'] ?? data['avatar'] ?? data['imageUrl'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: lastSeen,
      fcmToken: data['fcmToken'],
    );
  }

  Future<void> _startChatWithUser(ChatUser user) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return;

      final participants = [currentUserId, user.uid]..sort();
      final chatId = participants.join('_');

      final chatDoc = await _firestore.collection('chats').doc(chatId).get();

      if (!chatDoc.exists) {
        await _firestore.collection('chats').doc(chatId).set({
          'id': chatId,
          'participants': participants,
          'participantData': {
            currentUserId: {
              'name': _auth.currentUser?.displayName ?? 'You',
              'photoUrl': _auth.currentUser?.photoURL,
            },
            user.uid: {
              'name': user.name,
              'photoUrl': user.photoUrl,
            },
          },
          'lastMessage': null,
          'lastActivity': FieldValue.serverTimestamp(),
          'isGroup': false,
          'blockedUsers': {},
          'unreadCounts': {
            currentUserId: 0,
            user.uid: 0,
          },
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChatConversationScreen(
              chatId: chatId,
              recipientId: user.uid,
              recipientName: user.name,
              recipientImage: user.photoUrl,
            ),
          ),
        );
      }
    } catch (e) {
      DebugHelper.log('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('failed_to_start_chat'.tr()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('search_users'.tr(), 
          style: TextStyle(
            color: mainColor,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
          
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'search_by_name_or_phone'.tr(), 
                  hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
                  prefixIcon: Icon(Icons.search_rounded, color: mainColor, size: 24),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: mainColor, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 18,
                  ),
                ),
                style: TextStyle(color: textColor, fontSize: 16),
                onChanged: _performSearch,
              ),
            ),
          ),

          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return _buildLoadingState();
    }

    if (_hasSearched) {
      return _buildSearchResults();
    }

    return _buildRecentContacts();
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
              color: mainColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: mainColor,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'searching'.tr(),
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: textColor.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'no_users_found'.tr(),
              style: TextStyle(
                fontSize: 20,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'try_different_search_terms'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserListItem(user);
      },
    );
  }

  Widget _buildRecentContacts() {
    if (_recentContacts.isEmpty) {
      return Center(
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
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: textColor.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'no_recent_chats'.tr(),
              style: TextStyle(
                fontSize: 20,
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'search_users_to_start_chat'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: textColor.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Text(
            'recent_chats'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentContacts.length,
            itemBuilder: (context, index) {
              final user = _recentContacts[index];
              return _buildUserListItem(user);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserListItem(ChatUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
          onTap: () => _startChatWithUser(user),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: mainColor.withOpacity(0.1),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: user.photoUrl != null && user.photoUrl!.isNotEmpty
                            ? Image.network(
                                user.photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: mainColor.withOpacity(0.1),
                                    child: Icon(
                                      Icons.person,
                                      color: mainColor,
                                      size: 24,
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
                                      size: 24,
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: mainColor.withOpacity(0.1),
                                child: Icon(
                                  Icons.person,
                                  color: mainColor,
                                  size: 24,
                                ),
                              ),
                      ),
                    ),
                    if (user.isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 12,
                          height: 12,
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
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      user.phoneNumber != null && user.phoneNumber!.isNotEmpty
                          ? Text(
                              user.phoneNumber!,
                              style: TextStyle(
                                color: textColor.withOpacity(0.6),
                                fontSize: 14,
                              ),
                            )
                          : Text(
                              'no_phone_number'.tr(),
                              style: TextStyle(
                                color: textColor.withOpacity(0.4),
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: mainColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}