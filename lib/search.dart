import 'dart:async';
import 'post.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/profile.dart';
import 'package:femn/colors.dart'; // <--- IMPORT COLORS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// Enhanced Search Screen with multiple search types and smart features
class SearchScreen extends StatefulWidget {
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<dynamic> _searchResults = [];
  List<String> _searchSuggestions = [];
  List<Map<String, dynamic>> _recentSearches = [];
  List<String> _trendingHashtags = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  
  bool _isSearching = false;
  bool _showSuggestions = false;
  SearchCategory _selectedCategory = SearchCategory.all;
  
  // Personalization data
  Set<String> _userInterests = {};
  Set<String> _followingIds = {};
  
  // Debouncing for search
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadPersonalizationData();
    _loadTrendingData();
    _loadRecentSearches();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Load user preferences and network
  Future<void> _loadPersonalizationData() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
          
      if (userDoc.exists) {
        setState(() {
          _userInterests = Set<String>.from(userDoc['interests'] ?? []);
          _followingIds = Set<String>.from(userDoc['following'] ?? []);
        });
      }
    } catch (e) {
      print('Error loading personalization data: $e');
    }
  }

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
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _showSuggestions = true;
      });
      return;
    }

    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Show suggestions while typing
    if (query.length > 1) {
      _generateSearchSuggestions(query);
    }

    // Set up new debounce timer
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (query.isEmpty) return;

      setState(() {
        _isSearching = true;
        _showSuggestions = false;
      });

      try {
        final results = await _searchAcrossAllCategories(query);
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });

        // Save to recent searches
        _saveToRecentSearches(query, 'search');
      } catch (e) {
        print('Search error: $e');
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  // Generate smart search suggestions
  void _generateSearchSuggestions(String query) async {
    try {
      // Get all users and posts for suggestions
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(20)
          .get();

      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .limit(20)
          .get();

      final suggestions = <String>[];
      final queryLower = query.toLowerCase();
      
      // Add user suggestions
      suggestions.addAll(usersSnapshot.docs
          .where((doc) {
            final user = doc.data();
            final username = user['username']?.toString().toLowerCase() ?? '';
            return username.contains(queryLower);
          })
          .map((doc) => '@${doc['username']}')
          .toList());

      // Extract hashtags and keywords from posts
      for (final doc in postsSnapshot.docs) {
        final post = doc.data();
        final caption = post['caption']?.toString() ?? '';
        
        // Extract hashtags
        final hashtags = _extractHashtags(caption);
        suggestions.addAll(hashtags.where((tag) => 
            tag.toLowerCase().contains(queryLower)));
        
        // Add caption keywords
        final keywords = _extractKeywords(caption);
        suggestions.addAll(keywords.where((keyword) =>
            keyword.toLowerCase().contains(queryLower)));
      }

      // Remove duplicates and limit
      final uniqueSuggestions = suggestions.toSet().toList();
      setState(() {
        _searchSuggestions = uniqueSuggestions.take(8).toList();
        _showSuggestions = true;
      });
    } catch (e) {
      print('Error generating suggestions: $e');
    }
  }

  List<String> _extractHashtags(String text) {
    final regex = RegExp(r'#(\w+)');
    return regex.allMatches(text).map((match) => match.group(0)!).toList();
  }

  List<String> _extractKeywords(String text) {
    return text.split(' ')
        .where((word) => word.length > 2)
        .map((word) => word.trim())
        .where((word) => !word.startsWith('#'))
        .toList();
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

  // Relevance scoring algorithms
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
    if (_followingIds.contains(user['uid'])) score += 40;

    final mutualCount = _calculateMutualConnections(user);
    score += mutualCount * 5;

    return score;
  }

  double _calculatePostRelevanceScore(Map<String, dynamic> post, String query) {
    double score = 0.0;
    final caption = post['caption']?.toString().toLowerCase() ?? '';
    final queryLower = query.toLowerCase();

    if (caption == queryLower) score += 60;
    else if (caption.startsWith(queryLower)) score += 40;
    else if (caption.contains(queryLower)) score += 20;

    final hashtags = List<String>.from(post['hashtags'] ?? []);
    if (hashtags.any((tag) => tag.toLowerCase().contains(queryLower.replaceFirst('#', '')))) {
      score += 30;
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
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep, // Deep background
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
                onTap: () {
                  setState(() {
                    _showSuggestions = _searchController.text.isNotEmpty;
                  });
                },
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
          itemCount: SearchCategory.values.length,
          itemBuilder: (context, index) {
            final category = SearchCategory.values[index];
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
      return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
    }

    if (_searchController.text.isNotEmpty) {
      if (_showSuggestions && _searchSuggestions.isNotEmpty) {
        return _buildSuggestionsList();
      }
      
      final filteredResults = _getFilteredResults();
      if (filteredResults.isEmpty) {
        return _buildNoResults();
      }
      
      return _buildSearchResults(filteredResults);
    }

    // Default state - show trending and suggestions
    return _buildDefaultContent();
  }

  Widget _buildSuggestionsList() {
    if (_searchSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = _searchSuggestions[index];
        return ListTile(
          leading: Icon(
            suggestion.startsWith('@') ? Icons.person : Icons.tag,
            color: AppColors.textMedium,
          ),
          title: Text(suggestion, style: TextStyle(color: AppColors.textHigh)),
          onTap: () {
            _searchController.text = suggestion;
            _performSearch(suggestion);
            FocusScope.of(context).unfocus();
          },
        );
      },
    );
  }

  Widget _buildSearchResults(List<dynamic> results) {
    // Separate posts from other types
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
      crossAxisCount: 3, 
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
        // final likes = List<String>.from(post['likes'] ?? []);

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
                              child: Icon(Icons.error, color: AppColors.error),
                            ),
                          ),
                        )
                      : Container(
                          height: imageHeight,
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
                          ),
                        ),
                ),
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
        if (user['uid'] == FirebaseAuth.instance.currentUser!.uid) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: user['uid'])));
        } else {
          // Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfileScreen(userId: user['uid'])));
        }
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
                        const Icon(Icons.verified, color: Colors.blue, size: 16),
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
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textDisabled),
        onTap: () {
          _searchController.text = hashtag['tag'].toString();
          _performSearch(hashtag['tag'].toString());
        },
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: AppColors.textDisabled),
          SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(fontSize: 18, color: AppColors.textMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultContent() {
    return ListView(
      padding: EdgeInsets.all(12),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          _buildSectionHeader('Recent Searches'),
          ..._recentSearches.map((search) => _buildRecentSearchItem(search)),
          SizedBox(height: 16),
        ],
        
        // Trending Hashtags
        if (_trendingHashtags.isNotEmpty) ...[
          _buildSectionHeader('Trending Now'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingHashtags
                .take(10)
                .map((tag) => _buildTrendingTag(tag))
                .toList(),
          ),
          SizedBox(height: 16),
        ],
        
        // Suggested Users
        if (_suggestedUsers.isNotEmpty) ...[
          _buildSectionHeader('Suggested for You'),
          ..._suggestedUsers
              .take(5)
              .map((user) => _buildUserResult(user)),
        ],
      ],
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
      leading: Icon(Icons.history, color: AppColors.textMedium),
      title: Text(search['query']?.toString() ?? '', style: TextStyle(color: AppColors.textHigh)),
      trailing: IconButton(
        icon: Icon(Icons.close, size: 16, color: AppColors.textDisabled),
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
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'following': FieldValue.arrayUnion([userId])
      });
      
      setState(() {
        _followingIds.add(userId);
      });
    } catch (e) {
      print('Error following user: $e');
    }
  }
}

// Search categories enum
enum SearchCategory {
  all,
  users,
  posts,
  hashtags,
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
    }
  }
}