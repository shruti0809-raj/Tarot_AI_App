import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReadingBalanceService {
  static final ReadingBalanceService _instance = ReadingBalanceService._internal();
  factory ReadingBalanceService() => _instance;
  ReadingBalanceService._internal();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// 🔓 Tester account with unlimited access (no deduction)
  static const String unlimitedEmail = 'taowalker.testing@gmail.com';

  /// Toggle this to enforce 1 reading per calendar day for the daily plan.
  static const bool enforceOnePerDayForDailyPlan = true;

  /// Returns the *effective* balance the user can use **right now**.
  Future<int> getReadingBalance() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    if ((user.email ?? '').toLowerCase() == unlimitedEmail.toLowerCase()) {
      return 999999; // virtually unlimited for tester
    }

    final snap = await _firestore.collection('users').doc(user.uid).get();
    final data = snap.data() ?? {};

    final String planType = (data['planType'] ?? 'one_time') as String;
    final int readingBalance = (data['readingBalance'] ?? 0) as int;

    final DateTime? expiresAt = (data['planExpiresAt'] is Timestamp)
        ? (data['planExpiresAt'] as Timestamp).toDate()
        : null;
    final DateTime? activatedAt = (data['planActivatedAt'] is Timestamp)
        ? (data['planActivatedAt'] as Timestamp).toDate()
        : null;

    final now = DateTime.now();
    final bool active = _isSubActive(planType, activatedAt, expiresAt, now);

    if (planType == 'unlimited') {
      return active ? 9999 : 0;
    }
    if (planType == 'thirty_monthly') {
      return active ? readingBalance : 0;
    }
    // Default (one_time or unknown)
    return readingBalance;
  }

  /// Atomically deducts ONE credit if available & marks a session as 'revealed'.
  ///
  /// Throws:
  /// - 'NO_CREDITS'   if no balance available
  /// - 'NO_ACTIVE_SUB' if subscription window is not active
  /// - 'DAILY_LIMIT' if already used today's daily reading (when enforcement enabled)
  Future<void> chargeOnceForSession({
    required String sessionId,
    required String readingType,
    required Map<String, dynamic> sessionData,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final isUnlimitedTester =
        (user.email ?? '').toLowerCase() == unlimitedEmail.toLowerCase();

    final userRef = _firestore.collection('users').doc(user.uid);
    final sessionRef = userRef.collection('readingSessions').doc(sessionId);

    if (isUnlimitedTester) {
      // ✅ No deduction; still persist the session as revealed for resume UX
      await sessionRef.set({
        'status': 'revealed',
        'readingType': readingType,
        'sessionData': sessionData,
        'chargedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }

    await _firestore.runTransaction((txn) async {
      final userSnap = await txn.get(userRef);
      final data = userSnap.data() ?? {};

      final String planType = (data['planType'] ?? 'one_time') as String;
      final int storedBalance = (data['readingBalance'] ?? 0) as int;

      final DateTime? expiresAt = (data['planExpiresAt'] is Timestamp)
          ? (data['planExpiresAt'] as Timestamp).toDate()
          : null;
      final DateTime? activatedAt = (data['planActivatedAt'] is Timestamp)
          ? (data['planActivatedAt'] as Timestamp).toDate()
          : null;

      final now = DateTime.now();
      final bool active = _isSubActive(planType, activatedAt, expiresAt, now);

      // Compute effective balance **now**
      int effectiveBalance;
      if (planType == 'unlimited') {
        effectiveBalance = active ? 9999 : 0;
      } else if (planType == 'thirty_monthly') {
        effectiveBalance = active ? storedBalance : 0;
      } else {
        effectiveBalance = storedBalance; // one_time
      }

      // Subscription not active (for subs)
      if (planType != 'one_time' && !active) {
        throw Exception('NO_ACTIVE_SUB');
      }

      // Optional: enforce one per calendar day for daily plan
      if (planType == 'thirty_monthly' && enforceOnePerDayForDailyPlan) {
        final Timestamp? lastUseTs = data['lastDailyUseAt'] as Timestamp?;
        final DateTime? lastUse = lastUseTs?.toDate();
        if (_isSameDay(lastUse, now)) {
          throw Exception('DAILY_LIMIT');
        }
      }

      // Apply charge semantics:
      if (planType == 'unlimited' && effectiveBalance >= 9999) {
        // Active unlimited: do NOT decrement.
        txn.set(sessionRef, {
          'status': 'revealed',
          'readingType': readingType,
          'sessionData': sessionData,
          'chargedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (enforceOnePerDayForDailyPlan) {
          txn.set(userRef, {
            'lastDailyUseAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        return;
      }

      // thirty_monthly or one_time: need a credit
      if (effectiveBalance <= 0) {
        throw Exception('NO_CREDITS');
      }

      // Decrement by 1 for charged plans
      txn.update(userRef, {
        'readingBalance': storedBalance - 1,
        if (planType == 'thirty_monthly' && enforceOnePerDayForDailyPlan)
          'lastDailyUseAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Write / merge session as revealed
      txn.set(sessionRef, {
        'status': 'revealed',
        'readingType': readingType,
        'sessionData': sessionData,
        'chargedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Manually deduct one (legacy helper)
  Future<void> deductReading() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    if ((user.email ?? '').toLowerCase() == unlimitedEmail.toLowerCase()) {
      return; // skip deduction for tester
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final current = (snap.data()?['readingBalance'] ?? 0) as int;
      if (current <= 0) throw Exception('NO_CREDITS');
      txn.update(userRef, {
        'readingBalance': current - 1,
        // keeping behavior consistent with your original method (no daily touch)
      });
    });
  }

  /// Top-up balance by [amount] (for consumables / grants).
  Future<void> topUp(int amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    if ((user.email ?? '').toLowerCase() == unlimitedEmail.toLowerCase()) {
      return; // tester account doesn’t need top-ups
    }

    final userRef = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final current = (snap.data()?['readingBalance'] ?? 0) as int;
      txn.update(userRef, {
        'readingBalance': current + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Reset to an explicit number (e.g., onboarding free credit).
  Future<void> resetBalance(int amount) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    if ((user.email ?? '').toLowerCase() == unlimitedEmail.toLowerCase()) {
      return; // keep tester unlimited semantics
    }

    await _firestore.collection('users').doc(user.uid).set({
      'readingBalance': amount,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ───────────────────────────────── helpers ─────────────────────────────────

  bool _isSameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isActive30Days(DateTime? activatedAt, DateTime now) {
    if (activatedAt == null) return false;
    return now.isBefore(activatedAt.add(const Duration(days: 30)));
  }

  bool _isSubActive(
    String planType,
    DateTime? activatedAt,
    DateTime? expiresAt,
    DateTime now,
  ) {
    if (planType != 'unlimited' && planType != 'thirty_monthly') return false;
    if (expiresAt != null) return now.isBefore(expiresAt);
    return _isActive30Days(activatedAt, now);
  }
}
