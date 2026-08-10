// ─────────────────────────────────────────
// Helper: UserPrefsCache
// Description: In-memory cache of user preferences to reduce Firestore reads.
// Contains: loadPrefs, getPrefs, clearCache
// ─────────────────────────────────────────

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// In-memory cache for the current user's preferences (allergies, etc.).
/// Avoids redundant Firestore reads when multiple widgets on the same screen
/// need the same data.  The cache is invalidated on auth-state changes.
class UserPrefsCache {
  UserPrefsCache._();
  static final UserPrefsCache instance = UserPrefsCache._();

  List<String>? _allergies;
  String? _cachedUid;
  bool _loading = false;
  final List<Completer<List<String>>> _waiters = [];

  /// Returns the user's allergy list, fetching once per session.
  Future<List<String>> getAllergies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // Cache hit — same user
    if (_cachedUid == user.uid && _allergies != null) return _allergies!;

    // Already in flight — piggyback on the ongoing fetch
    if (_loading) {
      final c = Completer<List<String>>();
      _waiters.add(c);
      return c.future;
    }

    _loading = true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 3));

      final allergies = (doc.data()?['allergies'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList();

      _allergies = allergies;
      _cachedUid = user.uid;
      for (final c in _waiters) {
        c.complete(allergies);
      }
      _waiters.clear();
      return allergies;
    } catch (_) {
      for (final c in _waiters) {
        c.complete([]);
      }
      _waiters.clear();
      return _allergies ?? [];
    } finally {
      _loading = false;
    }
  }

  /// Call when user logs out or switches accounts.
  void invalidate() {
    _allergies = null;
    _cachedUid = null;
  }
}
