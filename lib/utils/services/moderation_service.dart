// ─────────────────────────────────────────
// Service: ModerationService
// Description: User reporting, blocking, and abuse detection.
// Contains: reportUser, blockUser, isBlocked
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ModerationService {
  ModerationService._();
  static final ModerationService instance = ModerationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Returns the set of user IDs the current user has blocked.
  Future<Set<String>> getBlockedUserIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final ids = List<String>.from(doc.data()?['blockedUserIds'] ?? []);
      return ids.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Returns a stream of blocked user IDs so the feed reacts in real-time.
  Stream<Set<String>> blockedUserIdsStream() {
    final uid = _uid;
    if (uid == null) return Stream.value({});
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      final ids = List<String>.from(doc.data()?['blockedUserIds'] ?? []);
      return ids.toSet();
    });
  }

  /// Block [targetUserId]. Adds to the current user's blockedUserIds list.
  Future<void> blockUser(String targetUserId) async {
    final uid = _uid;
    if (uid == null || targetUserId.isEmpty || targetUserId == uid) return;
    await _firestore.collection('users').doc(uid).update({
      'blockedUserIds': FieldValue.arrayUnion([targetUserId]),
    });
    // Also log a report so the developer is notified
    await _submitReport(
      reportedUserId: targetUserId,
      contentType: 'user',
      contentId: targetUserId,
      reason: 'block',
    );
  }

  /// Unblock [targetUserId].
  Future<void> unblockUser(String targetUserId) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).update({
      'blockedUserIds': FieldValue.arrayRemove([targetUserId]),
    });
  }

  /// Whether the current user has blocked [targetUserId].
  Future<bool> isBlocked(String targetUserId) async {
    final ids = await getBlockedUserIds();
    return ids.contains(targetUserId);
  }

  // ────────────────────────────────────────────
  // Reporting
  // ────────────────────────────────────────────

  /// Report a dish.
  Future<void> reportDish({
    required String dishId,
    required String chefId,
    required String reason,
  }) =>
      _submitReport(
        reportedUserId: chefId,
        contentType: 'dish',
        contentId: dishId,
        reason: reason,
      );

  /// Report a user directly.
  Future<void> reportUser({
    required String userId,
    required String reason,
  }) =>
      _submitReport(
        reportedUserId: userId,
        contentType: 'user',
        contentId: userId,
        reason: reason,
      );

  /// Report a chat message.
  Future<void> reportMessage({
    required String chatId,
    required String messageId,
    required String senderId,
    required String reason,
  }) =>
      _submitReport(
        reportedUserId: senderId,
        contentType: 'chat_message',
        contentId: '$chatId/$messageId',
        reason: reason,
      );

  Future<void> _submitReport({
    required String reportedUserId,
    required String contentType,
    required String contentId,
    required String reason,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.collection('reports').add({
      'reporterId': uid,
      'reportedUserId': reportedUserId,
      'contentType': contentType,
      'contentId': contentId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
