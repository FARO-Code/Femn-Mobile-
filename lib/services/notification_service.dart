import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'navigation_service.dart';
import '../hub_screens/post.dart';
import '../hub_screens/profile.dart';
import '../circle/petitions.dart';
import '../circle/poll_detail_screen.dart';
import '../hub_screens/messaging.dart';
import '../therapy/screens/therapist_dashboard.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Request Permissions
    await _requestPermissions();

    // 2. Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        _handleNotificationPayload(response.payload);
      },
    );

    // 2.1 Handle Cold Start (Notification that launched the app)
    final notificationAppLaunchDetails = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
      final payload =
          notificationAppLaunchDetails?.notificationResponse?.payload;
      _handleNotificationPayload(payload);
    }

    // 3. Listen for Auth Changes to start/stop Firestore listener
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToNotifications(user.uid);
      } else {
        _stopListeningToNotifications();
      }
    });

    _isInitialized = true;
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');
  }

  StreamSubscription? _notificationSubscription;
  DateTime _listenerStartTime = DateTime.now();

  void _listenToNotifications(String uid) {
    print("NotificationService: Starting listener for user $uid");
    _stopListeningToNotifications();
    _listenerStartTime = DateTime.now();

    _notificationSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(5) // Look at top few in case they arrive fast
        .snapshots()
        .listen((snapshot) {
          print(
            "NotificationService: Received snapshot with ${snapshot.docs.length} docs and ${snapshot.docChanges.length} changes",
          );
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                // Ensure it's a new notification and not part of initial fetch
                final timestamp = data['timestamp'];
                print(
                  "NotificationService: New doc added. Timestamp: $timestamp",
                );
                if (timestamp is Timestamp) {
                  // Only show if it happened AFTER the listener started (or very recently)
                  // We add a small buffer for clock drift
                  final tsDate = timestamp.toDate();
                  final isRecent = tsDate.isAfter(
                    _listenerStartTime.subtract(Duration(seconds: 10)),
                  );
                  print(
                    "NotificationService: Is recent? $isRecent (TS: $tsDate, Start: $_listenerStartTime)",
                  );
                  if (isRecent) {
                    print(
                      "NotificationService: Showing local notification: ${data['title']}",
                    );
                    _showLocalNotification(
                      title: data['title'] ?? 'New Notification',
                      body: data['body'] ?? 'You have a new interaction.',
                      payload:
                          "${data['type']}:${data['postId'] ?? data['fromUserId'] ?? data['sessionId'] ?? ''}",
                    );
                  }
                }
              }
            }
          }
        });
  }

  void _stopListeningToNotifications() {
    print("NotificationService: Stopping listener");
    _notificationSubscription?.cancel();
    _notificationSubscription = null;
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    print("NotificationService: Calling _showLocalNotification");
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'high_importance_channel', // id
          'High Importance Notifications', // title
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _localNotifications.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  void _handleNotificationPayload(String? payload) {
    if (payload == null || !payload.contains(':')) return;

    // Small delay to ensure navigator is ready if called early in app lifecycle
    Future.delayed(const Duration(milliseconds: 500), () {
      if (NavigationService.navigatorKey.currentState == null) return;

      final parts = payload.split(':');
      final type = parts[0];
      final id = parts[1];

      if (id.isEmpty) return;

      switch (type) {
        case 'like':
        case 'comment':
          NavigationService.navigateTo(PostDetailScreen(postId: id));
          break;
        case 'follow':
          NavigationService.navigateTo(ProfileScreen(userId: id));
          break;
        case 'poll':
          NavigationService.navigateTo(PollDetailScreen(pollId: id));
          break;
        case 'petition':
        case 'petition_goal':
        case 'petition_update':
          NavigationService.navigateTo(
            EnhancedPetitionDetailScreen(petitionId: id),
          );
          break;
        case 'therapy_booking':
          NavigationService.navigateTo(TherapistDashboard());
          break;
        case 'therapy_accepted':
          // For therapy sessions, navigate to the Messaging screen (HomeScreen index 4 equivalent)
          NavigationService.navigateTo(MessagingScreen());
          break;
      }
    });
  }

  /// Sends a "like" notification to the author of the post.
  /// This writes a document to the author's notifications subcollection.
  Future<void> sendLikeNotification({
    required String authorId,
    required String postId,
    required String likedByUsername,
    required String postTitle,
    String? postMediaUrl, // Added for thumb
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == authorId)
      return; // Don't notify self

    try {
      await _firestore
          .collection('users')
          .doc(authorId)
          .collection('notifications')
          .add({
            'type': 'like',
            'title': likedByUsername,
            'body': 'Liked your post.',
            'postId': postId,
            'fromUserId': currentUser.uid,
            'postMediaUrl': postMediaUrl, // Storing thumb
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending notification: $e");
    }
  }

  /// Sends a "comment" notification to the author of the post.
  Future<void> sendCommentNotification({
    required String authorId,
    required String postId,
    required String commentedByUsername,
    required String commentText,
    String? postMediaUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == authorId) return;

    try {
      await _firestore
          .collection('users')
          .doc(authorId)
          .collection('notifications')
          .add({
            'type': 'comment',
            'title': commentedByUsername,
            'body': 'Commented: $commentText',
            'postId': postId,
            'fromUserId': currentUser.uid,
            'postMediaUrl': postMediaUrl,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending comment notification: $e");
    }
  }

  /// Sends a "follow" notification to the followed user.
  Future<void> sendFollowNotification({
    required String followedUserId,
    required String followerUsername,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == followedUserId) return;

    try {
      await _firestore
          .collection('users')
          .doc(followedUserId)
          .collection('notifications')
          .add({
            'type': 'follow',
            'title': followerUsername,
            'body': 'Started following you.',
            'fromUserId': currentUser.uid,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending follow notification: $e");
    }
  }

  /// Sends a "comment like" notification to the comment owner.
  Future<void> sendCommentLikeNotification({
    required String commentOwnerId,
    required String postId,
    required String likedByUsername,
    String? postMediaUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == commentOwnerId) return;

    try {
      await _firestore
          .collection('users')
          .doc(commentOwnerId)
          .collection('notifications')
          .add({
            'type': 'like',
            'title': likedByUsername,
            'body': 'Liked your comment',
            'postId': postId,
            'fromUserId': currentUser.uid,
            'postMediaUrl': postMediaUrl,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending comment like notification: $e");
    }
  }

  /// Sends a "reply" notification to the person being replied to.
  Future<void> sendReplyNotification({
    required String targetUserId,
    required String postId,
    required String repliedByUsername,
    required String replyText,
    String? postMediaUrl,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null || currentUser.uid == targetUserId) return;

    try {
      await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('notifications')
          .add({
            'type': 'comment',
            'title': repliedByUsername,
            'body': 'Replied: $replyText',
            'postId': postId,
            'fromUserId': currentUser.uid,
            'postMediaUrl': postMediaUrl,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending reply notification: $e");
    }
  }

  /// Helper to send notifications to a list of users in parallel
  Future<void> _sendBatchNotifications({
    required List<String> userIds,
    required Map<String, dynamic> notificationData,
  }) async {
    final futures = userIds.map((uid) {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add(notificationData);
    });
    await Future.wait(futures);
  }

  /// Sends a notification to all followers when a user creates a poll.
  Future<void> sendPollCreatedNotification({
    required String creatorId,
    required String creatorUsername,
    required String pollId,
    required String pollQuestion,
    String? imageUrl,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(creatorId).get();
      final followers = List<String>.from(userDoc.data()?['followers'] ?? []);

      if (followers.isEmpty) return;

      final notificationData = {
        'type': 'poll',
        'title': creatorUsername,
        'body': 'Created a new poll: $pollQuestion',
        'postId': pollId,
        'fromUserId': creatorId,
        'postMediaUrl': imageUrl,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _sendBatchNotifications(
        userIds: followers,
        notificationData: notificationData,
      );
    } catch (e) {
      print("Error sending poll creation notifications: $e");
    }
  }

  /// Sends a notification to all followers when a user creates a petition.
  Future<void> sendPetitionCreatedNotification({
    required String creatorId,
    required String creatorUsername,
    required String petitionId,
    required String petitionTitle,
    String? bannerImageUrl,
  }) async {
    try {
      final userDoc = await _firestore.collection('users').doc(creatorId).get();
      final followers = List<String>.from(userDoc.data()?['followers'] ?? []);

      if (followers.isEmpty) return;

      final notificationData = {
        'type': 'petition',
        'title': creatorUsername,
        'body': 'Started a new petition: $petitionTitle',
        'postId': petitionId,
        'fromUserId': creatorId,
        'postMediaUrl': bannerImageUrl,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _sendBatchNotifications(
        userIds: followers,
        notificationData: notificationData,
      );
    } catch (e) {
      print("Error sending petition creation notifications: $e");
    }
  }

  /// Sends a notification to all signers when a petition reaches its goal.
  Future<void> sendPetitionGoalReachedNotification({
    required String petitionId,
    required String petitionTitle,
    required List<String> signerIds,
    String? bannerImageUrl,
  }) async {
    if (signerIds.isEmpty) return;

    try {
      final notificationData = {
        'type': 'petition_goal',
        'title': 'Victory!',
        'body': 'The petition "$petitionTitle" has reached its goal!',
        'postId': petitionId,
        'postMediaUrl': bannerImageUrl,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _sendBatchNotifications(
        userIds: signerIds,
        notificationData: notificationData,
      );
    } catch (e) {
      print("Error sending petition goal reached notifications: $e");
    }
  }

  /// Sends a notification to all signers when a petition gets an update.
  Future<void> sendPetitionUpdateNotification({
    required String petitionId,
    required String petitionTitle,
    required String updateTitle,
    required List<String> signerIds,
    String? bannerImageUrl,
  }) async {
    if (signerIds.isEmpty) return;

    try {
      final notificationData = {
        'type': 'petition_update',
        'title': 'Petition Update',
        'body': 'New update for "$petitionTitle": $updateTitle',
        'postId': petitionId,
        'postMediaUrl': bannerImageUrl,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await _sendBatchNotifications(
        userIds: signerIds,
        notificationData: notificationData,
      );
    } catch (e) {
      print("Error sending petition update notifications: $e");
    }
  }
}
