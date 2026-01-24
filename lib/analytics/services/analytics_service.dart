import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/analytics_models.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<AnalyticsDashboardData> fetchDashboardData(int days) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    final uid = user.uid;

    // 1. Fetch User Data (Followers, Embers)
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    
    // Followers & Visits
    final followersList = List<String>.from(userData['followers'] ?? []);
    final int totalFollowers = followersList.length;
    final int profileVisits = (userData['profileVisits'] as int?) ?? 0;
    
    // Embers (Earnings)
    final int totalEmbers = (userData['embers'] as int?) ?? 0;

    // 2. Fetch Content (Posts, Petitions, Polls)
    List<ContentPerformance> allContent = [];
    int totalViews = 0;
    int totalLikes = 0;
    int sumComments = 0;
    int totalShares = 0;
    int totalSaves = 0;
    int totalLinkClicks = 0;
    List<CampaignStats> campaigns = [];

    // --- A. POSTS ---
    final postsSnap = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();

    for (var doc in postsSnap.docs) {
      final data = doc.data();
      final likes = (data['likes'] as List?)?.length ?? 0;
      final comments = (data['commentsCount'] as int?) ?? 0; 
      final views = (data['views'] as int?) ?? 0;
      final shares = (data['shares'] as int?) ?? 0; // New
      final saves = (data['saves'] as int?) ?? 0;   // New
      final linkClicks = (data['linkClicks'] as int?) ?? 0; // New
      
      totalViews += views;
      totalLikes += likes;
      sumComments += comments;
      totalShares += shares;
      totalSaves += saves;
      totalLinkClicks += linkClicks;

      allContent.add(ContentPerformance(
        id: doc.id,
        title: data['description'] ?? 'Untitled Post',
        type: 'post',
        thumbnailUrl: data['thumbnailUrl'] ?? data['imageUrl'] ?? '',
        views: views,
        likes: likes,
        comments: comments,
        shares: shares,
        saves: saves,
        linkClicks: linkClicks,
        postedAt: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        originalDoc: doc,
      ));
    }

    // --- B. PETITIONS (Campaigns) ---
    final petitionsSnap = await _firestore
        .collection('petitions')
        .where('createdBy', isEqualTo: uid)
        .get();

    for (var doc in petitionsSnap.docs) {
      final data = doc.data();
      final sigs = (data['currentSignatures'] as int?) ?? 0;
      final goal = (data['goal'] as int?) ?? 1000;
      final banner = data['bannerImageUrl'] ?? data['imageUrl'] ?? '';
      
      campaigns.add(CampaignStats(
        campaignId: doc.id,
        title: data['title'] ?? 'Petition',
        signatures: sigs,
        goal: goal,
        progress: goal > 0 ? sigs / goal : 0.0,
      ));

      allContent.add(ContentPerformance(
        id: doc.id,
        title: data['title'] ?? 'Petition',
        type: 'petition',
        thumbnailUrl: banner,
        views: (data['views'] as int?) ?? 0, // FIXED: Use actual views
        likes: (data['signers'] as List?)?.length ?? 0, 
        comments: 0,
        shares: (data['shares'] as int?) ?? 0,
        saves: 0,
        linkClicks: 0,
        postedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        originalDoc: doc,
      ));
    }

    // --- C. POLLS ---
    final pollsSnap = await _firestore
        .collection('polls')
        .where('createdBy', isEqualTo: uid)
        .get();

    for (var doc in pollsSnap.docs) {
      final data = doc.data();
      final options = data['options'] as List? ?? [];
      int totalVotes = 0;
      for (var opt in options) {
        totalVotes += (opt['votes'] as int?) ?? 0;
      }

      allContent.add(ContentPerformance(
        id: doc.id,
        title: data['question'] ?? 'Poll',
        type: 'poll',
        thumbnailUrl: data['imageUrl'] ?? '',
        views: totalVotes,
        likes: (data['voters'] as List?)?.length ?? 0,
        comments: 0, 
        shares: (data['shares'] as int?) ?? 0,
        saves: 0,
        linkClicks: 0,
        postedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        originalDoc: doc,
      ));
    }

    // 3. Sort & Aggregates
    allContent.sort((a, b) => b.views.compareTo(a.views));
    final topContent = allContent.take(5).toList();

    // Weighted Engagement Rate
    // (Likes*1 + Comments*2 + Shares*3 + Saves*3) / Views * 100
    double engagementRate = 0.0;
    if (totalViews > 0) {
      double weightedScore = (totalLikes * 1.0) + (sumComments * 2.0) + (totalShares * 3.0) + (totalSaves * 3.0);
      engagementRate = (weightedScore / totalViews) * 100;
    }

    // 4. Demographics (Sampling)
    final audienceData = await _fetchDemographics(followersList);

    // 5. Growth History (Snapshot)
    List<GrowthPoint> followerGrowth = []; 
    followerGrowth.add(GrowthPoint(DateTime.now(), totalFollowers));

    // 6. Deep Analytics (Traffic, Geo, Funnel)
    final deepStats = await _fetchDeepAnalytics(uid, allContent);

    return AnalyticsDashboardData(
      overview: OverviewStats(
        totalFollowers: totalFollowers,
        followersGained: 0,
        totalViews: totalViews,
        totalLikes: totalLikes,
        totalComments: sumComments,
        totalShares: totalShares,
        profileVisits: profileVisits, // Real data
        engagementRate: engagementRate,
      ),
      followerGrowth: followerGrowth,
      topContent: topContent,
      audience: audienceData,
      engagement: EngagementMetrics( 
        likeToCommentRatio: sumComments > 0 ? totalLikes / sumComments : 0,
        responseRate: 0, 
      ),
      campaigns: campaigns,
      revenue: RevenueData(
        totalEmbers: totalEmbers,
        fromContent: 0,
        fromPartnerships: 0,
        earnedHistory: [],
      ),
      benchmarks: [], 
      deepStats: deepStats,
    );
  }

  Future<AudienceData> _fetchDemographics(List<String> followerIds) async {
    // Sample first 50 followers to save reads/performance
    final sampleIds = followerIds.take(50).toList();
    if (sampleIds.isEmpty) {
      return AudienceData(ageGroups: [], genderBreakdown: [], topLocations: [], activityByHour: []);
    }

    Map<String, int> genderCount = {};
    Map<String, int> ageCount = {};

    // Firestore allows 'IN' queries up to 10-30 items (we'll do batch of 10)
    // Actually fetching individually might be simpler for logic, or chunking.
    // Let's iterate fetches safely (Parallel futures)
    
    // Chunking to batches of 10
    List<Future<QuerySnapshot>> futures = [];
    for (var i = 0; i < sampleIds.length; i += 10) {
      var end = (i + 10 < sampleIds.length) ? i + 10 : sampleIds.length;
      var batch = sampleIds.sublist(i, end);
      if (batch.isNotEmpty) {
        futures.add(_firestore.collection('users').where(FieldPath.documentId, whereIn: batch).get());
      }
    }

    final snapshots = await Future.wait(futures);

    for (var snap in snapshots) {
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Gender
        String gender = data['gender'] ?? 'Unknown';
        if (gender.isEmpty) gender = 'Unknown';
        genderCount[gender] = (genderCount[gender] ?? 0) + 1;

        // Age
        if (data['dateOfBirth'] != null) {
          DateTime dob = (data['dateOfBirth'] as Timestamp).toDate();
          int age = DateTime.now().year - dob.year;
          String bucket = _getAgeBucket(age);
          ageCount[bucket] = (ageCount[bucket] ?? 0) + 1;
        } else {
          ageCount['Unknown'] = (ageCount['Unknown'] ?? 0) + 1;
        }
      }
    }

    // Convert to Percentages
    int totalSample = sampleIds.length; // Actually count docs found?
    // Better to use actual docs count
    int fetchedDocs = snapshots.fold(0, (sum, snap) => sum + snap.docs.length);
    if (fetchedDocs == 0) fetchedDocs = 1;

    List<AudienceDemographic> genderList = genderCount.entries.map((e) {
      return AudienceDemographic(e.key, (e.value / fetchedDocs) * 100);
    }).toList();

    List<AudienceDemographic> ageList = ageCount.entries.map((e) {
      return AudienceDemographic(e.key, (e.value / fetchedDocs) * 100);
    }).toList();

    return AudienceData(
      ageGroups: ageList,
      genderBreakdown: genderList,
      topLocations: [], // Adding location requires checking specific field availability
      activityByHour: [],
    );
  }

  // --- DEEP ANALYTICS ---
  Future<DeepAnalyticsData> _fetchDeepAnalytics(String uid, List<ContentPerformance> allContent) async {
    // 1. Traffic Sources (from aggregated map)
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> breakdown = userData['trafficBreakdown'] ?? {};
    
    Map<String, int> sourceCounts = {};
    int totalVisits = 0;
    
    breakdown.forEach((key, value) {
      if (value is int) {
        sourceCounts[key] = value;
        totalVisits += value;
      }
    });
    
    // Sort keys and format for UI
    List<TrafficSourceData> trafficSources = sourceCounts.entries.map((e) {
      String label = e.key;
      // Capitalize first letter or map to friendly names
      if (label == 'feed') label = 'For You Feed';
      if (label == 'profile') label = 'Profile Visits';
      if (label == 'search') label = 'Search';
      if (label == 'hashtag') label = 'Hashtags';
      
      return TrafficSourceData(
        label, 
        e.value, 
        totalVisits > 0 ? (e.value / totalVisits) * 100 : 0
      );
    }).toList();
    
    trafficSources.sort((a, b) => b.visits.compareTo(a.visits));

    
    // 2. Geo Impact (Petitions)
    // Filter petitions from allContent
    final petitions = allContent.where((c) => c.type == 'petition').toList();
    List<GeoImpactData> geoImpact = [];
    
    if (petitions.isNotEmpty) {
      // Sample up to 50 signers from the most popular petition
      // (Fetching ALL signers for ALL petitions is too heavy)
      final topPetition = petitions.first;
      // We need to fetch the actual petition doc to get the signers list
      // ContentPerformance has originalDoc, but let's be safe
      if (topPetition.originalDoc != null) {
        final data = topPetition.originalDoc!.data() as Map<String, dynamic>;
        final List signers = data['signers'] ?? [];
        final sampleSigners = signers.take(50).toList(); // List of UIDs
        
        if (sampleSigners.isNotEmpty) {
           // Batch fetch users
           // Reuse demographic logic pattern
           Map<String, int> regionCounts = {};
           int regionTotal = 0;
           
           List<Future<QuerySnapshot>> futures = [];
           for (var i = 0; i < sampleSigners.length; i += 10) {
             var end = (i + 10 < sampleSigners.length) ? i + 10 : sampleSigners.length;
             var batch = sampleSigners.sublist(i, end);
             if (batch.isNotEmpty) {
                futures.add(_firestore.collection('users').where(FieldPath.documentId, whereIn: batch).get());
             }
           }
           
           final snapshots = await Future.wait(futures);
           for (var snap in snapshots) {
             for (var doc in snap.docs) {
               final userData = doc.data() as Map<String, dynamic>;
               String region = userData['region'] ?? userData['country'] ?? 'Unknown';
               regionCounts[region] = (regionCounts[region] ?? 0) + 1;
               regionTotal++;
             }
           }
           
           if (regionTotal > 0) {
             geoImpact = regionCounts.entries.map((e) {
               return GeoImpactData(e.key, e.value, (e.value / regionTotal) * 100);
             }).toList();
           }
        }
      }
    }

    // 3. Petition Funnel
    // Aggregated from all petitions
    int totalPetitionViews = 0;
    int totalSignatures = 0;
    int totalPetitionShares = 0;
    
    for (var p in petitions) {
      totalPetitionViews += p.views;
      totalSignatures += p.likes; // We mapped signatures to 'likes' field in ContentPerformance
      totalPetitionShares += p.shares;
    }
    
    List<PetitionFunnelData> funnel = [
      PetitionFunnelData("Views", totalPetitionViews, 100.0),
      PetitionFunnelData("Signatures", totalSignatures, totalPetitionViews > 0 ? (totalSignatures / totalPetitionViews) * 100 : 0),
      PetitionFunnelData("Shares", totalPetitionShares, totalSignatures > 0 ? (totalPetitionShares / totalSignatures) * 100 : 0),
    ];
    
    // 4. Community/Groups Performance
    // Fetch groups owned by user
    List<CommunityStats> communities = [];
    try {
      final groupSnap = await _firestore.collection('groups')
          .where('createdBy', isEqualTo: uid)
          .limit(5)
          .get();
          
      for (var doc in groupSnap.docs) {
        final data = doc.data();
        communities.add(CommunityStats(
          doc.id,
          data['name'] ?? 'Untitled Group',
          (data['memberCount'] as int?) ?? 0
        ));
      }
    } catch (e) {
      print("Error fetching groups: $e");
    }

    return DeepAnalyticsData(
      trafficSources: trafficSources,
      geoImpact: geoImpact,
      petitionFunnel: funnel,
      communityPerformance: communities,
    );
  }

  String _getAgeBucket(int age) {
    if (age < 18) return '13-17';
    if (age <= 24) return '18-24';
    if (age <= 34) return '25-34';
    if (age <= 44) return '35-44';
    if (age <= 54) return '45-54';
    return '55+';
  }
}
