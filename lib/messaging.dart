import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/chatscreen.dart';
import 'package:femn/story.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:femn/profile.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// --- NEW MESSAGING SCREEN WITH STORIES ---
class MessagingScreen extends StatefulWidget {
  @override
  _MessagingScreenState createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
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
              color: const Color(0xFFFFE1E0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
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
            'Messages',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Color(0xFFE35773),
            ),
          ),
        ],
      ),
      // Inside your AppBar actions
      actions: [
        // Camera Button
        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFE1E0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Feather.camera, color: Color(0xFFE35773), size: 22),
            onPressed: () => _showStoryCreationModal(context),
          ),
        ),
        const SizedBox(width: 8),

        // New Chat Button (replacing FloatingActionButton)
        Container(
          width: 42,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFFE1E0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Feather.message_circle, color: Color(0xFFE35773), size: 22),
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
                  color: const Color(0xFFFFE1E0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
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
        const SizedBox(height: 12), // slightly tighter spacing

        // Subtle divider
        Container(
          height: 1,
          color: const Color(0xFFFFC1C0), // FEMN soft pink
          margin: const EdgeInsets.symmetric(horizontal: 16), // padding from sides
        ),

        const SizedBox(height: 12), // spacing below divider

        // Messages list
        Expanded(
          child: _buildMessagesList(),
        ),
      ],

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
            return Center(child: CircularProgressIndicator());
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
                return Center(child: CircularProgressIndicator());
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
                color: const Color(0xFFFFE1E0), // FEMN soft pink background
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Feather.plus, // Feather icon
                  size: 30,
                  color: Color(0xFFE35773), // FEMN pink
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
              color: Color(0xFFE35773), // FEMN pink
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE1E0), // FEMN soft pink background
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2), // optional inner padding
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
        const SizedBox(height: 4),
        SizedBox(
          width: 64,
          child: Text(
            username,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFE35773), // FEMN pink for uniformity
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
          return Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No messages yet'));
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
                  return ListTile(title: Text('Loading...'));
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
            color: const Color(0xFFFFE1E0),
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
                        color: Color(0xFFE35773),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE35773),
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
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  if (unreadCount > 0) const SizedBox(height: 6),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE35773),
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
                          color: Colors.white,
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
      // Fetch the current user's document to get their following list
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      if (currentUserDoc.exists) {
        final followingList = List<String>.from(currentUserDoc['following'] ?? []);
        // Include the current user's own ID to see their own stories
        followingList.add(currentUserId);
        return followingList;
      }
      return [currentUserId]; // Fallback to just current user
    } catch (e) {
      print('Error fetching followed users: $e');
      return [currentUserId]; // Fallback to just current user
    }
  }

  void _showStoryCreationModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StoryCreationModal(),
      isScrollControlled: true,
    );
  }

  // Inside _MessagingScreenState class, replace the _viewStory method:
  void _viewStory(String userId, String username, String profileImage) async {
    try {
      // Fetch stories for the specific userId that haven't expired
      final storiesSnapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: DateTime.now())
          .orderBy('timestamp', descending: false) // Order chronologically for viewing
          .get();

      // Check if there are any stories
      if (storiesSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No stories available for this user.')),
        );
        return;
      }

      // Convert QuerySnapshot docs to a List<DocumentSnapshot>
      final List<DocumentSnapshot> userStoriesList = storiesSnapshot.docs;

      // Navigate to the StoryViewerScreen, passing the list of stories
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoryViewerScreen(
            userId: userId,
            stories: userStoriesList, // Pass the list of stories
            username: username,       // Pass username
            profileImage: profileImage, // Pass profileImage
            // isOwnStory is not a parameter of the current StoryViewerScreen constructor,
            // but you can pass it if you add it, or determine it inside StoryViewerScreen
            // using userId == currentUserId. For now, we'll handle it inside the viewer.
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