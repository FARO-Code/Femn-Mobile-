import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/profile.dart';
import 'package:femn/search.dart';
import 'package:femn/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:femn/post.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:femn/feed_service.dart';
import 'package:femn/personalized_feed_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

// Feed Screen with pull-to-refresh and infinite scroll
class FeedScreen extends StatefulWidget {
  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // --- INFINITE SCROLL VARIABLES ---
  final ScrollController _scrollController = ScrollController();
  final FeedService _feedService = FeedService();
  final PersonalizedFeedService _personalizedFeed = PersonalizedFeedService();

  List<DocumentSnapshot> _posts = [];
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _selectedFilter = 'For You';

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

  // --- VIDEO SEQUENCE LOGIC ---
  final ValueNotifier<String?> _activeVideoIdNotifier = ValueNotifier(null);
  List<String> _videoIds = [];
  int _currentSequenceIndex = 0;

  // --- FOLLOWING LIST ---
  List<String> _followingIds = [];

  @override
  void initState() {
    super.initState();
    _fetchFollowingList();
    _checkDailyQuote();

    // 1. Initial Load
    _loadInitialPosts();

    // 2. Setup Scroll Listener for Infinite Scroll
    _scrollController.addListener(() {
      if (_scrollController.hasClients && 
          _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMorePosts();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _activeVideoIdNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadInitialPosts() async {
    if (!mounted) return;
    setState(() => _isLoadingInitial = true);
    List<DocumentSnapshot> newPosts;
    
    if (_selectedFilter == 'For You') {
      // Use personalized feed for "For You" tab
      newPosts = await _personalizedFeed.getPersonalizedFeed(limit: 20);
    } else if (_selectedFilter == 'Following') {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', whereIn: _followingIds.isEmpty ? ['empty'] : _followingIds)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      newPosts = snap.docs;
    } else {
      // News tab (coming soon)
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      newPosts = snap.docs;
    }
    
    if (mounted) {
      setState(() {
        _posts = newPosts;
        _isLoadingInitial = false;
        _hasMore = newPosts.isNotEmpty;
      });
      _triggerVideoLogic(newPosts);
    }
  }

  Future<void> _nukeAllPosts() async {
  // 1. CONFIRMATION DIALOG (Safety First)
  bool? confirm = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("NUKE ALL POSTS?", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text("This will permanently delete ALL posts and their media files from the database. This cannot be undone."),
      actions: [
        TextButton(
          child: Text("CANCEL"), 
          onPressed: () => Navigator.pop(context, false)
        ),
        TextButton(
          child: Text("NUKE IT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pop(context, true)
        ),
      ],
    ),
  );

  if (confirm != true) return;

  // 2. SHOW LOADING
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Center(child: CircularProgressIndicator(color: Colors.red)),
  );

  try {
    // 3. GET ALL POSTS
    final snapshot = await FirebaseFirestore.instance.collection('posts').get();
    int count = 0;

    print("Starting Nuke on ${snapshot.docs.length} posts...");

    for (var doc in snapshot.docs) {
      final data = doc.data();

      // 4. DELETE MEDIA FROM STORAGE
      if (data.containsKey('mediaUrl') && data['mediaUrl'] != null && data['mediaUrl'].toString().isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(data['mediaUrl']).delete();
          print("Deleted media for ${doc.id}");
        } catch (e) {
          print("Error deleting media for ${doc.id}: $e"); 
          // Continue anyway to ensure the doc gets deleted
        }
      }
      
      // 5. DELETE THUMBNAIL (If video)
      if (data.containsKey('thumbnailUrl') && data['thumbnailUrl'] != null) {
         try {
          await FirebaseStorage.instance.refFromURL(data['thumbnailUrl']).delete();
        } catch (e) { /* Ignore */ }
      }

      // 6. DELETE FIRESTORE DOC
      await FirebaseFirestore.instance.collection('posts').doc(doc.id).delete();
      count++;
    }

    // 7. CLEANUP
    Navigator.pop(context); // Dismiss loading
    setState(() {
      _posts.clear(); // Clear local list
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Nuked $count posts successfully."), backgroundColor: Colors.red),
    );

  } catch (e) {
    Navigator.pop(context); // Dismiss loading
    print(e);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
    );
  }
}

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore || _posts.isEmpty) return;
    setState(() => _isLoadingMore = true);
    List<DocumentSnapshot> newPosts;
    final lastDoc = _posts.last;
    
    if (_selectedFilter == 'For You') {
      newPosts = await _personalizedFeed.getPersonalizedFeed(
        limit: 10,
        lastDocument: lastDoc,
      );
    } else {
      final snap = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(lastDoc)
          .limit(12)
          .get();
      newPosts = snap.docs;
    }
    
    final existingIds = _posts.map((e) => e.id).toSet();
    final uniqueNewPosts = newPosts.where((doc) => !existingIds.contains(doc.id)).toList();
    
    if (mounted) {
      setState(() {
        _posts.addAll(uniqueNewPosts);
        _isLoadingMore = false;
        if (newPosts.length < 5) _hasMore = false;
      });
      _triggerVideoLogic(_posts);
    }
  }

  Future<void> _onRefresh() async {
    setState(() {
      _posts.clear();
      _hasMore = true;
    });
    await _loadInitialPosts();
  }

  void _triggerVideoLogic(List<DocumentSnapshot> posts) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVideoSequence(posts);
    });
  }

  void _startVideoSequence(List<DocumentSnapshot> posts) {
    _videoIds = posts
        .where((doc) => (doc.data() as Map<String, dynamic>)['mediaType'] == 'video')
        .map((doc) => doc.id)
        .toList();
    if (_videoIds.isEmpty) {
      _activeVideoIdNotifier.value = null;
      return;
    }
    if (_currentSequenceIndex == 0) _playNextInSequence();
  }

  void _playNextInSequence() {
    if (!mounted || _videoIds.isEmpty) return;
    if (_currentSequenceIndex >= _videoIds.length) _currentSequenceIndex = 0;
    _activeVideoIdNotifier.value = _videoIds[_currentSequenceIndex];
  }

  void _handleVideoFinished(String postId) {
    if (_videoIds.contains(postId) && _activeVideoIdNotifier.value == postId) {
      _currentSequenceIndex++;
      _playNextInSequence();
    }
  }

  Future<void> _checkDailyQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastDismissedDate = prefs.getString('last_dismissed_quote_date');
    final DateTime now = DateTime.now();
    final String todayDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    if (lastDismissedDate != todayDate) {
      final int quoteIndex = now.day % _dailyQuotes.length;
      setState(() {
        _todaysQuoteContent = _dailyQuotes[quoteIndex];
        _showQuote = true;
      });
    } else {
      setState(() => _showQuote = false);
    }
  }

  Future<void> _dismissQuote() async {
    final prefs = await SharedPreferences.getInstance();
    final DateTime now = DateTime.now();
    final String todayDate = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    await prefs.setString('last_dismissed_quote_date', todayDate);
    setState(() => _showQuote = false);
  }

  Future<void> _fetchFollowingList() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      if (userDoc.exists) {
        final following = List<String>.from(userDoc['following'] ?? []);
        setState(() => _followingIds = following);
      }
    } catch (e) {
      print('Error fetching following list: $e');
    }
  }

  void _showComingSoonPopup() {
     showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 6,
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Coming Soon', style: TextStyle(color: AppColors.accentMustard, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Text('The News section is currently under development.', style: TextStyle(color: AppColors.textMedium, fontSize: 15), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.elevation, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))]),
                  child: Text('OK', style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, fontSize: 14)),
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

    List<DocumentSnapshot> displayPosts = _posts;
    if (_selectedFilter == 'Following') {
      displayPosts = _posts.where((post) {
        final data = post.data() as Map<String, dynamic>;
        return data.containsKey('userId') && _followingIds.contains(data['userId']);
      }).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: RefreshIndicator(
        color: AppColors.primaryLavender,
        backgroundColor: AppColors.surface,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1. TOP BAR (Logo, Search, Profile)
            SliverAppBar(
              backgroundColor: AppColors.backgroundDeep,
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              automaticallyImplyLeading: false,
              toolbarHeight: 55,
              title: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevation,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipOval(child: Image.asset('assets/femnlogo.png', fit: BoxFit.cover)),
              ),
              actions: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.elevation,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Feather.search, color: AppColors.primaryLavender, size: 22),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SearchScreen())),
                  ),
                  
                ),
                SizedBox(width: 8),
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
                  builder: (context, snapshot) {
                    Widget avatar;
                    if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || !snapshot.data!.exists) {
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
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 2)),
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

            // 2. PILL BUTTONS (Sticky Header)
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                minHeight: 75.0, 
                maxHeight: 75.0,
                child: Container(
                  color: AppColors.backgroundDeep,
                  padding: const EdgeInsets.only(top: 20.0, left: 8.0, right: 8.0, bottom: 5.0),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFilterButton('News', onTap: _showComingSoonPopup),
                      _buildFilterButton('For You', onTap: () {
                        setState(() => _selectedFilter = 'For You');
                        _onRefresh();
                      }),
                      _buildFilterButton('Following', onTap: () {
                        setState(() => _selectedFilter = 'Following');
                        _onRefresh();
                      }),
                    ],
                  ),
                ),
              ),
            ),
            
            SliverToBoxAdapter(child: const SizedBox(height: 8)),

            // 3. DAILY QUOTE
            SliverToBoxAdapter(
              child: (_showQuote && _todaysQuoteContent.isNotEmpty)
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Dismissible(
                        key: const Key('daily_quote_card'),
                        direction: DismissDirection.horizontal,
                        onDismissed: (direction) => _dismissQuote(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryLavender.withOpacity(0.3), width: 1),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TODAY'S INSPIRATION",
                                style: TextStyle(color: AppColors.secondaryTeal, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "\"${_todaysQuoteContent['quote']}\"",
                                style: TextStyle(fontSize: 14.0, color: AppColors.textHigh, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: Text(
                                  "~ ${_todaysQuoteContent['author']}",
                                  style: TextStyle(fontSize: 12.0, color: AppColors.primaryLavender, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SizedBox.shrink(),
            ),


            if (_isLoadingInitial)
              const FeedShimmerSkeleton() 
            else if (displayPosts.isEmpty)
              SliverFillRemaining(
                child: Center(
                    child: Text("No posts found",
                        style: TextStyle(color: AppColors.textMedium))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                sliver: SliverMasonryGrid.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childCount: displayPosts.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == displayPosts.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primaryLavender, strokeWidth: 2)),
                      );
                    }

                    var post = displayPosts[index];
                    return FeedPostWrapper(
                      key: ValueKey(post.id),
                      postDoc: post,
                      activeNotifier: _activeVideoIdNotifier,
                      onVideoFinished: () => _handleVideoFinished(post.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

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
        builder: (context) => ProfileScreen(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  }
}

// PostCardWithStream
class PostCardWithStream extends StatelessWidget {
  final String postId;
  final ValueNotifier<String?>? activeNotifier;
  final VoidCallback? onVideoFinished;
  const PostCardWithStream({
    Key? key,
    required this.postId,
    this.activeNotifier,
    this.onVideoFinished,
  }) : super(key: key);

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
              activeNotifier: activeNotifier,
              onVideoFinished: onVideoFinished,
              thumbnailUrl: postData['thumbnailUrl'],
              linkUrl: postData['linkUrl'], // Extract Link
            );
          },
        );
      },
    );
  }
}

// PostCard - Updated with Link Display
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
  final String? thumbnailUrl;
  final String? linkUrl; // NEW LINK FIELD
  final ValueNotifier<String?>? activeNotifier;
  final VoidCallback? onVideoFinished;
  
  final double? metaWidth;
  final double? metaHeight;

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
    this.thumbnailUrl,
    this.linkUrl,
    this.activeNotifier,
    this.onVideoFinished,
    this.metaWidth,
    this.metaHeight,
  });

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  final GlobalKey<PopupMenuButtonState<String>> _menuKey = GlobalKey(); 
  
  bool isLiked = false;
  bool isSaved = false;
  late AnimationController _heartController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _isHeartVisible = false;
  Timer? _watchTimer;
  int _watchSeconds = 0;

  @override
  void initState() {
    super.initState();
    isLiked = widget.likes.contains(currentUserId);
    _checkIfSaved();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400), 
    );

    _heartScaleAnimation = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _heartController, curve: Curves.elasticOut),
    );
    
    _heartOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _heartController, curve: const Interval(0.0, 0.2)),
    );

    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _heartController.reverse();
        });
      }
      if (status == AnimationStatus.dismissed) {
        if (mounted) setState(() => _isHeartVisible = false);
      }
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    _watchTimer?.cancel();
    super.dispose();
  }

  void _checkIfSaved() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    if (doc.exists && mounted) {
      List saved = doc.data()?['savedPosts'] ?? [];
      setState(() => isSaved = saved.contains(widget.postId));
    }
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.likes.length != oldWidget.likes.length) {
      if (mounted) setState(() => isLiked = widget.likes.contains(currentUserId));
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

  void _startWatchTimer() {
    if (widget.mediaType != 'video') return;
    _watchTimer?.cancel();
    _watchSeconds = 0;
    _watchTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        _watchSeconds++;
        if (_watchSeconds % 5 == 0 && _watchSeconds > 0) {
          _sendAlgorithmSignal('watch_time', weight: _watchSeconds.toDouble());
        }
      }
    });
  }

  void _stopWatchTimer() {
    _watchTimer?.cancel();
    if (_watchSeconds >= 3) {
      _sendAlgorithmSignal('watch_time', weight: _watchSeconds.toDouble());
    }
    _watchSeconds = 0;
  }

  Future<void> _sendAlgorithmSignal(String type, {double weight = 1.0}) async {
    try {
      await PersonalizedFeedService().recordInteraction(
        type: type,
        postId: widget.postId,
        authorId: widget.userId,
        value: weight,
      );
    } catch (e) {}
  }

  Future<void> _handleDoubleTapLike() async {
     
    setState(() => _isHeartVisible = true);
    _heartController.reset();
    _heartController.forward();

    if (!isLiked) {
      setState(() => isLiked = true);
      final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      await ref.update({'likes': FieldValue.arrayUnion([currentUserId])});
      _sendAlgorithmSignal('like', weight: 1.0);
    }
  }

  Future<void> _toggleLike() async {
    
    setState(() => isLiked = !isLiked);
    final ref = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
    if (isLiked) {
      await ref.update({'likes': FieldValue.arrayUnion([currentUserId])});
      _sendAlgorithmSignal('like', weight: 1.0);
    } else {
      await ref.update({'likes': FieldValue.arrayRemove([currentUserId])});
    }
  }

  Future<void> _toggleSave() async {
    
    setState(() => isSaved = !isSaved);
    final ref = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    if (isSaved) {
      await ref.update({'savedPosts': FieldValue.arrayUnion([widget.postId])});
      _sendAlgorithmSignal('save', weight: 2.0);
      _showMinimalSnack("Saved", AppColors.accentMustard);
    } else {
      await ref.update({'savedPosts': FieldValue.arrayRemove([widget.postId])});
    }
  }

  Future<void> _sharePost() async {
    final String deepLink = "https://femn-9cabb.web.app/post/${widget.postId}";
    await Share.share('Check out this post on Femn: $deepLink');
    _sendAlgorithmSignal('share', weight: 2.5);
  }

  Future<void> _downloadMedia() async {
    
    _showMinimalSnack("Downloading...", AppColors.primaryLavender);
    await Future.delayed(Duration(seconds: 1));
    _sendAlgorithmSignal('download', weight: 3.0);
    _showMinimalSnack("Saved to Gallery", Colors.green);
  }

  Future<void> _reportPost() async {
    await FirebaseFirestore.instance.collection('reports').add({
      'postId': widget.postId,
      'reporterId': currentUserId,
      'reason': 'User reported via feed menu',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending'
    });
    _sendAlgorithmSignal('report', weight: -5.0);
    _showMinimalSnack("Report submitted.", AppColors.error);
  }

  void _showMinimalSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: EdgeInsets.all(12),
      duration: Duration(seconds: 1),
    ));
  }
  
  void _showMoreLikeThis() async {
    final similarPosts = await PersonalizedFeedService().getSimilarPosts(widget.postId);
    if (similarPosts.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => _MoreLikeThisDialog(
          posts: similarPosts,
          position: Offset(0, 0), 
        ),
      );
    } else {
      _showMinimalSnack("Showing more like this soon!", AppColors.secondaryTeal);
    }
  }

  void _showLessLikeThis() {
    _sendAlgorithmSignal('see_less', weight: -2.0);
    _showMinimalSnack("Showing less like this.", AppColors.textDisabled);
    if (widget.activeNotifier != null && widget.mediaType == 'video') {
      widget.onVideoFinished?.call();
    }
  }

  void _handleMenuAction(String value) {
    switch (value) {
      case 'Download': _downloadMedia(); break;
      case 'SeeMore': _sendAlgorithmSignal('see_more', weight: 1.5); _showMoreLikeThis(); break;
      case 'SeeLess': _showLessLikeThis(); break;
      case 'Report': _reportPost(); break;
    }
  }

  // Helper for opening link
  Future<void> _launchURL() async {
    if (widget.linkUrl != null && widget.linkUrl!.isNotEmpty) {
      final Uri uri = Uri.parse(widget.linkUrl!);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showMinimalSnack("Could not open link", AppColors.error);
      } else {
        _sendAlgorithmSignal('click_link', weight: 2.0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double? aspectRatio;
    if (widget.metaWidth != null && widget.metaHeight != null && widget.metaHeight! > 0) {
      aspectRatio = widget.metaWidth! / widget.metaHeight!;
    }

    Widget mediaWidget;
    if (widget.mediaType == 'video') {
      double videoRatio = aspectRatio ?? (9 / 16); 
      mediaWidget = AspectRatio(
        aspectRatio: videoRatio,
        child: FemnVideoPlayer(
          videoUrl: widget.mediaUrl,
          thumbnailUrl: widget.thumbnailUrl,
          isPreview: true,
          postId: widget.postId,
          activeNotifier: widget.activeNotifier,
          onVideoFinished: widget.onVideoFinished,
        ),
      );
    } else {
       Widget image = CachedNetworkImage(
        imageUrl: widget.mediaUrl,
        width: double.infinity, 
        fit: BoxFit.cover,
        memCacheWidth: 600,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: AppColors.elevation,
          highlightColor: AppColors.surface,
          child: Container(
            height: 200, 
            color: AppColors.elevation,
          ),
        ),
        errorWidget: (context, url, error) => Container(
            height: 200,
            color: AppColors.elevation,
            child: const Icon(Icons.error, color: AppColors.error)),
      );
      mediaWidget = aspectRatio != null ? AspectRatio(aspectRatio: aspectRatio, child: image) : image; 
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- MEDIA (Gestures) ---
        GestureDetector(
          onDoubleTap: _handleDoubleTapLike,
          onTap: _viewPostDetail,
          onLongPress: () {
            
            _menuKey.currentState?.showButtonMenu();
          },
          onLongPressStart: (_) => _startWatchTimer(),
          onLongPressEnd: (_) => _stopWatchTimer(),
          onLongPressCancel: _stopWatchTimer,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    mediaWidget,
                    if (_isHeartVisible)
                      Positioned.fill(
                        child: Center(
                          child: ScaleTransition(
                            scale: _heartScaleAnimation,
                            child: FadeTransition(
                              opacity: _heartOpacityAnimation,
                              child: const Icon(Icons.favorite, size: 100, color: Colors.red, shadows: [Shadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 4))]),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // --- BOTTOM ROW ---
        Padding(
          padding: const EdgeInsets.fromLTRB(4.0, 10.0, 0.0, 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.profileImage.isNotEmpty)
                CircleAvatar(
                  radius: 12,
                  backgroundImage: CachedNetworkImageProvider(widget.profileImage),
                  backgroundColor: AppColors.elevation,
                ),
              const SizedBox(width: 8),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.username,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textHigh),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    // --- DISPLAY LINK IF PRESENT ---
                    if (widget.linkUrl != null && widget.linkUrl!.isNotEmpty)
                      GestureDetector(
                        onTap: _launchURL,
                        child: Container(
                          margin: EdgeInsets.only(top: 4, bottom: 2),
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryTeal.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.secondaryTeal.withOpacity(0.5))
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Feather.link, size: 12, color: AppColors.secondaryTeal),
                              SizedBox(width: 6),
                              Text(
                                "Visit Website", 
                                style: TextStyle(color: AppColors.secondaryTeal, fontSize: 11, fontWeight: FontWeight.bold)
                              ),
                              Icon(Feather.chevron_right, size: 12, color: AppColors.secondaryTeal),
                            ],
                          ),
                        ),
                      ),

                    if (widget.caption.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          widget.caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMedium, height: 1.3),
                        ),
                      ),
                  ],
                ),
              ),

              // --- MINIMAL MENU ---
              SizedBox(
                width: 24, 
                height: 24,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<String>(
                    key: _menuKey,
                    onSelected: _handleMenuAction,
                    padding: EdgeInsets.zero,
                    tooltip: '',
                    icon: Icon(Feather.more_horizontal, size: 18, color: AppColors.textDisabled),
                    color: AppColors.surface, 
                    elevation: 4, 
                    shadowColor: Colors.black.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.textDisabled.withOpacity(0.1), width: 1),
                    ),
                    offset: const Offset(0, 5), 
                    
                    itemBuilder: (BuildContext context) {
                      return [
                        // ICONS ROW (Like, Save, Share)
                        PopupMenuItem<String>(
                          enabled: false, 
                          height: 40,
                          padding: EdgeInsets.zero,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                InkWell(
                                  onTap: () { _toggleLike(); Navigator.pop(context); },
                                  child: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 26, color: isLiked ? AppColors.error : AppColors.textHigh),
                                ),
                                InkWell(
                                  onTap: () { _toggleSave(); Navigator.pop(context); },
                                  child: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 26, color: isSaved ? AppColors.accentMustard : AppColors.textHigh),
                                ),
                                InkWell(
                                  onTap: () { _sharePost(); Navigator.pop(context); },
                                  child: Icon(Feather.share_2, size: 26, color: AppColors.textHigh),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        PopupMenuItem(height: 1, enabled: false, child: Divider(height: 1, color: AppColors.textDisabled.withOpacity(0.1))),
                        _buildMinimalItem('Download', Feather.download, 'Download'),
                        _buildMinimalItem('SeeMore', Feather.eye, 'See more'),
                        _buildMinimalItem('SeeLess', Feather.eye_off, 'See less'),
                        PopupMenuItem(height: 1, enabled: false, child: Divider(height: 1, color: AppColors.textDisabled.withOpacity(0.1))),
                        _buildMinimalItem('Report', Feather.alert_circle, 'Report', activeColor: AppColors.error),
                      ];
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMinimalItem(String value, IconData icon, String text, {Color? activeColor}) {
    final color = (activeColor != null && value == 'Report') ? activeColor : AppColors.textHigh;
    return PopupMenuItem<String>(
      value: value,
      height: 36, 
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color), 
          SizedBox(width: 12),
          Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// More Like This Dialog
class _MoreLikeThisDialog extends StatelessWidget {
  final List<DocumentSnapshot> posts;
  final Offset position;
  
  const _MoreLikeThisDialog({required this.posts, required this.position});
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Semi-transparent background
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.black54),
          ),
        ),
        
        // Content near the tapped position
        Positioned(
          top: position.dy,
          left: position.dx,
          child: Container(
            width: 300,
            height: 400,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    'More Like This',
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: posts.length < 5 ? posts.length : 5,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      final data = post.data() as Map<String, dynamic>;
                      
                      return ListTile(
                        leading: data['mediaType'] == 'image'
                          ? Image.network(data['mediaUrl'], width: 40, height: 40, fit: BoxFit.cover)
                          : data['thumbnailUrl'] != null
                            ? Image.network(data['thumbnailUrl'], width: 40, height: 40, fit: BoxFit.cover)
                            : Container(width: 40, height: 40, color: AppColors.elevation),
                        title: Text(
                          data['caption']?.toString().split('\n').first ?? 'Post',
                          style: TextStyle(color: AppColors.textHigh, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${(data['likes'] as List).length} likes',
                          style: TextStyle(color: AppColors.textMedium, fontSize: 10),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PostDetailScreen(
                                postId: post.id,
                                userId: data['userId'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Post Detail Screen - Updated Styling with Universal Colors
class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? userId;
  const PostDetailScreen({required this.postId, this.userId});

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

  // Send algorithm signal for detail screen actions
  Future<void> _sendAlgorithmSignal(String type, {double weight = 1.0}) async {
    try {
      await PersonalizedFeedService().recordInteraction(
        type: type,
        postId: widget.postId,
        authorId: widget.userId,
        value: weight,
      );
    } catch (e) {
      // silent fail
    }
  }

  // Share post from detail screen
  Future<void> _sharePost() async {
    final String deepLink = "https://femn-9cabb.web.app/post/${widget.postId}";
    
    await Share.share('Check out this post on Femn: $deepLink');
    
    _sendAlgorithmSignal('share', weight: 2.5);
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
      _sendAlgorithmSignal('save', weight: _isSaved ? 2.0 : 0);
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
      
      // Send signal for comment
      _sendAlgorithmSignal('comment', weight: 2.5);
      
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
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId!)));
                            } else {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.userId!)));
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
                                          child: const Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          height: 300,
                                          color: AppColors.elevation,
                                          child: const Icon(Icons.error, color: AppColors.error),
                                        ),
                                      )
                                    : FemnVideoPlayer(
                                        videoUrl: postData['mediaUrl'],
                                        thumbnailUrl: postData['thumbnailUrl'], // Uses thumbnail from Firestore if available
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
                                      if (!isLiked) {
                                        await postRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
                                        _sendAlgorithmSignal('like', weight: 1.0);
                                      } else {
                                        await postRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
                                      }
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
                                    onPressed: _sharePost,
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
                  Navigator.pop(context); // Close the menu first
                  _sharePost(); // <--- CHANGED THIS (was inline Share.share)
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
            SizedBox(width: 16),
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

// ======== UNIFIED VIDEO PLAYER COMPONENT ========
class FemnVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool isFullScreen;
  // --- Preview Props ---
  final bool isPreview; // true for Feed, false for Detail
  final String? postId;
  final ValueNotifier<String?>? activeNotifier;
  final VoidCallback? onVideoFinished;
  const FemnVideoPlayer({
    required this.videoUrl,
    this.thumbnailUrl,
    this.isFullScreen = false,
    this.isPreview = false,
    this.postId,
    this.activeNotifier,
    this.onVideoFinished,
  });

  @override
  _FemnVideoPlayerState createState() => _FemnVideoPlayerState();
}

class _FemnVideoPlayerState extends State<FemnVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  Timer? _previewTimer;
  bool _isFastForwarding = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPreview) {
      widget.activeNotifier?.addListener(_checkPreviewStatus);
    } else {
      _initializeFullVideo();
    }
  }

  // --- PREVIEW LOGIC (Feed) ---
  void _checkPreviewStatus() {
    final isActive = widget.activeNotifier?.value == widget.postId;
    if (isActive) {
      _initializePreviewVideo();
    } else {
      _disposeController();
    }
  }

  Future<void> _initializePreviewVideo() async {
    if (_controller.value.isInitialized) return;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      _controller.setVolume(0.0); // Muted for feed
      if (widget.activeNotifier?.value == widget.postId) {
        if (mounted) setState(() => _isInitialized = true);
        await _controller.play();
        // Start 5s Timer
        _previewTimer?.cancel();
        _previewTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _disposeController();
            widget.onVideoFinished?.call();
          }
        });
      } else {
        _disposeController();
      }
    } catch (e) {
      _disposeController();
      widget.onVideoFinished?.call();
    }
  }

  // --- FULL PLAYER LOGIC (Detail) ---
  Future<void> _initializeFullVideo() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    try {
      await _controller.initialize();
      if (mounted) setState(() => _isInitialized = true);
      _controller.play();
      _controller.setLooping(true);
      _startHideTimer();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint("Video Error: $e");
    }
  }

  @override
  void dispose() {
    widget.activeNotifier?.removeListener(_checkPreviewStatus);
    _hideTimer?.cancel();
    _previewTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _disposeController() {
    _previewTimer?.cancel();
    if (_isInitialized) {
      _controller.dispose();
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl)); // Reset
      if (mounted) setState(() => _isInitialized = false);
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) _startHideTimer();
    });
  }

  void _togglePlay() {
    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
      _showControls = true;
      _startHideTimer();
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  void _enterFullScreen(BuildContext context) {
    _controller.pause();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Scaffold(backgroundColor: Colors.black, body: Center(child: FemnVideoPlayer(videoUrl: widget.videoUrl, thumbnailUrl: widget.thumbnailUrl, isFullScreen: true)))),
    ).then((_) => _controller.play());
  }

  @override
  Widget build(BuildContext context) {
    // 1. FEED PREVIEW MODE
    if (widget.isPreview) {
      return Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          // Thumbnail (Always visible until video covers it)
          if (widget.thumbnailUrl != null)
            Image(image: CachedNetworkImageProvider(widget.thumbnailUrl!), fit: BoxFit.cover)
          else
            Container(color: Colors.black),
          // Video
          if (_isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          // Tiny Play Icon (Bottom Left Indicator)
          const Positioned(
            bottom: 10,
            left: 10,
            child: Icon(
              Icons.play_arrow, // Simple play icon
              color: Colors.white,
              size: 24,
              shadows: [Shadow(blurRadius: 4, color: Colors.black54, offset: Offset(0, 1))],
            ),
          ),
          // REMOVED: Loading Spinner is gone as requested
        ],
      );
    }
    // 2. FULL PLAYER (Detail Mode)
    return LayoutBuilder(
      builder: (context, constraints) {
        Widget playerStack = Stack(
          fit: StackFit.expand,
          children: [
            if (widget.thumbnailUrl != null)
              Image(image: CachedNetworkImageProvider(widget.thumbnailUrl!), fit: BoxFit.cover)
            else
              Container(color: Colors.black),
            if (_isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            if (_isInitialized)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Container(
                    color: Colors.black26,
                    child: Column(
                      children: [
                        const Spacer(),
                        IconButton(iconSize: 60, icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_outline : Icons.play_circle_outline, color: Colors.white), onPressed: _togglePlay),
                        const Spacer(),
                        _buildBottomBar(context),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_isInitialized)
              const Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
          ],
        );
        Widget gestureWrapper = GestureDetector(
          onDoubleTap: _togglePlay,
          onTap: _toggleControls,
          onLongPress: () {
            setState(() => _isFastForwarding = true);
            _controller.setPlaybackSpeed(2.0);
          },
          onLongPressUp: () {
            setState(() => _isFastForwarding = false);
            _controller.setPlaybackSpeed(1.0);
          },
          child: playerStack,
        );
        if (constraints.maxHeight == double.infinity) {
          return AspectRatio(aspectRatio: 9 / 16, child: gestureWrapper);
        }
        return gestureWrapper;
      },
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent])),
      child: Row(
        children: [
          Text(_formatDuration(_controller.value.position), style: const TextStyle(color: Colors.white, fontSize: 12)),
          Expanded(child: Slider(value: _controller.value.position.inSeconds.toDouble(), max: _controller.value.duration.inSeconds.toDouble(), onChanged: (val) { _controller.seekTo(Duration(seconds: val.toInt())); _startHideTimer(); })),
          Text(_formatDuration(_controller.value.duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
          if (!widget.isFullScreen) IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20), onPressed: () => _enterFullScreen(context)),
        ],
      ),
    );
  }
}

class FeedPostWrapper extends StatefulWidget {
  final DocumentSnapshot postDoc;
  final ValueNotifier<String?>? activeNotifier;
  final VoidCallback? onVideoFinished;
  const FeedPostWrapper({
    Key? key,
    required this.postDoc,
    this.activeNotifier,
    this.onVideoFinished,
  }) : super(key: key);

  @override
  _FeedPostWrapperState createState() => _FeedPostWrapperState();
}

class _FeedPostWrapperState extends State<FeedPostWrapper> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _userData;
  
  @override
  bool get wantKeepAlive => true; 

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  void _fetchUser() async {
    try {
      final postData = widget.postDoc.data() as Map<String, dynamic>;
      final userId = postData['userId'];
      if (userId == null) return;
      final userSnap = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userSnap.exists && mounted) {
        setState(() {
          _userData = userSnap.data() as Map<String, dynamic>;
        });
      }
    } catch (e) {}
  }

@override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (_userData == null) {
      return Shimmer.fromColors(
        baseColor: AppColors.elevation,
        highlightColor: AppColors.surface,
        child: Container(
          height: 200, 
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.elevation, 
            borderRadius: BorderRadius.circular(20)
          ),
        ),
      );
    }

    final postData = widget.postDoc.data() as Map<String, dynamic>;

    double? metaW;
    double? metaH;
    if (postData['width'] != null) metaW = (postData['width'] as num).toDouble();
    if (postData['height'] != null) metaH = (postData['height'] as num).toDouble();

    return PostCard(
      postId: widget.postDoc.id,
      userId: postData['userId'],
      username: _userData!['username'] ?? 'Unknown',
      profileImage: _userData!['profileImage'] ?? '',
      mediaUrl: postData['mediaUrl'] ?? '',
      caption: postData['caption'] ?? '',
      likes: List<String>.from(postData['likes'] ?? []),
      timestamp: postData['timestamp']?.toDate() ?? DateTime.now(),
      mediaType: postData['mediaType'] ?? 'image',
      thumbnailUrl: postData['thumbnailUrl'],
      linkUrl: postData['linkUrl'], // Pass Link
      activeNotifier: widget.activeNotifier,
      onVideoFinished: widget.onVideoFinished,
      metaWidth: metaW,
      metaHeight: metaH,
    );
  }
}

// Place this outside any class, or in a utils file
double snapToAllowedRatio(double rawRatio) {
  // The allowed ratios you specified
  const List<double> allowedRatios = [
    1.0,         // 1:1
    2.0,         // 2:1
    0.5,         // 1:2
    3.0,         // 3:1
    4.0 / 3.0,   // 4:3
    3.0 / 2.0,   // 3:2
    2.0 / 3.0,   // 2:3
    16.0 / 9.0,  // 16:9
    9.0 / 16.0,  // 9:16
  ];

  // Find the closest allowed ratio to the input
  return allowedRatios.reduce((a, b) {
    return (rawRatio - a).abs() < (rawRatio - b).abs() ? a : b;
  });
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minHeight;
  final double maxHeight;

  _StickyTabBarDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        child != oldDelegate.child;
  }
}

class FeedShimmerSkeleton extends StatelessWidget {
  const FeedShimmerSkeleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Generate some random heights to mimic your staggered grid
    final List<double> randomHeights = [200, 280, 180, 240, 300, 190, 250, 220];

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childCount: 8, // Show 8 skeleton items
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: AppColors.elevation,
            highlightColor: AppColors.surface, // Lighter shade for the wave effect
            child: Container(
              height: randomHeights[index % randomHeights.length],
              decoration: BoxDecoration(
                color: AppColors.elevation,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fake Image Area
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  // Fake Text Lines
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 10, width: 80, color: Colors.white),
                        SizedBox(height: 6),
                        Container(height: 8, width: double.infinity, color: Colors.white),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}