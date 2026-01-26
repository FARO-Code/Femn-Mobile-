import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/customization/colors.dart'; // <--- IMPORT YOUR COLORS FILE
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:femn/customization/layout.dart';
import 'groups.dart';

class DiscussionsScreen extends StatefulWidget {
  @override
  _DiscussionsScreenState createState() => _DiscussionsScreenState();
}

class _DiscussionsScreenState extends State<DiscussionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _currentUserId;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'General', 'Education', 'Health', 'Career', 'Relationships'];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  // Method to check if a discussion is archived
  bool _isDiscussionArchived(Map<String, dynamic> discussionData) {
    final Timestamp? expiresAt = discussionData['expiresAt'];
    if (expiresAt == null) return false;
    
    final DateTime expirationDate = expiresAt.toDate();
    return DateTime.now().isAfter(expirationDate);
  }

  // Method to get days left for a discussion
  int? _getDaysLeft(Map<String, dynamic> discussionData) {
    final Timestamp? expiresAt = discussionData['expiresAt'];
    if (expiresAt == null) return null;
    
    final DateTime expirationDate = expiresAt.toDate();
    final DateTime now = DateTime.now();
    
    if (now.isAfter(expirationDate)) return null;
    
    return expirationDate.difference(now).inDays;
  }

  // Method to get average rating for archived discussion
  double _getAverageRating(Map<String, dynamic> discussionData) {
    final Map<String, dynamic>? ratings = discussionData['ratings'];
    if (ratings == null || ratings.isEmpty) return 0.0;
    
    final double total = ratings.values.map((rating) => rating.toDouble()).reduce((a, b) => a + b);
    return total / ratings.length;
  }

  Widget _buildDiscussionsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('discussions')
          .where('isPrivate', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const GridShimmerSkeleton();
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.message_square, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                Text(
                  'No discussions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to start a discussion!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }
        
        final discussions = snapshot.data!.docs;
        
        // Filter by category
        final filteredDiscussions = _selectedCategory == 'All'
            ? discussions
            : discussions.where((discussion) {
                final discussionData = discussion.data() as Map<String, dynamic>;
                final String category = discussionData['category'] ?? 'General';
                return category == _selectedCategory;
              }).toList();
        
        // Filter out discussions user is already a member of
        final discoverDiscussions = filteredDiscussions.where((discussion) {
          final discussionData = discussion.data() as Map<String, dynamic>;
          final List<dynamic> members = discussionData['members'] ?? [];
          return !members.contains(_currentUserId);
        }).toList();
        
        if (discoverDiscussions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.search, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                Text(
                  'No discussions found in ${_selectedCategory == "All" ? "any category" : _selectedCategory}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                ),
                SizedBox(height: 8),
                Text(
                  'Try a different category or create your own discussion',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: discoverDiscussions.length,
            itemBuilder: (context, index) {
              final discussion = discoverDiscussions[index];
              final discussionData = discussion.data() as Map<String, dynamic>;
              final String discussionId = discussion.id;
              final String discussionName = discussionData['name'] ?? 'Untitled Discussion';
              final String discussionImage = discussionData['imageUrl'] ?? '';
              final int memberCount = discussionData['memberCount'] ?? 0;
              final String discussionDescription = discussionData['description'] ?? '';
              final String ageRating = discussionData['ageRating'] ?? '13-17';
              final List<dynamic> hashtagsList = discussionData['hashtags'] ?? [];
              final List<String> hashtags = hashtagsList.cast<String>();
              
              final bool isArchived = _isDiscussionArchived(discussionData);
              final int? daysLeft = isArchived ? null : _getDaysLeft(discussionData);
              
              final Map<String, dynamic> ratings = discussionData['ratings'] ?? {};
              double averageRating = 0;
              if (ratings.isNotEmpty) {
                averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
              }
              final int ratingCount = ratings.length;

              return Card(
                margin: EdgeInsets.zero,
                color: AppColors.surface, // Dark Card
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DiscussionViewScreen(
                          discussionId: discussionId,
                          onJoinSuccess: null,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: discussionImage.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: discussionImage,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Container(color: AppColors.elevation),
                                      errorWidget: (context, url, error) =>
                                          Icon(Feather.alert_circle, color: AppColors.error),
                                    )
                                  : Container(
                                      color: AppColors.elevation,
                                      child: Icon(Feather.message_square, color: AppColors.textDisabled),
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Feather.users, color: Colors.white, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    '$memberCount',
                                    style: TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Days left or Archived badge
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isArchived ? AppColors.textDisabled : AppColors.accentMustard,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isArchived ? 'Archived' : '$daysLeft days left',
                                style: TextStyle(
                                  color: AppColors.backgroundDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              discussionName,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textHigh),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.star_rounded, size: 16, color: AppColors.accentMustard),
                                SizedBox(width: 4),
                                Text(
                                  averageRating > 0 ? averageRating.toStringAsFixed(1) : '0.0',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textHigh),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "($ratingCount)",
                                  style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            if (hashtags.isNotEmpty)
                              SizedBox(
                                height: 20,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: hashtags.map((tag) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4.0),
                                      child: Text(
                                        '#$tag',
                                        style: TextStyle(fontSize: 11, color: AppColors.primaryLavender),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  discussionData['category'] ?? 'General',
                                  style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
                                ),
                                Text(
                                  ageRating,
                                  style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Discussions', style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Feather.search, color: AppColors.primaryLavender),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Category filter
          Container(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? category : 'All';
                      });
                    },
                    backgroundColor: AppColors.elevation,
                    selectedColor: AppColors.secondaryTeal,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textMedium,
                    ),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _buildDiscussionsGrid(),
          ),
        ],
      ),
    );
  }
}

class DiscussionViewScreen extends StatefulWidget {
  final String discussionId;
  final VoidCallback? onJoinSuccess;
  const DiscussionViewScreen({
    Key? key, 
    required this.discussionId, 
    this.onJoinSuccess
  }) : super(key: key);

  @override
  _DiscussionViewScreenState createState() => _DiscussionViewScreenState();
}

class _DiscussionViewScreenState extends State<DiscussionViewScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _currentUserId;
  late DocumentReference _discussionDocRef;
  bool _isMember = false;
  bool _isArchived = false;
  bool _isJoining = false;
  List<QueryDocumentSnapshot> _recentMessages = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    // --- ENSURE THIS POINTS TO 'discussions' ---
    _discussionDocRef = _firestore.collection('discussions').doc(widget.discussionId);
    _checkMembership();
    _checkIfArchived();
    _markMessagesAsRead();
    _loadRecentMessages();
  }

  Future<void> _loadRecentMessages() async {
    try {
      final messagesSnapshot = await _discussionDocRef
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();
      
      setState(() {
        _recentMessages = messagesSnapshot.docs;
      });
    } catch (e) {
      print("Error loading recent messages: $e");
    }
  }

  // Inside _DiscussionViewScreenState class (in discussions.dart)
  Future<void> _markMessagesAsRead() async {
    try {
      final discussionDoc = await _discussionDocRef.get();
      if (discussionDoc.exists) {
        final discussionData = discussionDoc.data() as Map<String, dynamic>?;
        if (discussionData == null) return;

        // Access the unreadCount map for the current user
        final Map<String, dynamic> unreadCountMap =
            discussionData['unreadCount'] ?? {};
        final int currentUnread = unreadCountMap[_currentUserId] ?? 0;

        // Only update if there are unread messages
        if (currentUnread > 0) {
          // Update the specific user's unread count within the map using dot notation
          await _discussionDocRef.update({
            'unreadCount.$_currentUserId': 0,
          });
        }
      }
    } catch (e) {
      print("Error marking messages as read: $e");
      // Optionally show a snackbar or handle the error
    }
  }

  Future<void> _checkMembership() async {
    final discussionDoc = await _discussionDocRef.get();
    if (discussionDoc.exists) {
      final discussionData = discussionDoc.data() as Map<String, dynamic>;
      final List<dynamic> members = discussionData['members'] ?? [];
      setState(() {
        _isMember = members.contains(_currentUserId);
      });
    }
  }

  Future<void> _checkIfArchived() async {
    final discussionDoc = await _discussionDocRef.get();
    if (discussionDoc.exists) {
      final discussionData = discussionDoc.data() as Map<String, dynamic>;
      final Timestamp? expiresAt = discussionData['expiresAt'];
      if (expiresAt != null) {
        final DateTime expirationDate = expiresAt.toDate();
        setState(() {
          _isArchived = DateTime.now().isAfter(expirationDate);
        });
      }
    }
  }

  Future<void> _joinDiscussion() async {
    if (_isJoining || _isMember || _isArchived) return;
    
    setState(() {
      _isJoining = true;
    });

    try {
      await _discussionDocRef.update({
        'members': FieldValue.arrayUnion([_currentUserId]),
        'memberCount': FieldValue.increment(1),
        'unreadCount.$_currentUserId': 0,
      });

      setState(() {
        _isMember = true;
        _isJoining = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Joined discussion successfully', style: TextStyle(color: AppColors.backgroundDeep)),
          backgroundColor: AppColors.success,
        ),
      );

      if (widget.onJoinSuccess != null) {
        widget.onJoinSuccess!();
      }
    } catch (e) {
      print("Error joining discussion: $e");
      setState(() {
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join discussion. Please try again.')),
      );
    }
  }

  Future<void> _rateDiscussion(double rating) async {
    try {
      await _discussionDocRef.update({
        'ratings.$_currentUserId': rating,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating submitted successfully', style: TextStyle(color: AppColors.backgroundDeep)),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      print("Error rating discussion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: _discussionDocRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Text('Discussion');
            final discussionData = snapshot.data!.data() as Map<String, dynamic>?;
            return Text(discussionData?['name'] ?? 'Discussion', style: TextStyle(color: AppColors.textHigh));
          },
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
        actions: [
          if (!_isMember && !_isArchived)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: _isJoining
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
                  : TextButton(
                      onPressed: _joinDiscussion,
                      child: Text('JOIN', style: TextStyle(color: AppColors.backgroundDeep, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryLavender,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
            ),
        ],
      ),
      body: _isMember 
          ? DiscussionChatScreen(discussionId: widget.discussionId)
          : _isArchived
              ? _buildArchivedDiscussionView()
              : _buildDiscussionPreview(),
    );
  }

  Widget _buildDiscussionPreview() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _discussionDocRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
        
        final discussionData = snapshot.data!.data() as Map<String, dynamic>?;
        if (discussionData == null) return Center(child: Text('Discussion not found'));
        
        final String description = discussionData['description'] ?? '';
        final List<dynamic> hashtags = discussionData['hashtags'] ?? [];
        final Map<String, dynamic> ratings = discussionData['ratings'] ?? {};
        
        double averageRating = 0;
        if (ratings.isNotEmpty) {
          averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
        }

        return Column(
          children: [
            // Enhanced Preview Header
                  Container(
                    padding: EdgeInsets.all(20),
                    margin: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primaryLavender.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLavender.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('PREVIEW MODE', 
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryLavender, letterSpacing: 1.2)),
                            ),
                            Spacer(),
                            if (averageRating > 0)
                              Row(
                                children: [
                                  Icon(Icons.star_rounded, color: AppColors.accentMustard, size: 18),
                                  SizedBox(width: 4),
                                  Text(averageRating.toStringAsFixed(1), 
                                    style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(' (${ratings.length})', 
                                    style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
                                ],
                              ),
                          ],
                        ),
                        SizedBox(height: 16),
                        if (description.isNotEmpty)
                          Text(description, 
                            style: TextStyle(color: AppColors.textHigh, fontSize: 15, height: 1.5, fontWeight: FontWeight.w500)),
                        if (hashtags.isNotEmpty) ...[
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: hashtags.map((tag) => Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [AppColors.primaryLavender.withOpacity(0.15), AppColors.primaryLavender.withOpacity(0.05)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.primaryLavender.withOpacity(0.1)),
                              ),
                              child: Text('#$tag', 
                                style: TextStyle(color: AppColors.primaryLavender, fontSize: 12, fontWeight: FontWeight.bold)),
                            )).toList(),
                          ),
                        ],
                        SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.elevation.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Feather.info, size: 14, color: AppColors.textDisabled),
                                SizedBox(width: 8),
                                Text('Join to participate in the conversation', 
                                  style: TextStyle(color: AppColors.textDisabled, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            // Chat Preview Area
            Expanded(
              child: ListView.builder(
                reverse: true, // Show most recent at bottom
                padding: EdgeInsets.symmetric(vertical: 16),
                itemCount: _recentMessages.length,
                itemBuilder: (context, index) {
                  final message = _recentMessages[index];
                  final messageData = message.data() as Map<String, dynamic>;
                  return _buildMessageItem(messageData);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> messageData) {
    final String senderId = messageData['senderId'] ?? '';
    final String text = messageData['text'] ?? '';
    final String type = messageData['type'] ?? 'text';
    final Timestamp? timestamp = messageData['timestamp'];
    final DateTime? messageTime = timestamp?.toDate();

    return FutureBuilder<Map<String, dynamic>>(
      future: UserProfileCache.getUserProfile(senderId),
      builder: (context, snapshot) {
        String senderName = 'User';
        String senderImage = '';
        if (snapshot.hasData) {
          senderName = snapshot.data!['name'] ?? 'User';
          senderImage = snapshot.data!['profileImage'] ?? '';
        }

        bool isMe = senderId == _currentUserId;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMe)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.elevation,
                  backgroundImage: senderImage.isNotEmpty ? CachedNetworkImageProvider(senderImage) : null,
                  child: senderImage.isEmpty ? Icon(Feather.user, size: 14, color: AppColors.textDisabled) : null,
                ),
              if (!isMe) SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(senderName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMedium)),
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isMe ? AppColors.primaryLavender : AppColors.elevation,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (type == 'image')
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: messageData['imageUrl'],
                                width: 200,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Text(text, style: TextStyle(color: isMe ? Colors.white : AppColors.textHigh, fontSize: 14)),
                          SizedBox(height: 2),
                          Text(
                            messageTime != null ? DateFormat.Hm().format(messageTime) : '',
                            style: TextStyle(fontSize: 9, color: isMe ? Colors.white.withOpacity(0.7) : AppColors.textDisabled),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchivedDiscussionView() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _discussionDocRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
        
        final discussionData = snapshot.data!.data() as Map<String, dynamic>?;
        if (discussionData == null) return Container();
        
        final double averageRating = _getAverageRating(discussionData);
        final bool hasRated = discussionData['ratings']?[_currentUserId] != null;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (discussionData['imageUrl'] != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: discussionData['imageUrl'],
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              SizedBox(height: 16),
              Text(
                discussionData['name'] ?? '',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
              SizedBox(height: 8),
              Text(
                discussionData['description'] ?? '',
                style: TextStyle(fontSize: 16, color: AppColors.textMedium),
              ),
              SizedBox(height: 16),
              Text(
                'This discussion has ended and is now archived.',
                style: TextStyle(fontSize: 14, color: AppColors.accentMustard, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: 16),
              if (averageRating > 0)
                Row(
                  children: [
                    Icon(Feather.star, color: Colors.amber, size: 20),
                    SizedBox(width: 4),
                    Text(
                      averageRating.toStringAsFixed(1),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '(${discussionData['ratings']?.length ?? 0} ratings)',
                      style: TextStyle(fontSize: 14, color: AppColors.textDisabled),
                    ),
                  ],
                ),
              SizedBox(height: 16),
              if (!hasRated)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rate this discussion:', style: TextStyle(color: AppColors.textHigh)),
                    SizedBox(height: 8),
                    Slider(
                      value: 5.0,
                      min: 1.0,
                      max: 10.0,
                      divisions: 9,
                      activeColor: AppColors.primaryLavender,
                      inactiveColor: AppColors.elevation,
                      onChanged: (value) {},
                      onChangeEnd: _rateDiscussion,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('1', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                        Text('5', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                        Text('10', style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                      ],
                    ),
                  ],
                ),
              SizedBox(height: 32),
              Text(
                'Discussion History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
              SizedBox(height: 16),
              Text(
                'Message history would be displayed here in a read-only format.',
                style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textDisabled),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getAverageRating(Map<String, dynamic> discussionData) {
    final Map<String, dynamic>? ratings = discussionData['ratings'];
    if (ratings == null || ratings.isEmpty) return 0.0;
    
    final double total = ratings.values.map((rating) => rating.toDouble()).reduce((a, b) => a + b);
    return total / ratings.length;
  }
}

class DiscussionChatScreen extends StatefulWidget {
  final String discussionId;
  const DiscussionChatScreen({Key? key, required this.discussionId}) : super(key: key);

  @override
  _DiscussionChatScreenState createState() => _DiscussionChatScreenState();
}

class _DiscussionChatScreenState extends State<DiscussionChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;
  late DocumentReference _discussionDocRef;
  bool _isMember = false;
  bool _isArchived = false;
  File? _imageToSend;
  File? _videoToSend;

  // Message reaction variables
  Map<String, String> _userReactions = {}; // messageId -> emoji

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _discussionDocRef = _firestore.collection('discussions').doc(widget.discussionId);
    _checkMembership();
    _checkIfArchived();
    _markMessagesAsRead();
  }

  Future<void> _checkMembership() async {
    final discussionDoc = await _discussionDocRef.get();
    if (discussionDoc.exists) {
      final discussionData = discussionDoc.data() as Map<String, dynamic>;
      final List<dynamic> members = discussionData['members'] ?? [];
      setState(() {
        _isMember = members.contains(_currentUserId);
      });
    }
  }

  Future<void> _checkIfArchived() async {
    final discussionDoc = await _discussionDocRef.get();
    if (discussionDoc.exists) {
      final discussionData = discussionDoc.data() as Map<String, dynamic>;
      final Timestamp? expiresAt = discussionData['expiresAt'];
      if (expiresAt != null) {
        final DateTime expirationDate = expiresAt.toDate();
        setState(() {
          _isArchived = DateTime.now().isAfter(expirationDate);
        });
      }
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final discussionDoc = await _discussionDocRef.get();
      if (!discussionDoc.exists) return;
      final discussionData = discussionDoc.data() as Map<String, dynamic>?;
      if (discussionData == null) return;
      final Map<String, dynamic> unreadCountMap = discussionData['unreadCount'] ?? {};
      final int currentUnread = unreadCountMap[_currentUserId] ?? 0;
      if (currentUnread > 0) {
        await _discussionDocRef.update({
          'unreadCount.$_currentUserId': 0,
        });
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

  Future<void> _pickImage() async {
    if (!_isMember || _isArchived) return;
    try {
      final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        _cropAndEditImage(File(pickedFile.path));
      }
    } catch (e) {
      print("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image. Please try again.')),
      );
    }
  }

  Future<void> _pickVideo() async {
    if (!_isMember || _isArchived) return;
    try {
      final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        _sendMessage(videoFile: File(pickedFile.path));
      }
    } catch (e) {
      print("Error picking video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick video. Please try again.')),
      );
    }
  }

  Future<void> _cropAndEditImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: AppColors.backgroundDeep,
            toolbarWidgetColor: AppColors.textHigh,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Edit Image',
          ),
        ],
      );
      if (croppedFile != null) {
        // Assume ImagePreviewScreen exists or is handled elsewhere
        // For refactoring, we'll just send directly to keep it simple, 
        // or you would navigate to your preview screen here.
        _sendMessage(imageFile: File(croppedFile.path));
      }
    } catch (e) {
      print("Error cropping image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit image. Please try again.')),
      );
    }
  }

  Future<void> _sendMessage({File? imageFile, File? videoFile, String? text}) async {
    if (!_isMember || _isArchived) return;
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && imageFile == null && videoFile == null) return;
    
    try {
      String? mediaUrl;
      String mediaType = 'text';
      
      if (imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('discussion_chats')
            .child(widget.discussionId)
            .child('images')
            .child('${Uuid().v4()}.jpg');
        await ref.putFile(imageFile);
        mediaUrl = await ref.getDownloadURL();
        mediaType = 'image';
      } else if (videoFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('discussion_chats')
            .child(widget.discussionId)
            .child('videos')
            .child('${Uuid().v4()}.mp4');
        await ref.putFile(videoFile);
        mediaUrl = await ref.getDownloadURL();
        mediaType = 'video';
      }

      final messageId = Uuid().v4();
      final timestamp = FieldValue.serverTimestamp();
      
      final messageData = {
        'id': messageId,
        'discussionId': widget.discussionId,
        'senderId': _currentUserId,
        'text': messageText,
        'mediaUrl': mediaUrl,
        'type': mediaType,
        'timestamp': timestamp,
        'reactions': {},
        'status': 'sent',
      };

      await _discussionDocRef.collection('messages').doc(messageId).set(messageData);
      
      final discussionUpdateData = {
        'lastMessage': mediaType == 'image' ? '📷 Image' : mediaType == 'video' ? '🎥 Video' : messageText,
        'lastMessageTime': timestamp,
        'lastMessageSender': _currentUserId,
      };

      await _discussionDocRef.update(discussionUpdateData);
      
      // Update unread counts for other members
      final discussionDoc = await _discussionDocRef.get();
      if (discussionDoc.exists) {
        final discussionData = discussionDoc.data() as Map<String, dynamic>;
        final List<dynamic> members = discussionData['members'] ?? [];
        final Map<String, dynamic> unreadCountMap = discussionData['unreadCount'] ?? {};
        
        for (var memberId in members) {
          if (memberId != _currentUserId) {
            final currentCount = unreadCountMap[memberId] ?? 0;
            unreadCountMap[memberId] = currentCount + 1;
          }
        }
        await _discussionDocRef.update({'unreadCount': unreadCountMap});
      }

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  Future<void> _reactToMessage(String messageId, String emoji) async {
    try {
      final messageRef = _discussionDocRef.collection('messages').doc(messageId);
      final messageDoc = await messageRef.get();
      
      if (messageDoc.exists) {
        final messageData = messageDoc.data() as Map<String, dynamic>;
        final Map<String, dynamic> reactions = Map<String, dynamic>.from(messageData['reactions'] ?? {});
        
        // Remove user's previous reaction if any
        reactions.removeWhere((key, value) => value['userId'] == _currentUserId);
        
        // Add new reaction
        reactions[Uuid().v4()] = {
          'userId': _currentUserId,
          'emoji': emoji,
          'timestamp': FieldValue.serverTimestamp(),
        };
        
        await messageRef.update({'reactions': reactions});
      }
    } catch (e) {
      print("Error reacting to message: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showReactionMenu(String messageId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '😡'];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _reactToMessage(messageId, emoji);
                },
                child: Text(emoji, style: TextStyle(fontSize: 24)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Discussion info header
          StreamBuilder<DocumentSnapshot>(
            stream: _discussionDocRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();
              final discussionData = snapshot.data!.data() as Map<String, dynamic>?;
              final String discussionName = discussionData?['name'] ?? 'Discussion';
              final String discussionImage = discussionData?['imageUrl'] ?? '';
              final int memberCount = discussionData?['memberCount'] ?? 0;
              final int? daysLeft = discussionData != null ? getDaysLeft(discussionData) : null;
              final bool isArchived = discussionData != null ? isDiscussionArchived(discussionData) : false;

              final Map<String, dynamic> ratings = discussionData?['ratings'] ?? {};
              double averageRating = 0;
              if (ratings.isNotEmpty) {
                averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
              }
              final int ratingCount = ratings.length;

              return Container(
                padding: EdgeInsets.all(16),
                color: AppColors.surface,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.elevation,
                      backgroundImage: discussionImage.isNotEmpty
                          ? CachedNetworkImageProvider(discussionImage)
                          : AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            discussionName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.textHigh,
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                isArchived 
                                  ? 'Archived' 
                                  : daysLeft != null 
                                    ? '$daysLeft days left' 
                                    : '$memberCount members',
                                style: TextStyle(
                                  color: isArchived ? AppColors.textDisabled : AppColors.secondaryTeal,
                                  fontSize: 14,
                                ),
                              ),
                              if (averageRating > 0) ...[
                                SizedBox(width: 8),
                                Icon(Icons.star_rounded, size: 14, color: AppColors.accentMustard),
                                SizedBox(width: 4),
                                Text(
                                  averageRating.toStringAsFixed(1),
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "($ratingCount)",
                                  style: TextStyle(fontSize: 11, color: AppColors.textDisabled),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    if (_isMember && !_isArchived)
                      PopupMenuButton<String>(
                        icon: Icon(Feather.more_vertical, color: AppColors.primaryLavender),
                        onSelected: (value) async {
                          if (value == 'rate') {
                            final double? rating = await showDialog<double>(
                              context: context,
                              builder: (context) => _RatingDialog(),
                            );
                            if (rating != null) {
                              _rateDiscussion(rating);
                            }
                          } else if (value == 'leave') {
                            // Implement leave logic if needed
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'rate',
                            child: ListTile(
                              leading: Icon(Feather.star, color: AppColors.primaryLavender),
                              title: Text('Rate Discussion', style: TextStyle(color: AppColors.textHigh)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'leave',
                            child: ListTile(
                              leading: Icon(Feather.log_out, color: AppColors.error),
                              title: Text('Leave Discussion', style: TextStyle(color: AppColors.error)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
          // Messages list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _discussionDocRef
                  .collection('messages')
                  .orderBy('timestamp', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
                }
                final messages = snapshot.data!.docs;
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final messageData = message.data() as Map<String, dynamic>;
                    final String messageId = message.id;
                    final String senderId = messageData['senderId'];
                    final String text = messageData['text'] ?? '';
                    final String type = messageData['type'] ?? 'text';
                    final String? mediaUrl = messageData['mediaUrl'];
                    final Timestamp? timestamp = messageData['timestamp'];
                    final Map<String, dynamic> reactions = messageData['reactions'] ?? {};
                    final bool isMe = senderId == _currentUserId;
                    final DateTime? messageTime = timestamp?.toDate();
                    
                    return GestureDetector(
                      onLongPress: _isArchived ? () => _showReactionMenu(messageId) : null,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          children: [
                            if (!isMe)
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: AppColors.elevation,
                                child: Icon(Feather.user, size: 16, color: AppColors.textMedium),
                              ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    constraints: BoxConstraints(
                                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                                    ),
                                    decoration: BoxDecoration(
                                      // Me = Teal (White Text), Other = Elevation (Off-White Text)
                                      color: isMe ? AppColors.secondaryTeal : AppColors.elevation,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 2,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (type == 'image' && mediaUrl != null)
                                          _buildImageMessage(mediaUrl, text),
                                        if (type == 'video' && mediaUrl != null)
                                          _buildVideoMessage(mediaUrl, text),
                                        if (type == 'text' && text.isNotEmpty)
                                          Text(
                                            text,
                                            style: TextStyle(
                                              // Teal bubble needs white, Elevation bubble needs textHigh
                                              color: isMe ? Colors.white : AppColors.textHigh
                                            ),
                                          ),
                                        SizedBox(height: 4),
                                        if (messageTime != null)
                                          Text(
                                            DateFormat.Hm().format(messageTime),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe ? Colors.white70 : AppColors.textDisabled,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Reactions
                                  if (reactions.isNotEmpty)
                                    Container(
                                      margin: EdgeInsets.only(top: 4),
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.elevation),
                                      ),
                                      child: Wrap(
                                        spacing: 4,
                                        children: _buildReactionWidgets(reactions),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isMe) SizedBox(width: 8),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Message input area (only show if not archived)
          if (_isMember && !_isArchived)
            Container(
              padding: EdgeInsets.all(8),
              color: AppColors.surface,
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Feather.image, color: AppColors.primaryLavender),
                    onPressed: _pickImage,
                  ),
                  IconButton(
                    icon: Icon(Feather.video, color: AppColors.primaryLavender),
                    onPressed: _pickVideo,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: AppColors.textHigh),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.elevation,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Feather.send, color: AppColors.primaryLavender),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildReactionWidgets(Map<String, dynamic> reactions) {
    // Group reactions by emoji
    final Map<String, int> emojiCounts = {};
    final Map<String, String> userEmojis = {};
    
    reactions.forEach((key, value) {
      final String emoji = value['emoji'];
      final String userId = value['userId'];
      
      emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
      if (userId == _currentUserId) {
        userEmojis[userId] = emoji;
      }
    });
    
    return emojiCounts.entries.map((entry) {
      final String emoji = entry.key;
      final int count = entry.value;
      final bool isMyReaction = userEmojis.containsValue(emoji);
      
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: isMyReaction ? AppColors.primaryLavender.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMyReaction ? AppColors.primaryLavender : AppColors.textDisabled,
          ),
        ),
        child: Text(
          '$emoji $count',
          style: TextStyle(fontSize: 12, color: AppColors.textMedium),
        ),
      );
    }).toList();
  }

  Widget _buildImageMessage(String imageUrl, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            // Navigator.push(...) to ImageViewer
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 200,
                height: 200,
                color: AppColors.elevation,
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200,
                height: 200,
                color: AppColors.elevation,
                child: Icon(Feather.alert_circle, color: AppColors.error),
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              caption,
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoMessage(String videoUrl, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            // Implement video player
          },
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.black, // Videos look best on black
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(Feather.play_circle, size: 50, color: Colors.white),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Text(
                    'Video',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              caption,
              style: TextStyle(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Future<void> _rateDiscussion(double rating) async {
    try {
      await _discussionDocRef.update({
        'ratings.$_currentUserId': rating,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rating submitted successfully', style: TextStyle(color: AppColors.backgroundDeep)),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      print("Error rating discussion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating. Please try again.')),
      );
    }
  }
}

class _RatingDialog extends StatefulWidget {
  @override
  __RatingDialogState createState() => __RatingDialogState();
}

class __RatingDialogState extends State<_RatingDialog> {
  double _currentRating = 5.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Rate Discussion', style: TextStyle(color: AppColors.textHigh)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Feather.star, color: Colors.amber, size: 24),
              SizedBox(width: 8),
              Text(
                _currentRating.round().toString(),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
            ],
          ),
          Slider(
            value: _currentRating,
            min: 1.0,
            max: 10.0,
            divisions: 9,
            activeColor: AppColors.primaryLavender,
            inactiveColor: AppColors.elevation,
            onChanged: (value) {
              setState(() {
                _currentRating = value;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
              Text('10', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.textMedium)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _currentRating),
          child: Text('Submit', style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// Helper function to check if discussion is archived
bool isDiscussionArchived(Map<String, dynamic> discussionData) {
  final Timestamp? expiresAt = discussionData['expiresAt'];
  if (expiresAt == null) return false;
  
  final DateTime expirationDate = expiresAt.toDate();
  return DateTime.now().isAfter(expirationDate);
}

// Helper function to get days left
int? getDaysLeft(Map<String, dynamic> discussionData) {
  final Timestamp? expiresAt = discussionData['expiresAt'];
  if (expiresAt == null) return null;
  
  final DateTime expirationDate = expiresAt.toDate();
  final DateTime now = DateTime.now();
  
  if (now.isAfter(expirationDate)) return null;
  
  return expirationDate.difference(now).inDays;
}
