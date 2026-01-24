import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'streak_service.dart';

class NotificationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Derogatory Comments Tier List ---
  
  static const List<String> mildComments = [
    "Expecting a gold star for doing nothing today? Pathetic.",
    "Your potential is currently a 404 error. Not found.",
    "Is 'Mediocrity' your middle name, or are you just a natural?",
    "If laziness was an Olympic sport, you'd finally have a medal.",
    "Another day, another streak of disappointment. Keep it up.",
    "You're like a 'coming soon' sign that never actually opens.",
    "Your ambition is adorable. Too bad it's non-existent.",
  ];

  static const List<String> sharpComments = [
    "At this rate, the only thing you'll ever finish is your battery life.",
    "Watching you fail is becoming my favorite hobby. Don't stop.",
    "Your excuses are almost as creative as the life you're not living.",
    "You used to have potential. Now you just have a phone and regret.",
    "Is this the 'success' you promised yourself? It looks a lot like failure.",
    "You're proof that some people are just meant to be background characters.",
    "Congratulations on another day of being absolutely useless.",
  ];

  static const List<String> brutalComments = [
    "I'd call you a failure, but that implies you actually tried to do something.",
    "Your life is a dumpster fire, and you're just standing there with a fan.",
    "The only growth you've shown lately is the height of your pile of regrets.",
    "You're the personification of a dead-end street. No future here.",
    "Even your disappointments are disappointed in you. Let that sink in.",
    "You're not just failing; you're becoming a warning story for others.",
    "Look at you. Another day wasted. Does it even hurt anymore?",
  ];

  // --- Scheduling Logic ---

  static Future<void> checkAndSchedulePunishment() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final streakStatus = await StreakService.getStreakStatus();
    final bool isPunishmentDay = !(streakStatus['active'] ?? true);

    if (isPunishmentDay) {
      await _scheduleDerogatoryNotifications(uid);
    }
  }

  static Future<void> _scheduleDerogatoryNotifications(String uid) async {
    // In a real app with local notifications, we'd use a plugin here.
    // For now, we'll log it or push to a 'punishment' collection that the UI listens to.
    
    final Random random = Random();
    final int frequency = 5 + random.nextInt(5); // 5-10 notifications

    for (int i = 0; i < frequency; i++) {
        final tier = random.nextInt(3);
        String comment;
        if (tier == 0) comment = mildComments[random.nextInt(mildComments.length)];
        else if (tier == 1) comment = sharpComments[random.nextInt(sharpComments.length)];
        else comment = brutalComments[random.nextInt(brutalComments.length)];

        // We'll add these to the 'notifications' collection in Firestore
        // This ensures they appear in the NotificationsScreen
        await _db.collection('notifications').add({
          'toUserId': uid,
          'fromUserId': 'system_femn',
          'type': 'admin',
          'message': comment,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
    }
  }

  // General helper for app-wide notifications
  static Future<void> sendNotification({
    required String toUserId,
    required String fromUserId,
    required String type,
    String? message,
    String? postId,
    String? commentText,
  }) async {
    await _db.collection('notifications').add({
      'toUserId': toUserId,
      'fromUserId': fromUserId,
      'type': type,
      'message': message,
      'postId': postId,
      'commentText': commentText,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  }
}
