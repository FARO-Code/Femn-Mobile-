import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth.dart';
import 'package:femn/discussions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'addpost.dart';
import 'package:femn/profile.dart';
import 'package:femn/search.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import 'petitions.dart';
import 'polls.dart'; 
import 'package:collection/collection.dart'; // For comparing lists (though not directly used in current code)
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

const Color primaryPink = Color(0xFFE56982); // Updated to #e56982
const Color lightPink = Color(0xFFFFE1E0); // Updated to #ffe1e0
const Color darkPink = Color(0xFFFFB7C5); // Updated to #ffb7c5
const Color bgWhite = Color(0xFFFFE1E0); // Updated to #ffe1e0
const Color cardWhite = Color(0xFFFFFFFF);
const Color outgoingBubble = Color(0xFFFFCDD2);
const Color incomingBubble = Colors.white;

const Map<String, IconData> _optionIcons = {
  'Polls': Icons.poll,
  'Discussions': Icons.forum,
  'Groups': Icons.group,
  'Mentorship': Icons.school,
  'Petitions': Icons.how_to_vote,
};

// Import necessary packages if not already imported elsewhere in your file
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

class UserProfileCache {
  // Private static cache map to store user data
  static final Map<String, Map<String, dynamic>> _cache = {};

  // Private constructor to prevent instantiation
  UserProfileCache._();

  /// Fetches user profile data, prioritizing cache, then Firestore.
  /// Ensures a consistent data structure is returned.
  static Future<Map<String, dynamic>> getUserProfile(String userId) async {
    debugPrint("UserProfileCache.getUserProfile: Requesting profile for user ID: '$userId'");

    // 1. Check if data is already in the cache
    if (_cache.containsKey(userId)) {
      final cachedData = _cache[userId]!;
      debugPrint("UserProfileCache.getUserProfile: Found in cache. Data: $cachedData");
      return cachedData;
    }

    // 2. If not in cache, fetch from Firestore
    try {
      final docSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();

      Map<String, dynamic> userData;
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        userData = {
          'uid': userId,
          'name': data['name'] ?? data['username'] ?? 'User',
          'profileImage': data['profileImage'] ?? data['photoUrl'] ?? '',
        };
        debugPrint("UserProfileCache: fetched & processed data for $userId: $userData");
      } else {
        userData = {
          'uid': userId,
          'name': 'User',
          'profileImage': '',
        };
        debugPrint("UserProfileCache: $userId doc missing, using default.");
      }

      // Cache and return
      _cache[userId] = userData;
      return userData;
    } catch (e) {
      debugPrint("UserProfileCache: Error fetching $userId -> $e");
      final fallback = {
        'uid': userId,
        'name': 'User',
        'profileImage': '',
      };
      _cache[userId] = fallback;
      return fallback;
    }
  }

  /// Preloads profiles for a list of user IDs, fetching only those not already cached.
  static Future<void> preloadUserProfiles(List<String> userIds) async {
    final idsToFetch = userIds.toSet().where((id) => !_cache.containsKey(id)).toList();
    if (idsToFetch.isEmpty) {
      debugPrint("UserProfileCache: nothing new to preload.");
      return;
    }

    try {
      final futures = idsToFetch
          .map((id) => FirebaseFirestore.instance.collection('users').doc(id).get())
          .toList();
      final snapshots = await Future.wait(futures);

      for (int i = 0; i < idsToFetch.length; i++) {
        final userId = idsToFetch[i];
        final docSnapshot = snapshots[i];

        Map<String, dynamic> userData;
        if (docSnapshot.exists) {
          final data = docSnapshot.data()!;
          userData = {
            'uid': userId,
            'name': data['name'] ?? data['username'] ?? 'User',
            'profileImage': data['profileImage'] ?? data['photoUrl'] ?? '',
          };
        } else {
          userData = {
            'uid': userId,
            'name': 'User',
            'profileImage': '',
          };
        }

        _cache[userId] = userData;
        debugPrint("UserProfileCache: preloaded $userId -> $userData");
      }
    } catch (e) {
      debugPrint("UserProfileCache: preload error -> $e");
    }
  }

  /// Clears the cache
  static void clearCache() {
    _cache.clear();
    debugPrint("UserProfileCache: cache cleared.");
  }

  /// Returns cached profile immediately (null if not cached yet).
  static Map<String, dynamic>? getCachedProfile(String userId) {
    return _cache[userId];
  }
}

class GroupsScreen extends StatefulWidget {
  @override
  _GroupsScreenState createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isPrivate = false;
  File? _groupImage;
  late String _currentUserId;
  String _selectedCategory = 'All';
  final List<String> _contentTypes = ['All', 'Groups', 'Polls', 'Discussions', 'Petitions'];
  int _selectedContentTypeIndex = 0; // 0 corresponds to 'Groups'
  String _searchQuery = '';

  String _selectedAgeRating = '13-17'; // Default age rating
  final List<String> _ageRatings = ['13-17', '18-25', '26+'];
  List<String> _hashtags = []; // Store hashtags
  final TextEditingController _hashtagController = TextEditingController();

  String get _currentContentType {
    return _contentTypes[_selectedContentTypeIndex];
  }

  

  final List<String> _categories = [
    'All',
    'Polls',
    'Discussions',
    'Groups',
    'Mentorship',
    'Petitions'
  ];
  final Map<String, String> _categoryIcons = {
    'Polls': '',
    'Discussions': '',
    'Groups': '',
    'Mentorship': '',
    'Petitions': '',
  };

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  Future<void> _pickGroupImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _groupImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadGroupImage() async {
    if (_groupImage == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('group_images')
          .child('${Uuid().v4()}.jpg');
      await ref.putFile(_groupImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading group image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image. Please try again.')),
      );
      return null;
    }
  }

  // Add this method to your _GroupsScreenState class
  void showPetitionDetails(BuildContext context, Petition petition, bool isSigned) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedPetitionDetailScreen(petitionId: petition.id),
      ),
    );
  }

  // Add this method to your _GroupsScreenState class
  void showCreatePetitionModal(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedPetitionCreationScreen(),
      ),
    );
  }

  // Add these methods to your _GroupsScreenState class

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

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty ||
        _groupDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title and Description are required.')),
      );
      return;
    }
    final groupName = _groupNameController.text.trim();
    final groupDescription = _groupDescriptionController.text.trim();
    final imageUrl = await _uploadGroupImage();

    try {
      final groupId = Uuid().v4();
      final timestamp = FieldValue.serverTimestamp();
      
      // Create base group data
      final groupData = {
        'id': groupId,
        'name': groupName,
        'description': groupDescription,
        'imageUrl': imageUrl ?? '',
        'isPrivate': _isPrivate,
        'createdBy': _currentUserId,
        'createdAt': timestamp,
        'members': [_currentUserId],
        'admins': [_currentUserId],
        'moderators': [],
        'memberCount': 1,
        'lastMessage': '',
        'lastMessageTime': timestamp,
        'lastMessageSender': '',
        'unreadCount': {_currentUserId: 0},
        'category': _selectedCategory != 'All' ? _selectedCategory : 'General',
        'isReadOnly': false,
        'profanityFilter': true,
        'linkRestrictions': false,
        'typing': {},
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
      };

      // Add expiration for discussions
      // Add expiration for discussions
      if (_selectedCategory == 'Discussions') {
        final expiresAt = DateTime.now().add(Duration(days: 7));
        groupData['expiresAt'] = Timestamp.fromDate(expiresAt);
        groupData['isTemporary'] = true;
      }

      await _firestore.collection('groups').doc(groupId).set(groupData);

      // Reset form including new fields
      _groupNameController.clear();
      _groupDescriptionController.clear();
      _hashtagController.clear();
      setState(() {
        _groupImage = null;
        _isPrivate = false;
        _selectedAgeRating = '13-17';
        _selectedCategory = 'All';
        _hashtags.clear();
      });

      // Navigate to the new group chat
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(groupId: groupId),
        ),
      );
    } catch (e) {
      print("Error creating group: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group. Please try again.')),
      );
    }
  }

    // --- Add this new method ---
// Modified _buildAllTab method with shuffling















Widget _buildAllTab() {
  // Singular control variables for widths and paddings
  const double externalPadding = 20.0; // Horizontal padding for the entire grid
  const double cardSpacing = 8.0; // Spacing between cards
  const double cardInternalPadding = 12.0; // Padding inside each card
  const double cardMarginVertical = 2.0; // Vertical margin for cards
  const double cardMarginHorizontal = 2.0; // Horizontal margin for cards
  const double borderRadiusValue = 24.0; // Border radius for all cards


  return FutureBuilder<List<QuerySnapshot>>(
    // Fetch snapshots from all relevant collections simultaneously
    future: Future.wait([
      _firestore.collection('groups').where('isPrivate', isEqualTo: false).get(),
      _firestore.collection('polls').get(),
      _firestore.collection('groups')
          .where('category', isEqualTo: 'Discussions')
          .where('isPrivate', isEqualTo: false)
          .get(), // Re-fetch discussions if needed separately or filter later
      _firestore.collection('petitions').get(),
    ]),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator(color: primaryPink));
      }

      if (snapshot.hasError || !snapshot.hasData) {
        return Center(child: Text('Error loading content.'));
      }

      final groupsSnapshot = snapshot.data![0];
      final pollsSnapshot = snapshot.data![1];
      // final discussionsSnapshot = snapshot.data![2]; // Optional: if you need discussions separately
      final petitionsSnapshot = snapshot.data![3];

      List<DocumentSnapshot> allItems = [];
      List<String> itemTypes = []; // To track the type of each item

      // Add Groups
      for (var doc in groupsSnapshot.docs) {
        // Filter out discussions if they are included in the general groups collection
        // and you want to handle them distinctly or only via the 'Discussions' tab.
        // You might need logic here based on your data structure.
        // For now, assuming 'category' field distinguishes them.
        final data = doc.data() as Map<String, dynamic>;
        final String category = data['category'] ?? 'General';

        if (category != 'Discussions') {
          // Filter out groups user is already a member of if desired for "Discover" in All
          final List<dynamic> members = data['members'] ?? [];
          if (!members.contains(_currentUserId)) {
            allItems.add(doc);
            itemTypes.add('group');
          }
        }
      }

      // Add Discussions (ensure they are fetched correctly, e.g., by category)
      // Assuming discussions are also stored in 'groups' collection with category 'Discussions'
      for (var doc in groupsSnapshot.docs) {
        // Or use discussionsSnapshot.docs if separate and preferred
        final data = doc.data() as Map<String, dynamic>;
        final String category = data['category'] ?? 'General';

        if (category == 'Discussions') {
          // Filter out discussions user is already a member of if desired
          final List<dynamic> members = data['members'] ?? [];
          if (!members.contains(_currentUserId)) {
            allItems.add(doc);
            itemTypes.add('discussion'); // Treat discussions as a specific type
          }
        }
      }

      // Add Polls
      for (var doc in pollsSnapshot.docs) {
        allItems.add(doc);
        itemTypes.add('poll');
      }

      // Add Petitions
      for (var doc in petitionsSnapshot.docs) {
        allItems.add(doc);
        itemTypes.add('petition');
      }

      // Check if combined list is empty
      if (allItems.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore, size: 50, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Nothing here yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 8),
              Text(
                'Explore or create content!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      // --- Shuffle the combined list here ---
      // Combine items and types, shuffle the combined list, then separate
      List<Map<String, dynamic>> combinedList = [];
      for (int i = 0; i < allItems.length; i++) {
        combinedList.add({
          'item': allItems[i],
          'type': itemTypes[i],
        });
      }

      // Shuffle the combined list to randomize the order
      combinedList.shuffle();

      // Separate the shuffled list back into items and types
      List<DocumentSnapshot> shuffledItems = combinedList.map((map) => map['item'] as DocumentSnapshot).toList();
      List<String> shuffledItemTypes = combinedList.map((map) => map['type'] as String).toList();
      // --- End of shuffling logic ---

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: externalPadding),
        child: MasonryGridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: cardSpacing,
          crossAxisSpacing: cardSpacing,
          itemCount: shuffledItems.length, // Use shuffled list length
          itemBuilder: (context, index) {
            // Use shuffled lists for item and type
            final DocumentSnapshot item = shuffledItems[index];
            final String itemType = shuffledItemTypes[index];
            final itemData = item.data() as Map<String, dynamic>;

            // - Render different item types -
            if (itemType == 'group') {
              final String groupId = item.id;
              final String groupName = itemData['name'] ?? 'Untitled';
              final String groupImage = itemData['imageUrl'] ?? '';
              final int memberCount = itemData['memberCount'] ?? 0;
              final String groupDescription = itemData['description'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: cardMarginVertical,
                  horizontal: cardMarginHorizontal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22), // smoother rounded corners
                ),
                color: const Color(0xFFFFE1E0),
                elevation: 4, // subtle soft shadow
                shadowColor: Colors.black.withOpacity(0.08),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GroupViewScreen(
                          groupId: groupId,
                          onJoinSuccess: null,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(cardInternalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Group image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: groupImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: groupImage,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[200]),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error, color: Color(0xFFE56982)),
                                )
                              : Container(
                                  width: double.infinity,
                                  color: Colors.grey[200],
                                  padding: const EdgeInsets.all(28),
                                  child: const Icon(
                                    Icons.group,
                                    color: Color(0xFFE56982),
                                    size: 36,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 12),

                        // Group name
                        Text(
                          groupName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFFE56982),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Description
                        Text(
                          groupDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE56982),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // Member count pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFB7C5).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.people_rounded,
                                size: 16,
                                color: Color(0xFFE56982),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$memberCount members',
                                style: const TextStyle(
                                  color: Color(0xFFE56982),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            else if (itemType == 'discussion') {
              final String discussionId = item.id;
              final String discussionName = itemData['name'] ?? 'Untitled Discussion';
              final String discussionImage = itemData['imageUrl'] ?? '';
              final String discussionDescription = itemData['description'] ?? '';
              final int memberCount = itemData['memberCount'] ?? 0;

              final bool isArchived = _isDiscussionArchived(itemData);
              final int? daysLeft = isArchived ? null : _getDaysLeft(itemData);

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: cardMarginVertical,
                  horizontal: cardMarginHorizontal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                ),
                color: const Color(0xFFFFE1E0),
                elevation: 3,
                shadowColor: const Color(0xFFFFB7C5).withOpacity(0.3),
                child: InkWell(
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                  onTap: isArchived
                      ? null
                      : () {
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
                  child: Padding(
                    padding: const EdgeInsets.all(cardInternalPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🖼️ Image with overlay if archived
                        ClipRRect(
                          borderRadius: BorderRadius.circular(borderRadiusValue - 4),
                          child: SizedBox(
                            width: double.infinity,
                            height: 140,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                discussionImage.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: discussionImage,
                                        fit: BoxFit.cover,
                                        color: isArchived
                                            ? Colors.grey.withOpacity(0.5)
                                            : null,
                                        colorBlendMode:
                                            isArchived ? BlendMode.saturation : null,
                                        placeholder: (context, url) =>
                                            Container(color: Colors.grey[300]),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Icons.error),
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.forum, color: Colors.grey),
                                      ),
                                if (isArchived)
                                  Container(
                                    color: Colors.black.withOpacity(0.4),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'ARCHIVED',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.3,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 🏷️ Title (uniform color)
                        Text(
                          discussionName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFFE56982), // same as other items
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // 📝 Description (uniform color)
                        Text(
                          discussionDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE56982), // same as other items
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 10),

                        // 🕓 Days left (if active)
                        if (!isArchived && daysLeft != null)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE1E0),
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE56982).withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              '$daysLeft days left',
                              style: const TextStyle(
                                color: Color(0xFFE56982),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),

                        // 👥 Member count pill
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isArchived
                                ? Colors.grey[400] // gray pill for archived
                                : const Color(0xFFFFE1E0),
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: (isArchived
                                        ? Colors.grey[500]
                                        : const Color(0xFFE56982))
                                    ?.withOpacity(0.1) ?? const Color(0xFFE56982).withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people,
                                  size: 14,
                                  color: isArchived ? Colors.grey[700] : Color(0xFFE56982)),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount members',
                                style: TextStyle(
                                  color: isArchived ? Colors.grey[700] : Color(0xFFE56982),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            else if (itemType == 'poll') {
              // Poll card rendering
              final DocumentSnapshot pollSnapshot = shuffledItems[index];
              return PollCard(
                pollSnapshot: pollSnapshot,
                cardMarginVertical: cardMarginVertical,
                cardMarginHorizontal: cardMarginHorizontal,
                cardInternalPadding: cardInternalPadding,
                borderRadiusValue: borderRadiusValue,
              );
            }
            else if (itemType == 'petition') {
              final petitionDoc = item;
              final petition = Petition.fromDocument(petitionDoc);
              final bool isSigned = petition.signers.contains(_currentUserId);
              final double progress =
                  petition.goal > 0 ? petition.currentSignatures / petition.goal : 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(
                    vertical: cardMarginVertical, horizontal: cardMarginHorizontal),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                ),
                color: const Color(0xFFFFE1E0),
                elevation: 2,
                shadowColor: const Color(0xFFFFB7C5).withOpacity(0.4),
                child: InkWell(
                  onTap: () {
                    showPetitionDetails(context, petition, isSigned);
                  },
                  borderRadius: BorderRadius.circular(borderRadiusValue),
                  child: Padding(
                    padding: const EdgeInsets.all(cardInternalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Banner image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(borderRadiusValue - 4),
                          child: petition.bannerImageUrl != null &&
                                  petition.bannerImageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: petition.bannerImageUrl!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: Colors.grey[300]),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error),
                                )
                              : Container(
                                  height: 140,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          petition.title.length > 50
                              ? '${petition.title.substring(0, 50)}...'
                              : petition.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFFE56982),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),

                        // Description
                        Text(
                          petition.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE56982),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Signature pill with progress border
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE1E0), // pill bg same as member pill
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: const Color(0xFFE56982),
                              width: 4.5 * progress, // thin, proportional to progress
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE56982).withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.how_to_reg, size: 14, color: Color(0xFFE56982)),
                              const SizedBox(width: 4),
                              Text(
                                '${petition.currentSignatures}/${petition.goal} signatures',
                                style: const TextStyle(
                                  color: Color(0xFFE56982),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            else {
              // Fallback for unknown item types
              return Card(child: ListTile(title: Text('Unknown Item Type')));
            }
          },
        ),
      );
    },
  );
}


  Widget _buildGroupsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('isPrivate', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryPink));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group, size: 40, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('No public groups yet', style: TextStyle(fontSize: 14)),
                  SizedBox(height: 6),
                  Text(
                    'Be the first to create a group!',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        }
        
        final allGroups = snapshot.data!.docs;
        // Filter by category
        final filteredGroups = _selectedCategory == 'All'
            ? allGroups
            : allGroups.where((group) {
                final groupData = group.data() as Map<String, dynamic>;
                final String category = groupData['category'] ?? 'General';
                return category == _selectedCategory;
              }).toList();
        
        // Filter out groups user is already a member of
        final discoverGroups = filteredGroups.where((group) {
          final groupData = group.data() as Map<String, dynamic>;
          final List<dynamic> members = groupData['members'] ?? [];
          return !members.contains(_currentUserId);
        }).toList();
        
        if (discoverGroups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No groups found in ${_selectedCategory == "All" ? "any category" : _selectedCategory}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Try a different category or create your own group',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: MasonryGridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    itemCount: discoverGroups.length,
    itemBuilder: (context, index) {
      final group = discoverGroups[index];
      final groupData = group.data() as Map<String, dynamic>;
      final String groupId = group.id;
      final String groupName = groupData['name'] ?? 'Untitled';
      final String groupImage = groupData['imageUrl'] ?? '';
      final int memberCount = groupData['memberCount'] ?? 0;
      final String category = groupData['category'] ?? 'General';
      final String groupDescription = groupData['description'] ?? '';
      final String ageRating = groupData['ageRating'] ?? '13-17';
      final List<dynamic> hashtagsList = groupData['hashtags'] ?? [];
      final List<String> hashtags = hashtagsList.cast<String>();

      int? daysLeft;
      if (category == 'Discussions' && groupData['expiresAt'] != null) {
        final expiresAt = groupData['expiresAt'].toDate();
        final now = DateTime.now();
        daysLeft = expiresAt.difference(now).inDays;
      }

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFE1E0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupViewScreen(
                  groupId: groupId,
                  onJoinSuccess: null,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: groupImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: groupImage,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[300]),
                              errorWidget: (context, url, error) =>
                                  Container(
                                    color: Colors.grey[300],
                                    child: Icon(Icons.group, color: Colors.white),
                                  ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.group, color: Colors.white),
                            ),
                    ),
                  ),
                  // Member count badge
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
                          Icon(Icons.people, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '$memberCount',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Days left badge
                  if (daysLeft != null && daysLeft >= 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryPink.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$daysLeft days left',
                          style: TextStyle(
                            color: Colors.white,
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
                      groupName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryPink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      groupDescription,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    // Hashtags as pills
                    if (hashtags.isNotEmpty)
                      SizedBox(
                        height: 24,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: hashtags.map((tag) {
                            return Container(
                              margin: EdgeInsets.only(right: 4),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 3,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: primaryPink,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          category,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        Text(
                          ageRating,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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

  Widget _buildPollsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('polls').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryPink));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.poll, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No polls yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to create a poll!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        final polls = snapshot.data!.docs;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: polls.length,
            itemBuilder: (context, index) {
              final poll = polls[index];
              final pollData = poll.data() as Map<String, dynamic>;
              final String question = pollData['question'] ?? '';
              final int totalVotes = pollData['totalVotes'] ?? 0;
              final String ageRating = pollData['ageRating'] ?? '13-17';
              final List<dynamic> hashtagsList = pollData['hashtags'] ?? [];
              final List<String> hashtags = hashtagsList.cast<String>();
              
              // Calculate days left
              int? daysLeft;
              if (pollData['expiresAt'] != null) {
                final expiresAt = pollData['expiresAt'].toDate();
                final now = DateTime.now();
                daysLeft = expiresAt.difference(now).inDays;
              }

              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: InkWell(
                  onTap: () {
                    // Navigate to poll screen
                    // You'll need to create a PollScreen for this
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 120,
                        color: lightPink,
                        child: Center(
                          child: Icon(Icons.poll, size: 40, color: primaryPink),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              question,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '$totalVotes votes',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (daysLeft != null && daysLeft >= 0)
                              Text(
                                '$daysLeft days left',
                                style: TextStyle(fontSize: 11, color: primaryPink),
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
                                        style: TextStyle(fontSize: 10, color: primaryPink),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            SizedBox(height: 2),
                            Text(
                              ageRating,
                              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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

  Widget _buildDiscussionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('category', isEqualTo: 'Discussions')
          .where('isPrivate', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryPink));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.forum, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No discussions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to start a discussion!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        final discussions = snapshot.data!.docs;
        
        return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0),
  child: MasonryGridView.count(
    crossAxisCount: 2,
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    itemCount: discussions.length,
    itemBuilder: (context, index) {
      final discussion = discussions[index];
      final discussionData = discussion.data() as Map<String, dynamic>;
      final String discussionId = discussion.id;
      final String discussionName = discussionData['name'] ?? 'Untitled Discussion';
      final String discussionImage = discussionData['imageUrl'] ?? '';
      final int memberCount = discussionData['memberCount'] ?? 0;
      final String discussionDescription = discussionData['description'] ?? '';
      final String ageRating = discussionData['ageRating'] ?? '13-17';
      final List<dynamic> hashtagsList = discussionData['hashtags'] ?? [];
      final List<String> hashtags = hashtagsList.cast<String>();

      int? daysLeft;
      if (discussionData['expiresAt'] != null) {
        final expiresAt = discussionData['expiresAt'].toDate();
        final now = DateTime.now();
        daysLeft = expiresAt.difference(now).inDays;
      }

      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFE1E0),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupViewScreen(
                  groupId: discussionId,
                  onJoinSuccess: null,
                ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: discussionImage.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: discussionImage,
                              fit: BoxFit.cover,
                              placeholder: (context, url) =>
                                  Container(color: Colors.grey[300]),
                              errorWidget: (context, url, error) =>
                                  Container(
                                    color: Colors.grey[300],
                                    child: Icon(Icons.forum, color: Colors.white),
                                  ),
                            )
                          : Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.forum, color: Colors.white),
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
                          Icon(Icons.people, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '$memberCount',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (daysLeft != null && daysLeft >= 0)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryPink.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$daysLeft days left',
                          style: TextStyle(
                            color: Colors.white,
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: primaryPink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Text(
                      discussionDescription,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    if (hashtags.isNotEmpty)
                      SizedBox(
                        height: 24,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: hashtags.map((tag) {
                            return Container(
                              margin: EdgeInsets.only(right: 4),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 3,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                '#$tag',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: primaryPink,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Discussion',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        Text(
                          ageRating,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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

  Widget _buildPetitionsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('petitions').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryPink));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.how_to_vote, size: 50, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No petitions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to create a petition!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final petitions = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: petitions.length,
            itemBuilder: (context, index) {
              final petition = petitions[index];
              final petitionData = petition.data() as Map<String, dynamic>;
              final String title = petitionData['title'] ?? '';
              final String description = petitionData['description'] ?? '';
              final int goal = petitionData['goal'] ?? 0;
              final int currentSignatures = petitionData['currentSignatures'] ?? 0;

              return Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                color: Colors.pink[50], // light background similar to screenshot
                child: InkWell(
                  onTap: () {
                    // Navigate to petition screen
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner image
                      ClipRRect(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        child: Container(
                          height: 120,
                          width: double.infinity,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(Icons.how_to_vote, size: 40, color: primaryPink),
                          ),
                        ),
                      ),

                      // Content section
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 6),

                            // Description
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 10),

                            // Progress text
                            Text(
                              '$currentSignatures/$goal signatures left',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryPink,
                              ),
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


  void _showCreatePetitionModal() {
    final TextEditingController _titleController = TextEditingController();
    final TextEditingController _descriptionController = TextEditingController();
    final TextEditingController _goalController = TextEditingController(text: '100');
    
    // Reset hashtags for a new petition
    setState(() {
      _hashtags.clear();
    });
    _hashtagController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Create Petition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Petition Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Petition Description *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _goalController,
                    decoration: InputDecoration(
                      labelText: 'Signature Goal *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 16),
                  // Age Rating Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedAgeRating,
                    items: _ageRatings.map((rating) {
                      return DropdownMenuItem<String>(
                        value: rating,
                        child: Text(rating),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedAgeRating = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Age Rating',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  // Hashtags
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _hashtags.map((tag) {
                      return Chip(
                        label: Text('#$tag'),
                        deleteIcon: Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setModalState(() {
                            _hashtags.remove(tag);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hashtagController,
                          decoration: InputDecoration(
                            labelText: 'Add Hashtag',
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                String newTag = _hashtagController.text.trim().replaceAll('#', '');
                                if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                                  setModalState(() {
                                    _hashtags.add(newTag);
                                  });
                                  _hashtagController.clear();
                                }
                              },
                            ),
                          ),
                          onSubmitted: (_) {
                            String newTag = _hashtagController.text.trim().replaceAll('#', '');
                            if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                              setModalState(() {
                                _hashtags.add(newTag);
                              });
                              _hashtagController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_titleController.text.isEmpty || 
                          _descriptionController.text.isEmpty ||
                          _goalController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('All fields are required')),
                        );
                        return;
                      }
                      
                      _createPetition(
                        _titleController.text,
                        _descriptionController.text,
                        int.parse(_goalController.text),
                      );
                    },
                    child: Text('Create Petition'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _createPetition(String title, String description, int goal) async {
    try {
      final petitionId = Uuid().v4();
      final timestamp = FieldValue.serverTimestamp();
      
      final petitionData = {
        'id': petitionId,
        'title': title,
        'description': description,
        'goal': goal,
        'currentSignatures': 0,
        'createdBy': _currentUserId,
        'createdAt': timestamp,
        'signatures': [],
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
        'type': 'petition',
      };
      
      await _firestore.collection('petitions').doc(petitionId).set(petitionData);
      
      // Reset form
      setState(() {
        _hashtags.clear();
      });
      _hashtagController.clear();
      _selectedAgeRating = '13-17';
      
      Navigator.pop(context); // Close the modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Petition created successfully')),
      );
    } catch (e) {
      print("Error creating petition: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create petition. Please try again.')),
      );
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
                'This feature is currently under development.',
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

  void _showOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgWhite, // #ffe1e0 background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: darkPink, // #ffb7c5 color
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Create New', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            // Options grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              childAspectRatio: 1.8,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _buildOptionCard('Polls', _optionIcons['Polls']!),
                _buildOptionCard('Discussions', _optionIcons['Discussions']!),
                _buildOptionCard('Groups', _optionIcons['Groups']!),
                _buildOptionCard('Mentorship', _optionIcons['Mentorship']!),
                _buildOptionCard('Petitions', _optionIcons['Petitions']!),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Replace the existing _showCreateGroupModal function with this:
  void _navigateToGroupCreationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupCreationScreen(),
      ),
    );
  }

  // Add this method to your _GroupsScreenState class
  void _navigateToPollCreationScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PollCreationScreen()),
    );
  }

  // Helper method to build option cards
  Widget _buildOptionCard(String title, IconData icon) {
    return Card(
      color: cardWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: darkPink, width: 1.0),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.pop(context); // Close the options modal
          if (title == 'Groups') {
            _navigateToGroupCreationScreen();
          } else if (title == 'Polls') {
            Navigator.pop(context);
            // Replace the modal call with screen navigation
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PollCreationScreen()),
            );
          } else if (title == 'Discussions') {
            // _showCreateDiscussionModal();
            _showComingSoonPopup();
          } else if (title == 'Petitions') {
            Navigator.pop(context);
            showCreatePetitionModal(context);
          } else if (title == 'Mentorship') {
           _showComingSoonPopup();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primaryPink, size: 28),
              SizedBox(height: 8),
              Text(title, 
                  style: TextStyle(fontWeight: FontWeight.w500, color: primaryPink)),
            ],
          ),
        ),
      ),
    );
  }

  // Show a "coming soon" modal for Mentorship
  void _showComingSoonModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Coming Soon'),
        content: Text('Mentorship feature is coming in a future update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: primaryPink)),
          ),
        ],
      ),
    );
  }


  void _showCreateDiscussionModal() {
    // Reset hashtags for a new discussion
    setState(() {
      _hashtags.clear();
    });
    _hashtagController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('New Discussion',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: _pickGroupImage, // Reusing the same image picking logic
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _groupImage != null
                            ? FileImage(_groupImage!)
                            : null,
                        child: _groupImage == null
                            ? Icon(Icons.camera_alt, size: 30, color: Colors.grey)
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _groupNameController, // Reusing the same controller for simplicity
                    decoration: InputDecoration(
                      labelText: 'Discussion Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _groupDescriptionController, // Reusing the same controller for simplicity
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  // Hashtags Display
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _hashtags.map((tag) {
                      return Chip(
                        label: Text('#$tag'),
                        deleteIcon: Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setModalState(() {
                            _hashtags.remove(tag);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  // Add Hashtag Input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hashtagController,
                          decoration: InputDecoration(
                            labelText: 'Add Hashtag',
                            border: OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () {
                                String newTag = _hashtagController.text.trim().replaceAll('#', '');
                                if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                                  setModalState(() {
                                    _hashtags.add(newTag);
                                  });
                                  _hashtagController.clear();
                                }
                              },
                            ),
                          ),
                          onSubmitted: (_) {
                            String newTag = _hashtagController.text.trim().replaceAll('#', '');
                            if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                              setModalState(() {
                                _hashtags.add(newTag);
                              });
                              _hashtagController.clear();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Age Rating Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedAgeRating,
                    items: _ageRatings.map((rating) {
                      return DropdownMenuItem<String>(
                        value: rating,
                        child: Text(rating),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedAgeRating = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Age Rating',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Private Discussion'),
                    subtitle: Text('Only invited members can join (Coming Soon)'),
                    value: _isPrivate,
                    onChanged: (value) {
                      setModalState(() {
                        _isPrivate = value;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _createDiscussion, // New method to create discussion
                    child: Text('Create'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

// Inside _createDiscussion function (likely in the screen where you create discussions)
  Future<void> _createDiscussion() async {
    if (_groupNameController.text.trim().isEmpty || _groupDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title and Description are required.')),
      );
      return;
    }

    final String discussionId = _groupNameController.text.trim().toLowerCase().replaceAll(' ', '_') + '_' + DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = FieldValue.serverTimestamp();

    try {
      // --- CHANGE HERE: Save to 'discussions' collection ---
      final discussionData = {
        'id': discussionId, // Consider if you really need this if using doc ID
        'name': _groupNameController.text.trim(),
        'description': _groupDescriptionController.text.trim(),
        'imageUrl': _groupImage != null ? await _uploadImage(_groupImage!) : '',
        'createdAt': timestamp,
        'createdBy': _currentUserId,
        'admins': [_currentUserId],
        'moderators': [], // Initialize empty moderators list
        'members': [_currentUserId], // Creator is the first member
        'memberCount': 1,
        'lastMessage': '',
        'lastMessageTime': timestamp,
        'lastMessageSender': '',
        'unreadCount': {_currentUserId: 0}, // Initialize unread count for creator
        'category': 'Discussions', // Set category
        'isReadOnly': false,
        'profanityFilter': true,
        'linkRestrictions': false,
        'typing': {},
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
        // Add expiration for discussions if needed
        'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        'isTemporary': true,
      };

      // --- CHANGE HERE: Use 'discussions' collection ---
      await _firestore.collection('discussions').doc(discussionId).set(discussionData);

      // Reset form fields
      _groupNameController.clear();
      _groupDescriptionController.clear();
      _hashtagController.clear();
      setState(() {
        _groupImage = null;
        _isPrivate = false; // Reset privacy if applicable
        _selectedAgeRating = '13-17';
        _hashtags.clear();
      });

      // Navigate to the discussion chat screen
      // --- CHANGE HERE (Potentially): Use DiscussionChatScreen or adapt GroupChatScreen ---
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DiscussionChatScreen(discussionId: discussionId), // Use DiscussionChatScreen
          // OR if GroupChatScreen handles both:  MaterialPageRoute(builder: (context) => GroupChatScreen(groupId: discussionId, isDiscussion: true)), // Pass flag if needed
        ),
      );

    } catch (e) {
      print("Error creating discussion: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create discussion. Please try again.')),
      );
    }
  }

  // Inside _GroupsScreenState class
  Future<String?> _uploadImage(File imageFile) async {
    try {
      // Example path - adjust if needed, maybe just 'images' or specific to discussions
      // Consider if this method should be truly generic or specific to context
      final ref = FirebaseStorage.instance
          .ref()
          .child('discussion_images') // Or a more generic 'images' folder
          .child('${Uuid().v4()}.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image. Please try again.')),
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
      appBar: AppBar(
        // --- Modified Title Section ---
        title: Row(
          mainAxisSize: MainAxisSize.min, // Only take as much space as needed
          children: [
            // --- Logo Container (adapted from the first file) ---
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE1E0), // soft pink background
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
            // --- Space between logo and text ---
            SizedBox(width: 8), // Adjust spacing if needed
            // --- Original Title Text ---
            Text(
              'Circles',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE35773),),
            ),
          ],
        ),
        // --- Keep the rest of your AppBar properties ---
        backgroundColor: cardWhite,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // --- Add Button ---
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
              icon: const Icon(
                Icons.add,
                color: Color(0xFFE35773),
                size: 22, // fits inside 42x42 nicely
              ),
              onPressed: () => _showOptionsModal(),
              tooltip: 'Create New',
            ),
          ),
          const SizedBox(width: 8),

          // --- Search Button ---
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
          const SizedBox(width: 8),

          // --- User Avatar ---
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(_currentUserId).get(),
            builder: (context, snapshot) {
              Widget avatar;
              if (snapshot.connectionState == ConnectionState.waiting) {
                avatar = Image.asset(
                  'assets/default_avatar.png',
                  fit: BoxFit.cover,
                );
              } else if (!snapshot.hasData || !snapshot.data!.exists) {
                avatar = Image.asset(
                  'assets/default_avatar.png',
                  fit: BoxFit.cover,
                );
              } else {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final String profileImage = userData['profileImage'] ?? '';
                avatar = profileImage.isNotEmpty
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
                    color: const Color(0xFFFFE1E0), // soft pink background
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

          const SizedBox(width: 8),
        ],
      ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {});
            await Future.delayed(Duration(seconds: 1));
          },
          child: Column(
            children: [
              // Content Type Selector - ADD THIS SECTION
              Container(
                height: 45,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _contentTypes.length,
                    itemBuilder: (context, index) {
                      final type = _contentTypes[index];
                      final isSelected = _selectedContentTypeIndex == index;

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedContentTypeIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE1E0), // soft pink bg
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(isSelected ? 0.15 : 0.03),
                                blurRadius: isSelected ? 6 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              type,
                              style: TextStyle(
                                color: const Color(0xFFE35773),
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
              ),
                            
              // Top 1/4: Pinned/Joined Groups - Fixed height constraint
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.12,
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('groups')
                      .where('members', arrayContains: _currentUserId)
                      .orderBy('lastMessageTime', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child: CircularProgressIndicator(color: primaryPink));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group, size: 50, color: Colors.grey),
                                const SizedBox(height: 16),
                                const Text(
                                  'Join your first group!',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Discover communities that matter to you',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _navigateToGroupCreationScreen(),
                                  child: const Text('Create Group'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryPink,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final joinedGroups = snapshot.data!.docs;

                    return SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: joinedGroups.length,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (context, index) {
                          final group = joinedGroups[index];
                          final groupData = group.data() as Map<String, dynamic>;
                          final String groupId = group.id;
                          final String groupName = groupData['name'] ?? '';
                          final String groupImage = groupData['imageUrl'] ?? '';
                          final Map<String, dynamic> unreadCountMap =
                              groupData['unreadCount'] ?? {};
                          final int unreadCount =
                              unreadCountMap[_currentUserId] ?? 0;
                          final bool hasNewMessages = unreadCount > 0;

                          final Timestamp? lastMessageTime =
                              groupData['lastMessageTime'];
                          final String lastMessage =
                              groupData['lastMessage'] ?? '';
                          final String lastMessageSender =
                              groupData['lastMessageSender'] ?? '';
                          String displayMessage = lastMessage;
                          if (lastMessageSender == _currentUserId) {
                            displayMessage = "You: $lastMessage";
                          } else if (lastMessageSender.isNotEmpty) {
                            displayMessage = "Someone: $lastMessage";
                          }

                          String timeString = '';
                          if (lastMessageTime != null) {
                            final now = DateTime.now();
                            final messageDate = lastMessageTime.toDate();
                            if (now.difference(messageDate).inDays < 1) {
                              timeString = DateFormat.Hm().format(messageDate);
                            } else {
                              timeString = DateFormat.MMMd().format(messageDate);
                            }
                          }

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GroupChatScreen(groupId: groupId),
                                ),
                              );
                            },
                            child: Container(
                              width: 260,
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: bgWhite,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Group image
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey[200],
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: groupImage.isNotEmpty
                                          ? Image(
                                              image: CachedNetworkImageProvider(groupImage),
                                              fit: BoxFit.cover,
                                            )
                                          : Image.asset(
                                              'assets/femnlogo.png',
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Name + last message
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          groupName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: primaryPink,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: primaryPink.withOpacity(0.8),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Time + unread badge
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        timeString,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: primaryPink,
                                        ),
                                      ),
                                      if (hasNewMessages)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: primaryPink,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 20,
                                            minHeight: 20,
                                          ),
                                          child: Center(
                                            child: Text(
                                              unreadCount > 99 ? '99+' : '$unreadCount',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),

              // Main Content Area - Show different content based on selection
              Expanded(
                child: _buildContentForSelectedType(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Update this existing method ---
  Widget _buildContentForSelectedType() {
    switch (_currentContentType) {
      case 'All': // Add this case
        return _buildAllTab();
      case 'Polls':
        return _buildPollsTab();
      case 'Discussions':
        return _buildDiscussionsTab(); // Or keep if you want a dedicated Discussions tab too
      case 'Groups':
        return _buildGroupsTab();
      case 'Petitions':
        return _buildPetitionsTab();
      default:
        // It's good practice to handle the default, even if 'All' is now default.
        // You might want to return _buildAllTab() here as well, or an error widget.
        return _buildAllTab(); // Redirect unknown/default to All
    }
  }
  // --- End of update ---
}


// --- New Group Creation Screen ---
class GroupCreationScreen extends StatefulWidget {
  @override
  _GroupCreationScreenState createState() => _GroupCreationScreenState();
}

class _GroupCreationScreenState extends State<GroupCreationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescriptionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();

  String _selectedCategory = 'All';
  bool _isPrivate = false;
  File? _groupImage;
  String _selectedAgeRating = '13-17';
  final List<String> _ageRatings = ['13-17', '18-25', '26+'];
  List<String> _hashtags = [];
  
  bool _isLoading = false;
  late String _currentUserId;

  final List<String> _categories = [
    'All', 'Polls', 'Discussions', 'Groups', 'Mentorship', 'Petitions'
  ];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  Future<void> _pickGroupImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _groupImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadGroupImage() async {
    if (_groupImage == null) return null;
    try {
      final ref = _storage.ref().child('group_images').child('${Uuid().v4()}.jpg');
      await ref.putFile(_groupImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading group image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image. Please try again.')),
      );
      return null;
    }
  }

  Future<void> _createGroup() async {
    if (_groupNameController.text.trim().isEmpty || 
        _groupDescriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title and Description are required.')),
      );
      return;
    }

    final groupName = _groupNameController.text.trim();
    final groupDescription = _groupDescriptionController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final imageUrl = await _uploadGroupImage();
      final groupId = Uuid().v4();
      final timestamp = FieldValue.serverTimestamp();
      
      final groupData = {
        'id': groupId,
        'name': groupName,
        'description': groupDescription,
        'imageUrl': imageUrl ?? '',
        'isPrivate': _isPrivate,
        'createdBy': _currentUserId,
        'createdAt': timestamp,
        'members': [_currentUserId],
        'admins': [_currentUserId],
        'moderators': [],
        'memberCount': 1,
        'lastMessage': '',
        'lastMessageTime': timestamp,
        'lastMessageSender': '',
        'unreadCount': {_currentUserId: 0},
        'category': _selectedCategory != 'All' ? _selectedCategory : 'General',
        'isReadOnly': false,
        'profanityFilter': true,
        'linkRestrictions': false,
        'typing': {},
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
      };

      // Add expiration for discussions
      if (_selectedCategory == 'Discussions') {
        final expiresAt = DateTime.now().add(Duration(days: 7));
        groupData['expiresAt'] = Timestamp.fromDate(expiresAt);
        groupData['isTemporary'] = true;
      }

      await _firestore.collection('groups').doc(groupId).set(groupData);

      // Show success and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group created successfully!')),
      );

      // Navigate to the new group chat
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GroupChatScreen(groupId: groupId),
        ),
      );

    } catch (e) {
      print("Error creating group: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: primaryPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: primaryPink),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B4E6B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.pink[50], // soft feminine background
      appBar: AppBar(
        title: Text(
          'Create New Group ✨',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.pink[300],
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(18.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section with curved edges
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.group, color: Colors.pink[300], size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Create Your Community',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8B4E6B),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Fill in the details below to create your group and start connecting!',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Group Image
              _buildSectionHeader('Group Image', Icons.camera_alt),
              SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _pickGroupImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.pink[100],
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.pink[200]!),
                      image: _groupImage != null
                          ? DecorationImage(
                              image: FileImage(_groupImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _groupImage == null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.image_outlined, size: 40, color: Colors.pink[400]),
                                SizedBox(height: 6),
                                Text(
                                  "Upload Group Image",
                                  style: TextStyle(color: Colors.pink[400]),
                                ),
                              ],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Group Title
              _buildSectionHeader('Group Title', Icons.title),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _groupNameController,
                  decoration: InputDecoration(
                    labelText: 'Enter group name',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.edit, color: Colors.pink[300]),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 20),

              // Description
              _buildSectionHeader('Description', Icons.description),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _groupDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Describe your group...',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.all(20),
                  ),
                  maxLines: 4,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 20),

              // Age Rating
              _buildSectionHeader('Age Rating', Icons.people),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedAgeRating,
                  items: _ageRatings.map((rating) {
                    return DropdownMenuItem<String>(
                      value: rating,
                      child: Text(rating),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAgeRating = value!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Who should see this group?',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.people_outline, color: Colors.pink[300]),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  dropdownColor: Colors.white,
                  style: TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(height: 20),

              // Hashtags
              _buildSectionHeader('Hashtags', Icons.tag),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _hashtagController,
                  decoration: InputDecoration(
                    labelText: 'Add relevant hashtags',
                    labelStyle: TextStyle(color: Colors.grey[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: Icon(Icons.tag, color: Colors.pink[300]),
                    suffixIcon: IconButton(
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.pink[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.add, color: Colors.white, size: 18),
                      ),
                      onPressed: () {
                        String newTag = _hashtagController.text.trim().replaceAll('#', '');
                        if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                          setState(() {
                            _hashtags.add(newTag);
                          });
                          _hashtagController.clear();
                        }
                      },
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onSubmitted: (_) {
                    String newTag = _hashtagController.text.trim().replaceAll('#', '');
                    if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                      setState(() {
                        _hashtags.add(newTag);
                      });
                      _hashtagController.clear();
                    }
                  },
                ),
              ),
              SizedBox(height: 12),

              // Display added hashtags
              if (_hashtags.isNotEmpty)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _hashtags.map((tag) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFE3ED), Color(0xFFFFF0F5)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: TextStyle(
                                color: Color(0xFF8B4E6B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _hashtags.remove(tag);
                                });
                              },
                              child: Icon(Icons.close, size: 16, color: Color(0xFF8B4E6B)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              SizedBox(height: 20),

              // Privacy Setting
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SwitchListTile(
                  title: Text(
                    'Private Group',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B4E6B),
                    ),
                  ),
                  subtitle: Text('Only invited members can join (Comming Soon)'),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                  secondary: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.pink[300]!.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.lock, size: 18, color: Colors.pink[300]),
                  ),
                ),
              ),
              SizedBox(height: 30),

              // Create Group Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink[300]!.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 55),
                    backgroundColor: Colors.pink[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading 
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_add, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Create Group',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}


// Ensure these variables exist in _GroupChatScreenState
// bool _isMember = false;
// bool _isReadOnly = false;
// And that _sendMessage is implemented to handle files.

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

class GroupViewScreen extends StatefulWidget {
  final String groupId;
  final VoidCallback? onJoinSuccess;
  const GroupViewScreen({
    Key? key, 
    required this.groupId, 
    this.onJoinSuccess
  }) : super(key: key);

  @override
  _GroupViewScreenState createState() => _GroupViewScreenState();
}

class _GroupViewScreenState extends State<GroupViewScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _currentUserId;
  late DocumentReference _groupDocRef;
  bool _isMember = false;
  bool _isAdmin = false;
  bool _isModerator = false;
  bool _isJoining = false;
  List<QueryDocumentSnapshot> _recentMessages = [];

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _groupDocRef = _firestore.collection('groups').doc(widget.groupId);
    _checkMembership();
    _loadRecentMessages(); // Load recent messages for preview
  }

  Future<void> _checkMembership() async {
    final groupDoc = await _groupDocRef.get();
    if (groupDoc.exists) {
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> members = groupData['members'] ?? [];
      final List<dynamic> admins = groupData['admins'] ?? [];
      final List<dynamic> moderators = groupData['moderators'] ?? [];
      setState(() {
        _isMember = members.contains(_currentUserId);
        _isAdmin = admins.contains(_currentUserId);
        _isModerator = moderators.contains(_currentUserId);
      });
    }
  }

  // NEW: Load recent messages for preview
  Future<void> _loadRecentMessages() async {
    try {
      final messagesSnapshot = await _groupDocRef
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      
      setState(() {
        _recentMessages = messagesSnapshot.docs;
      });
    } catch (e) {
      print("Error loading recent messages: $e");
    }
  }

  Future<void> _joinGroup() async {
    if (_isJoining || _isMember) return;
    
    setState(() {
      _isJoining = true;
    });

    try {
      await _groupDocRef.update({
        'members': FieldValue.arrayUnion([_currentUserId]),
        'memberCount': FieldValue.increment(1),
        'unreadCount.$_currentUserId': 0,
      });

      setState(() {
        _isMember = true;
        _isJoining = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Joined group successfully')),
      );

      if (widget.onJoinSuccess != null) {
        widget.onJoinSuccess!();
      }
    } catch (e) {
      print("Error joining group: $e");
      setState(() {
        _isJoining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join group. Please try again.')),
      );
    }
  }

  // NEW: Build message preview UI
  Widget _buildMessagePreview(Map<String, dynamic> messageData, bool isMe) {
    final String text = messageData['text'] ?? '';
    final String type = messageData['type'] ?? 'text';
    final String? imageUrl = messageData['imageUrl'];
    final Timestamp? timestamp = messageData['timestamp'];
    final String senderId = messageData['senderId'];
    final DateTime? messageTime = timestamp?.toDate();
    
    String previewText = '';
    if (type == 'image') {
      previewText = '📷 Image';
    } else if (type == 'audio') {
      previewText = '🎤 Voice message';
    } else {
      previewText = text;
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: UserProfileCache.getUserProfile(senderId),
      builder: (context, userSnapshot) {
        String userName = 'User';
        String userProfileImage = '';
        
        if (userSnapshot.hasData) {
          final userData = userSnapshot.data!;
          userName = userData['name'] ?? 'User';
          userProfileImage = userData['profileImage'] ?? '';
        }

        return Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey[300],
                backgroundImage: userProfileImage.isNotEmpty
                    ? CachedNetworkImageProvider(userProfileImage)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
                child: userProfileImage.isEmpty ? Icon(Icons.person, size: 16) : null,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      previewText,
                      style: TextStyle(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (messageTime != null)
                      Text(
                        DateFormat.Hm().format(messageTime),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<DocumentSnapshot>(
            stream: _groupDocRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Text('Group');
              final groupData = snapshot.data!.data() as Map<String, dynamic>?;
              return Text(groupData?['name'] ?? 'Group');
            },
          ),
          backgroundColor: cardWhite,
          foregroundColor: Colors.black,
          elevation: 0,
          actions: [
            if (!_isMember)
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: _isJoining
                    ? Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryPink,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: _joinGroup,
                        child: Text('JOIN',
                            style: TextStyle(
                                color: Colors.white, 
                                fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: primaryPink,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
              ),
            // NEW: Three-dot menu replacement for info button
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (value) {
                // Handle menu selection
                if (value == 'info') {
                  // Show group info
                } else if (value == 'media') {
                  // Show group media
                } else if (value == 'search') {
                  // Show search
                }
              },
              itemBuilder: (BuildContext context) {
                return [
                  PopupMenuItem<String>(
                    value: 'info',
                    child: ListTile(
                      leading: Icon(Icons.info_outline, color: primaryPink),
                      title: Text('Group Info'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'media',
                    child: ListTile(
                      leading: Icon(Icons.photo_library, color: primaryPink),
                      title: Text('Group Media'),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'search',
                    child: ListTile(
                      leading: Icon(Icons.search, color: primaryPink),
                      title: Text('Search'),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
        body: _isMember 
            ? GroupChatScreen(groupId: widget.groupId)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group preview header
                  Container(
                    padding: EdgeInsets.all(16),
                    color: cardWhite,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Previewing Group', 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text('Join this group to start chatting', 
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  // Recent messages preview
                  Expanded(
                    child: ListView.builder(
                      itemCount: _recentMessages.length,
                      itemBuilder: (context, index) {
                        final message = _recentMessages[index];
                        final messageData = message.data() as Map<String, dynamic>;
                        return _buildMessagePreview(messageData, false);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// NEW: Group Info Screen Widget
class GroupInfoScreen extends StatefulWidget {
  final String groupId;

  const GroupInfoScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupInfoScreenState createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final groupDoc = await _firestore.collection('groups').doc(widget.groupId).get();
    if (groupDoc.exists) {
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> admins = groupData['admins'] ?? [];
      setState(() {
        _isAdmin = admins.contains(_currentUserId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      appBar: AppBar(
        title: Text('Group Info'),
        backgroundColor: cardWhite,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: primaryPink));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final String groupName = groupData['name'] ?? '';
          final String groupImage = groupData['imageUrl'] ?? '';
          final String description = groupData['description'] ?? '';
          final List<dynamic> members = groupData['members'] ?? [];
          final List<dynamic> admins = groupData['admins'] ?? [];

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Group Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: groupImage.isNotEmpty
                          ? CachedNetworkImageProvider(groupImage)
                          : AssetImage('assets/femnlogo.png',) as ImageProvider,
                    ),
                    SizedBox(height: 16),
                    Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryPink,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // Members Section
              _buildSectionHeader('Members (${members.length})'),
              _buildMembersList(members, admins),
              
              SizedBox(height: 16),
              
              // Media, Links & Docs Section
              _buildSectionHeader('Shared Media'),
              _buildMediaSection(),
              
              SizedBox(height: 16),
              
              // Group Settings (Admin only)
              if (_isAdmin) _buildAdminSettings(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryPink,
        ),
      ),
    );
  }

  Widget _buildMembersList(List<dynamic> members, List<dynamic> admins) {
    return Column(
      children: [
        if (_isAdmin) ...[
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryPink.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.person_add, color: primaryPink),
            ),
            title: Text('Add Participants'),
            onTap: _addParticipants,
          ),
          Divider(),
        ],
        
        ...members.map((memberId) => FutureBuilder<Map<String, dynamic>>(
          future: UserProfileCache.getUserProfile(memberId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                leading: CircleAvatar(radius: 20),
                title: Text('Loading...'),
              );
            }
            
            final userData = snapshot.data!;
            final String userName = userData['name'] ?? 'User';
            final String userImage = userData['profileImage'] ?? '';
            final bool isAdmin = admins.contains(memberId);
            final bool isMe = memberId == _currentUserId;
            
            return ListTile(
              leading: CircleAvatar(
                radius: 20,
                backgroundImage: userImage.isNotEmpty
                    ? CachedNetworkImageProvider(userImage)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              title: Row(
                children: [
                  Text(userName),
                  if (isMe) Text(' (You)', style: TextStyle(color: Colors.grey)),
                ],
              ),
              subtitle: isAdmin ? Text('Admin', style: TextStyle(color: primaryPink)) : null,
              trailing: _isAdmin && !isMe ? PopupMenuButton<String>(
                onSelected: (value) => _handleMemberAction(value, memberId, isAdmin),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: isAdmin ? 'demote' : 'promote',
                    child: Text(isAdmin ? 'Demote from Admin' : 'Promote to Admin'),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from Group', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ) : null,
            );
          },
        )).toList(),
      ],
    );
  }

  Widget _buildMediaSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('groups').doc(widget.groupId)
          .collection('messages').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator(color: primaryPink);
        }
        
        final messages = snapshot.data!.docs;
        final mediaMessages = messages.where((msg) {
          final data = msg.data() as Map<String, dynamic>;
          return data['imageUrl'] != null || 
                 data['type'] == 'file' || 
                 _containsLink(data['text'] ?? '');
        }).toList();
        
        return GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: mediaMessages.length,
          itemBuilder: (context, index) {
            final message = mediaMessages[index];
            final data = message.data() as Map<String, dynamic>;
            
            if (data['imageUrl'] != null) {
              return CachedNetworkImage(
                imageUrl: data['imageUrl'],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
              );
            } else if (data['type'] == 'file') {
              return Container(
                color: lightPink,
                child: Icon(Icons.insert_drive_file, color: primaryPink),
              );
            } else {
              return Container(
                color: lightPink,
                child: Icon(Icons.link, color: primaryPink),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildAdminSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Admin Controls'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Read-only Mode'),
                subtitle: Text('Only admins can send messages'),
                value: false, // You'll need to store this in your group data
                onChanged: (value) => _toggleReadOnlyMode(value),
              ),
              SwitchListTile(
                title: Text('Profanity Filter'),
                subtitle: Text('Automatically filter inappropriate content'),
                value: true, // You'll need to store this in your group data
                onChanged: (value) => _toggleProfanityFilter(value),
              ),
              SwitchListTile(
                title: Text('Link Restrictions'),
                subtitle: Text('Prevent sharing of external links'),
                value: false, // You'll need to store this in your group data
                onChanged: (value) => _toggleLinkRestrictions(value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _containsLink(String text) {
    final urlRegex = RegExp(r'https?://[^\s]+');
    return urlRegex.hasMatch(text);
  }

  void _addParticipants() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Participants'),
        content: Text('Feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleMemberAction(String action, String memberId, bool isAdmin) {
    switch (action) {
      case 'promote':
        _promoteToAdmin(memberId);
        break;
      case 'demote':
        _demoteFromAdmin(memberId);
        break;
      case 'remove':
        _removeMember(memberId);
        break;
    }
  }

  void _promoteToAdmin(String memberId) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'admins': FieldValue.arrayUnion([memberId]),
    });
  }

  void _demoteFromAdmin(String memberId) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'admins': FieldValue.arrayRemove([memberId]),
    });
  }

  void _removeMember(String memberId) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'members': FieldValue.arrayRemove([memberId]),
      'admins': FieldValue.arrayRemove([memberId]),
      'memberCount': FieldValue.increment(-1),
    });
  }

  void _toggleReadOnlyMode(bool value) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'isReadOnly': value,
    });
  }

  void _toggleProfanityFilter(bool value) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'profanityFilter': value,
    });
  }

  void _toggleLinkRestrictions(bool value) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'linkRestrictions': value,
    });
  }
}

// NEW: Search Dialog Widget
class SearchDialog extends StatefulWidget {
  final String groupId;

  const SearchDialog({Key? key, required this.groupId}) : super(key: key);

  @override
  _SearchDialogState createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<QueryDocumentSnapshot> _searchResults = [];
  bool _isSearching = false;

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await _firestore
          .collection('groups')
          .doc(widget.groupId)
          .collection('messages')
          .where('text', isGreaterThanOrEqualTo: query)
          .where('text', isLessThanOrEqualTo: query + '\uf8ff')
          .get();

      setState(() {
        _searchResults = results.docs;
        _isSearching = false;
      });
    } catch (e) {
      print("Search error: $e");
      setState(() {
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: bgWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.search, color: primaryPink),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search in chat...',
                      border: InputBorder.none,
                    ),
                    onChanged: _performSearch,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(),
            SizedBox(height: 16),
            if (_isSearching)
              Center(child: CircularProgressIndicator(color: primaryPink))
            else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
              Center(child: Text('No messages found'))
            else if (_searchResults.isEmpty)
              Center(child: Text('Enter search terms above'))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final message = _searchResults[index];
                    final data = message.data() as Map<String, dynamic>;
                    final String text = data['text'] ?? '';
                    final Timestamp timestamp = data['timestamp'];
                    
                    return ListTile(
                      title: Text(text),
                      subtitle: Text(DateFormat.yMMMd().add_Hm().format(timestamp.toDate())),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  const GroupChatScreen({Key? key, required this.groupId}) : super(key: key);
  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late String _currentUserId;
  late DocumentReference _groupDocRef;
  File? _imageToSend;


  bool _isMember = false;
  bool _isAdmin = false;
  bool _isModerator = false;
  bool _isReadOnly = false;


  Map<String, dynamic> _typingStatus = {};
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showScrollToBottom = false;
  double _lastScrollOffset = 0.0;

  // Message reply variables
  Map<String, dynamic>? _replyingToMessage;
  final FocusNode _messageFocusNode = FocusNode();

  // Inside _GroupsScreenState class, near other variable declarations like _groupNameController, _isPrivate, etc.
  // Add these lines:
  String _selectedAgeRating = '13-17'; // Default age rating
  final List<String> _ageRatings = ['13-17', '18-25', '26+'];
  List<String> _hashtags = []; // Store hashtags
  final TextEditingController _hashtagController = TextEditingController(); // For adding hashtags
  

  // The _isMember and _isReadOnly variables belong in _GroupChatScreenState, not here.
  // They are likely already declared there, or should be if they are missing.

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _groupDocRef = _firestore.collection('groups').doc(widget.groupId);
    _checkMembership();
    _markMessagesAsRead();
    _setupTypingListener();
    _scrollController.addListener(_scrollListener);
    // Initialize audio recorder and player
  }

  

  Future<void> _preloadUserProfiles(List<QueryDocumentSnapshot> messages) async {
    print("GroupChatScreen._preloadUserProfiles: Starting preload for ${messages.length} messages.");
    final userIds = messages
        .map((msg) => msg['senderId'] as String)
        .where((id) => id != null && id.isNotEmpty) // Basic validation
        .toList();
    print("GroupChatScreen._preloadUserProfiles: Extracted sender IDs: $userIds");

    if (userIds.isNotEmpty) {
      // Call the cache's preload function
      await UserProfileCache.preloadUserProfiles(userIds);
      print("GroupChatScreen._preloadUserProfiles: Preload completed.");
    } else {
      print("GroupChatScreen._preloadUserProfiles: No valid sender IDs found to preload.");
    }
  }

  // Inside _GroupChatScreenState class
  Future<void> _pickFile() async {
    if (!_isMember || _isReadOnly) return; // Use class variables
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // Allows any file type
        // Or be more specific:
        // type: FileType.custom,
        // allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        // Pass the file to your sendMessage function
        // You need to implement _sendMessage to handle File type
        // Example: _sendMessage(file: file); 
        // The actual implementation depends on how you send messages.
        // It would involve uploading the file.bytes or file.path to Firebase Storage
        // and then calling _sendMessage with the download URL and type 'file'.
      } else {
        // User canceled the picker
      }
    } catch (e) {
      print("Error picking file: $e");
      // Use context from the widget state
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file. Please try again.')),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _typingTimer?.cancel();
    _stopTyping();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final delta = 20.0;
    if (!_showScrollToBottom && currentScroll < maxScroll - delta) {
      setState(() {
        _showScrollToBottom = true;
      });
    } else if (_showScrollToBottom && currentScroll >= maxScroll - delta) {
      setState(() {
        _showScrollToBottom = false;
      });
    }
    _lastScrollOffset = currentScroll;
  }

  Future<void> _checkMembership() async {
    final groupDoc = await _groupDocRef.get();
    if (groupDoc.exists) {
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final List<dynamic> members = groupData['members'] ?? [];
      final List<dynamic> admins = groupData['admins'] ?? [];
      final List<dynamic> moderators = groupData['moderators'] ?? [];
      final bool isReadOnly = groupData['isReadOnly'] ?? false;
      setState(() {
        _isMember = members.contains(_currentUserId);
        _isAdmin = admins.contains(_currentUserId);
        _isModerator = moderators.contains(_currentUserId);
        _isReadOnly = isReadOnly;
      });
    }
  }

  

  void _setupTypingListener() {
    _groupDocRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _typingStatus = data['typing'] ?? {};
        });
      }
    });
  }

  void _startTyping() {
    if (!_isMember || _isReadOnly) return;
    if (!_isTyping) {
      _isTyping = true;
      _groupDocRef.update({
        'typing.$_currentUserId': FieldValue.serverTimestamp(),
      });
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(Duration(seconds: 2), _stopTyping);
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      _groupDocRef.update({
        'typing.$_currentUserId': FieldValue.delete(),
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final groupDoc = await _groupDocRef.get();
      if (!groupDoc.exists) return;
      final groupData = groupDoc.data() as Map<String, dynamic>?;
      if (groupData == null) return;
      final Map<String, dynamic> unreadCountMap =
          groupData['unreadCount'] ?? {};
      final int currentUnread = unreadCountMap[_currentUserId] ?? 0;
      if (currentUnread > 0) {
        await _groupDocRef.update({
          'unreadCount.$_currentUserId': 0,
        });
      }
    } catch (e) {
      print("Error marking messages as read: $e");
    }
  }

 Future<void> _pickImage() async {
    if (!_isMember || _isReadOnly) return;
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
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

  Future<void> _cropAndEditImage(File imageFile) async {
    try {
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Edit Image',
            toolbarColor: primaryPink,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Edit Image',
          ),
        ],
      );
      if (croppedFile != null) {
        // Navigate to image preview screen with caption option
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ImagePreviewScreen(imageFile: File(croppedFile.path)),
          ),
        );
        if (result != null && result is Map<String, dynamic>) {
          final File editedImage = result['image'];
          final String caption = result['caption'] ?? '';
          _sendMessage(
              imageFile: editedImage,
              text: caption.isNotEmpty ? caption : null);
        }
      }
    } catch (e) {
      print("Error cropping image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to edit image. Please try again.')),
      );
    }
  }

  // Message sending methods
  Future<void> _sendMessage({File? imageFile, String? text}) async {
    if (!_isMember || _isReadOnly) return;
    final messageText = text ?? _messageController.text.trim();
    if (messageText.isEmpty && imageFile == null) return;
    try {
      String? imageUrl;
      if (imageFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('group_chats')
            .child(widget.groupId)
            .child('images')
            .child('${Uuid().v4()}.jpg');
        await ref.putFile(imageFile);
        imageUrl = await ref.getDownloadURL();
      }
      final messageId = Uuid().v4();
      final timestamp = FieldValue.serverTimestamp();
      final messageData = {
        'id': messageId,
        'groupId': widget.groupId,
        'senderId': _currentUserId,
        'text': messageText,
        'imageUrl': imageUrl,
        'timestamp': timestamp,
        'type': imageUrl != null ? 'image' : 'text',
        'reactions': {},
        'replies': 0,
        'status': 'sent',
        'replyTo': _replyingToMessage != null
            ? {
                'messageId': _replyingToMessage!['id'],
                'senderId': _replyingToMessage!['senderId'],
                'text': _replyingToMessage!['text'] ??
                    (_replyingToMessage!['type'] == 'image'
                        ? '📷 Image'
                        : 'Audio'),
              }
            : null,
      };
      await _groupDocRef.collection('messages').doc(messageId).set(messageData);
      final groupUpdateData = {
        'lastMessage': imageUrl != null ? '📷 Image' : messageText,
        'lastMessageTime': timestamp,
        'lastMessageSender': _currentUserId,
      };
      await _groupDocRef.update(groupUpdateData);
      // Update unread counts
      final groupDoc = await _groupDocRef.get();
      if (groupDoc.exists) {
        final groupData = groupDoc.data() as Map<String, dynamic>;
        final List<dynamic> members = groupData['members'] ?? [];
        final Map<String, dynamic> unreadCountMap =
            groupData['unreadCount'] ?? {};
        for (var memberId in members) {
          if (memberId != _currentUserId) {
            final currentCount = unreadCountMap[memberId] ?? 0;
            unreadCountMap[memberId] = currentCount + 1;
          }
        }
        await _groupDocRef.update({'unreadCount': unreadCountMap});
      }
      _messageController.clear();
      // Clear reply if it exists
      setState(() {
        _replyingToMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message. Please try again.')),
      );
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

  void _cancelReply() {
    setState(() {
      _replyingToMessage = null;
    });
    _messageFocusNode.requestFocus();
  }

  void _replyToMessage(Map<String, dynamic> message) {
    setState(() {
      _replyingToMessage = message;
    });
    _messageFocusNode.requestFocus();
  }

  void _jumpToMessage(String messageId) {
    // This would ideally scroll to the specific message
    // For now, we'll just clear the reply
    setState(() {
      _replyingToMessage = null;
    });
  }

  Future<String?> _getProfileImageUrl(String userId) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child("profile_images/$userId.jpg"); // 🔥 check your folder name
      return await ref.getDownloadURL();
    } catch (e) {
      print("No profile image for $userId: $e");
      return null;
    }
  }

  // NEW: Enhanced three-dot menu implementation
  void _showThreeDotMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: bgWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardWhite,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.more_vert, color: primaryPink, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Group Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryPink,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: primaryPink),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    // Group Info Section
                    _buildMenuSection(
                      title: 'Group Info',
                      icon: Icons.info_outline,
                      onTap: _showGroupInfoScreen,
                    ),
                    
                    // Search Section
                    _buildMenuSection(
                      title: 'Search',
                      icon: Icons.search,
                      onTap: _showSearchScreen,
                    ),
                    
                    // Wallpaper Section
                    _buildMenuSection(
                      title: 'Wallpaper',
                      icon: Icons.wallpaper,
                      onTap: _showWallpaperOptions,
                    ),
                    
                    // More Options Section
                    _buildExpandableSection(
                      title: 'More Options',
                      icon: Icons.expand_more,
                      children: [
                        if (!_isAdmin) // Only show report for non-admins
                          _buildMenuOption(
                            title: 'Report Group',
                            icon: Icons.report,
                            color: Colors.orange,
                            onTap: _reportGroup,
                          ),
                        _buildMenuOption(
                          title: 'Exit Group',
                          icon: Icons.exit_to_app,
                          color: Colors.red,
                          onTap: _leaveGroup,
                        ),
                      ],
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

  Widget _buildMenuSection({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryPink, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryPink, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        children: children,
      ),
    );
  }

  Widget _buildMenuOption({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  // NEW: Group Info Screen
  void _showGroupInfoScreen() {
    Navigator.pop(context); // Close the menu first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupInfoScreen(groupId: widget.groupId),
      ),
    );
  }

  // NEW: Search Screen
  void _showSearchScreen() {
    Navigator.pop(context); // Close the menu first
    showDialog(
      context: context,
      builder: (context) => SearchDialog(groupId: widget.groupId),
    );
  }

  // NEW: Wallpaper Options
  void _showWallpaperOptions() {
    Navigator.pop(context); // Close the menu first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Wallpaper'),
        content: Text('Wallpaper feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: primaryPink)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgWhite,
      body: Column(
        children: [
          // Group info header - REPLACED with three-dot menu
          StreamBuilder<DocumentSnapshot>(
            stream: _groupDocRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Container();
              final groupData =
                  snapshot.data!.data() as Map<String, dynamic>?;
              final String groupName = groupData?['name'] ?? 'Group';
              final String groupImage = groupData?['imageUrl'] ?? '';
              final int memberCount = groupData?['memberCount'] ?? 0;
              return Container(
                padding: EdgeInsets.all(16),
                color: cardWhite,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: groupImage.isNotEmpty
                          ? CachedNetworkImageProvider(groupImage)
                          : AssetImage('assets/femnlogo.png',)
                              as ImageProvider,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '$memberCount members',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // REPLACED: Info button with three-dot menu
                    // NEW: Enhanced three-dot menu
                    IconButton(
                      icon: Icon(Icons.more_vert, color: primaryPink),
                      onPressed: _showThreeDotMenu,
                    ),
                  ],
                ),
              );
            },
          ),
          // Typing indicators
          if (_typingStatus.isNotEmpty)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  // Inside the Typing indicators Container
                  Text(
                    '${_typingStatus.keys.length} ${_typingStatus.keys.length == 1 ? 'person is' : 'people are'} typing...',
                    style: TextStyle(
                      color: darkPink,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          // Messages list
Expanded(
  child: StreamBuilder<QuerySnapshot>(
    stream: _groupDocRef
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(
          child: CircularProgressIndicator(color: primaryPink),
        );
      }
      final messages = snapshot.data!.docs;

      // Preload user profiles when messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _preloadUserProfiles(messages);
      });

      return Stack(
        children: [
          ListView.builder(
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
              final String? imageUrl = messageData['imageUrl'];
              final Timestamp? timestamp = messageData['timestamp'];
              final Map<String, dynamic>? replyTo = messageData['replyTo'] is Map
                  ? Map<String, dynamic>.from(messageData['replyTo'])
                  : null;
              final bool isMe = senderId == _currentUserId;
              final DateTime? messageTime = timestamp?.toDate();

              // 🔥 Use StreamBuilder so avatar & username auto-refresh
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(senderId)
                    .snapshots(),
                builder: (context, userSnapshot) {
                  String senderUsername = 'User';

                  if (userSnapshot.hasData && userSnapshot.data!.exists) {
                    final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                    senderUsername = userData['username'] ?? userData['name'] ?? 'User';
                  }

                  return GestureDetector(
                    onLongPress: () {
                      _showMessageOptions(messageData);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          // --- AVATAR (only show for other users) ---
                          if (!isMe) ...[
                            Builder(
                              builder: (context) {
                                final cachedProfile = UserProfileCache.getCachedProfile(senderId);
                                if (cachedProfile != null && cachedProfile['profileImage'] != null) {
                                  final profileImageUrl = cachedProfile['profileImage'] as String;
                                  return Container(
                                    padding: const EdgeInsets.all(1.5), // thin outline
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Color(0xFFFFB7C5), width: 1.5),
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.grey[300],
                                      backgroundImage: profileImageUrl.isNotEmpty
                                          ? CachedNetworkImageProvider(profileImageUrl)
                                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                    ),
                                  );
                                }

                                // fallback → fetch only if cache is empty
                                return FutureBuilder<String?>(
                                  future: UserProfileCache.getUserProfile(senderId)
                                      .then((profile) => profile['profileImage'] as String?),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Container(
                                        padding: const EdgeInsets.all(1.5),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Color(0xFFFFB7C5), width: 1.5),
                                        ),
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.grey[300],
                                          child: const Icon(Icons.person, size: 16),
                                        ),
                                      );
                                    }

                                    final profileImageUrl = snapshot.data!;
                                    return Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Color(0xFFFFB7C5), width: 1.5),
                                      ),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage: profileImageUrl.isNotEmpty
                                            ? CachedNetworkImageProvider(profileImageUrl)
                                            : null,
                                        child: profileImageUrl.isEmpty
                                            ? const Icon(Icons.person, size: 16)
                                            : null,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                          ],

            // --- MESSAGE BUBBLE ---
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: isMe ? outgoingBubble : incomingBubble,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8.0,
                          left: 12.0,
                          right: 12.0,
                          bottom: 4.0,
                        ),
                        child: Text(
                          senderUsername,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 8.0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replyTo != null) _buildReplyPreview(replyTo, isMe),

                          if (type == 'text' && text.isNotEmpty)
                            Text(
                              text,
                              style: const TextStyle(color: Colors.black87),
                            ),

                          if (type == 'image' && imageUrl != null)
                            _buildImageMessage(imageUrl, text),

                          if (messageTime != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                DateFormat.Hm().format(messageTime),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMe ? Colors.black54 : Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
;

            },
          ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _scrollToBottom,
                mini: true,
                backgroundColor: primaryPink,
                child: Icon(Icons.arrow_downward,
                    color: Colors.white, size: 20),
              ),
            ),
        ],
      );
    },
  ),
),
          // --- Modified Message Input Area ---
          if (_isMember &&
              !_isReadOnly) // Only show input area if member and not read-only
            Container(
              padding: EdgeInsets.all(8),
              color: cardWhite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview (if replying to a message)
                  if (_replyingToMessage != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.grey[100],
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to ${_replyingToMessage!['senderId'] == _currentUserId ? 'yourself' : 'message'}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _replyingToMessage!['text'] ??
                                      (_replyingToMessage!['type'] == 'image'
                                          ? '📷 Image'
                                          : ''),
                                  style: TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 18),
                            onPressed: _cancelReply,
                          ),
                        ],
                      ),
                    ),
                  // Standard message input row
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.image, color: primaryPink),
                        onPressed: _pickImage,
                      ),
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(maxHeight: 100),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            onChanged: (value) => _startTyping(),
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (value) => _sendMessage(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _messageController.text.isNotEmpty
                              ? Icons.send
                              : Icons.add,
                          color: primaryPink,
                        ),
                        onPressed: () {
                          if (_messageController.text.isNotEmpty) {
                            _sendMessage();
                          } else {
                            // Optionally show options for attachments
                            _showAttachmentOptions();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          // --- End Modified Message Input Area ---
        ],
      ),
    );
  }

  // Add this helper method for attachment options
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.image, color: primaryPink),
                title: Text('Send Image'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Icons.insert_drive_file, color: primaryPink),
                title: Text('Send File'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFile();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview(Map<String, dynamic> replyData, bool isMe) {
    final String repliedMessageSenderId = replyData['senderId'];
    final bool isReplyingToSelf = repliedMessageSenderId == _currentUserId;
    
    return FutureBuilder<Map<String, dynamic>>(
      future: UserProfileCache.getUserProfile(repliedMessageSenderId),
      builder: (context, userSnapshot) {
        String senderName = 'User'; // Default fallback
        
        if (userSnapshot.hasData) {
          final userData = userSnapshot.data!;
          senderName = userData['name'] ?? userData['username'] ?? 'User';
        } else if (isReplyingToSelf) {
          senderName = 'You';
        }
        
        return Container(
          padding: EdgeInsets.all(8),
          margin: EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: (isMe
                ? primaryPink.withOpacity(0.2)
                : Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isMe ? primaryPink : Colors.grey,
                width: 3,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName, // Use the actual username instead of "Someone"
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isMe ? primaryPink : Colors.grey[700],
                ),
              ),
              SizedBox(height: 2),
              Text(
                replyData['text'] ?? 'Media',
                style: TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageMessage(String imageUrl, String caption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ImageViewerScreen(imageUrl: imageUrl),
              ),
            );
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
                color: Colors.grey[300],
                child: Center(
                    child: CircularProgressIndicator(color: primaryPink)),
              ),
              errorWidget: (context, url, error) => Container(
                width: 200,
                height: 200,
                color: Colors.grey[300],
                child: Icon(Icons.error),
              ),
            ),
          ),
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              caption,
              style: TextStyle(color: Colors.black87),
            ),
          ),
      ],
    );
  }


  void _showMessageOptions(Map<String, dynamic> messageData) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.reply, color: primaryPink),
                title: Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _replyToMessage(messageData);
                },
              ),
              ListTile(
                leading: Icon(Icons.content_copy, color: primaryPink),
                title: Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
                  if (messageData['text'] != null) {
                    Clipboard.setData(ClipboardData(text: messageData['text']));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Message copied')),
                    );
                  }
                },
              ),
              if (messageData['imageUrl'] != null)
                ListTile(
                  leading: Icon(Icons.download, color: primaryPink),
                  title: Text('Save to gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    // Implement save to gallery functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Image saved to gallery')),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

 // NEW: Group info dialog
  void _showGroupInfo() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Group Info'),
          content: StreamBuilder<DocumentSnapshot>(
            stream: _groupDocRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final groupData = snapshot.data!.data() as Map<String, dynamic>;
              final String name = groupData['name'] ?? '';
              final String description = groupData['description'] ?? '';
              final Timestamp createdAt = groupData['createdAt'] ?? Timestamp.now();
              final int memberCount = groupData['memberCount'] ?? 0;
              final String category = groupData['category'] ?? 'General';

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: $name', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  if (description.isNotEmpty) Text('Description: $description'),
                  SizedBox(height: 8),
                  Text('Category: $category'),
                  SizedBox(height: 8),
                  Text('Created: ${DateFormat.yMMMd().format(createdAt.toDate())}'),
                  SizedBox(height: 8),
                  Text('Members: $memberCount'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Group media screen
  void _showGroupMedia() {
    // Implementation for showing group media
    // This would typically navigate to a new screen showing images, videos, and links
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMediaScreen(groupId: widget.groupId),
      ),
    );
  }

  // NEW: Search dialog
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        return AlertDialog(
          title: Text('Search in Chat'),
          content: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Enter search term...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement search functionality
                _searchInChat(searchController.text);
                Navigator.pop(context);
              },
              child: Text('Search'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Search in chat implementation
  void _searchInChat(String query) {
    // Implementation for searching within the chat
    // This would typically filter messages based on the query
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Search for: $query')),
    );
  }

  // NEW: Leave group functionality
  void _leaveGroup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Leave Group'),
          content: Text('Are you sure you want to leave this group?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await _groupDocRef.update({
                    'members': FieldValue.arrayRemove([_currentUserId]),
                    'memberCount': FieldValue.increment(-1),
                    'unreadCount.$_currentUserId': FieldValue.delete(),
                  });

                  // If user was admin, remove from admins list
                  if (_isAdmin) {
                    await _groupDocRef.update({
                      'admins': FieldValue.arrayRemove([_currentUserId]),
                    });
                  }

                  // If user was moderator, remove from moderators list
                  if (_isModerator) {
                    await _groupDocRef.update({
                      'moderators': FieldValue.arrayRemove([_currentUserId]),
                    });
                  }

                  Navigator.pop(context); // Go back to groups list
                } catch (e) {
                  print("Error leaving group: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to leave group. Please try again.')),
                  );
                }
              },
              child: Text('Leave', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // NEW: Report group functionality
  void _reportGroup() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController reportController = TextEditingController();
        return AlertDialog(
          title: Text('Report Group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please describe the issue:'),
              SizedBox(height: 8),
              TextField(
                controller: reportController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement report functionality
                _submitReport(reportController.text);
                Navigator.pop(context);
              },
              child: Text('Submit Report'),
            ),
          ],
        );
      },
    );
  }

  // NEW: Submit report implementation
  void _submitReport(String reason) {
    // Implementation for submitting a group report
    // This would typically save the report to a separate collection
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report submitted successfully')),
    );
  }
}

// NEW: GroupMediaScreen class for showing group media
class GroupMediaScreen extends StatelessWidget {
  final String groupId;

  const GroupMediaScreen({Key? key, required this.groupId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Media'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('messages')
            .where('type', whereIn: ['image', 'video'])
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final mediaMessages = snapshot.data!.docs;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: mediaMessages.length,
            itemBuilder: (context, index) {
              final message = mediaMessages[index];
              final messageData = message.data() as Map<String, dynamic>;
              final String mediaUrl = messageData['imageUrl'] ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageViewerScreen(imageUrl: mediaUrl),
                    ),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: mediaUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ImagePreviewScreen extends StatefulWidget {
  final File imageFile;
  const ImagePreviewScreen({Key? key, required this.imageFile})
      : super(key: key);

  @override
  _ImagePreviewScreenState createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _editedImage;

  @override
  void initState() {
    super.initState();
    _editedImage = widget.imageFile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Image'),
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, {
                'image': _editedImage!,
                'caption': _captionController.text,
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              child: Image.file(_editedImage!),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _captionController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  const ImageViewerScreen({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: Hero(
            tag: imageUrl,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

  // Custom painter for waveform visualization
  class _WaveformPainter extends CustomPainter {
    final int duration;

    _WaveformPainter(this.duration);

    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      final rng = Random(duration);
      final barWidth = 3.0;
      final spacing = 2.0;
      final totalBars = (size.width / (barWidth + spacing)).floor();

      for (int i = 0; i < totalBars; i++) {
        final height = rng.nextDouble() * size.height;
        final x = i * (barWidth + spacing);

        canvas.drawRect(
          Rect.fromLTWH(x, (size.height - height) / 2, barWidth, height),
          paint,
        );
      }
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
  }

void main() {
  runApp(MaterialApp(
    title: 'Women Support Groups',
    theme: ThemeData(
      primaryColor: primaryPink,
      colorScheme: ColorScheme.light(
        primary: primaryPink,
        secondary: lightPink,
      ),
      scaffoldBackgroundColor: bgWhite,
      appBarTheme: AppBarTheme(
        backgroundColor: cardWhite,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
      ),
    ),
    home: GroupsScreen(),
  ));
}