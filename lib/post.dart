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

// Feed Screen with pull-to-refresh
class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<void> _refreshFeed;
  String _selectedFilter = 'For You'; // Default filter
  List<String> _followingIds = []; // Store the list of users the current user follows

  Future<void> _onRefresh() async {
    // No need to manually reload stream — StreamBuilder auto-updates
    // But we can add a small delay to simulate refresh
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    _refreshFeed = _onRefresh();
    // Fetch the current user's following list when the screen initializes
    _fetchFollowingList();
  }

  // Function to fetch the list of users the current user is following
  Future<void> _fetchFollowingList() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        final following = List<String>.from(userDoc['following'] ?? []);
        setState(() {
          _followingIds = following;
        });
      }
    } catch (e) {
      print('Error fetching following list: $e');
      // Handle error appropriately (e.g., show snackbar)
    }
  }

void _showComingSoonPopup() {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 6,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Coming Soon',
              style: TextStyle(
                color: Color(0xFFE56982),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The News section is currently under development.',
              style: TextStyle(
                color: Colors.black.withOpacity(0.8),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFFFFE1E0),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Color(0xFFE35773),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(55),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0, // remove shadow
          shadowColor: Colors.transparent, // make sure no shadow shows
          automaticallyImplyLeading: false,
          title: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white, // keeps it clean
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/femnlogo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          actions: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE1E0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
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

            SizedBox(width: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
              builder: (context, snapshot) {
                Widget avatar;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  avatar = Image.asset(
                    'assets/default_avatar.png',
                    fit: BoxFit.cover,
                  );
                } else if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  avatar = Image.asset(
                    'assets/default_avatar.png',
                    fit: BoxFit.cover,
                  );
                } else {
                  final user = snapshot.data!;
                  final userData = user.data() as Map<String, dynamic>;
                  
                  // Safe way to check for profileImage field
                  final profileImage = userData.containsKey('profileImage') 
                      ? userData['profileImage'] 
                      : '';
                      
                  avatar = profileImage != null && profileImage.isNotEmpty
                      ? Image(
                          image: CachedNetworkImageProvider(profileImage),
                          fit: BoxFit.cover,
                        )
                      : Image.asset(
                          'assets/default_avatar.png',
                          fit: BoxFit.cover,
                        );
                }

                return GestureDetector(
                  onTap: () => _showProfileMenu(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFE1E0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 15,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(child: avatar),
                  ),
                );
              },
            ),

            SizedBox(width: 12),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- Pill Buttons ---
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // --- News ---
            GestureDetector(
              onTap: () => _showComingSoonPopup(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                constraints: const BoxConstraints(minWidth: 80),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1E0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          _selectedFilter == 'News' ? 0.08 : 0.05),
                      blurRadius: _selectedFilter == 'News' ? 8 : 6,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'News',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _selectedFilter == 'News'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: _selectedFilter == 'News' ? 15.0 : 13.0,
                    color: const Color(0xFFE56982),
                  ),
                ),
              ),
            ),

            // --- For You ---
            GestureDetector(
              onTap: () => setState(() => _selectedFilter = 'For You'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                constraints: const BoxConstraints(minWidth: 80),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1E0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          _selectedFilter == 'For You' ? 0.08 : 0.05),
                      blurRadius: _selectedFilter == 'For You' ? 8 : 6,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'For You',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _selectedFilter == 'For You'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: _selectedFilter == 'For You' ? 15.0 : 13.0,
                    color: const Color(0xFFE56982),
                  ),
                ),
              ),
            ),

            // --- Following ---
            GestureDetector(
              onTap: () => setState(() => _selectedFilter = 'Following'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                constraints: const BoxConstraints(minWidth: 80),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE1E0),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                          _selectedFilter == 'Following' ? 0.08 : 0.05),
                      blurRadius: _selectedFilter == 'Following' ? 8 : 6,
                      spreadRadius: 0.5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  'Following',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _selectedFilter == 'Following'
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: _selectedFilter == 'Following' ? 15.0 : 13.0,
                    color: const Color(0xFFE56982),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
              
          Expanded(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No posts yet'));
                  }
                  final posts = snapshot.data!.docs;

                  // --- FILTERING LOGIC STARTS HERE ---
                  List<QueryDocumentSnapshot> filteredPosts = [];

                  // Filter out posts that don't have userId field
                  final validPosts = posts.where((post) {
                    final postData = post.data() as Map<String, dynamic>;
                    return postData.containsKey('userId') && postData['userId'] != null;
                  }).toList();

                  if (_selectedFilter == 'Following') {
                    // Only show posts from users the current user is following
                    if (_followingIds.isEmpty) {
                      filteredPosts = []; // Show nothing if not following anyone
                    } else {
                      filteredPosts = validPosts.where((post) {
                        final userId = post['userId'];
                        return _followingIds.contains(userId);
                      }).toList();
                    }
                  } else {
                    // For 'For You' filter, show all valid posts
                    filteredPosts = validPosts;
                  }
                  // --- FILTERING LOGIC ENDS HERE ---

                  if (filteredPosts.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedFilter == 'Following' 
                          ? 'No posts from people you follow yet'
                          : 'No posts available',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
                    child: MasonryGridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      itemCount: filteredPosts.length,
                      cacheExtent: 1000,
                      itemBuilder: (context, index) {
                        var post = filteredPosts[index];
                        return PostCardWithStream(postId: post.id);
                      },
                    ),
                  );
                },
              ),
            ),
          ),
          // --- End of Posts List ---
        ],
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileScreen(
          userId: FirebaseAuth.instance.currentUser!.uid,
        ),
      ),
    );
  }
}

// PostCardWithStream with error handling
class PostCardWithStream extends StatelessWidget {
  final String postId;

  const PostCardWithStream({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return SizedBox();
        }
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return SizedBox();
        }

        final post = postSnapshot.data!;
        final postData = post.data() as Map<String, dynamic>;

        // Check if userId exists in the post
        if (!postData.containsKey('userId') || postData['userId'] == null) {
          print('Post $postId is missing userId field');
          return SizedBox(); // Skip posts without userId
        }

        final userId = postData['userId'];

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return SizedBox();
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              print('User $userId not found for post $postId');
              return SizedBox();
            }

            final user = userSnapshot.data!;
            final userData = user.data() as Map<String, dynamic>;

            // Safe field access with defaults
            return PostCard(
              postId: postId,
              userId: userId,
              username: userData.containsKey('username') ? userData['username'] : 'Unknown',
              profileImage: userData.containsKey('profileImage') ? userData['profileImage'] : '',
              mediaUrl: postData['mediaUrl'] ?? '',
              caption: postData['caption'] ?? '',
              likes: List<String>.from(postData['likes'] ?? []),
              timestamp: postData['timestamp']?.toDate() ?? DateTime.now(),
              mediaType: postData['mediaType'] ?? 'image',
            );
          },
        );
      },
    );
  }
}

// PostCard remains mostly unchanged
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
        builder: (context) => PostDetailScreen(
          postId: widget.postId,
          userId: widget.userId,
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final randomHeightFactor = (widget.postId.hashCode % 3) + 1.75;
  final double imageHeight = 100.0 * randomHeightFactor;
  final double borderRadiusValue = 24.0;

  return GestureDetector(
    onTap: _viewPostDetail,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- media container with shadow ---
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadiusValue),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
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
                      color: const Color(0xFFFFE1E0),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: imageHeight,
                      color: const Color(0xFFFFE1E0),
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

        // --- caption (no shadow) ---
        if (widget.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Text(
              widget.caption,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
}

}

// Post Detail Screen with pull-to-refresh
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
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (userDoc.exists) {
      final savedPosts = List<String>.from(userDoc['savedPosts'] ?? []);
      setState(() {
        _isSaved = savedPosts.contains(widget.postId);
      });
    }
  }

  void _toggleSave() async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      if (_isSaved) {
        await userRef.update({
          'savedPosts': FieldValue.arrayRemove([widget.postId])
        });
      } else {
        await userRef.update({
          'savedPosts': FieldValue.arrayUnion([widget.postId])
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

  void _addComment({String? replyToCommentId, String? replyToUserId, String? replyToUsername}) async {
    if (_commentController.text.isEmpty) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
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
      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
        'comments': FieldValue.increment(1),
      });
      if (postOwnerId != currentUserId && (replyToCommentId == null || replyToUserId != postOwnerId)) {
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
      if (replyToUserId != null && replyToUserId != currentUserId && replyToUserId != postOwnerId) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding comment')),
      );
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
          'likes': FieldValue.arrayRemove([currentUserId])
        });
      } else {
        await commentRef.update({
          'likes': FieldValue.arrayUnion([currentUserId])
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
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
            return Center(child: Text('Post not found'));
          }

          final post = postSnapshot.data!;
          final postData = post.data() as Map<String, dynamic>;
          final likes = List<String>.from(postData['likes'] ?? []);
          final isLiked = likes.contains(currentUserId);
          final likeCount = likes.length;
          final commentCount = postData['comments'] ?? 0;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                return Center(child: Text('User not found'));
              }

              final user = userSnapshot.data!;
              final userData = user.data() as Map<String, dynamic>;

              return Scaffold(
                backgroundColor: Colors.white,
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(55),
                  child: AppBar(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      icon: const Icon(Feather.chevron_left, color: Color(0xFFE35773)), // Apple-style back
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Row(
                      children: [
                        // Profile picture
                        GestureDetector(
                          onTap: () {
                            if (widget.userId == currentUserId) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId)),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: widget.userId)),
                              );
                            }
                          },
                          child: Container(
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
                              child: userData['profileImage'] != null && userData['profileImage'].isNotEmpty
                                  ? Image(image: CachedNetworkImageProvider(userData['profileImage']), fit: BoxFit.cover)
                                  : Image.asset('assets/default_avatar.png', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Username and timestamp
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userData['username'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Color(0xFFE35773),
                              ),
                            ),
                            Text(
                              timeago.format(postData['timestamp']?.toDate() ?? DateTime.now()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFE35773), // Pink timestamp
                                fontWeight: FontWeight.normal, // Ensure not bold
                              ),
                            ),

                          ],
                        ),
                        const Spacer(),

                        // More options button
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
                          child: IconButton(
                            icon: const Icon(Feather.more_vertical, color: Color(0xFFE35773), size: 22),
                            onPressed: () => _showPostOptions(context, post, user),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                body: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Post media
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: postData['mediaType'] == 'image'
                                  ? CachedNetworkImage(
                                      imageUrl: postData['mediaUrl'],
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        height: 300,
                                        color: Colors.grey[300],
                                        child: const Center(child: CircularProgressIndicator()),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        height: 300,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.error),
                                      ),
                                    )
                                  : Container(
                                      height: 300,
                                      color: Colors.black,
                                      child: const Center(
                                        child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                                      ),
                                    ),
                            ),
                          ),

                            // Post actions
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              children: [
                                // Like button
                                IconButton(
                                  icon: Icon(
                                    isLiked ? Icons.favorite : Icons.favorite_border,
                                    color: isLiked ? Colors.red : Color(0xFFE35773), // FEMN pink for unliked
                                    size: 28, // slightly bigger
                                  ),
                                  onPressed: () async {
                                    setState(() {
                                      if (isLiked) likes.remove(currentUserId);
                                      else likes.add(currentUserId);
                                    });
                                    final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
                                    if (!isLiked) {
                                      await postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
                                    } else {
                                      await postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
                                    }
                                  },
                                ),
                                Text(
                                  '$likeCount',
                                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black),
                                ),
                                const SizedBox(width: 16),

                                // Comment button
                                IconButton(
                                  icon: Icon(Feather.message_circle, color: Color(0xFFE35773), size: 28),
                                  onPressed: _showAndFocusCommentInput,
                                ),
                                Text(
                                  '$commentCount',
                                  style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black),
                                ),
                                const SizedBox(width: 16),

                                // Share button
                                IconButton(
                                  icon: Icon(Feather.share_2, color: Color(0xFFE35773), size: 28),
                                  onPressed: () {
                                    Share.share('Check out this post: ${postData['mediaUrl']}');
                                  },
                                ),

                                const Spacer(),

                                // Bookmark button
                                IconButton(
                                  icon: Icon(
                                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                    color: _isSaved ? Colors.pink : Color(0xFFE35773),
                                    size: 28,
                                  ),
                                  onPressed: _toggleSave,
                                ),
                              ],
                            ),
                          ),
                            if (postData['caption'] != null && postData['caption'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${userData['username']} ',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      TextSpan(text: postData['caption']),
                                    ],
                                  ),
                                ),
                              ),
                            // Comments
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                'Comments',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold, // bold as requested
                                  color: Color(0xFFE35773),   // FEMN pink
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
                                if (!commentsSnapshot.hasData || commentsSnapshot.data!.docs.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                    child: Text(
                                      'No comments yet. Be the first to comment!',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  );
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: commentsSnapshot.data!.docs.length,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  itemBuilder: (context, index) {
                                    final comment = commentsSnapshot.data!.docs[index];
                                    final commentLikes = List<String>.from(comment['likes'] ?? []);
                                    final isCommentLiked = commentLikes.contains(currentUserId);
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: _buildCommentItem(
                                        comment,
                                        commentLikes.length,
                                        isCommentLiked,
                                        context,
                                      ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _addComment(),
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.send, color: Colors.pink), onPressed: _addComment),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
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
      // Vertical line for nested comments (only if not root)
      if (depth > 0)
        Padding(
          padding: EdgeInsets.only(left: indent - 16.0),
          child: Container(
            width: 2,
            height: 24,
            color: Colors.grey[300],
          ),
        ),

      // Main comment card
      Padding(
        padding: EdgeInsets.only(left: indent, right: 12.0, top: 6.0, bottom: 6.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.pink.shade50,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture
              CircleAvatar(
                radius: 28,
                backgroundImage: commentData['profileImage']?.isNotEmpty == true
                    ? CachedNetworkImageProvider(commentData['profileImage'])
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
                backgroundColor: Colors.pink.shade50,
              ),
              SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Username + Verified Badge
                    Row(
                      children: [
                        Text(
                          commentUsername,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFFE35773),
                          ),
                        ),
                        if (commentData['isVerified'] == true) ...[
                          SizedBox(width: 4),
                          Icon(Icons.verified, color: Colors.blue, size: 16),
                        ],
                      ],
                    ),

                    // Reply-to indicator
                    if (commentData['replyToUsername'] != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Replying to ',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            TextSpan(
                              text: '@${commentData['replyToUsername']}',
                              style: TextStyle(
                                color: Colors.pink,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 4),

                    // Comment Text
                    Text(
                      commentData['text'],
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),

                    SizedBox(height: 6),

                    // Timestamp + Likes
                    Row(
                      children: [
                        Text(
                          timeago.format(commentData['timestamp'].toDate()),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _likeComment(comment.id, List<String>.from(commentData['likes'] ?? [])),
                          child: Text(
                            '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                            style: TextStyle(
                              color: Color(0xFFE35773),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Action Buttons (Like & Reply)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _likeComment(comment.id, List<String>.from(commentData['likes'] ?? [])),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 24,
                      color: isLiked ? Color(0xFFE35773) : Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: 15),
                  GestureDetector(
                    onTap: () => _showAndFocusCommentInput(replyToUsername: commentUsername),
                    child: Icon(
                      Feather.corner_up_left,
                      size: 20,
                      color: Color(0xFFE35773),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      // Replies (nested comments)
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .where('replyToCommentId', isEqualTo: comment.id)
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, repliesSnapshot) {
          if (!repliesSnapshot.hasData || repliesSnapshot.data!.docs.isEmpty) {
            return SizedBox.shrink();
          }

          return Padding(
            padding: EdgeInsets.only(left: 16.0 * (depth + 1)), // Indent replies by 16 * (depth + 1)
            child: Column(
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
            ),
          );
        },
      ),
    ],
  );
}


void _showPostOptions(BuildContext context, DocumentSnapshot post, DocumentSnapshot user) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent, // allows rounded corners on container
    builder: (context) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post['userId'] == currentUserId)
              _buildOptionItem(
                icon: Feather.trash,
                iconColor: Colors.red,
                label: 'Delete Post',
                labelColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _deletePost(context, post);
                },
              ),
            _buildOptionItem(
              icon: Feather.alert_circle,
              iconColor: Colors.orange,
              label: 'Report Post',
              onTap: () {
                Navigator.pop(context);
                _reportPost(context, post, user);
              },
            ),
            _buildOptionItem(
              icon: Feather.share_2,
              iconColor: const Color(0xFFE35773),
              label: 'Share Post',
              onTap: () {
                Navigator.pop(context);
                Share.share(
                  'Check out this post by ${user['username']} on Femn: ${post['mediaUrl']}',
                );
              },
            ),
            const Divider(height: 24, color: Colors.grey),
            _buildOptionItem(
              icon: Feather.x,
              iconColor: Colors.grey,
              label: 'Cancel',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildOptionItem({
    required IconData icon,
    Color iconColor = Colors.black,
    required String label,
    Color? labelColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: labelColor ?? const Color(0xFFE35773),
              ),
            ),
          ],
        ),
      ),
    );
  }


  void _deletePost(BuildContext context, DocumentSnapshot post) async {
    try {
      await FirebaseFirestore.instance.collection('posts').doc(widget.postId).delete();
      final storageRef = FirebaseStorage.instance.refFromURL(post['mediaUrl']);
      await storageRef.delete();
      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
        'posts': FieldValue.increment(-1),
      });
      Navigator.pop(context);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      print('Error deleting post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting post')),
      );
    }
  }

  void _reportPost(BuildContext context, DocumentSnapshot post, DocumentSnapshot user) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Report Post'),
          content: Text('Are you sure you want to report this post by ${user['username']}?'),
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
                    SnackBar(content: Text('Post reported. Thank you for your feedback.')),
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