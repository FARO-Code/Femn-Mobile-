import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'petitions.dart';
import 'package:rxdart/rxdart.dart';

import 'polls.dart';

class TrackerScreen extends StatefulWidget {
  @override
  _TrackerScreenState createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFE1E0),
      appBar: AppBar(
        title: Text(
          'My Trackers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFE35773),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFFE35773)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: _buildAllTrackedItems(),
      ),
    );
  }

  // Add this method to your _TrackerScreenState class
  void showPetitionDetails(BuildContext context, Petition petition, bool isSigned) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedPetitionDetailScreen(petitionId: petition.id),
      ),
    );
  }

  Widget _buildAllTrackedItems() {
    return StreamBuilder<List<DocumentSnapshot>>(
      stream: _getCombinedTrackedItemsStream(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: Color(0xFFE35773)));
        }

        // Handle errors
        if (snapshot.hasError) {
          print('Error loading tracked items: ${snapshot.error}');
          return _buildErrorState('Error loading tracked items');
        }

        final allTrackedItems = snapshot.data ?? [];

        print('Found ${allTrackedItems.length} total tracked items');

        if (allTrackedItems.isEmpty) {
          return _buildEmptyState(
            icon: Icons.track_changes_rounded,
            title: 'No Tracked Items',
            subtitle: 'Your created and interacted petitions and polls will appear here',
          );
        }

        return MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: allTrackedItems.length,
          itemBuilder: (context, index) {
            final item = allTrackedItems[index];
            final itemType = item.reference.parent.id; // 'petitions' or 'polls'
            
            if (itemType == 'petitions') {
              final petition = Petition.fromDocument(item);
              final isCreated = petition.createdBy == _currentUserId;
              return _buildPetitionTrackerCard(petition, isCreated);
            } else if (itemType == 'polls') {
              final pollData = item.data() as Map<String, dynamic>;
              final isCreated = pollData['createdBy'] == _currentUserId;
              return _buildPollTrackerCard(item, isCreated);
            } else {
              return Container(); // Fallback
            }
          },
        );
      },
    );
  }

  Stream<List<DocumentSnapshot>> _getCombinedTrackedItemsStream() {
    // Define Firestore queries
    final createdPetitionsStream = _firestore
        .collection('petitions')
        .where('createdBy', isEqualTo: _currentUserId)
        .snapshots();

    final signedPetitionsStream = _firestore
        .collection('petitions')
        .where('signers', arrayContains: _currentUserId)
        .snapshots();

    final createdPollsStream = _firestore
        .collection('polls')
        .where('createdBy', isEqualTo: _currentUserId)
        .snapshots();

    final votedPollsStream = _firestore
        .collection('polls')
        .where('voters', arrayContains: _currentUserId)
        .snapshots();

    // Combine all four streams manually
    return Rx.combineLatest4<QuerySnapshot, QuerySnapshot, QuerySnapshot, QuerySnapshot, List<DocumentSnapshot>>(
      createdPetitionsStream,
      signedPetitionsStream,
      createdPollsStream,
      votedPollsStream,
      (createdPetitions, signedPetitions, createdPolls, votedPolls) {
        final allItems = <DocumentSnapshot>[];
        final seenIds = <String>{};

        void addDocs(List<DocumentSnapshot> docs, String prefix) {
          for (final doc in docs) {
            final id = '${prefix}_${doc.id}';
            if (!seenIds.contains(id)) {
              seenIds.add(id);
              allItems.add(doc);
            }
          }
        }

        addDocs(createdPetitions.docs, 'petition');
        addDocs(signedPetitions.docs, 'petition');
        addDocs(createdPolls.docs, 'poll');
        addDocs(votedPolls.docs, 'poll');

        // Sort newest first
        allItems.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'] as Timestamp;
          final bTime = bData['createdAt'] as Timestamp;
          return bTime.compareTo(aTime);
        });

        return allItems;
      },
    );
  }


  Widget _buildPetitionTrackerCard(Petition petition, bool isCreated) {
    final progress = petition.goal > 0 ? petition.currentSignatures / petition.goal : 0.0;
    final progressPercent = (progress * 100).toInt();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: () {
          showPetitionDetails(context, petition, petition.signers.contains(_currentUserId));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge for created/signed
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCreated ? Color(0xFFE35773) : Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCreated ? 'CREATED' : 'SIGNED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8),
              
              // Banner image
              if (petition.bannerImageUrl != null && petition.bannerImageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: petition.bannerImageUrl!,
                    height: 80,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Color(0xFFFFE1E0),
                      height: 80,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Color(0xFFFFE1E0),
                      height: 80,
                      child: Icon(Icons.error, color: Color(0xFFE35773)),
                    ),
                  ),
                ),
              
              SizedBox(height: 8),
              
              // Title
              Text(
                petition.title.length > 30 
                    ? '${petition.title.substring(0, 30)}...' 
                    : petition.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFE35773),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 6),
              
              // Progress bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Color(0xFFFFE1E0),
                color: Color(0xFFE35773),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              
              SizedBox(height: 6),
              
              // Progress text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE35773),
                    ),
                  ),
                  Text(
                    '${petition.currentSignatures}/${petition.goal}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 6),
              
              // Days ago
              Text(
                _getDaysAgo(petition.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollTrackerCard(DocumentSnapshot pollSnapshot, bool isCreated) {
    final pollData = pollSnapshot.data() as Map<String, dynamic>;
    final String question = pollData['question'] ?? '';
    final List<dynamic> options = pollData['options'] ?? [];
    final int totalVotes = pollData['totalVotes'] ?? 0;
    final List<dynamic> voters = pollData['voters'] ?? [];
    final Timestamp createdAt = pollData['createdAt'] ?? Timestamp.now();
    final Timestamp? expiresAt = pollData['expiresAt'];

    // Check if user has voted
    bool hasVoted = false;
    for (var voter in voters) {
      if (voter is Map<String, dynamic> && voter['userId'] == _currentUserId) {
        hasVoted = true;
        break;
      }
    }

    // Calculate days left
    int? daysLeft;
    if (expiresAt != null) {
      final now = DateTime.now();
      final expiration = expiresAt.toDate();
      daysLeft = expiration.difference(now).inDays;
      if (daysLeft < 0) daysLeft = 0;
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Colors.white,
      elevation: 2,
      child: InkWell(
        onTap: () {
          // You might want to create a showPollDetails function similar to showPetitionDetails
          _showPollDetails(context, pollSnapshot);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge for created/voted
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCreated ? Color(0xFFE35773) : (hasVoted ? Color(0xFF4CAF50) : Color(0xFF2196F3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCreated ? 'CREATED' : (hasVoted ? 'VOTED' : 'TRACKING'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 8),
              
              // Poll icon or first option image
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color(0xFFFFE1E0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildPollImage(options),
              ),
              
              SizedBox(height: 8),
              
              // Question
              Text(
                question.length > 30 
                    ? '${question.substring(0, 30)}...' 
                    : question,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFFE35773),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              SizedBox(height: 6),
              
              // Votes info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.poll, size: 16, color: Color(0xFFE35773)),
                  Text(
                    '$totalVotes votes',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE35773),
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 6),
              
              // Options count
              Text(
                '${options.length} options',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              
              SizedBox(height: 6),
              
              // Days info
              if (daysLeft != null && daysLeft > 0)
                Text(
                  '$daysLeft days left',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                )
              else if (daysLeft == 0)
                Text(
                  'Ended today',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[500],
                  ),
                )
              else
                Text(
                  _getDaysAgo(createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPollImage(List<dynamic> options) {
    // Try to find the first option with an image
    for (var option in options) {
      if (option is Map<String, dynamic> && option['imageUrl'] != null && option['imageUrl'].isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: option['imageUrl'],
            height: 80,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Color(0xFFFFE1E0),
            ),
            errorWidget: (context, url, error) => Container(
              color: Color(0xFFFFE1E0),
              child: Icon(Icons.poll, color: Color(0xFFE35773)),
            ),
          ),
        );
      }
    }
    
    // Fallback to poll icon
    return Center(
      child: Icon(Icons.poll, size: 40, color: Color(0xFFE35773)),
    );
  }

  void _showPollDetails(BuildContext context, DocumentSnapshot pollSnapshot) {
    // You can implement a detailed poll view similar to petition details
    // For now, we'll just show a simple dialog
    final pollData = pollSnapshot.data() as Map<String, dynamic>;
    final String question = pollData['question'] ?? '';
    final int totalVotes = pollData['totalVotes'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Poll Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Total Votes: $totalVotes'),
            // You can add more detailed poll information here
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getDaysAgo(Timestamp createdAt) {
    final now = DateTime.now();
    final created = createdAt.toDate();
    final difference = now.difference(created);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return '1 day ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Color(0xFFE35773).withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE35773),
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withOpacity(0.5),
          ),
          SizedBox(height: 16),
          Text(
            'Oops!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE35773),
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}