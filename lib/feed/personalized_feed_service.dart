import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class PersonalizedFeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Weights for different interaction types
  static const Map<String, double> _signalWeights = {
    'like': 2.0,
    'save': 3.0,
    'share': 4.0,
    'download': 3.5,
    'see_more': 1.5,
    'see_less': -3.0,
    'report': -10.0,
    'comment': 2.5,
    'watch_time': 0.1,
  };
  
  static const double _decayFactor = 0.98;

  // In-memory cache for user profile
  Map<String, dynamic>? _cachedUserProfile;
  DateTime? _profileCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  Future<List<DocumentSnapshot>> getPersonalizedFeed({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];
    
    try {
      // 1. Get user's interaction history (Cached)
      if (_cachedUserProfile == null || 
          _profileCacheTime == null || 
          DateTime.now().difference(_profileCacheTime!) > _cacheDuration) {
        _cachedUserProfile = await _buildUserInterestProfile(userId);
        _profileCacheTime = DateTime.now();
      }
      
      final userProfile = _cachedUserProfile!;
      
      // 2. Fetch User Data needed for scoring (Following list)
      // We can also cache this briefly or fetch it once per session if needed, 
      // but one read here is fine compared to N reads later.
      final userDoc = await _db.collection('users').doc(userId).get();
      final following = List<String>.from(userDoc.data()?['following'] ?? []);
      
      // 3. Get candidate posts
      Query query = _db.collection('posts')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(Duration(days: 30)))
        .orderBy('timestamp', descending: true);
        
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      // Fetch more candidates than needed to allow for ranking
      final snapshot = await query.limit(limit * 3).get();
      
      if (snapshot.docs.isEmpty) return [];
      
      // 4. Score and rank synchronously
      List<Map<String, dynamic>> scoredPosts = [];
      
      for (final postDoc in snapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;
        
        // Calculate score heavily relies on CPU now, avoiding awaits
        final score = _calculatePostScoreSync(
          postDoc: postDoc,
          postData: postData,
          userProfile: userProfile,
          userId: userId,
          following: following,
        );
        
        scoredPosts.add({
          'post': postDoc,
          'score': score,
        });
      }
      
      // 5. Sort by score
      scoredPosts.sort((a, b) => b['score'].compareTo(a['score']));
      
      // 6. Apply diversity/variety logic
      final diversifiedPosts = _addVariety(scoredPosts);
      
      return diversifiedPosts.take(limit).map((item) => item['post'] as DocumentSnapshot).toList();
      
    } catch (e) {
      print('Error in personalized feed: $e');
      // Fallback
      final fallback = await _db.collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
      return fallback.docs;
    }
  }
  
  Future<Map<String, dynamic>> _buildUserInterestProfile(String userId) async {
    final tagWeights = <String, double>{};
    final categoryWeights = <String, double>{};
    final authorWeights = <String, double>{};
    final interactPostIds = <String>{}; // Cache of posts user interacted with
    
    int interactionCount = 0;
    double avgWatchTime = 0.0;
    
    try {
      final now = DateTime.now();
      final signalsSnapshot = await _db.collection('users')
        .doc(userId)
        .collection('signals')
        .where('timestamp', isGreaterThan: now.subtract(Duration(days: 90)))
        .orderBy('timestamp', descending: true)
        .limit(500) // Reduced limit for performance, 500 signals is plenty
        .get();
      
      double totalWatchTime = 0;
      int watchCount = 0;

      // Optimization: Batch fetch related posts
      // We only need details for posts to get tags/categories. 
      // 1. Collect unique Post IDs from signals that have positive weight logic
      final postIdsToFetch = <String>{};
      
      for (final doc in signalsSnapshot.docs) {
        final data = doc.data();
        postIdsToFetch.add(data['postId']);
        
        // Also track all interacted IDs for the 'already viewed' check
        interactPostIds.add(data['postId']);
      }
      
      // 2. Fetch post details in batches
      // Firestore 'whereIn' supports only 10 items. Parallel HTTP requests are better for larger sets.
      // We will limit to fetching details for the most recent 50 distinct posts to keep it fast.
      // Older interactions still count for frequency but maybe we don't need their tags as urgently.
      final topRecentPostIds = postIdsToFetch.take(50).toList();
      
      final List<DocumentSnapshot> postDocs = await Future.wait(
        topRecentPostIds.map((id) => _db.collection('posts').doc(id).get())
      );
      
      // Map for quick lookup
      final postMap = {for (var doc in postDocs) doc.id: doc};

      // 3. Process signals
      for (final signalDoc in signalsSnapshot.docs) {
        final signal = signalDoc.data();
        final postId = signal['postId'];
        final signalTime = (signal['timestamp'] as Timestamp).toDate();
        final daysAgo = now.difference(signalTime).inDays;
        
        final timeWeight = pow(_decayFactor, daysAgo).toDouble();
        final baseWeight = _signalWeights[signal['type']] ?? 1.0;
        final finalWeight = baseWeight * timeWeight;
        
        // Only process content-based weights if we fetched the post
        final postDoc = postMap[postId];
        if (postDoc != null && postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          
          final tags = List<String>.from(postData['smartTags'] ?? []);
          for (final tag in tags) {
            tagWeights[tag] = (tagWeights[tag] ?? 0) + finalWeight;
          }
          
          final category = postData['category'] ?? 'General';
          categoryWeights[category] = (categoryWeights[category] ?? 0) + finalWeight;
          
          if (finalWeight > 0) {
            final authorId = postData['userId'];
            authorWeights[authorId] = (authorWeights[authorId] ?? 0) + finalWeight;
          }
        }
        
        if (signal['type'] == 'watch_time') {
          totalWatchTime += signal['value'] ?? 0;
          watchCount++;
        }
      }
      
      interactionCount = signalsSnapshot.docs.length;
      avgWatchTime = watchCount > 0 ? totalWatchTime / watchCount : 0;
      
      _normalizeWeights(tagWeights);
      _normalizeWeights(categoryWeights);
      _normalizeWeights(authorWeights);
      
    } catch (e) {
      print('Error building user profile: $e');
    }
    
    return {
      'tagWeights': tagWeights,
      'categoryWeights': categoryWeights,
      'authorWeights': authorWeights,
      'interactedPostIds': interactPostIds, // Important for scoring
      'interactionCount': interactionCount,
      'avgWatchTime': avgWatchTime,
    };
  }

  // Synchronous scoring function
  double _calculatePostScoreSync({
    required DocumentSnapshot postDoc,
    required Map<String, dynamic> postData,
    required Map<String, dynamic> userProfile,
    required String userId,
    required List<String> following,
  }) {
    double score = 0;
    
    // 1. Check if user already interacted (Negative if disliked, or just filter out if viewed?)
    // In naive implementation we might filter out ALL 'view' posts, but maybe user wants to see them again?
    // Let's just check for negative signals or 'seen_less'.
    // NOTE: This check is simplified. We assume if it's in 'interactedPostIds', 
    // it *might* have been acted upon.
    // For exact negative filtering, we'd need to store *types* of interaction in the set or map.
    // As a tradeoff, we won't strictly filter -100 here unless we stored that info.
    // BUT we can check author blocks etc.
    // For now, let's just use the profile content matching which is the heavy part.
    
    final previouslyInteracted = (userProfile['interactedPostIds'] as Set<String>).contains(postDoc.id);
    // Optional: Boost unseen posts, punish seen ones slightly? 
    if (previouslyInteracted) score -= 5.0; 
    
    // 2. Content-based scoring
    final tags = List<String>.from(postData['smartTags'] ?? []);
    final tagWeights = userProfile['tagWeights'] as Map<String, double>;
    for (final tag in tags) {
      score += tagWeights[tag] ?? 0;
    }
    
    // 3. Category match
    final category = postData['category'] ?? 'General';
    final catWeights = userProfile['categoryWeights'] as Map<String, double>;
    score += (catWeights[category] ?? 0) * 2;
    
    // 4. Author relationship
    final authorId = postData['userId'];
    if (authorId != userId) {
      if (following.contains(authorId)) {
        score += 10;
      } else {
        final authWeights = userProfile['authorWeights'] as Map<String, double>;
        score += authWeights[authorId] ?? 0;
      }
    }
    
    // 5. Quality score
    score += (postData['qualityScore'] ?? 5).toDouble() * 0.5;
    
    // 6. Recency boost
    final postTime = postData['timestamp'].toDate();
    final hoursAgo = DateTime.now().difference(postTime).inHours;
    final recencyBoost = max(0, 24 - hoursAgo) * 0.1;
    score += recencyBoost;
    
    // 7. Engagement
    final likes = List<String>.from(postData['likes'] ?? []);
    final comments = postData['comments'] ?? 0;
    final engagement = (likes.length * 0.5) + (comments * 0.3);
    score += engagement * 0.2;
    
    return score;
  }
  
  List<Map<String, dynamic>> _addVariety(List<Map<String, dynamic>> scoredPosts) {
    if (scoredPosts.length < 5) return scoredPosts;
    
    final diversified = <Map<String, dynamic>>[];
    final categoriesSeen = <String>{};
    
    // Take top 20%
    final topCount = (scoredPosts.length * 0.2).ceil();
    for (int i = 0; i < topCount && i < scoredPosts.length; i++) {
      diversified.add(scoredPosts[i]);
      final postData = scoredPosts[i]['post'].data() as Map<String, dynamic>;
      categoriesSeen.add(postData['category'] ?? 'General');
    }
    
    // Add variety
    for (int i = topCount; i < scoredPosts.length; i++) {
      final postData = scoredPosts[i]['post'].data() as Map<String, dynamic>;
      final category = postData['category'] ?? 'General';
      
      if (diversified.length % 3 == 0 && !categoriesSeen.contains(category)) {
        diversified.add(scoredPosts[i]);
        categoriesSeen.add(category);
      } else if (Random().nextDouble() < 0.3) {
        diversified.add(scoredPosts[i]);
      }
    }
    
    return diversified;
  }
  
  void _normalizeWeights(Map<String, double> weights) {
    if (weights.isEmpty) return;
    final maxWeight = weights.values.reduce(max);
    if (maxWeight > 0) {
      for (final key in weights.keys.toList()) {
        weights[key] = weights[key]! / maxWeight;
      }
    }
  }
  
  Future<void> recordInteraction({
    required String type,
    required String postId,
    String? authorId,
    double? value,
    String? source,
    String collection = 'posts',
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    // Invalidate profile cache on strong signals if needed, or just let it expire naturally.
    // For 'see_less' or 'report', maybe we want immediate effect?
    // For optimization, we'll let it abide by the 5 min window.
    
    try {
       await _db.collection('users')
        .doc(userId)
        .collection('signals')
        .add({
          'type': type,
          'postId': postId,
          'authorId': authorId,
          'value': value,
          'source': source ?? 'feed',
          'timestamp': FieldValue.serverTimestamp(),
        });

      if (authorId != null && (type == 'view' || type == 'click_link')) {
        String sourceKey = source ?? 'feed';
        _db.collection('users').doc(authorId).update({
          'trafficBreakdown.$sourceKey': FieldValue.increment(1)
        }).onError((_, __) => null);
      }

      final docRef = _db.collection(collection).doc(postId);
      
      if (type == 'view') {
        docRef.update({'views': FieldValue.increment(1)}).onError((_, __) => null);
      } else if (type == 'share') {
        docRef.update({'shares': FieldValue.increment(1)}).onError((_, __) => null);
      } else if (type == 'save') {
        docRef.update({'saves': FieldValue.increment(1)}).onError((_, __) => null);
      } else if (type == 'click_link') {
        docRef.update({'linkClicks': FieldValue.increment(1)}).onError((_, __) => null);
      } else if (type == 'unsave') {
        docRef.update({'saves': FieldValue.increment(-1)}).onError((_, __) => null);
      }
    } catch (e) {
      print('Error recording interaction: $e');
    }
  }

  Future<List<DocumentSnapshot>> getSimilarPosts(String postId, {int limit = 10}) async {
    try {
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) return [];
      
      final postData = postDoc.data() as Map<String, dynamic>;
      final tags = List<String>.from(postData['smartTags'] ?? []);
      
      if (tags.isEmpty) return [];
      
      final similarPosts = <DocumentSnapshot>[];
      final seenIds = <String>{postId};
      
      for (final tag in tags.take(3)) {
        final query = await _db.collection('posts')
          .where('smartTags', arrayContains: tag)
          .where('timestamp', isGreaterThan: DateTime.now().subtract(Duration(days: 60)))
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
        
        for (final doc in query.docs) {
          if (!seenIds.contains(doc.id)) {
            similarPosts.add(doc);
            seenIds.add(doc.id);
          }
          if (similarPosts.length >= limit) break;
        }
        if (similarPosts.length >= limit) break;
      }
      return similarPosts;
    } catch (e) {
      print('Error getting similar posts: $e');
      return [];
    }
  }
}
