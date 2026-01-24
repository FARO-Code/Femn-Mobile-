import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// Internal App Imports
import 'package:femn/hub_screens/chatscreen.dart';
import 'package:femn/hub_screens/story.dart';
import 'package:femn/customization/colors.dart';
import 'package:femn/hub_screens/profile.dart';
import 'package:femn/hub_screens/notifications_screen.dart'; // Added Import
// Assuming NewChatScreen is imported or defined in your project structure

class MessagingScreen extends StatefulWidget {
  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Deep background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // FEMN Logo
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevation, // Dark container
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/femnlogo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 8),
            // Screen Title
            Text(
              'Inbox',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh,),
            ),
          ],
        ),
        // AppBar actions
        actions: [
          // Camera Button
          Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 4),
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
            child: IconButton(
              icon: const Icon(Feather.camera, color: AppColors.primaryLavender, size: 22),
              onPressed: () => _showStoryCreationModal(context),
            ),
          ),
          const SizedBox(width: 8),

          // New Chat Button
          Container(
            width: 42,
            height: 42,
            margin: const EdgeInsets.symmetric(horizontal: 4),
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
            child: IconButton(
              icon: const Icon(Feather.message_circle, color: AppColors.primaryLavender, size: 22),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => NewChatScreen()),
                );
              },
            ),
          ),
          const SizedBox(width: 8),

          // User Profile
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
            builder: (context, snapshot) {
              Widget avatar;
              if (snapshot.connectionState == ConnectionState.waiting ||
                  !snapshot.hasData ||
                  !snapshot.data!.exists) {
                avatar = Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
              } else {
                final user = snapshot.data!;
                final profileImage = user['profileImage'] ?? '';
                avatar = profileImage.isNotEmpty
                    ? Image(image: CachedNetworkImageProvider(profileImage), fit: BoxFit.cover)
                    : Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
              }

              return GestureDetector(
                onTap: () => _showProfileMenu(context),
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
                  child: ClipOval(child: avatar),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
        ],
      ),

      body: Column(
        children: [
          // Stories header row
          _buildStoriesHeader(),
          const SizedBox(height: 12), 

          // Subtle divider
          Container(
            height: 1,
            color: AppColors.elevation, // Dark divider
            margin: const EdgeInsets.symmetric(horizontal: 16), 
          ),

          // --- NEW: SPECIAL NOTIFICATION TILES ---
          
          // 1. Activity / Interactions Tile
          _buildActivityTile(),

          // 2. Femn Team / Admin Tile
          _buildSystemMessagesTile(),

          // ---------------------------------------

          // Messages list
          Expanded(
            child: _buildMessagesList(),
          ),
        ],

      ),
    );
  }

  // --- NEW WIDGET: Activity Tile ---
  Widget _buildActivityTile() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('toUserId', isEqualTo: currentUserId)
          .where('read', isEqualTo: false) // Only count unread
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        String previewText = "Check your recent interactions";
        
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
          if (unreadCount > 0) {
            // Simple logic to clump notifications
            if (unreadCount > 99) {
               previewText = "99+ people interacted with you";
            } else {
               previewText = "$unreadCount new interactions";
            }
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: GestureDetector(
            onTap: () {
               // Mark read logic could go here
               Navigator.push(context, MaterialPageRoute(builder: (context) => NotificationScreen()));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent, // Blend with bg or make AppColors.surface for card look
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  // Icon container mimicking a profile picture
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.elevation, 
                      border: Border.all(color: AppColors.secondaryTeal.withOpacity(0.5), width: 1),
                    ),
                    child: Center(
                      child: Icon(Feather.heart, color: AppColors.secondaryTeal, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Activity",
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textHigh
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          previewText,
                          style: TextStyle(
                            fontSize: 13, 
                            color: unreadCount > 0 ? AppColors.textOnSecondary : AppColors.textMedium,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accentMustard,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- NEW WIDGET: System Messages Tile ---
  Widget _buildSystemMessagesTile() {
    // This could also be a stream if you have a 'system_messages' collection
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: GestureDetector(
        onTap: () {
          // Navigate to a specific System Chat or just show a modal
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("No new system announcements."),
            backgroundColor: AppColors.elevation,
          ));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
             color: Colors.transparent,
             borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Femn Logo as Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLavender, // Highlight color
                  boxShadow: [
                    BoxShadow(color: AppColors.primaryLavender.withOpacity(0.3), blurRadius: 8),
                  ]
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: ClipOval(
                    child: Image.asset('assets/femnlogo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Femn Team",
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textHigh
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Feather.check_circle, size: 14, color: AppColors.primaryLavender),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Welcome to the community! 💜",
                      style: TextStyle(fontSize: 13, color: AppColors.textMedium),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileScreen(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  }

  Widget _buildStoriesHeader() {
    return SizedBox(
      height: 100,
      child: FutureBuilder<List<String>>(
        future: _getFollowedUserIds(),
        builder: (context, followedUsersSnapshot) {
          if (!followedUsersSnapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          
          final followedUserIds = followedUsersSnapshot.data!;
          
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stories')
                .where('userId', whereIn: followedUserIds)
                .where('expiresAt', isGreaterThan: DateTime.now())
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
              }
              
              // Group stories by user
              final Map<String, DocumentSnapshot> userStories = {};
              for (var doc in snapshot.data!.docs) {
                final userId = doc['userId'];
                if (!userStories.containsKey(userId)) {
                  userStories[userId] = doc;
                }
              }
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: userStories.length + 1, // +1 for "Add Story" button
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAddStoryButton(context);
                  }
                  
                  final userId = userStories.keys.elementAt(index - 1);
                  final story = userStories[userId]!;
                  final isSeen = List.from(story['viewers']).contains(currentUserId);
                  
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                    builder: (context, userSnapshot) {
                      if (!userSnapshot.hasData) {
                        return SizedBox.shrink();
                      }
                      
                      final user = userSnapshot.data!;
                      return _buildStoryCircle(
                        user['username'],
                        user['profileImage'],
                        isSeen: isSeen,
                        onTap: () => _viewStory(userId, user['username'], user['profileImage']),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _showStoryCreationModal(context),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevation, // Dark circle
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Feather.plus, 
                  size: 30,
                  color: AppColors.primaryLavender, 
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'You',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryLavender,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStoryCircle(String username, String profileImage,
      {bool isSeen = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 64,
              height: 64,
              padding: EdgeInsets.all(2), // Padding for the ring
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Teal for unseen, Disabled for seen
                  color: isSeen ? AppColors.textDisabled : AppColors.secondaryTeal,
                  width: 2,
                ),
              ),
              child: Container(
                  decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevation, // Background behind image
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2), 
                  child: CircleAvatar(
                    radius: 30,
                    backgroundImage: profileImage.isNotEmpty
                        ? CachedNetworkImageProvider(profileImage)
                        : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              username,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMedium, 
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No messages yet', style: TextStyle(color: AppColors.textMedium)));
        }
        
        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chat = snapshot.data!.docs[index];
            final participants = List.from(chat['participants']);
            final otherUserId = participants.firstWhere((id) => id != currentUserId);
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return ListTile(title: Text('Loading...', style: TextStyle(color: AppColors.textDisabled)));
                }
                
                final user = userSnapshot.data!;
                final unreadCount = chat['unreadCount'] != null 
                    ? chat['unreadCount'][currentUserId] ?? 0 
                    : 0;
                
                return _buildMessageTile(
                  chat.id,
                  user['username'],
                  user['profileImage'],
                  chat['lastMessage'] ?? '',
                  chat['lastMessageTime'].toDate(),
                  unreadCount,
                  otherUserId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessageTile(
    String chatId,
    String username,
    String profileImage,
    String lastMessage,
    DateTime timestamp,
    int unreadCount,
    String otherUserId,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                otherUserId: otherUserId,
                otherUserName: username,
                otherUserProfileImage: profileImage,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface, // Surface color for message tile
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Profile image
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.elevation,
                backgroundImage: profileImage.isNotEmpty
                    ? CachedNetworkImageProvider(profileImage)
                    : const AssetImage('assets/default_avatar.png')
                        as ImageProvider,
              ),
              const SizedBox(width: 12),

              // Name and last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHigh, // White Name
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMedium, // Gray message preview
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Timestamp and unread count
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeago.format(timestamp),
                    style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
                  ),
                  if (unreadCount > 0) const SizedBox(height: 6),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentMustard, // Mustard for notification badge
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.backgroundDeep, // Dark text on light badge
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<String>> _getFollowedUserIds() async {
    try {
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (currentUserDoc.exists) {
        final followingList = List<String>.from(currentUserDoc['following'] ?? []);
        followingList.add(currentUserId);
        return followingList;
      }
      return [currentUserId]; 
    } catch (e) {
      print('Error fetching followed users: $e');
      return [currentUserId]; 
    }
  }

  void _showStoryCreationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StoryCreationModal(),
      isScrollControlled: true,
      backgroundColor: AppColors.surface, // Ensure modal matches theme
    );
  }

  void _viewStory(String userId, String username, String profileImage) async {
    try {
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .orderBy('timestamp', descending: false) 
          .get();

      if (storiesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No stories available for this user.')),
        );
        return;
      }

      final List<DocumentSnapshot> userStoriesList = storiesSnapshot.docs;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryViewerScreen(
            userId: userId,
            stories: userStoriesList, 
            username: username,      
            profileImage: profileImage, 
          ),
        ),
      );
    } catch (e) {
      print('Error viewing story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading story.')),
      );
    }
  }
}