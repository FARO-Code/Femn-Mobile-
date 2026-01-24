import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class PersonalizedFeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Weights for different interaction types (like TikTok)
  static const Map<String, double> _signalWeights = {
    'like': 2.0,
    'save': 3.0,           // Strong signal (like Pinterest)
    'share': 4.0,          // Very strong signal
    'download': 3.5,       // Strong engagement
    'see_more': 1.5,       // Interest in similar content
    'see_less': -3.0,      // Negative signal
    'report': -10.0,       // Very negative signal
    'comment': 2.5,        // Strong engagement
    'watch_time': 0.1,     // Per second of video watched
  };
  
  // Time decay factor (recent signals matter more)
  static const double _decayFactor = 0.98; // 2% decay per day
  
  Future<List<DocumentSnapshot>> getPersonalizedFeed({
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return [];
    
    try {
      // 1. Get user's interaction history
      final userProfile = await _buildUserInterestProfile(userId);
      
      // 2. Get candidate posts (from last 30 days)
      Query query = _db.collection('posts')
        .where('timestamp', isGreaterThan: DateTime.now().subtract(Duration(days: 30)))
        .orderBy('timestamp', descending: true);
        
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }
      
      final snapshot = await query.limit(100).get(); // Get more candidates for ranking
      
      if (snapshot.docs.isEmpty) return [];
      
      // 3. Score and rank each post
      List<Map<String, dynamic>> scoredPosts = [];
      
      for (final postDoc in snapshot.docs) {
        final postData = postDoc.data() as Map<String, dynamic>;
        final score = await _calculatePostScore(
          postDoc: postDoc,
          postData: postData,
          userProfile: userProfile,
          userId: userId,
        );
        
        scoredPosts.add({
          'post': postDoc,
          'score': score,
        });
      }
      
      // 4. Sort by score and apply variety factor
      scoredPosts.sort((a, b) => b['score'].compareTo(a['score']));
      
      // 5. Add some diversity (like TikTok's "explore" factor)
      final diversifiedPosts = _addVariety(scoredPosts);
      
      // 6. Return top posts
      return diversifiedPosts.take(limit).map((item) => item['post'] as DocumentSnapshot).toList();
      
    } catch (e) {
      print('Error in personalized feed: $e');
      // Fallback to recent posts
      final fallback = await _db.collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
      return fallback.docs;
    }
  }
  
Future<Map<String, dynamic>> _buildUserInterestProfile(String userId) async {
    // FIX: Define these as strongly typed maps first so we can modify them easily
    final tagWeights = <String, double>{};
    final categoryWeights = <String, double>{};
    final authorWeights = <String, double>{};
    
    // FIX: Initialize primitive stats separately
    int interactionCount = 0;
    double avgWatchTime = 0.0;
    
    try {
      // Get recent signals (last 90 days)
      final now = DateTime.now();
      final signalsSnapshot = await _db.collection('users')
        .doc(userId)
        .collection('signals')
        .where('timestamp', isGreaterThan: now.subtract(Duration(days: 90)))
        .orderBy('timestamp', descending: true)
        .limit(1000) 
        .get();
      
      double totalWatchTime = 0;
      int watchCount = 0;
      
      for (final signalDoc in signalsSnapshot.docs) {
        final signal = signalDoc.data();
        final signalTime = (signal['timestamp'] as Timestamp).toDate();
        final daysAgo = now.difference(signalTime).inDays;
        
        // Apply time decay
        final timeWeight = pow(_decayFactor, daysAgo).toDouble();
        final baseWeight = _signalWeights[signal['type']] ?? 1.0;
        final finalWeight = baseWeight * timeWeight;
        
        // Get post details to understand what was interacted with
        final postId = signal['postId'];
        final postDoc = await _db.collection('posts').doc(postId).get();
        
        if (postDoc.exists) {
          final postData = postDoc.data() as Map<String, dynamic>;
          
          // Update tag weights
          final tags = List<String>.from(postData['smartTags'] ?? []);
          for (final tag in tags) {
            // FIX: Now works because tagWeights is explicitly Map<String, double>
            tagWeights[tag] = (tagWeights[tag] ?? 0) + finalWeight;
          }
          
          // Update category weight
          final category = postData['category'] ?? 'General';
          categoryWeights[category] = 
            (categoryWeights[category] ?? 0) + finalWeight;
          
          // Update author weight (if positive interaction)
          if (finalWeight > 0) {
            final authorId = postData['userId'];
            authorWeights[authorId] = 
              (authorWeights[authorId] ?? 0) + finalWeight;
          }
          
          // Track watch time for videos
          if (signal['type'] == 'watch_time') {
            totalWatchTime += signal['value'] ?? 0;
            watchCount++;
          }
        }
      }
      
      interactionCount = signalsSnapshot.docs.length;
      avgWatchTime = watchCount > 0 ? totalWatchTime / watchCount : 0;
      
      // FIX: Arguments now match expected Map<String, double>
      _normalizeWeights(tagWeights);
      _normalizeWeights(categoryWeights);
      _normalizeWeights(authorWeights);
      
    } catch (e) {
      print('Error building user profile: $e');
    }
    
    // FIX: Construct the final dynamic map at the end
    return {
      'tagWeights': tagWeights,
      'categoryWeights': categoryWeights,
      'authorWeights': authorWeights,
      'interactionCount': interactionCount,
      'avgWatchTime': avgWatchTime,
    };
  }
  
  Future<double> _calculatePostScore({
    required DocumentSnapshot postDoc,
    required Map<String, dynamic> postData,
    required Map<String, dynamic> userProfile,
    required String userId,
  }) async {
    double score = 0;
    
    // 1. Check if user already interacted with this post (negative if disliked)
    final signalsSnapshot = await _db.collection('users')
      .doc(userId)
      .collection('signals')
      .where('postId', isEqualTo: postDoc.id)
      .get();
    
    for (final signalDoc in signalsSnapshot.docs) {
      final signal = signalDoc.data();
      final weight = _signalWeights[signal['type']] ?? 0;
      if (weight < -2) return -100; // User reported or strongly disliked
    }
    
    // 2. Content-based scoring
    final tags = List<String>.from(postData['smartTags'] ?? []);
    for (final tag in tags) {
      score += userProfile['tagWeights'][tag] ?? 0;
    }
    
    // 3. Category match
    final category = postData['category'] ?? 'General';
    score += (userProfile['categoryWeights'][category] ?? 0) * 2; // Category is important
    
    // 4. Author relationship
    final authorId = postData['userId'];
    if (authorId != userId) {
      // Check if following
      final userDoc = await _db.collection('users').doc(userId).get();
      final following = List<String>.from(userDoc['following'] ?? []);
      
      if (following.contains(authorId)) {
        score += 10; // Boost for following
      } else {
        score += userProfile['authorWeights'][authorId] ?? 0;
      }
    }
    
    // 5. Quality score (from AI analysis)
    score += (postData['qualityScore'] ?? 5).toDouble() * 0.5;
    
    // 6. Recency boost
    final postTime = postData['timestamp'].toDate();
    final hoursAgo = DateTime.now().difference(postTime).inHours;
    final recencyBoost = max(0, 24 - hoursAgo) * 0.1;
    score += recencyBoost;
    
    // 7. Engagement signals (likes, comments, etc.)
    final likes = List<String>.from(postData['likes'] ?? []);
    final comments = postData['comments'] ?? 0;
    final engagement = (likes.length * 0.5) + (comments * 0.3);
    score += engagement * 0.2;
    
    // 8. Diversity penalty (avoid too much similar content)
    // This would need tracking of recent shown posts
    
    return score;
  }
  
  List<Map<String, dynamic>> _addVariety(List<Map<String, dynamic>> scoredPosts) {
    if (scoredPosts.length < 5) return scoredPosts;
    
    final diversified = <Map<String, dynamic>>[];
    final categoriesSeen = <String>{};
    
    // Take top 20% as is (highest relevance)
    final topCount = (scoredPosts.length * 0.2).ceil();
    for (int i = 0; i < topCount && i < scoredPosts.length; i++) {
      diversified.add(scoredPosts[i]);
      final postData = scoredPosts[i]['post'].data() as Map<String, dynamic>;
      categoriesSeen.add(postData['category'] ?? 'General');
    }
    
    // Add variety: mix of high-scoring and exploratory content
    for (int i = topCount; i < scoredPosts.length; i++) {
      final postData = scoredPosts[i]['post'].data() as Map<String, dynamic>;
      final category = postData['category'] ?? 'General';
      
      // Every 3rd post, try to show something from a new category
      if (diversified.length % 3 == 0 && !categoriesSeen.contains(category)) {
        diversified.add(scoredPosts[i]);
        categoriesSeen.add(category);
      } else if (Random().nextDouble() < 0.3) { // 30% chance of exploratory content
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
  
  // Call this when user interacts to update profile in real-time
  Future<void> recordInteraction({
    required String type,
    required String postId,
    String? authorId,
    double? value,
    String? source, // 'feed', 'profile', 'search', 'hashtag'
    String collection = 'posts', // NEW: Target collection
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    try {
      await _db.collection('users')
        .doc(userId)
        .collection('signals')
        .add({
          'type': type,
          'postId': postId,
          'authorId': authorId,
          'value': value,
          'source': source ?? 'feed', // Default to feed if unknown
          'timestamp': FieldValue.serverTimestamp(),
        });

      // --- NEW: Update Author Traffic Analytics ---
      if (authorId != null && (type == 'view' || type == 'click_link')) {
        String sourceKey = source ?? 'feed';
        _db.collection('users').doc(authorId).update({
          'trafficBreakdown.$sourceKey': FieldValue.increment(1)
        }).onError((_, __) => null);
      }


      // --- NEW: Increment Global Counters ---
      // We assume most interactions are on 'posts' collection for now. 
      // Ideally, we'd pass collection name or infer it.
      // For now, try updating 'posts'. If it fails (doc not found), it's fine.
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
  
  // Get recommendations based on specific content
  Future<List<DocumentSnapshot>> getSimilarPosts(String postId, {int limit = 10}) async {
    try {
      final postDoc = await _db.collection('posts').doc(postId).get();
      if (!postDoc.exists) return [];
      
      final postData = postDoc.data() as Map<String, dynamic>;
      final tags = List<String>.from(postData['smartTags'] ?? []);
      final category = postData['category'] ?? 'General';
      
      if (tags.isEmpty) return [];
      
      // Find posts with similar tags
      final similarPosts = <DocumentSnapshot>[];
      final seenIds = <String>{postId};
      
      for (final tag in tags.take(3)) { // Check top 3 tags
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