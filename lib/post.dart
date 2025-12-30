import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/profile.dart';
import 'package:femn/search.dart';
import 'package:femn/colors.dart'; // <--- IMPORT YOUR NEW COLOR FILE
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- ADDED
import 'package:femn/post.dart'; // <--- ADD THIS IMPORT

// Feed Screen with pull-to-refresh
class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<void> _refreshFeed;
  String _selectedFilter = 'For You'; 
  List<String> _followingIds = []; 

  // --- QUOTE VARIABLES ---
  bool _showQuote = false;
  Map<String, String> _todaysQuoteContent = {};

  final List<Map<String, String>> _dailyQuotes = [
    {"quote": "Deeds, not words.", "author": "Emmeline Pankhurst"},
    {"quote": "Feminism is the radical notion that women are people.", "author": "Marie Shear"},
    {"quote": "Well-behaved women seldom make history.", "author": "Laurel Thatcher Ulrich"},
    {"quote": "If they don't give you a seat at the table, bring a folding chair.", "author": "Shirley Chisholm"},
    {"quote": "My silences had not protected me. Your silence will not protect you.", "author": "Audre Lorde"},
    {"quote": "Women belong in all places where decisions are being made.", "author": "Ruth Bader Ginsburg"},
    {"quote": "We cannot all succeed when half of us are held back.", "author": "Malala Yousafzai"},
    {"quote": "The most common way people give up their power is by thinking they don't have any.", "author": "Alice Walker"},
    {"quote": "I am not free while any woman is unfree, even when her shackles are very different from my own.", "author": "Audre Lorde"},
    {"quote": "No pride for some of us without liberation for all of us.", "author": "Marsha P. Johnson"},
  ];

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    _refreshFeed = _onRefresh();
    _fetchFollowingList();
    _checkDailyQuote(); // <--- Check quote logic on init
  }

  // --- QUOTE LOGIC START ---
  Future<void> _checkDailyQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastDismissedDate = prefs.getString('last_dismissed_quote_date');
    
    // Get today's date in YYYY-MM-DD format
    final DateTime now = DateTime.now();
    final String todayDate = "${now.year}-${now.month}-${now.day}";

    if (lastDismissedDate != todayDate) {
      // Pick a quote based on the day of the month so it's consistent for the whole day
      final int quoteIndex = now.day % _dailyQuotes.length;
      
      setState(() {
        _todaysQuoteContent = _dailyQuotes[quoteIndex];
        _showQuote = true;
      });
    } else {
      setState(() {
        _showQuote = false;
      });
    }
  }

  Future<void> _dismissQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    final String todayDate = "${now.year}-${now.month}-${now.day}";
    
    await prefs.setString('last_dismissed_quote_date', todayDate);
    
    setState(() {
      _showQuote = false;
    });
  }
  // --- QUOTE LOGIC END ---

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
        backgroundColor: AppColors.surface, // Universal Surface
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Coming Soon',
                style: TextStyle(
                  color: AppColors.accentMustard, // Universal Mustard
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The News section is currently under development.',
                style: TextStyle(
                  color: AppColors.textMedium, // Universal Medium Text
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
                    color: AppColors.elevation, // Universal Elevation
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: AppColors.primaryLavender, // Universal Lavender
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
      backgroundColor: AppColors.backgroundDeep, // Universal Background
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(55),
        child: AppBar(
          backgroundColor: AppColors.backgroundDeep,
          elevation: 0,
          shadowColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.elevation,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
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
                color: AppColors.elevation,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Feather.search,
                  color: AppColors.primaryLavender,
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
                if (snapshot.connectionState == ConnectionState.waiting || 
                    snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                  avatar = Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
                } else {
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  final profileImage = userData['profileImage'] ?? '';
                  avatar = profileImage.isNotEmpty
                      ? Image(image: CachedNetworkImageProvider(profileImage), fit: BoxFit.cover)
                      : Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
                }

                return GestureDetector(
                  onTap: () => _showProfileMenu(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.elevation,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
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
                _buildFilterButton('News', onTap: () => _showComingSoonPopup()),
                _buildFilterButton('For You', onTap: () => setState(() => _selectedFilter = 'For You')),
                _buildFilterButton('Following', onTap: () => setState(() => _selectedFilter = 'Following')),
              ],
            ),
          ),
          
          const SizedBox(height: 8),

          // --- DAILY QUOTE CARD (New & Themed) ---
          if (_showQuote && _todaysQuoteContent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Dismissible(
                key: const Key('daily_quote_card'),
                direction: DismissDirection.horizontal,
                onDismissed: (direction) {
                  _dismissQuote();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface, // Matches the theme surface
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryLavender.withOpacity(0.3), width: 1), // Subtle lavender border
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                        "Today's Inspiration".toUpperCase(), // <--- Apply .toUpperCase() here
                        style: TextStyle(
                          color: AppColors.secondaryTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          // uppercase: true, <--- DELETE THIS LINE
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "\"${_todaysQuoteContent['quote']}\"",
                        style: TextStyle(
                          fontSize: 14.0,
                          color: AppColors.textHigh, // White/Light text
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          "~ ${_todaysQuoteContent['author']}",
                          style: TextStyle(
                            fontSize: 12.0,
                            color: AppColors.primaryLavender, // Signature lavender
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // --- END QUOTE CARD ---

          Expanded(
            child: RefreshIndicator(
              color: AppColors.primaryLavender,
              backgroundColor: AppColors.surface,
              onRefresh: _onRefresh,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('No posts yet', style: TextStyle(color: AppColors.textMedium)));
                  }
                  final posts = snapshot.data!.docs;
                  
                  // Filtering logic reused from your code...
                  final validPosts = posts.where((post) {
                    final postData = post.data() as Map<String, dynamic>;
                    return postData.containsKey('userId') && postData['userId'] != null;
                  }).toList();

                  List<QueryDocumentSnapshot> filteredPosts = [];
                  if (_selectedFilter == 'Following') {
                    if (_followingIds.isEmpty) {
                      filteredPosts = [];
                    } else {
                      filteredPosts = validPosts.where((post) {
                        return _followingIds.contains(post['userId']);
                      }).toList();
                    }
                  } else {
                    filteredPosts = validPosts;
                  }

                  if (filteredPosts.isEmpty) {
                    return Center(
                      child: Text(
                        _selectedFilter == 'Following' 
                          ? 'No posts from people you follow yet'
                          : 'No posts available',
                        style: TextStyle(fontSize: 16, color: AppColors.textDisabled),
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
        ],
      ),
    );
  }

  // Helper widget for the pills
  Widget _buildFilterButton(String title, {required VoidCallback onTap}) {
    final bool isSelected = _selectedFilter == title;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        constraints: const BoxConstraints(minWidth: 80),
        decoration: BoxDecoration(
          // Teal for active, Dark Gray (Elevation) for inactive
          color: isSelected ? AppColors.secondaryTeal : AppColors.elevation, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.3 : 0.1),
              blurRadius: isSelected ? 8 : 6,
              spreadRadius: 0.5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: isSelected ? 15.0 : 13.0,
            // White text inside Teal, Gray text inside dark container
            color: isSelected ? AppColors.textOnSecondary : AppColors.textMedium, 
          ),
        ),
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

// PostCardWithStream (Logic remains same, styling updated in PostCard)
class PostCardWithStream extends StatelessWidget {
  final String postId;
  const PostCardWithStream({Key? key, required this.postId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('posts').doc(postId).snapshots(),
      builder: (context, postSnapshot) {
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) return SizedBox();
        final postData = postSnapshot.data!.data() as Map<String, dynamic>;
        if (!postData.containsKey('userId') || postData['userId'] == null) return SizedBox();

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(postData['userId']).get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) return SizedBox();
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;

            return PostCard(
              postId: postId,
              userId: postData['userId'],
              username: userData['username'] ?? 'Unknown',
              profileImage: userData['profileImage'] ?? '',
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

// PostCard - Updated Styling using Universal Colors
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
  // Logic remains identical
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
          // Media Container
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadiusValue),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3), // Stronger shadow for dark mode
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
                        color: AppColors.elevation, // Universal Dark placeholder
                        child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: imageHeight,
                        color: AppColors.elevation,
                        child: Center(child: Icon(Icons.error, color: AppColors.error)),
                      ),
                    )
                  : Container(
                      height: imageHeight,
                      color: Colors.black, // Video BG
                      child: Center(
                        child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                      ),
                    ),
            ),
          ),

          // Caption
          if (widget.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.username,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh, // Universal Off-white for username
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    widget.caption,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMedium, // Universal Light gray for caption
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Post Detail Screen - Updated Styling with Universal Colors
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

  Future<void> _onRefresh() async { await Future.delayed(Duration(milliseconds: 500)); }

  void _checkIfSaved() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (userDoc.exists) {
      final savedPosts = List<String>.from(userDoc['savedPosts'] ?? []);
      setState(() => _isSaved = savedPosts.contains(widget.postId));
    }
  }
  
  void _toggleSave() async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      if (_isSaved) {
        await userRef.update({'savedPosts': FieldValue.arrayRemove([widget.postId])});
      } else {
        await userRef.update({'savedPosts': FieldValue.arrayUnion([widget.postId])});
      }
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isSaved ? 'Post saved!' : 'Post removed from saved', style: TextStyle(color: AppColors.backgroundDeep)),
        backgroundColor: AppColors.primaryLavender,
      ));
    } catch (e) { print(e); }
  }

  void _addComment({String? replyToCommentId, String? replyToUserId, String? replyToUsername}) async {
    if (_commentController.text.isEmpty) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      final postOwnerId = postDoc['userId'];
      final commentsRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments');
      
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

      // Notification logic (Simplified for brevity as logic wasn't changed)
      if (postOwnerId != currentUserId && (replyToCommentId == null || replyToUserId != postOwnerId)) {
        await FirebaseFirestore.instance.collection('notifications').add({
           'type': 'comment', 'fromUserId': currentUserId, 'toUserId': postOwnerId,
           'postId': widget.postId, 'commentText': _commentController.text, 'timestamp': DateTime.now(), 'read': false,
        });
      }

      _commentController.clear();
      if (replyToCommentId == null) {
        _hideAndUnfocusCommentInput();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding comment')));
    }
  }
  
  void _likeComment(String commentId, List<String> currentLikes) async {
    try {
      final commentRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').doc(commentId);
      if (currentLikes.contains(currentUserId)) {
        await commentRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
      } else {
        await commentRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
      }
    } catch (e) { print(e); }
  }

  void _showAndFocusCommentInput({String? replyToUsername}) {
    setState(() => _showCommentInput = true);
    if (replyToUsername != null) {
      _commentController.text = '@$replyToUsername ';
      _commentController.selection = TextSelection.fromPosition(TextPosition(offset: _commentController.text.length));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => FocusScope.of(context).requestFocus(_commentFocusNode));
  }

  void _hideAndUnfocusCommentInput() {
    setState(() => _showCommentInput = false);
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primaryLavender,
      backgroundColor: AppColors.surface,
      onRefresh: _onRefresh,
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
        builder: (context, postSnapshot) {
          if (postSnapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          if (!postSnapshot.hasData || !postSnapshot.data!.exists) return Center(child: Text('Post not found', style: TextStyle(color: AppColors.textHigh)));

          final post = postSnapshot.data!;
          final postData = post.data() as Map<String, dynamic>;
          final likes = List<String>.from(postData['likes'] ?? []);
          final isLiked = likes.contains(currentUserId);
          final likeCount = likes.length;
          final commentCount = postData['comments'] ?? 0;

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) return SizedBox();
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) return SizedBox();

              final userData = userSnapshot.data!.data() as Map<String, dynamic>;

              return Scaffold(
                backgroundColor: AppColors.backgroundDeep, // Universal Deep background
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(55),
                  child: AppBar(
                    backgroundColor: AppColors.backgroundDeep,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      icon: const Icon(Feather.chevron_left, color: AppColors.primaryLavender),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Row(
                      children: [
                        // Avatar
                        GestureDetector(
                          onTap: () {
                             if (widget.userId == currentUserId) {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId)));
                              } else {
                                // Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(userId: widget.userId)));
                              }
                          },
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
                            child: ClipOval(
                              child: userData['profileImage'] != null && userData['profileImage'].isNotEmpty
                                  ? Image(image: CachedNetworkImageProvider(userData['profileImage']), fit: BoxFit.cover)
                                  : Image.asset('assets/default_avatar.png', fit: BoxFit.cover),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userData['username'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textHigh, // Universal Off-white
                              ),
                            ),
                            Text(
                              timeago.format(postData['timestamp']?.toDate() ?? DateTime.now()),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryLavender, // Universal Lavender timestamp
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.elevation,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(Feather.more_vertical, color: AppColors.primaryLavender, size: 22),
                            onPressed: () => _showPostOptions(context, post, userSnapshot.data!),
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
                            // Post Media
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
                                          color: AppColors.elevation,
                                          child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          height: 300,
                                          color: AppColors.elevation,
                                          child: const Icon(Icons.error, color: AppColors.error),
                                        ),
                                      )
                                    : Container(
                                        height: 300,
                                        color: Colors.black,
                                        child: const Center(child: Icon(Icons.play_arrow, color: Colors.white, size: 50)),
                                      ),
                              ),
                            ),

                            // Action Buttons
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? AppColors.error : AppColors.primaryLavender, // Error is Red
                                      size: 28,
                                    ),
                                    onPressed: () async {
                                      final postRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
                                      if (!isLiked) await postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
                                      else await postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
                                    },
                                  ),
                                  Text('$likeCount', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: Icon(Feather.message_circle, color: AppColors.primaryLavender, size: 28),
                                    onPressed: _showAndFocusCommentInput,
                                  ),
                                  Text('$commentCount', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: Icon(Feather.share_2, color: AppColors.primaryLavender, size: 28),
                                    onPressed: () { Share.share('Check out this post: ${postData['mediaUrl']}'); },
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(
                                      _isSaved ? Icons.bookmark : Icons.bookmark_border,
                                      color: _isSaved ? AppColors.accentMustard : AppColors.primaryLavender,
                                      size: 28,
                                    ),
                                    onPressed: _toggleSave,
                                  ),
                                ],
                              ),
                            ),

                            // Caption
                            if (postData['caption'] != null && postData['caption'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${userData['username']} ',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh),
                                      ),
                                      TextSpan(
                                        text: postData['caption'],
                                        style: TextStyle(color: AppColors.textMedium),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Comments Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                'Comments',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryLavender,
                                ),
                              ),
                            ),
                            
                            // Comment Stream
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
                                    child: Text('No comments yet.', style: TextStyle(color: AppColors.textDisabled)),
                                  );
                                }
                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: commentsSnapshot.data!.docs.length,
                                  itemBuilder: (context, index) {
                                    final comment = commentsSnapshot.data!.docs[index];
                                    final commentLikes = List<String>.from(comment['likes'] ?? []);
                                    return _buildCommentItem(
                                      comment,
                                      commentLikes.length,
                                      commentLikes.contains(currentUserId),
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
                    
                    // Input Field
                    if (_showCommentInput)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: AppColors.surface, // Universal Dark surface for input area
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                style: TextStyle(color: AppColors.textHigh),
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  hintStyle: TextStyle(color: AppColors.textDisabled),
                                  filled: true,
                                  fillColor: AppColors.elevation,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => _addComment(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: AppColors.primaryLavender),
                              onPressed: () => _addComment(),
                            ),
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
        if (depth > 0)
          Padding(
            padding: EdgeInsets.only(left: indent - 16.0),
            child: Container(width: 2, height: 24, color: AppColors.textDisabled),
          ),
        
        Padding(
          padding: EdgeInsets.only(left: indent, right: 12.0, top: 6.0, bottom: 6.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface, // Universal Surface color for comment cards
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: commentData['profileImage']?.isNotEmpty == true
                      ? CachedNetworkImageProvider(commentData['profileImage'])
                      : AssetImage('assets/default_avatar.png') as ImageProvider,
                  backgroundColor: AppColors.elevation,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            commentUsername,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.primaryLavender, // Name in Universal Lavender
                            ),
                          ),
                          if (commentData['isVerified'] == true) ...[
                            SizedBox(width: 4),
                            Icon(Icons.verified, color: Colors.blue, size: 16),
                          ],
                        ],
                      ),
                      if (commentData['replyToUsername'] != null)
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Replying to ', style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                              TextSpan(
                                text: '@${commentData['replyToUsername']}',
                                style: TextStyle(color: AppColors.secondaryTeal, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 4),
                      Text(
                        commentData['text'],
                        style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                      ),
                      SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            timeago.format(commentData['timestamp'].toDate()),
                            style: TextStyle(color: AppColors.textDisabled, fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                          SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _likeComment(comment.id, List<String>.from(commentData['likes'] ?? [])),
                            child: Text(
                              '$likeCount ${likeCount == 1 ? 'like' : 'likes'}',
                              style: TextStyle(color: AppColors.primaryLavender, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _likeComment(comment.id, List<String>.from(commentData['likes'] ?? [])),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 24,
                        color: isLiked ? AppColors.error : AppColors.textDisabled,
                      ),
                    ),
                    SizedBox(height: 15),
                    GestureDetector(
                      onTap: () => _showAndFocusCommentInput(replyToUsername: commentUsername),
                      child: Icon(Feather.corner_up_left, size: 20, color: AppColors.primaryLavender),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Nested Replies
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('posts').doc(widget.postId)
              .collection('comments')
              .where('replyToCommentId', isEqualTo: comment.id)
              .orderBy('timestamp', descending: false)
              .snapshots(),
          builder: (context, repliesSnapshot) {
            if (!repliesSnapshot.hasData || repliesSnapshot.data!.docs.isEmpty) return SizedBox.shrink();
            return Padding(
              padding: EdgeInsets.only(left: 16.0 * (depth + 1)),
              child: Column(
                children: repliesSnapshot.data!.docs.map((reply) {
                  final replyLikes = List<String>.from(reply['likes'] ?? []);
                  return _buildCommentItem(
                    reply, replyLikes.length, replyLikes.contains(currentUserId), context,
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

Future<void> _deletePost(DocumentSnapshot post) async {
    // 1. Show Confirmation Dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Post', style: TextStyle(color: AppColors.textHigh)),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cancel
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMedium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Confirm
            child: const Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // --- CRITICAL FIX START ---
    // Capture the Navigator and Messenger BEFORE the async gap.
    // If the widget disposes during the delete, 'context' becomes dead, 
    // but these variables will remain valid.
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    // --- CRITICAL FIX END ---

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryLavender),
        ),
      );

      final postData = post.data() as Map<String, dynamic>;
      final String mediaUrl = postData['mediaUrl'] ?? '';

      // 2. Delete the Image/Video from Storage (Cleanup)
      if (mediaUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(mediaUrl).delete();
        } catch (e) {
          debugPrint("Error deleting storage file: $e");
          // Continue deleting the document even if storage fails
        }
      }

      // 3. Delete the Post Document from Firestore
      await FirebaseFirestore.instance.collection('posts').doc(post.id).delete();

      // 4. Close Loading Dialog (Use captured navigator)
      navigator.pop(); 

      // 5. Go back to Feed (Use captured navigator)
      navigator.pop(); 

      // 6. Show Success (Use captured messenger)
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Post deleted successfully'),
          backgroundColor: AppColors.primaryLavender,
        ),
      );
    } catch (e) {
      // Close Loading Dialog if open
      navigator.pop(); 
      
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting post: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showPostOptions(BuildContext context, DocumentSnapshot post, DocumentSnapshot user) { 
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface, // Universal Surface
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            if (post['userId'] == currentUserId)
                _buildOptionItem(
                  icon: Feather.trash,
                  iconColor: AppColors.error,
                  label: 'Delete Post',
                  labelColor: AppColors.error,
                  onTap: () {
                    Navigator.pop(context); // Close the bottom sheet
                    _deletePost(post); // <--- Call the new function here
                  },
                ),
              _buildOptionItem(
                icon: Feather.alert_circle,
                iconColor: AppColors.accentMustard,
                label: 'Report Post',
                labelColor: AppColors.accentMustard,
                onTap: () {
                  Navigator.pop(context);
                  // _reportPost(context, post, user); 
                },
              ),
               _buildOptionItem(
                icon: Feather.share_2,
                iconColor: AppColors.primaryLavender,
                label: 'Share Post',
                onTap: () {
                  Navigator.pop(context);
                  Share.share('Check out this post...');
                },
              ),
              const Divider(height: 24, color: AppColors.textDisabled),
              _buildOptionItem(
                icon: Feather.x,
                iconColor: AppColors.textDisabled,
                label: 'Cancel',
                labelColor: AppColors.textMedium,
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
    Color iconColor = AppColors.textMedium,
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
                color: AppColors.elevation,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: labelColor ?? AppColors.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}