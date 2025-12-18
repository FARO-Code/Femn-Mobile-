import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/profile.dart';
import 'package:femn/search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'dart:math';
import 'tracker.dart'; // ADD THIS IMPORT

// Wellness Screen
class WellnessScreen extends StatefulWidget {
  @override
  _WellnessScreenState createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  late Future<void> _refreshWellness;

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    _refreshWellness = _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(55),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
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
              // Screen title
              const Text(
                'You',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFFE35773),
                ),
              ),
            ],
          ),
          actions: [
            // Search Button
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
                icon: const Icon(
                  Feather.search,
                  color: Color(0xFFE35773),
                  size: 22,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),

            // User Avatar
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .get(),
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
      ),

      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: 14, // CHANGED FROM 13 TO 14
            cacheExtent: 1000,
            itemBuilder: (context, index) {
              return _buildWellnessCard(index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWellnessCard(int index) {
    final List<Map<String, dynamic>> wellnessItems = [
      {
        'name': 'Daily Quote',
        'icon': Feather.message_circle, // represents a quote/message
        'description': 'Inspirational quotes for your day',
      },
      {
        'name': 'Pinks & Level',
        'icon': Feather.bar_chart, // represents tracking/levels
        'description': 'Track your pink levels',
      },
      {
        'name': 'Achievements',
        'icon': Feather.award, // represents awards/achievements
        'description': 'View your accomplishments',
      },
      {
        'name': 'MBTI Match',
        'icon': Feather.users, // for personality matching/social
        'description': 'Personality matching tool',
      },
      {
        'name': 'Contributions',
        'icon': Feather.star, // represents community contribution/recognition
        'description': 'Your community contributions',
      },
      {
        'name': 'Wellness Journal',
        'icon': Feather.book, // journal/book
        'description': 'Track your mental health',
      },
      {
        'name': 'Streaks',
        'icon': Feather.activity, // activity graph/streak
        'description': 'Maintain your streaks',
      },
      {
        'name': 'Period Tracker',
        'icon': Feather.calendar, // for calendar/period tracking
        'description': 'Track your cycle',
      },
      {
        'name': 'Literature Archive',
        'icon': Feather.book_open, // reading/archives
        'description': 'Read educational content',
      },
      {
        'name': 'Self-defense',
        'icon': Feather.shield, // safety/protection
        'description': 'Learn self-defense techniques',
      },
      {
        'name': 'Mood Boards',
        'icon': Feather.layout, // for organizing/visualization
        'description': 'Visualize your mood',
      },
      {
        'name': 'Check-in Timer',
        'icon': Feather.clock, // timer/clock
        'description': 'Set check-in reminders',
      },
      {
        'name': 'Safety Heatmaps',
        'icon': Feather.map_pin, // map/safety location
        'description': 'View safety information',
      },
      // ADDED NEW ITEM:
      {
        'name': 'Activity Tracker',
        'icon': Feather.trending_up, // tracking icon
        'description': 'Track your petitions & polls',
        'onTap': (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TrackerScreen()),
          );
        },
      },
    ];

    // Order by recents/frequently used (mock order)
    final orderedItems = [
      wellnessItems[5], // Wellness Journal
      wellnessItems[7], // Period Tracker
      wellnessItems[6], // Streaks
      wellnessItems[0], // Daily Quote
      wellnessItems[10], // Mood Boards
      wellnessItems[11], // Check-in Timer
      wellnessItems[2], // Achievements
      wellnessItems[4], // Contributions
      wellnessItems[1], // Pinks & Level
      wellnessItems[3], // MBTI Match
      wellnessItems[8], // Literature Archive
      wellnessItems[9], // Self-defense
      wellnessItems[12], // Safety Heatmaps
      wellnessItems[13], // Activity Tracker (NEW)
    ];

    final item = orderedItems[index];
    final double borderRadiusValue = 20.0;

    final random = Random();
    final double minHeight = 120;
    final double maxHeight = 200;
    final double cardHeight =
        minHeight + random.nextInt((maxHeight - minHeight).toInt());

    return GestureDetector(
      onTap: () {
        if (item['onTap'] != null) {
          item['onTap'](context);
        } else {
          print('Tapped on: ${item['name']}');
          // You can add default behavior for other items here
        }
      },
      child: Container(
        height: cardHeight,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE1E0),
          borderRadius: BorderRadius.circular(borderRadiusValue),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item['icon'], size: 60, color: const Color(0xFFE56982)),
            const SizedBox(height: 8),
            Text(
              item['name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Color(0xFFE56982),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              item['description'],
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: const Color(0xFFE56982).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
}

// Keep the existing PostCardWithStream and PostCard classes for reference
class PostCardWithStream extends StatelessWidget {
  final String postId;
  const PostCardWithStream({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .doc(postId)
          .snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return SizedBox();
        }
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return SizedBox();
        }
        final post = postSnapshot.data!;
        final userId = post['userId'];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return SizedBox();
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return SizedBox();
            }
            final user = userSnapshot.data!;
            return PostCard(
              postId: postId,
              userId: userId,
              username: user['username'],
              profileImage: user['profileImage'],
              mediaUrl: post['mediaUrl'],
              caption: post['caption'],
              likes: List<String>.from(post['likes'] ?? []),
              timestamp: post['timestamp'].toDate(),
              mediaType: post['mediaType'],
            );
          },
        );
      },
    );
  }
}

class PostCard extends StatefulWidget {
  final String postId;
  final String userId;
  final String username;
  final String profileImage;
  final String mediaUrl;
  final String caption;
  final List<String> likes;
  final DateTime timestamp;
  final String mediaType;
  const PostCard({
    required this.postId,
    required this.userId,
    required this.username,
    required this.profileImage,
    required this.mediaUrl,
    required this.caption,
    required this.likes,
    required this.timestamp,
    required this.mediaType,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool isLiked = false;
  int likeCount = 0;

  @override
  void initState() {
    super.initState();
    isLiked = widget.likes.contains(currentUserId);
    likeCount = widget.likes.length;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.likes.length != oldWidget.likes.length) {
      setState(() {
        isLiked = widget.likes.contains(currentUserId);
        likeCount = widget.likes.length;
      });
    }
  }

  void _viewPostDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PostDetailScreen(postId: widget.postId, userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final randomHeightFactor = (widget.postId.hashCode % 3) + 2;
    final double imageHeight = 150.0 * randomHeightFactor;
    final double borderRadiusValue = 24.0;

    return GestureDetector(
      onTap: _viewPostDetail,
      child: Container(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(borderRadiusValue),
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFFFE1E0),
                  border: Border.all(color: Color(0xFFFFB7C5), width: 1.0),
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                  child: widget.mediaType == 'image'
                      ? CachedNetworkImage(
                          imageUrl: widget.mediaUrl,
                          width: double.infinity,
                          height: imageHeight,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            height: imageHeight,
                            color: Color(0xFFFFE1E0),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: imageHeight,
                            color: Color(0xFFFFE1E0),
                            child: const Center(
                              child: Icon(Icons.error, color: Colors.red),
                            ),
                          ),
                        )
                      : Container(
                          height: imageHeight,
                          color: Colors.black,
                          child: const Center(
                            child: Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (widget.caption.isNotEmpty)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    widget.caption,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Post Detail Screen (kept for reference)
class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String userId;
  const PostDetailScreen({required this.postId, required this.userId});

  @override
  _PostDetailScreenState createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isSaved = false;
  bool _showCommentInput = false;
  late Future<void> _refreshPost;

  @override
  void initState() {
    super.initState();
    _refreshPost = _onRefresh();
    _checkIfSaved();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 500));
  }

  void _checkIfSaved() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    if (userDoc.exists) {
      final savedPosts = List<String>.from(userDoc['savedPosts'] ?? []);
      setState(() {
        _isSaved = savedPosts.contains(widget.postId);
      });
    }
  }

  void _toggleSave() async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId);
      if (_isSaved) {
        await userRef.update({
          'savedPosts': FieldValue.arrayRemove([widget.postId]),
        });
      } else {
        await userRef.update({
          'savedPosts': FieldValue.arrayUnion([widget.postId]),
        });
      }
      setState(() {
        _isSaved = !_isSaved;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSaved ? 'Post saved!' : 'Post removed from saved'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      print('Error toggling save: $e');
    }
  }

  void _addComment({
    String? replyToCommentId,
    String? replyToUserId,
    String? replyToUsername,
  }) async {
    if (_commentController.text.isEmpty) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      final postDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();
      final postOwnerId = postDoc['userId'];
      final commentsRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments');

      await commentsRef.add({
        'userId': currentUserId,
        'username': userDoc['username'],
        'profileImage': userDoc['profileImage'],
        'text': _commentController.text,
        'timestamp': DateTime.now(),
        'replyToCommentId': replyToCommentId,
        'replyToUserId': replyToUserId,
        'replyToUsername': replyToUsername,
        'likes': [],
      });

      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .update({'comments': FieldValue.increment(1)});

      if (postOwnerId != currentUserId &&
          (replyToCommentId == null || replyToUserId != postOwnerId)) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'comment',
          'fromUserId': currentUserId,
          'toUserId': postOwnerId,
          'postId': widget.postId,
          'commentText': _commentController.text,
          'timestamp': DateTime.now(),
          'read': false,
        });
      }

      if (replyToUserId != null &&
          replyToUserId != currentUserId &&
          replyToUserId != postOwnerId) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'reply',
          'fromUserId': currentUserId,
          'toUserId': replyToUserId,
          'postId': widget.postId,
          'commentText': _commentController.text,
          'timestamp': DateTime.now(),
          'read': false,
        });
      }

      _commentController.clear();
      if (replyToCommentId == null) {
        _hideAndUnfocusCommentInput();
      }
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding comment')));
    }
  }

  void _likeComment(String commentId, List<String> currentLikes) async {
    try {
      final commentRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);
      if (currentLikes.contains(currentUserId)) {
        await commentRef.update({
          'likes': FieldValue.arrayRemove([currentUserId]),
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([currentUserId]),
        });
      }
    } catch (e) {
      print('Error liking comment: $e');
    }
  }

  void _showAndFocusCommentInput({String? replyToUsername}) {
    setState(() {
      _showCommentInput = true;
    });
    if (replyToUsername != null) {
      _commentController.text = '@$replyToUsername ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_commentFocusNode);
    });
  }

  void _hideAndUnfocusCommentInput() {
    setState(() {
      _showCommentInput = false;
    });
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        automaticallyImplyLeading: true,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .snapshots(),
          builder: (context, postSnapshot) {
            if (postSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
              return Center(child: Text('Post not found'));
            }
            final post = postSnapshot.data!;
            final likes = List<String>.from(post['likes'] ?? []);
            final isLiked = likes.contains(currentUserId);
            final likeCount = likes.length;
            final commentCount = post['comments'] ?? 0;

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .get(),
              builder: (context, userSnapshot) {
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return Center(child: Text('User not found'));
                }
                final user = userSnapshot.data!;

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        clipBehavior: Clip.none,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8.0,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () {
                                              if (widget.userId ==
                                                  currentUserId) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        ProfileScreen(
                                                          userId: widget.userId,
                                                        ),
                                                  ),
                                                );
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        OtherUserProfileScreen(
                                                          userId: widget.userId,
                                                        ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: CircleAvatar(
                                              radius: 20,
                                              backgroundImage:
                                                  user['profileImage']
                                                      .isNotEmpty
                                                  ? CachedNetworkImageProvider(
                                                      user['profileImage'],
                                                    )
                                                  : AssetImage(
                                                          'assets/default_avatar.png',
                                                        )
                                                        as ImageProvider,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                user['username'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                timeago.format(
                                                  post['timestamp'].toDate(),
                                                ),
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Spacer(),
                                          IconButton(
                                            icon: Icon(Icons.more_vert),
                                            onPressed: () {
                                              _showPostOptions(
                                                context,
                                                post,
                                                user,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(16.0),
                                      child: post['mediaType'] == 'image'
                                          ? CachedNetworkImage(
                                              imageUrl: post['mediaUrl'],
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(
                                                    height: 300,
                                                    color: Colors.grey[300],
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Container(
                                                        height: 300,
                                                        color: Colors.grey[300],
                                                        child: Icon(
                                                          Icons.error,
                                                        ),
                                                      ),
                                            )
                                          : Container(
                                              height: 300,
                                              color: Colors.black,
                                              child: Center(
                                                child: Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 50,
                                                ),
                                              ),
                                            ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 12.0,
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isLiked
                                                  ? Colors.red
                                                  : null,
                                            ),
                                            onPressed: () async {
                                              final originalIsLiked = isLiked;
                                              setState(() {
                                                if (isLiked) {
                                                  likes.remove(currentUserId);
                                                } else {
                                                  likes.add(currentUserId);
                                                }
                                              });
                                              try {
                                                final postRef =
                                                    FirebaseFirestore.instance
                                                        .collection('posts')
                                                        .doc(widget.postId);
                                                if (!originalIsLiked) {
                                                  await postRef.update({
                                                    'likes':
                                                        FieldValue.arrayUnion([
                                                          currentUserId,
                                                        ]),
                                                  });
                                                  if (widget.userId !=
                                                      currentUserId) {
                                                    // Add notification logic here if needed
                                                  }
                                                } else {
                                                  await postRef.update({
                                                    'likes':
                                                        FieldValue.arrayRemove([
                                                          currentUserId,
                                                        ]),
                                                  });
                                                }
                                              } catch (e) {
                                                setState(() {
                                                  if (originalIsLiked) {
                                                    likes.add(currentUserId);
                                                  } else {
                                                    likes.remove(currentUserId);
                                                  }
                                                });
                                                print(
                                                  'Error toggling like: $e',
                                                );
                                              }
                                            },
                                          ),
                                          Text('$likeCount'),
                                          SizedBox(width: 16),
                                          IconButton(
                                            icon: Icon(Icons.comment),
                                            onPressed: () {
                                              _showAndFocusCommentInput();
                                            },
                                          ),
                                          Text('$commentCount'),
                                          SizedBox(width: 16),
                                          IconButton(
                                            icon: Icon(Icons.share),
                                            onPressed: () {
                                              Share.share(
                                                'Check out this post on Femn: ${post['mediaUrl']}',
                                              );
                                            },
                                          ),
                                          Spacer(),
                                          IconButton(
                                            icon: Icon(
                                              _isSaved
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              color: _isSaved
                                                  ? Colors.pink
                                                  : null,
                                            ),
                                            onPressed: _toggleSave,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (post['caption'] != null &&
                                        post['caption'].isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16.0,
                                          vertical: 8.0,
                                        ),
                                        child: Text.rich(
                                          TextSpan(
                                            children: [
                                              TextSpan(
                                                text: user['username'] + ' ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(text: post['caption']),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                'Comments',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('posts')
                                  .doc(widget.postId)
                                  .collection('comments')
                                  .where('replyToCommentId', isNull: true)
                                  .orderBy('timestamp', descending: false)
                                  .snapshots(),
                              builder: (context, commentsSnapshot) {
                                if (commentsSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                                if (!commentsSnapshot.hasData ||
                                    commentsSnapshot.data!.docs.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(
                                      'No comments yet. Be the first to comment!',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: commentsSnapshot.data!.docs.length,
                                  itemBuilder: (context, index) {
                                    final comment =
                                        commentsSnapshot.data!.docs[index];
                                    final commentLikes = List<String>.from(
                                      comment['likes'] ?? [],
                                    );
                                    final isCommentLiked = commentLikes
                                        .contains(currentUserId);
                                    return _buildCommentItem(
                                      comment,
                                      commentLikes.length,
                                      isCommentLiked,
                                      context,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showCommentInput)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(color: Colors.white),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _addComment(),
                              ),
                            ),
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.send, color: Colors.pink),
                              onPressed: () => _addComment(),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommentItem(
    DocumentSnapshot comment,
    int likeCount,
    bool isLiked,
    BuildContext context, {
    int depth = 0,
  }) {
    final indent = depth > 0 ? 16.0 * depth : 0.0;
    final commentData = comment.data() as Map<String, dynamic>;
    final String commentUsername = commentData['username'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (depth > 0)
          Padding(
            padding: EdgeInsets.only(left: indent - 16.0),
            child: Container(width: 2, height: 20, color: Colors.grey[300]),
          ),
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: Card(
            margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            color: Colors.pink.shade50.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: commentData['profileImage'].isNotEmpty
                            ? CachedNetworkImageProvider(
                                commentData['profileImage'],
                              )
                            : AssetImage('assets/default_avatar.png')
                                  as ImageProvider,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commentUsername,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            if (commentData['replyToUsername'] != null)
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Replying to ',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    TextSpan(
                                      text:
                                          '@${commentData['replyToUsername']}',
                                      style: TextStyle(
                                        color: Colors.pink,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Text(
                              commentData['text'],
                              style: TextStyle(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  timeago.format(
                                    commentData['timestamp'].toDate(),
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () => _likeComment(
                                    comment.id,
                                    List<String>.from(
                                      commentData['likes'] ?? [],
                                    ),
                                  ),
                                  child: Text(
                                    '${likeCount} ${likeCount == 1 ? 'like' : 'likes'}',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    _showAndFocusCommentInput(
                                      replyToUsername: commentUsername,
                                    );
                                  },
                                  child: Text(
                                    'Reply',
                                    style: TextStyle(
                                      color: Colors.pink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: isLiked ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => _likeComment(
                          comment.id,
                          List<String>.from(commentData['likes'] ?? []),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts')
              .doc(widget.postId)
              .collection('comments')
              .where('replyToCommentId', isEqualTo: comment.id)
              .orderBy('timestamp', descending: false)
              .snapshots(),
          builder: (context, repliesSnapshot) {
            if (!repliesSnapshot.hasData ||
                repliesSnapshot.data!.docs.isEmpty) {
              return SizedBox.shrink();
            }
            return Column(
              children: repliesSnapshot.data!.docs.map((reply) {
                final replyLikes = List<String>.from(reply['likes'] ?? []);
                final isReplyLiked = replyLikes.contains(currentUserId);
                return _buildCommentItem(
                  reply,
                  replyLikes.length,
                  isReplyLiked,
                  context,
                  depth: depth + 1,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  void _showPostOptions(
    BuildContext context,
    DocumentSnapshot post,
    DocumentSnapshot user,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (post['userId'] == currentUserId)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    'Delete Post',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePost(context, post);
                  },
                ),
              ListTile(
                leading: Icon(Icons.report, color: Colors.orange),
                title: Text('Report Post'),
                onTap: () {
                  Navigator.pop(context);
                  _reportPost(context, post, user);
                },
              ),
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Share Post'),
                onTap: () {
                  Navigator.pop(context);
                  Share.share(
                    'Check out this post by ${user['username']} on Femn: ${post['mediaUrl']}',
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.cancel),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deletePost(BuildContext context, DocumentSnapshot post) async {
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .delete();
      final storageRef = FirebaseStorage.instance.refFromURL(post['mediaUrl']);
      await storageRef.delete();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'posts': FieldValue.increment(-1)});
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Post deleted successfully')));
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting post')));
    }
  }

  void _reportPost(
    BuildContext context,
    DocumentSnapshot post,
    DocumentSnapshot user,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report Post'),
          content: Text(
            'Are you sure you want to report this post by ${user['username']}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'postId': widget.postId,
                    'reporterId': currentUserId,
                    'reportedUserId': post['userId'],
                    'reason': 'User reported post',
                    'timestamp': DateTime.now(),
                    'status': 'pending',
                  });
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Post reported. Thank you for your feedback.',
                      ),
                    ),
                  );
                } catch (e) {
                  print('Error reporting post: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error reporting post')),
                  );
                }
              },
              child: Text('Report', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
