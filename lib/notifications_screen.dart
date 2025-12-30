import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/colors.dart';
import 'package:femn/post.dart'; // Import to access PostDetailScreen
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.chevron_left, color: AppColors.primaryLavender),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Activity',
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('toUserId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .limit(50) // Limit to recent 50 for performance
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Feather.bell_off, size: 48, color: AppColors.textDisabled),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(color: AppColors.textMedium)),
                ],
              ),
            );
          }

          // Mark all as read when opening this screen (Optional logic)
          // _markNotificationsAsRead(snapshot.data!.docs); 

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              return _buildNotificationItem(context, notification);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type']; // 'like', 'comment', 'reply', 'follow', 'admin'
    
    // Determine Icon and Text based on type
    IconData iconData;
    Color iconColor;
    String textPreview;

    switch (type) {
      case 'like':
        iconData = Icons.favorite;
        iconColor = AppColors.error;
        textPreview = 'liked your post.';
        break;
      case 'comment':
        iconData = Feather.message_circle;
        iconColor = AppColors.secondaryTeal;
        textPreview = 'commented: "${data['commentText'] ?? ''}"';
        break;
      case 'reply':
        iconData = Feather.corner_down_right;
        iconColor = AppColors.primaryLavender;
        textPreview = 'replied: "${data['commentText'] ?? ''}"';
        break;
      case 'admin':
        iconData = Feather.shield;
        iconColor = AppColors.accentMustard;
        textPreview = data['message'] ?? 'System update.';
        break;
      default:
        iconData = Feather.bell;
        iconColor = AppColors.textMedium;
        textPreview = 'interacted with you.';
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(data['fromUserId']).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) return SizedBox();

        final user = userSnapshot.data!.data() as Map<String, dynamic>;
        final username = user['username'] ?? 'Someone';
        final profileImage = user['profileImage'] ?? '';

        return ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.elevation,
                backgroundImage: profileImage.isNotEmpty
                    ? CachedNetworkImageProvider(profileImage)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDeep,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, size: 12, color: iconColor),
                ),
              ),
            ],
          ),
          title: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$username ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh, fontSize: 14),
                ),
                TextSpan(
                  text: textPreview,
                  style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                ),
              ],
            ),
          ),
          subtitle: Text(
            timeago.format(data['timestamp']?.toDate() ?? DateTime.now()),
            style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
          ),
          trailing: data['postId'] != null && type != 'follow'
            ? _buildPostThumbnail(data['postId']) // Optional: Show small image of post
            : null,
          onTap: () {
            if (data['postId'] != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(
                    postId: data['postId'],
                    userId: FirebaseAuth.instance.currentUser!.uid, // Technically detail screen needs post owner ID, but for deep link fetch usually PostDetail handles fetching
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildPostThumbnail(String postId) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
      builder: (context, snapshot) {
        if(!snapshot.hasData || !snapshot.data!.exists) return SizedBox();
        final postData = snapshot.data!.data() as Map<String, dynamic>;
        if(postData['mediaUrl'] == null) return SizedBox();
        
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            image: DecorationImage(
              image: CachedNetworkImageProvider(postData['mediaUrl']),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}