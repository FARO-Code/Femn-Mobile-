import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';

// Internal App Imports
import 'package:femn/customization/colors.dart';
import 'package:femn/hub_screens/post.dart';
import 'package:femn/hub_screens/profile.dart';
import 'package:femn/hub_screens/messaging.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    // Mark all as read when opening the screen
    _markAllAsRead(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevation,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Feather.arrow_left,
                  color: AppColors.primaryLavender,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        leadingWidth: 60,
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textHigh,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLavender,
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Feather.bell_off,
                    size: 64,
                    color: AppColors.textDisabled,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: AppColors.textMedium, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _NotificationTile(
                docId: doc.id,
                data: data,
                currentUserId: _currentUserId,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAllAsRead({bool silent = false}) async {
    try {
      final snapshots = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshots.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in snapshots.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
    } catch (e) {
      print("Error marking notifications as read: $e");
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String currentUserId;

  const _NotificationTile({
    Key? key,
    required this.docId,
    required this.data,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isRead = data['isRead'] ?? false;
    final String fromUserId = data['fromUserId'] ?? '';
    final Timestamp? timestamp = data['timestamp'] as Timestamp?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isRead
                ? AppColors.surface.withOpacity(0.7)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: isRead
                ? null
                : Border.all(
                    color: AppColors.primaryLavender.withOpacity(0.3),
                    width: 1,
                  ),
          ),
          child: Row(
            children: [
              // Avatar with Icon overlay
              _buildLeading(fromUserId),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] ?? 'Notification',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isRead ? FontWeight.bold : FontWeight.w900,
                        color: AppColors.textHigh,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['body'] ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isRead
                            ? AppColors.textMedium
                            : AppColors.textHigh,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Timestamp & unread dot
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timestamp != null
                        ? timeago.format(timestamp.toDate(), locale: 'en_short')
                        : 'now',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                  if (!isRead) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.accentMustard,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),

              // Post Thumbnail (if exists)
              if (data['postMediaUrl'] != null &&
                  data['postMediaUrl'].isNotEmpty) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: data['postMediaUrl'],
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 44,
                      height: 44,
                      color: AppColors.elevation,
                    ),
                    errorWidget: (context, url, error) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(String fromUserId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(fromUserId)
          .get(),
      builder: (context, snapshot) {
        String profileImage = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          profileImage = snapshot.data!['profileImage'] ?? '';
        }

        return Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.elevation,
              backgroundImage: profileImage.isNotEmpty
                  ? CachedNetworkImageProvider(profileImage)
                  : const AssetImage('assets/default_avatar.png')
                        as ImageProvider,
            ),
            Positioned(
              bottom: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.backgroundDeep,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _getIconForType(),
                  size: 10,
                  color: AppColors.primaryLavender,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getIconForType() {
    switch (data['type']) {
      case 'like':
        return Ionicons.heart;
      case 'comment':
        return Ionicons.chatbubble;
      case 'follow':
        return Ionicons.person_add;
      default:
        return Ionicons.notifications;
    }
  }

  void _handleTap(BuildContext context) async {
    // Navigate based on type
    final String type = data['type'] ?? '';
    final String postId = data['postId'] ?? '';
    final String fromUserId = data['fromUserId'] ?? '';

    if (type == 'like' || type == 'comment') {
      if (postId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: postId,
              userId: currentUserId,
              source: 'notification',
            ),
          ),
        );
      }
    } else if (type == 'follow') {
      if (fromUserId.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProfileScreen(userId: fromUserId),
          ),
        );
      }
    } else if (type == 'therapy_accepted') {
      // Navigate to Chat
      // Pass necessary params if we have them, or just go to MessagingScreen/ChatScreen if feasible.
      // Since we have fromUserId (therapist), we can try to open the chat directly if we fetch user details,
      // or just go to the MessagingScreen main list for simplicity.
      // Although MessagingScreen is where chats are listed. To open specific chat we need Chat ID or User.
      // Let's go to MessagingScreen for now as it's safer.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => MessagingScreen()),
      );
    }
  }
}
