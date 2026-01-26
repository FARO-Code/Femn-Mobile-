import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static DocumentReference get _userRef => 
      _db.collection('users').doc(_auth.currentUser!.uid);

  // --- 1. Update Streak (Called when saving a Journal Entry) ---
  static Future<void> updateStreakOnEntry() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _userRef.get();
    final data = doc.data() as Map<String, dynamic>? ?? {};

    final int currentStreak = data['streakCount'] ?? 0;
    final Timestamp? lastLogTs = data['lastStreakDate'];
    
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    if (lastLogTs == null) {
      // First ever entry
      await _userRef.update({
        'streakCount': 1,
        'lastStreakDate': Timestamp.fromDate(now),
        'streakActive': true,
      });
      return;
    }

    final DateTime lastLogDate = lastLogTs.toDate();
    final DateTime lastLogDay = DateTime(lastLogDate.year, lastLogDate.month, lastLogDate.day);

    if (today.difference(lastLogDay).inDays == 0) {
      // Already logged today, do nothing
      return;
    } else if (today.difference(lastLogDay).inDays == 1) {
      // Consecutive day
      await _userRef.update({
        'streakCount': currentStreak + 1,
        'lastStreakDate': Timestamp.fromDate(now),
        'streakActive': true,
      });
    } else {
      // Streak broken (missed more than 1 day)
      // We don't reset to 1 immediately here logic-wise if we want to allow restoration,
      // but usually, if they log today after missing yesterday, the previous streak is considered "lost".
      // However, for the visual "Flame Out", we handle that in the UI fetch.
      // If they are logging now, they are starting a NEW streak of 1.
      
      // Save the old streak info in case they want to restore later (if logic permits),
      // but generally, logging a new entry confirms the new streak.
      await _userRef.update({
        'streakCount': 1, // Reset to 1 because they logged today
        'lastStreakDate': Timestamp.fromDate(now),
        'streakLostDate': lastLogTs, // Save when they lost it
        'streakActive': true,
      });
    }
  }

  // --- 2. Check Streak Status (For UI Display) ---
  // Returns a Map with status for the UI
  static Future<Map<String, dynamic>> getStreakStatus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    final doc = await _userRef.get();
    if (!doc.exists) return {'count': 0, 'active': false};

    final data = doc.data() as Map<String, dynamic>;
    final int count = data['streakCount'] ?? 0;
    final Timestamp? lastLogTs = data['lastStreakDate'];
    
    if (lastLogTs == null) return {'count': 0, 'active': false};

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime lastLog = lastLogTs.toDate();
    final DateTime lastLogDay = DateTime(lastLog.year, lastLog.month, lastLog.day);

    final int diff = today.difference(lastLogDay).inDays;

    if (diff <= 1) {
      // Logged today or yesterday (streak is safe)
      return {'count': count, 'active': true};
    } else {
      // Missed a day
      return {'count': count, 'active': false, 'lostDate': lastLogTs};
    }
  }

  // --- 3. Restore Streak Logic ---
  static Future<String> tryRestoreStreak() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return "User not found";

    final doc = await _userRef.get();
    final data = doc.data() as Map<String, dynamic>;

    final Timestamp? lastLogTs = data['lastStreakDate'];
    if (lastLogTs == null) return "No streak to restore";

    final DateTime now = DateTime.now();
    final DateTime lastLog = lastLogTs.toDate();
    
    // Check 1: Is it within 2 days?
    // If last log was Jan 1, and today is Jan 4 (diff is 3), it's too late. 
    // Allowed: Jan 3 (diff 2).
    final int daysMissed = now.difference(lastLog).inDays;
    
    if (daysMissed > 2) {
      // Too late, reset permanently
      await _userRef.update({'streakCount': 0});
      return "Too late to restore (limit 48hrs)";
    }

    // Check 2: Restoration Counts
    final int restorationsUsed = data['restorationsUsed'] ?? 0;
    final Timestamp? lastRestorationTs = data['lastRestorationDate'];
    
    // Check if month changed since last restoration
    int currentRestorations = restorationsUsed;
    if (lastRestorationTs != null) {
      final lastResDate = lastRestorationTs.toDate();
      if (lastResDate.month != now.month || lastResDate.year != now.year) {
        currentRestorations = 0; // New month, reset count
      }
    }

    if (currentRestorations >= 3) {
      return "Monthly restoration limit reached (3/3)";
    }

    // Perform Restoration
    // We update the lastStreakDate to "Yesterday" so the streak continues seamlessly
    final DateTime yesterday = now.subtract(Duration(days: 1));
    
    await _userRef.update({
      'lastStreakDate': Timestamp.fromDate(yesterday), // Pretend they logged yesterday
      'streakActive': true,
      'restorationsUsed': currentRestorations + 1,
      'lastRestorationDate': Timestamp.fromDate(now),
    });

    return "Success";
  }
}
