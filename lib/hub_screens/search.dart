import 'package:femn/circle/petitions.dart';
import 'dart:async';
import 'post.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/hub_screens/profile.dart';
import 'package:femn/customization/colors.dart'; // <--- IMPORT COLORS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/layout.dart';
import 'package:url_launcher/url_launcher.dart';

// Enhanced Search Screen with multiple search types and smart features
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<dynamic> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  List<String> _trendingHashtags = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  
  bool _isSearching = false;
  SearchCategory _selectedCategory = SearchCategory.all;
  
  // Personalization data
  Set<String> _userInterests = {};
  Set<String> _followingIds = {};
  
  // Debouncing for search
  Timer? _debounceTimer;
  StreamSubscription<DocumentSnapshot>? _followingSubscription;

  @override
  void initState() {
    super.initState();
    _setupFollowingStream();
    _loadTrendingData();
    _loadRecentSearches();
    _loadSuggestedUsers();
  }

  void _setupFollowingStream() {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    _followingSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _followingIds = Set<String>.from((data['following'] as List?) ?? []);
          _userInterests = Set<String>.from((data['interests'] as List?) ?? []);
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _followingSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Removed manual load in favor of setupFollowingStream
  Future<void> _loadPersonalizationData() async {}

  // Load trending hashtags and content
  Future<void> _loadTrendingData() async {
    try {
      final hashtagsSnapshot = await FirebaseFirestore.instance
          .collection('trending')
          .doc('hashtags')
          .get();
          
      if (hashtagsSnapshot.exists) {
        setState(() {
          _trendingHashtags = List<String>.from(hashtagsSnapshot['trending'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading trending data: $e');
    }
  }

  // Load suggested users based on network and interests
  Future<void> _loadSuggestedUsers() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isNotEqualTo: currentUserId)
          .limit(10)
          .get();
          
      // Simple suggestion algorithm
      final suggested = usersSnapshot.docs
          .map((doc) => doc.data())
          .where((user) => _userInterests.any((interest) => 
              user['bio']?.toLowerCase().contains(interest.toLowerCase()) == true ||
              user['username'].toLowerCase().contains(interest.toLowerCase())))
          .toList();
          
      setState(() {
        _suggestedUsers = suggested;
      });
    } catch (e) {
      print('Error loading suggested users: $e');
    }
  }

  // Load recent searches from local storage or Firestore
  Future<void> _loadRecentSearches() async {
    // Simplified version
    setState(() {
      _recentSearches = []; 
    });
  }

  // Save search to recent searches
  void _saveToRecentSearches(String query, String type) {
    final searchItem = {
      'query': query,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    setState(() {
      _recentSearches.removeWhere((item) => item['query'] == query);
      _recentSearches.insert(0, searchItem);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    });
    
    // Save to Firestore for cross-device sync
    _saveRecentSearchToFirestore(searchItem);
  }

  // Fetch thumbnails for hashtags to show in discovery
  Future<List<Map<String, dynamic>>> _fetchThumbnailsForHashtag(String tag) async {
    try {
      final cleanTag = tag.replaceFirst('#', '').toLowerCase();
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('hashtags', arrayContains: cleanTag)
          .limit(5)
          .get();
      
      return postsSnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      return [];
    }
  }

  // Fetch thumbnails for suggested users
  Future<List<Map<String, dynamic>>> _fetchThumbnailsForUser(String userId) async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(3)
          .get();
      
      return postsSnapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveRecentSearchToFirestore(Map<String, dynamic> searchItem) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('recentSearches')
          .add(searchItem);
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  // Smart search with debouncing and multiple data sources
  void _performSearch(String query) async {
    final trimmedQuery = query.trim();
    
    // Contextual Suffixes: Auto-switch category if query starts with #
    if (trimmedQuery.startsWith('#') && _selectedCategory != SearchCategory.hashtags) {
      setState(() {
        _selectedCategory = SearchCategory.hashtags;
      });
    } else if (trimmedQuery.startsWith('@') && _selectedCategory != SearchCategory.users) {
      setState(() {
        _selectedCategory = SearchCategory.users;
      });
    }

    if (trimmedQuery.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Set up new debounce timer - made snappier (200ms)
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      if (trimmedQuery.isEmpty) return;

      if (mounted) {
        setState(() {
          _isSearching = true;
        });
      }

      try {
        final results = await _searchAcrossAllCategories(trimmedQuery);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }

        // Save to recent searches
        _saveToRecentSearches(trimmedQuery, 'search');
      } catch (e) {
        print('Search error: $e');
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }





  // Search across all categories with relevance scoring
  Future<List<dynamic>> _searchAcrossAllCategories(String query) async {
    try {
      final results = <Map<String, dynamic>>[];
      
      // Search users
      final users = await _searchUsers(query);
      results.addAll(users);

      // Search posts by caption and hashtags
      final posts = await _searchPosts(query);
      results.addAll(posts);

      // Search hashtags
      final hashtags = await _searchHashtags(query);
      results.addAll(hashtags);
      
      // Search petitions
      final petitions = await _searchPetitions(query);
      results.addAll(petitions);

      // Sort by relevance score
      results.sort((a, b) => (b['relevanceScore'] ?? 0).compareTo(a['relevanceScore'] ?? 0));
      
      return results;
      
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }

  // Enhanced user search with local filtering
  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(200) // Added safety limit
          .get();

      return usersSnapshot.docs
          .where((doc) {
            final user = doc.data();
            final username = user['username']?.toString().toLowerCase() ?? '';
            final fullName = user['fullName']?.toString().toLowerCase() ?? '';
            final queryLower = query.toLowerCase().replaceFirst('@', '');
            
            return username.contains(queryLower) || 
                   fullName.contains(queryLower);
          })
          .map((doc) {
            final user = doc.data();
            double relevanceScore = _calculateUserRelevanceScore(user, query);
            
            return {
              'type': 'user',
              'data': user,
              'relevanceScore': relevanceScore,
              'id': doc.id,
            };
          })
          .toList();
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Enhanced post search with local filtering
  Future<List<Map<String, dynamic>>> _searchPosts(String query) async {
    try {
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .limit(200) // Added safety limit
          .get();

      return postsSnapshot.docs
          .where((doc) {
            final post = doc.data();
            final caption = post['caption']?.toString().toLowerCase() ?? '';
            final hashtags = List<String>.from(post['hashtags'] ?? []);
            final queryLower = query.toLowerCase();
            
            // Search in caption
            if (caption.contains(queryLower)) return true;
            
            // Search in hashtags
            if (hashtags.any((tag) => tag.toLowerCase().contains(queryLower.replaceFirst('#', '')))) {
              return true;
            }

            // Search in smartTags (AI Generated)
            final smartTags = List<String>.from(post['smartTags'] ?? []);
            if (smartTags.any((tag) => tag.toLowerCase().contains(queryLower))) {
              return true;
            }
            
            return false;
          })
          .map((doc) {
            final post = doc.data();
            double relevanceScore = _calculatePostRelevanceScore(post, query);
            
            return {
              'type': 'post',
              'data': post,
              'relevanceScore': relevanceScore,
              'id': doc.id,
            };
          })
          .toList();
    } catch (e) {
      print('Error searching posts: $e');
      return [];
    }
  }

  // Enhanced hashtag search
  Future<List<Map<String, dynamic>>> _searchHashtags(String query) async {
    try {
      final cleanQuery = query.replaceFirst('#', '').toLowerCase();
      
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();

      // Find all unique hashtags across posts
      final allHashtags = <String, int>{};
      
      for (final doc in postsSnapshot.docs) {
        final post = doc.data();
        final hashtags = List<String>.from(post['hashtags'] ?? []);
        
        for (final tag in hashtags) {
          final cleanTag = tag.toLowerCase();
          if (cleanTag.contains(cleanQuery)) {
            allHashtags[tag] = (allHashtags[tag] ?? 0) + 1;
          }
        }
      }

      return allHashtags.entries.map((entry) {
        return {
          'type': 'hashtag',
          'data': {
            'tag': '#${entry.key}',
            'popularity': entry.value,
          },
          'relevanceScore': entry.value.toDouble(),
          'id': entry.key,
        };
      }).toList();
    } catch (e) {
      print('Error searching hashtags: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _searchPetitions(String query) async {
    try {
      final petitionsSnapshot = await FirebaseFirestore.instance
          .collection('petitions')
          .get();

      return petitionsSnapshot.docs
          .where((doc) {
            final petition = doc.data();
            final title = petition['title']?.toString().toLowerCase() ?? '';
            final description = petition['description']?.toString().toLowerCase() ?? '';
            final queryLower = query.toLowerCase();
            
            return title.contains(queryLower) || description.contains(queryLower);
          })
          .map((doc) {
            final petition = doc.data();
            petition['id'] = doc.id; // Ensure ID is in the data map
            double relevanceScore = _calculatePetitionRelevanceScore(petition, query);
            
            return {
              'type': 'petition',
              'data': petition,
              'relevanceScore': relevanceScore,
              'id': doc.id,
            };
          })
          .toList();
    } catch (e) {
      print('Error searching petitions: $e');
      return [];
    }
  }

  // Relevance scoring algorithms
  double _calculatePetitionRelevanceScore(Map<String, dynamic> petition, String query) {
    double score = 0.0;
    final title = petition['title']?.toString().toLowerCase() ?? '';
    final queryLower = query.toLowerCase();

    if (title == queryLower) score += 100;
    else if (title.startsWith(queryLower)) score += 60;
    else if (title.contains(queryLower)) score += 30;

    final goal = petition['goal'] ?? 0;
    final signatures = petition['currentSignatures'] ?? 0;
    if (goal > 0) {
      score += (signatures / goal) * 50;
    }
    
    return score;
  }

  double _calculateUserRelevanceScore(Map<String, dynamic> user, String query) {
    double score = 0.0;
    final username = user['username']?.toString().toLowerCase() ?? '';
    final fullName = user['fullName']?.toString().toLowerCase() ?? '';
    final queryLower = query.toLowerCase();

    if (username == queryLower) score += 100;
    else if (username.startsWith(queryLower)) score += 50;
    else if (username.contains(queryLower)) score += 25;

    if (fullName.contains(queryLower)) score += 20;
    if (user['isVerified'] == true) score += 30;
    
    // HEAVY WEIGHT for followed users (Discover-first but following-prioritized)
    if (_followingIds.contains(user['uid'])) score += 150; 

    final mutualCount = _calculateMutualConnections(user);
    score += mutualCount * 5;

    return score;
  }

  double _calculatePostRelevanceScore(Map<String, dynamic> post, String query) {
    double score = 0.0;
    final caption = post['caption']?.toString().toLowerCase() ?? '';
    final queryLower = query.toLowerCase();

    if (caption == queryLower) score += 160;
    else if (caption.startsWith(queryLower)) score += 100;
    else if (caption.contains(queryLower)) score += 60;

    final hashtags = List<String>.from(post['hashtags'] ?? []);
    if (hashtags.any((tag) => tag.toLowerCase().contains(queryLower.replaceFirst('#', '')))) {
      score += 80;
    }

    final smartTags = List<String>.from(post['smartTags'] ?? []);
    if (smartTags.any((tag) => tag.toLowerCase().contains(queryLower))) {
      score += 70;
    }

    final likes = List<String>.from(post['likes'] ?? []).length;
    final comments = post['comments'] ?? 0;
    score += (likes * 0.1) + (comments * 0.2);

    final timestamp = post['timestamp']?.toDate() ?? DateTime.now();
    final ageInHours = DateTime.now().difference(timestamp).inHours;
    if (ageInHours < 24) score += 20;
    if (ageInHours < 1) score += 30;

    return score;
  }

  int _calculateMutualConnections(Map<String, dynamic> user) {
    final userFollowing = Set<String>.from(user['following'] ?? []);
    return userFollowing.intersection(_followingIds).length;
  }

  // Filter results by category
  List<dynamic> _getFilteredResults() {
    if (_selectedCategory == SearchCategory.all) {
      return _searchResults;
    }
    
    return _searchResults.where((item) {
      switch (_selectedCategory) {
        case SearchCategory.users:
          return item['type'] == 'user';
        case SearchCategory.posts:
          return item['type'] == 'post';
        case SearchCategory.hashtags:
          return item['type'] == 'hashtag';
        case SearchCategory.petitions:
          return item['type'] == 'petition';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Deep background
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Search Bar
            _buildSearchBar(),
            
            // Search Categories
            _buildCategoryFilter(),
            
            // Search Results or Default State
            Expanded(
              child: _buildSearchContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.elevation, // Dark container
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Feather.search, color: AppColors.primaryLavender),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search users, posts, hashtags...',
                  hintStyle: TextStyle(color: AppColors.textDisabled),
                  border: InputBorder.none,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Feather.x, color: AppColors.primaryLavender),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                ),
                onChanged: _performSearch,
                onTap: () {},
                style: const TextStyle(color: AppColors.textHigh), // Off-white text
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 45,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: SearchCategory.values.where((c) => c != SearchCategory.hashtags && c != SearchCategory.petitions).length,
          itemBuilder: (context, index) {
            final category = SearchCategory.values.where((c) => c != SearchCategory.hashtags && c != SearchCategory.petitions).elementAt(index);
            final isSelected = _selectedCategory == category;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                decoration: BoxDecoration(
                  // Teal for active, Elevation for inactive
                  color: isSelected ? AppColors.secondaryTeal : AppColors.elevation,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSelected ? 0.3 : 0.1),
                      blurRadius: isSelected ? 6 : 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    category.name.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textMedium,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isSearching) {
      return const GridShimmerSkeleton();
    }

    if (_searchController.text.trim().isNotEmpty) {
      final filteredResults = _getFilteredResults();
      if (filteredResults.isEmpty) {
        return _buildNoResults();
      }
      
      return _buildSearchResults(filteredResults);
    }

    // Default state - show trending and suggestions
    return _buildDefaultContent();
  }



  Widget _buildMagazineLayout(List<dynamic> results) {
    if (results.isEmpty) return _buildNoResults();

    final users = results.where((item) => item['type'] == 'user').toList();
    final petitions = results.where((item) => item['type'] == 'petition').toList();
    final posts = results.where((item) => item['type'] == 'post').toList();
    final hashtags = results.where((item) => item['type'] == 'hashtag').toList();

    // Determine the absolute top result and its type
    final topResult = results.first;
    final topType = topResult['type'];

    // Define sections with their top scores to determine priority
    final sectionScores = {
      'users': users.isNotEmpty ? (users.first['relevanceScore'] ?? 0.0) : -1.0,
      'petitions': petitions.isNotEmpty ? (petitions.first['relevanceScore'] ?? 0.0) : -1.0,
      'posts': posts.isNotEmpty ? (posts.first['relevanceScore'] ?? 0.0) : -1.0,
    };

    // Sort categories by their top score
    final sortedSections = sectionScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        // 1. Mandatory Top Result Card (Only for Users/Petitions as they look best as cards)
        if (topType == 'user' || topType == 'petition') ...[
          _buildSectionHeader('Top Result'),
          topType == 'user' 
            ? _buildUserResult(topResult['data']) 
            : _buildPetitionResult(topResult['data']),
          SizedBox(height: 24),
        ],

        // 2. Dynamic Sections based on relevance
        ...sortedSections.take(3).map((entry) {
          final type = entry.key;
          if (entry.value < 0) return const SizedBox.shrink();

          // Skip if already shown as Top Result (unless there are more items)
          if (type == 'users') {
            final displayUsers = topType == 'user' ? users.skip(1).toList() : users;
            if (displayUsers.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('People'),
                ...displayUsers.take(5).map((u) => _buildUserResult(u['data'])),
                if (displayUsers.length > 5) _buildViewMoreButton(SearchCategory.users),
                SizedBox(height: 24),
              ],
            );
          }

          if (type == 'petitions') {
            final displayPetitions = topType == 'petition' ? petitions.skip(1).toList() : petitions;
            if (displayPetitions.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Petitions'),
                ...displayPetitions.take(3).map((p) => _buildPetitionResult(p['data'])),
                if (displayPetitions.length > 3) _buildViewMoreButton(SearchCategory.petitions),
                SizedBox(height: 24),
              ],
            );
          }

          if (type == 'posts') {
            // Posts are always displayed in grid, no special skip needed as they aren't "Top Result" cards
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(topType == 'post' ? 'Top Results' : 'Post Gallery'),
                _buildPostGrid(posts.take(20).toList()),
                if (posts.length > 20) _buildViewMoreButton(SearchCategory.posts),
                SizedBox(height: 24),
              ],
            );
          }

          return const SizedBox.shrink();
        }).toList(),
        
        // 5. Hashtags (Usually utility, so keep towards end)
        if (hashtags.isNotEmpty) ...[
          _buildSectionHeader('Explore Hashtags'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: hashtags.take(15).map((h) => _buildTrendingTag(h['data']['tag'])).toList(),
          ),
          SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildViewMoreButton(SearchCategory category) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Center(
        child: TextButton(
          onPressed: () {
            setState(() {
              _selectedCategory = category;
            });
          },
          child: Text('View all ${category.name}', style: TextStyle(color: AppColors.secondaryTeal, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }



  Widget _buildSearchResults(List<dynamic> results) {
    if (_selectedCategory == SearchCategory.all) {
      return _buildMagazineLayout(results);
    }
    
    // Original category-specific view
    final posts = results.where((item) => item['type'] == 'post').toList();
    final nonPosts = results.where((item) => item['type'] != 'post').toList();

    return ListView(
      padding: EdgeInsets.all(8),
      children: [
        // Show non-post items first (users, hashtags)
        ...nonPosts.map((item) {
          switch (item['type']) {
            case 'user':
              return _buildUserResult(item['data']);
            case 'hashtag':
              return _buildHashtagResult(item['data']);
            case 'petition':
              return _buildPetitionResult(item['data']);
            default:
              return SizedBox();
          }
        }),
        
        // Show posts in staggered grid if there are any
        if (posts.isNotEmpty) ...[
          if (nonPosts.isNotEmpty) SizedBox(height: 16),
          _buildPostGrid(posts),
        ],
      ],
    );
  }

  Widget _buildPostGrid(List<dynamic> posts) {
    return MasonryGridView.count(
      crossAxisCount: ResponsiveLayout.getColumnCount(context), 
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index]['data'];
        final postId = posts[index]['id'];
        final mediaUrl = post['mediaUrl'] ?? '';
        final mediaType = post['mediaType'] ?? 'image';
        final caption = post['caption'] ?? '';
        final userId = post['userId'] ?? '';
        final likesCount = (post['likes'] as List?)?.length ?? 0;
        final commentsCount = post['comments'] ?? 0;

        final randomHeightFactor = ((postId.hashCode % 2) + 1.4);
        final double imageHeight = 120.0 * randomHeightFactor;
        final double borderRadiusValue = 20.0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PostDetailScreen(
                  postId: postId,
                  userId: userId,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Media container ---
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(borderRadiusValue),
                      child: mediaType == 'image'
                          ? CachedNetworkImage(
                              imageUrl: mediaUrl,
                              width: double.infinity,
                              height: imageHeight,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                height: imageHeight,
                                color: AppColors.elevation,
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLavender)),
                              ),
                              errorWidget: (context, url, error) => Container(
                                height: imageHeight,
                                color: AppColors.elevation,
                                child: const Center(
                                  child: Icon(Feather.alert_circle, color: AppColors.error),
                                ),
                              ),
                            )
                          : Container(
                              height: imageHeight,
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Feather.play, color: Colors.white, size: 36),
                              ),
                            ),
                    ),
                  ),
                  // Engagement Overlay
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Feather.heart, size: 10, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            likesCount.toString(),
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0, left: 4.0, right: 4.0),
                  child: Text(
                    caption,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMedium, // Light gray for caption
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserResult(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: user['uid'])));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface, // Surface card
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.elevation,
                backgroundImage: (user['profileImage']?.isNotEmpty == true)
                    ? CachedNetworkImageProvider(user['profileImage'])
                    : const AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user['username']?.toString() ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.primaryLavender, // Lavender username
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user['isVerified'] == true) const SizedBox(width: 4),
                      if (user['isVerified'] == true)
                        const Icon(Feather.check_circle, color: Colors.blue, size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['fullName']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMedium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _followUser(user['uid']),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _followingIds.contains(user['uid'])
                      ? AppColors.elevation // Following = Dark Gray
                      : AppColors.primaryLavender, // Follow = Lavender
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  _followingIds.contains(user['uid']) ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: _followingIds.contains(user['uid']) ? AppColors.textMedium : AppColors.backgroundDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagResult(Map<String, dynamic> hashtag) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.elevation,
          ),
          child: const Center(
            child: Icon(Feather.hash, color: AppColors.primaryLavender, size: 22),
          ),
        ),
        title: Text(
          hashtag['tag']?.toString() ?? '',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.primaryLavender,
          ),
        ),
        subtitle: Text(
          '${hashtag['popularity']} posts',
          style: TextStyle(fontSize: 12, color: AppColors.textMedium),
        ),
        trailing: const Icon(Feather.chevron_right, size: 16, color: AppColors.textDisabled),
        onTap: () {
          _searchController.text = hashtag['tag'].toString();
          _performSearch(hashtag['tag'].toString());
        },
      ),
    );
  }

  Widget _buildPetitionResult(Map<String, dynamic> petition) {
    final title = petition['title'] ?? 'Untitled Petition';
    final signers = petition['currentSignatures'] ?? 0;
    final progress = (petition['goal'] ?? 0) > 0 
        ? signers / petition['goal'] 
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.elevation,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (petition['bannerImageUrl'] != null && petition['bannerImageUrl'].toString().isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: petition['bannerImageUrl'],
                    fit: BoxFit.cover,
                  )
                : const Icon(Feather.flag, color: AppColors.primaryLavender),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(title, style: const TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 14))),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$signers',
                style: TextStyle(color: AppColors.secondaryTeal, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trending Petition', style: const TextStyle(color: AppColors.textMedium, fontSize: 11)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppColors.elevation,
                color: AppColors.secondaryTeal,
                minHeight: 4,
              ),
            ),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedPetitionDetailScreen(petitionId: petition['id']),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoResults() {
    final query = _searchController.text.trim();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Feather.search, size: 64, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text(
            'No results found for "$query"',
            style: TextStyle(fontSize: 16, color: AppColors.textMedium),
          ),
          SizedBox(height: 8),
          Text(
            'Try checking your spelling or use different keywords.',
            style: TextStyle(fontSize: 12, color: AppColors.textDisabled),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultContent() {
    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        // Support Card (Initial Blank)
        _buildSupportCard(),
        
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches'),
          ..._recentSearches.take(3).map((search) => _buildRecentSearchItem(search)),
          SizedBox(height: 16),
        ],
        
        // Visual Trending Hashtags
        if (_trendingHashtags.isNotEmpty) ...[
          _buildSectionHeader('Visual Trends'),
          ..._trendingHashtags.take(5).map((tag) => _buildVisualTrendingHashtagSection(tag)),
          SizedBox(height: 16),
        ],
        
        // Suggested Creators (Card Layout)
        if (_suggestedUsers.isNotEmpty) ...[
          _buildSectionHeader('Rising Creators'),
          Container(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedUsers.length,
              itemBuilder: (context, index) {
                return _buildSuggestedCreatorCard(_suggestedUsers[index]);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisualTrendingHashtagSection(String tag) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(Feather.trending_up, size: 14, color: AppColors.secondaryTeal),
              SizedBox(width: 8),
              Text(tag, style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
              Spacer(),
              Icon(Feather.chevron_right, size: 16, color: AppColors.textDisabled),
            ],
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchThumbnailsForHashtag(tag),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) return SizedBox(height: 80);
            return Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final post = snapshot.data![index];
                  return Container(
                    width: 75,
                    margin: EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(post['mediaUrl'] ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSuggestedCreatorCard(Map<String, dynamic> user) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevation,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: CachedNetworkImageProvider(user['profileImage'] ?? ''),
          ),
          SizedBox(height: 8),
          Text(
            user['username'] ?? 'User',
            style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchThumbnailsForUser(user['uid']),
            builder: (context, snapshot) {
              final posts = snapshot.data ?? [];
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Container(
                    width: 40,
                    height: 40,
                    margin: EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      image: i < posts.length 
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(posts[i]['mediaUrl'] ?? ''),
                            fit: BoxFit.cover,
                          )
                        : null,
                    ),
                  );
                }),
              );
            },
          ),
          Spacer(),
          GestureDetector(
            onTap: () => _followUser(user['uid']),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLavender,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                'Follow',
                style: TextStyle(color: AppColors.backgroundDeep, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: AppColors.primaryLavender,
        ),
      ),
    );
  }

  Widget _buildRecentSearchItem(Map<String, dynamic> search) {
    return ListTile(
      leading: Icon(Feather.clock, color: AppColors.textMedium),
      title: Text(search['query']?.toString() ?? '', style: TextStyle(color: AppColors.textHigh)),
      trailing: IconButton(
        icon: Icon(Feather.x, size: 16, color: AppColors.textDisabled),
        onPressed: () => _removeRecentSearch(search['query']?.toString() ?? ''),
      ),
      onTap: () {
        _searchController.text = search['query']?.toString() ?? '';
        _performSearch(search['query']?.toString() ?? '');
      },
    );
  }

  Widget _buildTrendingTag(String tag) {
    return ActionChip(
      label: Text(tag),
      onPressed: () {
        _searchController.text = tag;
        _performSearch(tag);
      },
      backgroundColor: AppColors.elevation,
      labelStyle: TextStyle(color: AppColors.primaryLavender),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
    );
  }

  void _removeRecentSearch(String query) {
    setState(() {
      _recentSearches.removeWhere((item) => item['query'] == query);
    });
  }

  void _followUser(String userId) async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    if (userId == currentUserId) return; // Can't follow self

    final isFollowing = _followingIds.contains(userId);
    
    try {
      final batch = FirebaseFirestore.instance.batch();
      final currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      final targetUserRef = FirebaseFirestore.instance.collection('users').doc(userId);

      if (isFollowing) {
        // Unfollow
        batch.update(currentUserRef, {'following': FieldValue.arrayRemove([userId])});
        batch.update(targetUserRef, {'followers': FieldValue.arrayRemove([currentUserId])});
      } else {
        // Follow
        batch.update(currentUserRef, {'following': FieldValue.arrayUnion([userId])});
        batch.update(targetUserRef, {'followers': FieldValue.arrayUnion([currentUserId])});
      }

      await batch.commit();
      
      if (mounted) {
        setState(() {
          if (isFollowing) {
            _followingIds.remove(userId);
          } else {
            _followingIds.add(userId);
          }
        });
      }
    } catch (e) {
      print('Error updating follow status: $e');
    }
  }

  Widget _buildSupportCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.elevation.withOpacity(0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Feather.heart,
            color: AppColors.error,
            size: 20,
          ),
        ),
        title: const Text(
          "Support Femn",
          style: TextStyle(
            color: AppColors.textHigh,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: const Text(
          "Show your love & help us grow",
          style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
        ),
        trailing: const Icon(
          Feather.chevron_right,
          color: AppColors.textDisabled,
          size: 16,
        ),
        onTap: () async {
           final Uri url = Uri.parse('https://selar.co/showlove/femn');
           if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
             if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('Could not launch support link')),
               );
             }
           }
        },
      ),
    );
  }
}

// Search categories enum
enum SearchCategory {
  all,
  users,
  posts,
  hashtags,
  petitions,
}

// Extension to get display names
extension SearchCategoryExtension on SearchCategory {
  String get name {
    switch (this) {
      case SearchCategory.all:
        return 'All';
      case SearchCategory.users:
        return 'People';
      case SearchCategory.posts:
        return 'Posts';
      case SearchCategory.hashtags:
        return 'Hashtags';
      case SearchCategory.petitions:
        return 'Petitions';
    }
  }
}
