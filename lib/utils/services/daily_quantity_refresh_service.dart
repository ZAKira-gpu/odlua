// ─────────────────────────────────────────
// Service: DailyQuantityRefreshService
// Description: Resets daily dish stock quantities once per day for chefs.
// Contains: runIfNeeded, resetQuantities
// ─────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:odlua/utils/helpers/debug_helper.dart';

/// Resets each of the logged-in chef's dish `stock` back to `dailyQuantity`
/// once per calendar day (client-side trigger).
///
/// Firestore dish document must have:
///   - `dailyQuantity`: int  – the max quantity available per day
///   - `stock`: int          – current remaining stock (decremented per order)
///   - `lastRefreshDate`: String (yyyy-MM-dd) – date of last reset
///
/// Call [runIfNeeded] once at app startup (after auth) to silently refresh.
class DailyQuantityRefreshService {
  static const _prefKey = 'last_daily_refresh_date';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Runs the daily refresh if it hasn't already run today.
  /// Safe to call every app launch — no-ops on same-day calls.
  static Future<void> runIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = _today();

    // Fast-path: check local prefs first to avoid Firestore reads on same day
    final prefs = await SharedPreferences.getInstance();
    final lastRun = prefs.getString(_prefKey);
    if (lastRun == today) {
      DebugHelper.log('🔄 DailyRefresh: already ran today ($today), skipping');
      return;
    }

    DebugHelper.log('🔄 DailyRefresh: running for $today');

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('dishes')
          .where('chefID', isEqualTo: user.uid)
          .where('isAvailable', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.docs.isEmpty) {
        DebugHelper.log('🔄 DailyRefresh: no active dishes found');
        await prefs.setString(_prefKey, today);
        return;
      }

      final batch = FirebaseFirestore.instance.batch();
      int refreshed = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lastRefreshDate = data['lastRefreshDate'] as String? ?? '';
        if (lastRefreshDate == today) continue; // Already refreshed today

        final dailyQuantity = data['dailyQuantity'] as int?;
        if (dailyQuantity == null || dailyQuantity <= 0) continue;

        batch.update(doc.reference, {
          'stock': dailyQuantity,
          'availableStock': dailyQuantity,
          'reservedCount': 0,
          'isAvailable': true,
          'lastRefreshDate': today,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        refreshed++;
      }

      if (refreshed > 0) {
        await batch.commit();
        DebugHelper.log('🔄 DailyRefresh: ✅ reset stock for $refreshed dishes');
      } else {
        DebugHelper.log('🔄 DailyRefresh: all dishes already refreshed today');
      }

      await prefs.setString(_prefKey, today);
    } catch (e) {
      DebugHelper.logError('🔄 DailyRefresh: error during refresh', error: e);
      // Don't save today's date on error — retry next launch
    }
  }
}
