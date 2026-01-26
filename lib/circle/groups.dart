import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth/auth.dart';
import 'package:femn/circle/discussions.dart';
import 'package:femn/customization/colors.dart'; // Import the new color scheme
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart'; // For SystemUiOverlayStyle
import 'package:flutter/widgets.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:femn/customization/layout.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../feed/addpost.dart';
import 'package:femn/hub_screens/profile.dart';
import 'package:femn/hub_screens/search.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:math';
import 'petitions.dart';
import 'polls.dart'; 
import 'package:collection/collection.dart'; // For comparing lists (though not directly used in current code)
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:shimmer/shimmer.dart';

// Remove old color constants and use AppColors instead
const Map<String, IconData> _optionIcons = {
  'Polls': Feather.bar_chart_2,
  'Discussions': Feather.message_square,
  'Groups': Feather.users,
  'Mentorship': Feather.book_open,
  'Petitions': Feather.check_square,
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
  final List<String> _contentTypes = ['All', 'Groups', 'Polls', 'Discussions', 'Archived', 'Petitions'];
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
        return const GridShimmerSkeleton();
      }

      if (snapshot.hasError || !snapshot.hasData) {
        return Center(child: Text('Error loading content.', style: TextStyle(color: AppColors.textHigh)));
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
              Icon(Feather.compass, size: 50, color: AppColors.textDisabled),
              SizedBox(height: 16),
              Text(
                'Nothing here yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textHigh),
              ),
              SizedBox(height: 8),
              Text(
                'Explore or create content!',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textDisabled),
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
          crossAxisCount: ResponsiveLayout.getColumnCount(context),
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
              final Map<String, dynamic> ratings = itemData['ratings'] ?? {};
              double averageRating = 0;
              if (ratings.isNotEmpty) {
                averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
              }
              final int ratingCount = ratings.length;

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: cardMarginVertical,
                  horizontal: cardMarginHorizontal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22), // smoother rounded corners
                ),
                color: AppColors.surface,
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
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: AppColors.elevation,
                                    highlightColor: AppColors.surface.withOpacity(0.5),
                                    child: Container(color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Feather.alert_circle, color: AppColors.primaryLavender),
                                )
                              : Container(
                                  width: double.infinity,
                                  color: AppColors.elevation,
                                  padding: const EdgeInsets.all(28),
                                  child: const Icon(
                                    Feather.users,
                                    color: AppColors.primaryLavender,
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
                            color: AppColors.primaryLavender,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Rating Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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

                        const SizedBox(height: 6),
                        const SizedBox(height: 12),

                        // Member count pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryTeal,
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
                                Feather.users,
                                size: 16,
                                color: AppColors.textOnSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$memberCount members',
                                style: const TextStyle(
                                  color: AppColors.textOnSecondary,
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
              final Map<String, dynamic> ratings = itemData['ratings'] ?? {};
              double averageRating = 0;
              if (ratings.isNotEmpty) {
                averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
              }
              final int ratingCount = ratings.length;

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
                color: AppColors.surface,
                elevation: 3,
                shadowColor: AppColors.elevation,
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
                                        placeholder: (context, url) => Shimmer.fromColors(
                                          baseColor: AppColors.elevation,
                                          highlightColor: AppColors.surface.withOpacity(0.5),
                                          child: Container(color: Colors.white),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Feather.alert_circle),
                                      )
                                    : Container(
                                        color: AppColors.elevation,
                                        child: const Icon(Feather.message_square, color: AppColors.textDisabled),
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
                            color: AppColors.primaryLavender,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Rating Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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

                        const SizedBox(height: 10),

                        // 🕓 Days left (if active)
                        if (!isArchived && daysLeft != null)
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryTeal,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLavender.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              '$daysLeft days left',
                              style: const TextStyle(
                                color: AppColors.textOnSecondary,
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
                                ? AppColors.textDisabled
                                : AppColors.secondaryTeal,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: (isArchived
                                        ? AppColors.textDisabled
                                        : AppColors.primaryLavender)
                                    .withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Feather.users,
                                  size: 14,
                                  color: isArchived ? AppColors.textHigh : AppColors.textOnSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount members',
                                style: TextStyle(
                                  color: isArchived ? AppColors.textHigh : AppColors.textOnSecondary,
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
                color: AppColors.surface,
                elevation: 2,
                shadowColor: AppColors.elevation,
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
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: AppColors.elevation,
                                    highlightColor: AppColors.surface.withOpacity(0.5),
                                    child: Container(color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Feather.alert_circle),
                                )
                              : Container(
                                  height: 140,
                                  width: double.infinity,
                                  color: AppColors.elevation,
                                  child: const Icon(Feather.image, color: AppColors.textDisabled),
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
                            color: AppColors.primaryLavender,
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
                            color: AppColors.textMedium,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),

                        // Signature pill with progress border
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryTeal,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: AppColors.primaryLavender,
                              width: 4.5 * progress, // thin, proportional to progress
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLavender.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Feather.user_check, size: 14, color: AppColors.textOnSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${petition.currentSignatures}/${petition.goal} signatures',
                                style: const TextStyle(
                                  color: AppColors.textOnSecondary,
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
              return Card(
                color: AppColors.surface,
                child: ListTile(
                  title: Text('Unknown Item Type', style: TextStyle(color: AppColors.textHigh))
                )
              );
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
          return const GridShimmerSkeleton();
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Feather.users, size: 40, color: AppColors.textDisabled),
                  SizedBox(height: 12),
                  Text('No public groups yet', style: TextStyle(fontSize: 14, color: AppColors.textHigh)),
                  SizedBox(height: 6),
                  Text(
                    'Be the first to create a group!',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
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
                Icon(Feather.search, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                Text(
                  'No groups found in ${_selectedCategory == "All" ? "any category" : _selectedCategory}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
                SizedBox(height: 8),
                Text(
                  'Try a different category or create your own group',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // externalPadding
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 8.0, // cardSpacing
            crossAxisSpacing: 8.0, // cardSpacing
            itemCount: discoverGroups.length,
            itemBuilder: (context, index) {
              final group = discoverGroups[index];
              final groupData = group.data() as Map<String, dynamic>;
              final String groupId = group.id;
              final String groupName = groupData['name'] ?? 'Untitled';
              final String groupImage = groupData['imageUrl'] ?? '';
              final int memberCount = groupData['memberCount'] ?? 0;
              final String groupDescription = groupData['description'] ?? '';
              final Map<String, dynamic> ratings = groupData['ratings'] ?? {};
              double averageRating = 0;
              if (ratings.isNotEmpty) {
                averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
              }
              final int ratingCount = ratings.length;

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 2.0, // cardMarginVertical
                  horizontal: 2.0, // cardMarginHorizontal
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22), // matches _buildAllTab
                ),
                color: AppColors.surface,
                elevation: 4,
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
                    padding: const EdgeInsets.all(12.0), // cardInternalPadding
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
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: AppColors.elevation,
                                    highlightColor: AppColors.surface.withOpacity(0.5),
                                    child: Container(color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Feather.alert_circle, color: AppColors.primaryLavender),
                                )
                              : Container(
                                  width: double.infinity,
                                  color: AppColors.elevation,
                                  padding: const EdgeInsets.all(28),
                                  child: const Icon(
                                    Feather.users,
                                    color: AppColors.primaryLavender,
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
                            color: AppColors.primaryLavender,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // Rating Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
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

                        const SizedBox(height: 6),
                        const SizedBox(height: 12),

                        // Member count pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryTeal,
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
                                Feather.users,
                                size: 16,
                                color: AppColors.textOnSecondary,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$memberCount members',
                                style: const TextStyle(
                                  color: AppColors.textOnSecondary,
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
          return const GridShimmerSkeleton();
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.bar_chart_2, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                Text(
                  'No polls yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to create a poll!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }
        
        final polls = snapshot.data!.docs;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            itemCount: polls.length,
            itemBuilder: (context, index) {
              final poll = polls[index];
              return PollCard(
                pollSnapshot: poll,
                cardMarginVertical: 2.0,
                cardMarginHorizontal: 2.0,
                cardInternalPadding: 12.0,
                borderRadiusValue: 24.0,
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
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
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
        
        final allDiscussions = snapshot.data!.docs;
        final discussions = allDiscussions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return !_isDiscussionArchived(data);
        }).toList();
        
        if (discussions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.message_square, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                const Text(
                  'No active discussions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
              ],
            ),
          );
        }
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            itemCount: discussions.length,
            itemBuilder: (context, index) {
              final discussion = discussions[index];
              final discussionData = discussion.data() as Map<String, dynamic>;
              final String discussionId = discussion.id;
              final String discussionName = discussionData['name'] ?? 'Untitled Discussion';
              final String discussionImage = discussionData['imageUrl'] ?? '';
              final int memberCount = discussionData['memberCount'] ?? 0;
              final String discussionDescription = discussionData['description'] ?? '';

              final bool isArchived = _isDiscussionArchived(discussionData);
              final int? daysLeft = isArchived ? null : _getDaysLeft(discussionData);

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 2.0,
                  horizontal: 2.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                color: AppColors.surface,
                elevation: 3,
                shadowColor: AppColors.elevation,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24.0),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🖼️ Image with shimmer
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20.0),
                          child: SizedBox(
                            width: double.infinity,
                            height: 140,
                            child: discussionImage.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: discussionImage,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: AppColors.elevation,
                                      highlightColor: AppColors.surface.withOpacity(0.5),
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Feather.alert_circle),
                                  )
                                : Container(
                                    color: AppColors.elevation,
                                    child: const Icon(Feather.message_square, color: AppColors.textDisabled),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 🏷️ Title
                        Text(
                          discussionName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryLavender,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // 📝 Description
                        Text(
                          discussionDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
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
                              color: AppColors.secondaryTeal,
                              borderRadius: BorderRadius.circular(50),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryLavender.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              '$daysLeft days left',
                              style: const TextStyle(
                                color: AppColors.textOnSecondary,
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
                                ? AppColors.textDisabled
                                : AppColors.secondaryTeal,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: [
                              BoxShadow(
                                color: (isArchived
                                        ? AppColors.textDisabled
                                        : AppColors.primaryLavender)
                                    .withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Feather.users,
                                  size: 14,
                                  color: isArchived ? AppColors.textHigh : AppColors.textOnSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount members',
                                style: TextStyle(
                                  color: isArchived ? AppColors.textHigh : AppColors.textOnSecondary,
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
            },
          ),
        );

      },
    );
  }

  Widget _buildArchivedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groups')
          .where('category', isEqualTo: 'Discussions')
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
                Icon(Feather.archive, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                const Text(
                  'No archived discussions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
              ],
            ),
          );
        }

        final allDiscussions = snapshot.data!.docs;
        final archivedDiscussions = allDiscussions.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return _isDiscussionArchived(data);
        }).toList();

        if (archivedDiscussions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.archive, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                const Text(
                  'No archived discussions',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            itemCount: archivedDiscussions.length,
            itemBuilder: (context, index) {
              final discussion = archivedDiscussions[index];
              final discussionData = discussion.data() as Map<String, dynamic>;
              final String discussionId = discussion.id;
              final String discussionName = discussionData['name'] ?? 'Untitled Discussion';
              final String discussionImage = discussionData['imageUrl'] ?? '';
              final int memberCount = discussionData['memberCount'] ?? 0;
              final String discussionDescription = discussionData['description'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 2.0,
                  horizontal: 2.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                color: AppColors.surface,
                elevation: 3,
                shadowColor: AppColors.elevation,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24.0),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🖼️ Image with shimmer and ARCHIVED overlay
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20.0),
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
                                        color: Colors.grey.withOpacity(0.5),
                                        colorBlendMode: BlendMode.saturation,
                                        placeholder: (context, url) => Shimmer.fromColors(
                                          baseColor: AppColors.elevation,
                                          highlightColor: AppColors.surface.withOpacity(0.5),
                                          child: Container(color: Colors.white),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(Feather.alert_circle),
                                      )
                                    : Container(
                                        color: AppColors.elevation,
                                        child: const Icon(Feather.message_square, color: AppColors.textDisabled),
                                      ),
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

                        // 🏷️ Title
                        Text(
                          discussionName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textDisabled,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // 📝 Description
                        Text(
                          discussionDescription,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textDisabled,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 10),

                        // 👥 Member count pill (Disabled style)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.elevation,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Feather.users, size: 14, color: AppColors.textDisabled),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount members',
                                style: const TextStyle(
                                  color: AppColors.textDisabled,
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
          return const GridShimmerSkeleton();
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.check_square, size: 50, color: AppColors.textDisabled),
                SizedBox(height: 16),
                Text(
                  'No petitions yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
                SizedBox(height: 8),
                Text(
                  'Be the first to create a petition!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        }

        final petitions = snapshot.data!.docs;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 8.0,
            crossAxisSpacing: 8.0,
            itemCount: petitions.length,
            itemBuilder: (context, index) {
              final petition = petitions[index];
              final petitionData = petition.data() as Map<String, dynamic>;
              final String petitionId = petition.id;
              final String title = petitionData['title'] ?? 'Untitled Petition';
              final String imageUrl = petitionData['imageUrl'] ?? '';
              final String description = petitionData['description'] ?? '';
              final int signaturesCount = petitionData['signaturesCount'] ?? petitionData['currentSignatures'] ?? 0;
              final int goal = petitionData['goal'] ?? 1000;
              final double progress = (signaturesCount / goal).clamp(0.0, 1.0);

              return Card(
                margin: const EdgeInsets.symmetric(
                  vertical: 2.0,
                  horizontal: 2.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24.0),
                ),
                color: AppColors.surface,
                elevation: 4,
                shadowColor: Colors.black.withOpacity(0.06),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24.0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EnhancedPetitionDetailScreen(petitionId: petitionId),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🖼️ Petition Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: imageUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: AppColors.elevation,
                                    highlightColor: AppColors.surface.withOpacity(0.5),
                                    child: Container(color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Feather.alert_circle),
                                )
                              : Container(
                                  height: 120,
                                  color: AppColors.elevation,
                                  width: double.infinity,
                                  child: const Icon(
                                    Feather.file_text,
                                    color: AppColors.primaryLavender,
                                    size: 32,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 12),

                        // 🏷️ Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryLavender,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 6),

                        // 📝 Description
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // 📊 Progress Bar
                        Stack(
                          children: [
                            Container(
                              height: 6,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.elevation,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryTeal,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.secondaryTeal.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ✍️ Signature Count
                        Text(
                          '$signaturesCount / $goal signed',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryTeal,
                          ),
                        ),
                      ],
                    ),
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
      backgroundColor: AppColors.surface,
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
                      Text('Create Petition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                      IconButton(
                        icon: Icon(Feather.x, color: AppColors.textHigh),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Petition Title *',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Petition Description *',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
                    ),
                    maxLines: 4,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _goalController,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Signature Goal *',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
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
                        child: Text(rating, style: TextStyle(color: AppColors.textHigh)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedAgeRating = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Age Rating',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
                    ),
                    dropdownColor: AppColors.surface,
                  ),
                  SizedBox(height: 16),
                  // Hashtags
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    children: _hashtags.map((tag) {
                      return Chip(
                        label: Text('#$tag', style: TextStyle(color: AppColors.textOnSecondary)),
                        backgroundColor: AppColors.secondaryTeal,
                        deleteIcon: Icon(Feather.x, size: 18, color: AppColors.textOnSecondary),
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
                          style: TextStyle(color: AppColors.textHigh),
                          decoration: InputDecoration(
                            labelText: 'Add Hashtag',
                            labelStyle: TextStyle(color: AppColors.textMedium),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: AppColors.elevation,
                            suffixIcon: IconButton(
                              icon: Icon(Feather.plus, color: AppColors.primaryLavender),
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
                    child: Text('Create Petition', style: TextStyle(color: AppColors.textOnSecondary)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: AppColors.primaryLavender,
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
        backgroundColor: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Coming Soon',
                style: TextStyle(
                  color: AppColors.accentMustard,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This feature is currently under development.',
                style: TextStyle(
                  color: AppColors.textMedium,
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
                    color: AppColors.elevation,
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
                        color: AppColors.primaryLavender,
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
      backgroundColor: AppColors.surface,
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
                  color: AppColors.primaryLavender,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Create New', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
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
      color: AppColors.elevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primaryLavender, width: 1.0),
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
              Icon(icon, color: AppColors.primaryLavender, size: 28),
              SizedBox(height: 8),
              Text(title, 
                  style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
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
        title: Text('Coming Soon', style: TextStyle(color: AppColors.textHigh)),
        content: Text('Mentorship feature is coming in a future update.', style: TextStyle(color: AppColors.textMedium)),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primaryLavender)),
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
      backgroundColor: AppColors.surface,
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
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                      IconButton(
                        icon: Icon(Feather.x, color: AppColors.textHigh),
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
                        backgroundColor: AppColors.elevation,
                        backgroundImage: _groupImage != null
                            ? FileImage(_groupImage!)
                            : null,
                        child: _groupImage == null
                            ? Icon(Feather.camera, size: 30, color: AppColors.textDisabled)
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _groupNameController, // Reusing the same controller for simplicity
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Discussion Title *',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _groupDescriptionController, // Reusing the same controller for simplicity
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
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
                        label: Text('#$tag', style: TextStyle(color: AppColors.textOnSecondary)),
                        backgroundColor: AppColors.secondaryTeal,
                        deleteIcon: Icon(Feather.x, size: 18, color: AppColors.textOnSecondary),
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
                          style: TextStyle(color: AppColors.textHigh),
                          decoration: InputDecoration(
                            labelText: 'Add Hashtag',
                            labelStyle: TextStyle(color: AppColors.textMedium),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: AppColors.elevation,
                            suffixIcon: IconButton(
                              icon: Icon(Feather.plus, color: AppColors.primaryLavender),
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
                        child: Text(rating, style: TextStyle(color: AppColors.textHigh)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setModalState(() {
                        _selectedAgeRating = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Age Rating',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: AppColors.elevation,
                    ),
                    dropdownColor: AppColors.surface,
                  ),
                  SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Private Discussion', style: TextStyle(color: AppColors.textHigh)),
                    subtitle: Text('Only invited members can join (Coming Soon)', style: TextStyle(color: AppColors.textMedium)),
                    value: _isPrivate,
                    onChanged: (value) {
                      setModalState(() {
                        _isPrivate = value;
                      });
                    },
                    activeColor: AppColors.primaryLavender,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _createDiscussion, // New method to create discussion
                    child: Text('Create', style: TextStyle(color: AppColors.textOnSecondary)),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                      backgroundColor: AppColors.primaryLavender,
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
      value: SystemUiOverlayStyle.light,
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
              color: AppColors.elevation,
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
                'assets/default_avatar.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
            // --- Space between logo and text ---
            SizedBox(width: 8), // Adjust spacing if needed
            // --- Original Title Text ---
            Text(
              'Circles',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh,),
            ),
          ],
        ),
        // --- Keep the rest of your AppBar properties ---
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
        actions: [
          // --- Add Button ---
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.elevation,
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
                Feather.plus,
                color: AppColors.primaryLavender,
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
              color: AppColors.elevation,
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
                    color: AppColors.elevation,
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
          color: AppColors.primaryLavender,
          backgroundColor: Colors.transparent,
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
                            color: isSelected ? AppColors.secondaryTeal : AppColors.elevation,
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
                                color: isSelected ? AppColors.textOnSecondary : AppColors.textHigh,
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
                          child: CircularProgressIndicator(color: AppColors.primaryLavender));
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
                                Icon(Feather.users, size: 20, color: AppColors.textDisabled),
                                const SizedBox(height: 16),
                                Text(
                                  'Join your first group!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textHigh,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Discover communities that matter to you',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textDisabled, fontSize: 14),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => _navigateToGroupCreationScreen(),
                                  child: const Text('Create Group', style: TextStyle(color: AppColors.textOnSecondary)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryLavender,
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
                                color: AppColors.surface,
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
                                      color: AppColors.elevation,
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
                                              'assets/default_avatar.png',
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
                                            color: AppColors.primaryLavender,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          displayMessage,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textMedium,
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
                                          color: AppColors.textMedium,
                                        ),
                                      ),
                                      if (hasNewMessages)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryLavender,
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
                                                color: AppColors.textOnSecondary,
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
    case 'Archived':
      return _buildArchivedTab();
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
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryLavender),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textHigh,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Create New Group ✨',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
            color: AppColors.textHigh,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
                        Icon(Feather.users, color: AppColors.primaryLavender, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'Create Your Community',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Fill in the details below to create your group and start connecting!',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Group Image
              _buildSectionHeader('Group Image', Feather.camera),
              SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _pickGroupImage,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.elevation,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.primaryLavender),
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
                                Icon(Feather.image, size: 40, color: AppColors.primaryLavender),
                                SizedBox(height: 6),
                                Text(
                                  "Upload Group Image",
                                  style: TextStyle(color: AppColors.primaryLavender),
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
              _buildSectionHeader('Group Title', Feather.type),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
child: TextField(
  controller: _groupNameController,
  // Combined the color and fontSize into one style argument
  style: TextStyle(
    color: AppColors.textHigh,
    fontSize: 16,
  ),
  decoration: InputDecoration(
    labelText: 'Enter group name',
    labelStyle: TextStyle(color: AppColors.textMedium),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: AppColors.elevation,
    prefixIcon: Icon(Feather.edit_2, color: AppColors.primaryLavender),
    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
  ),
),
              ),
              SizedBox(height: 20),

              // Description
              _buildSectionHeader('Description', Feather.align_left),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
child: TextField(
  controller: _groupDescriptionController,
  // Combined both style properties here
  style: TextStyle(
    color: AppColors.textHigh,
    fontSize: 16,
  ),
  decoration: InputDecoration(
    labelText: 'Describe your group...',
    labelStyle: TextStyle(color: AppColors.textMedium),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: AppColors.elevation,
    alignLabelWithHint: true,
    contentPadding: EdgeInsets.all(20),
  ),
  maxLines: 4,
),
              ),
              SizedBox(height: 20),

              // Age Rating
              _buildSectionHeader('Age Rating', Feather.users),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                      child: Text(rating, style: TextStyle(color: AppColors.textHigh)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedAgeRating = value!;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: 'Who should see this group?',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(Feather.users, color: AppColors.primaryLavender),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  dropdownColor: AppColors.surface,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                ),
              ),
              SizedBox(height: 20),

              // Hashtags
              _buildSectionHeader('Hashtags', Feather.hash),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _hashtagController,
                  style: TextStyle(color: AppColors.textHigh),
                  decoration: InputDecoration(
                    labelText: 'Add relevant hashtags',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(Feather.hash, color: AppColors.primaryLavender),
                    suffixIcon: IconButton(
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLavender,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Feather.plus, color: AppColors.textOnSecondary, size: 18),
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
                          colors: [AppColors.primaryLavender.withOpacity(0.2), AppColors.primaryLavender.withOpacity(0.1)],
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
                                color: AppColors.primaryLavender,
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
                              child: Icon(Feather.x, size: 16, color: AppColors.primaryLavender),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
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
                      color: AppColors.textHigh,
                    ),
                  ),
                  subtitle: Text('Only invited members can join (Coming Soon)', style: TextStyle(color: AppColors.textMedium)),
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
                      color: AppColors.primaryLavender.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Feather.lock, size: 18, color: AppColors.primaryLavender),
                  ),
                  activeColor: AppColors.primaryLavender,
                ),
              ),
              SizedBox(height: 30),

              // Create Group Button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLavender.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 55),
                    backgroundColor: AppColors.primaryLavender,
                    foregroundColor: AppColors.textOnSecondary,
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
                            color: AppColors.textOnSecondary,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Feather.user_plus, size: 20),
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
    final String senderId = messageData['senderId'];
    final Timestamp? timestamp = messageData['timestamp'];
    final DateTime? messageTime = timestamp?.toDate();

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

        bool isActuallyMe = senderId == _currentUserId;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            mainAxisAlignment: isActuallyMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isActuallyMe)
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.elevation,
                  backgroundImage: userProfileImage.isNotEmpty ? CachedNetworkImageProvider(userProfileImage) : null,
                  child: userProfileImage.isEmpty ? Icon(Feather.user, size: 14, color: AppColors.textDisabled) : null,
                ),
              if (!isActuallyMe) SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: isActuallyMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (!isActuallyMe)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 2),
                        child: Text(userName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMedium)),
                      ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActuallyMe ? AppColors.primaryLavender : AppColors.elevation,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(isActuallyMe ? 16 : 4),
                          bottomRight: Radius.circular(isActuallyMe ? 4 : 16),
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
                          else if (type == 'audio')
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Feather.mic, size: 16, color: isActuallyMe ? Colors.white : AppColors.primaryLavender),
                                SizedBox(width: 8),
                                Text('Voice message', style: TextStyle(color: isActuallyMe ? Colors.white : AppColors.textHigh, fontSize: 13)),
                              ],
                            )
                          else
                            Text(text, style: TextStyle(color: isActuallyMe ? Colors.white : AppColors.textHigh, fontSize: 14)),
                          SizedBox(height: 2),
                          Text(
                            messageTime != null ? DateFormat.Hm().format(messageTime) : '',
                            style: TextStyle(fontSize: 9, color: isActuallyMe ? Colors.white.withOpacity(0.7) : AppColors.textDisabled),
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

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        appBar: AppBar(
          title: StreamBuilder<DocumentSnapshot>(
            stream: _groupDocRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Text('Group', style: TextStyle(color: AppColors.textHigh));
              final groupData = snapshot.data!.data() as Map<String, dynamic>?;
              return Text(groupData?['name'] ?? 'Group', style: TextStyle(color: AppColors.textHigh));
            },
          ),
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textHigh,
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
                            color: AppColors.primaryLavender,
                          ),
                        ),
                      )
                    : TextButton(
                        onPressed: _joinGroup,
                        child: Text('JOIN',
                            style: TextStyle(
                                color: AppColors.textOnSecondary, 
                                fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.primaryLavender,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                        ),
                      ),
              ),
            // NEW: Three-dot menu replacement for info button
            PopupMenuButton<String>(
              icon: Icon(Feather.more_vertical, color: AppColors.textHigh),
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
                      leading: Icon(Feather.info, color: AppColors.primaryLavender),
                      title: Text('Group Info', style: TextStyle(color: AppColors.textHigh)),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'media',
                    child: ListTile(
                      leading: Icon(Feather.image, color: AppColors.primaryLavender),
                      title: Text('Group Media', style: TextStyle(color: AppColors.textHigh)),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'search',
                    child: ListTile(
                      leading: Icon(Feather.search, color: AppColors.primaryLavender),
                      title: Text('Search', style: TextStyle(color: AppColors.textHigh)),
                    ),
                  ),
                ];
              },
            ),
          ],
        ),
        body: _isMember 
            ? GroupChatScreen(groupId: widget.groupId)
            : StreamBuilder<DocumentSnapshot>(
                stream: _groupDocRef.snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
                  
                  final groupData = snapshot.data!.data() as Map<String, dynamic>?;
                  if (groupData == null) return Center(child: Text('Group not found'));

                  final String description = groupData['description'] ?? '';
                  final List<dynamic> hashtags = groupData['hashtags'] ?? [];
                  final Map<String, dynamic> ratings = groupData['ratings'] ?? {};
                  
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
                        child: Container(
                          decoration: BoxDecoration(
                            // Optional: Add a subtle background pattern or color to match the chat
                          ),
                          child: ListView.builder(
                            reverse: true, // Show most recent at bottom
                            padding: EdgeInsets.symmetric(vertical: 16),
                            itemCount: _recentMessages.length,
                            itemBuilder: (context, index) {
                              final message = _recentMessages[index];
                              final messageData = message.data() as Map<String, dynamic>;
                              return _buildMessagePreview(messageData, false);
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Group Info', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final String groupName = groupData['name'] ?? '';
          final String groupImage = groupData['imageUrl'] ?? '';
          final String description = groupData['description'] ?? '';
          final List<dynamic> members = groupData['members'] ?? [];
          final List<dynamic> admins = groupData['admins'] ?? [];
          final List<dynamic> hashtags = groupData['hashtags'] ?? [];
          final Map<String, dynamic> ratings = groupData['ratings'] ?? {};
          
          double averageRating = 0;
          if (ratings.isNotEmpty) {
            averageRating = ratings.values.map((v) => (v as num).toDouble()).reduce((a, b) => a + b) / ratings.length;
          }
          final double myRating = (ratings[_currentUserId] ?? 0).toDouble();

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Group Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.elevation,
                      backgroundImage: groupImage.isNotEmpty
                          ? CachedNetworkImageProvider(groupImage)
                          : AssetImage('assets/default_avatar.png',) as ImageProvider,
                    ),
                    SizedBox(height: 16),
                    Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLavender,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMedium),
                      ),
                    ],
                    if (hashtags.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: hashtags.map((tag) => Text('#$tag', style: TextStyle(color: AppColors.primaryLavender, fontSize: 12))).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              SizedBox(height: 24),

              // Rating Section
              _buildSectionHeader('Rating'),
              Card(
                color: AppColors.surface,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Feather.star, color: Colors.amber, size: 24),
                          SizedBox(width: 8),
                          Text(
                            averageRating > 0 ? averageRating.toStringAsFixed(1) : 'No ratings yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                          ),
                          if (ratings.isNotEmpty) ...[
                            SizedBox(width: 8),
                            Text('(${ratings.length})', style: TextStyle(color: AppColors.textDisabled)),
                          ],
                        ],
                      ),
                      SizedBox(height: 16),
                      Text('Your Rating', style: TextStyle(color: AppColors.textMedium, fontSize: 14)),
                      Slider(
                        value: myRating > 0 ? myRating : 5.0,
                        min: 1.0,
                        max: 10.0,
                        divisions: 9,
                        activeColor: AppColors.primaryLavender,
                        inactiveColor: AppColors.elevation,
                        label: (myRating > 0 ? myRating : 5.0).round().toString(),
                        onChanged: (value) {
                          _updateRating(value);
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
                          Text('5', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
                          Text('10', style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
                        ],
                      ),
                    ],
                  ),
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
          color: AppColors.primaryLavender,
        ),
      ), // This closing parenthesis belongs to the Text widget
    ); // This closing parenthesis belongs to the Padding widget
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
                color: AppColors.primaryLavender.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Feather.user_plus, color: AppColors.primaryLavender),
            ),
            title: Text('Add Participants', style: TextStyle(color: AppColors.textHigh)),
            onTap: _addParticipants,
          ),
          Divider(color: AppColors.elevation),
        ],
        
        ...members.map((memberId) => FutureBuilder<Map<String, dynamic>>(
          future: UserProfileCache.getUserProfile(memberId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                leading: CircleAvatar(radius: 20, backgroundColor: AppColors.elevation),
                title: Text('Loading...', style: TextStyle(color: AppColors.textHigh)),
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
                backgroundColor: AppColors.elevation,
                backgroundImage: userImage.isNotEmpty
                    ? CachedNetworkImageProvider(userImage)
                    : AssetImage('assets/default_avatar.png') as ImageProvider,
              ),
              title: Row(
                children: [
                  Text(userName, style: TextStyle(color: AppColors.textHigh)),
                  if (isMe) Text(' (You)', style: TextStyle(color: AppColors.textDisabled)),
                ],
              ),
              subtitle: isAdmin ? Text('Admin', style: TextStyle(color: AppColors.primaryLavender)) : null,
              trailing: _isAdmin && !isMe ? PopupMenuButton<String>(
                onSelected: (value) => _handleMemberAction(value, memberId, isAdmin),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: isAdmin ? 'demote' : 'promote',
                    child: Text(isAdmin ? 'Demote from Admin' : 'Promote to Admin', style: TextStyle(color: AppColors.textHigh)),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Text('Remove from Group', style: TextStyle(color: AppColors.error)),
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
          return CircularProgressIndicator(color: AppColors.primaryLavender);
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
                placeholder: (context, url) => Container(color: AppColors.elevation),
              );
            } else if (data['type'] == 'file') {
              return Container(
                color: AppColors.elevation,
                child: Icon(Feather.file, color: AppColors.primaryLavender),
              );
            } else {
              return Container(
                color: AppColors.elevation,
                child: Icon(Feather.link, color: AppColors.primaryLavender),
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
          color: AppColors.surface,
          child: Column(
            children: [
              SwitchListTile(
                title: Text('Read-only Mode', style: TextStyle(color: AppColors.textHigh)),
                subtitle: Text('Only admins can send messages', style: TextStyle(color: AppColors.textMedium)),
                value: false, // You'll need to store this in your group data
                onChanged: (value) => _toggleReadOnlyMode(value),
                activeColor: AppColors.primaryLavender,
              ),
              SwitchListTile(
                title: Text('Profanity Filter', style: TextStyle(color: AppColors.textHigh)),
                subtitle: Text('Automatically filter inappropriate content', style: TextStyle(color: AppColors.textMedium)),
                value: true, // You'll need to store this in your group data
                onChanged: (value) => _toggleProfanityFilter(value),
                activeColor: AppColors.primaryLavender,
              ),
              SwitchListTile(
                title: Text('Link Restrictions', style: TextStyle(color: AppColors.textHigh)),
                subtitle: Text('Prevent sharing of external links', style: TextStyle(color: AppColors.textMedium)),
                value: false, // You'll need to store this in your group data
                onChanged: (value) => _toggleLinkRestrictions(value),
                activeColor: AppColors.primaryLavender,
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
        title: Text('Add Participants', style: TextStyle(color: AppColors.textHigh)),
        content: Text('Feature coming soon!', style: TextStyle(color: AppColors.textMedium)),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primaryLavender)),
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

  void _updateRating(double rating) {
    _firestore.collection('groups').doc(widget.groupId).update({
      'ratings.$_currentUserId': rating,
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
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Feather.search, color: AppColors.primaryLavender),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      hintText: 'Search in chat...',
                      hintStyle: TextStyle(color: AppColors.textDisabled),
                      border: InputBorder.none,
                    ),
                    onChanged: _performSearch,
                  ),
                ),
                IconButton(
                  icon: Icon(Feather.x, color: AppColors.textHigh),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: AppColors.elevation),
            SizedBox(height: 16),
            if (_isSearching)
              Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
            else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
              Center(child: Text('No messages found', style: TextStyle(color: AppColors.textMedium)))
            else if (_searchResults.isEmpty)
              Center(child: Text('Enter search terms above', style: TextStyle(color: AppColors.textMedium)))
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
                      title: Text(text, style: TextStyle(color: AppColors.textHigh)),
                      subtitle: Text(DateFormat.yMMMd().add_Hm().format(timestamp.toDate()), style: TextStyle(color: AppColors.textDisabled)),
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
            toolbarColor: AppColors.primaryLavender,
            toolbarWidgetColor: AppColors.textOnSecondary,
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
            color: AppColors.backgroundDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                child: Row(
                  children: [
                    Icon(Feather.more_vertical, color: AppColors.primaryLavender, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Group Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLavender,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Feather.x, color: AppColors.primaryLavender),
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
                      icon: Feather.info,
                      onTap: _showGroupInfoScreen,
                    ),
                    
                    // Search Section
                    _buildMenuSection(
                      title: 'Search',
                      icon: Feather.search,
                      onTap: _showSearchScreen,
                    ),
                    
                    // Wallpaper Section
                    _buildMenuSection(
                      title: 'Wallpaper',
                      icon: Feather.image,
                      onTap: _showWallpaperOptions,
                    ),
                    
                    // More Options Section
                    _buildExpandableSection(
                      title: 'More Options',
                      icon: Feather.chevron_down,
                      children: [
                        if (!_isAdmin) // Only show report for non-admins
                          _buildMenuOption(
                            title: 'Report Group',
                            icon: Feather.alert_triangle,
                            color: AppColors.accentMustard,
                            onTap: _reportGroup,
                          ),
                        _buildMenuOption(
                          title: 'Exit Group',
                          icon: Feather.log_out,
                          color: AppColors.error,
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
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryLavender, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
        trailing: Icon(Feather.chevron_right, size: 16, color: AppColors.textDisabled),
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
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primaryLavender, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
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
        title: Text('Wallpaper', style: TextStyle(color: AppColors.textHigh)),
        content: Text('Wallpaper feature coming soon!', style: TextStyle(color: AppColors.textMedium)),
        backgroundColor: AppColors.surface,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: AppColors.primaryLavender)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
                color: AppColors.surface,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.elevation,
                      backgroundImage: groupImage.isNotEmpty
                          ? CachedNetworkImageProvider(groupImage)
                          : AssetImage('assets/default_avatar.png',)
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
                              color: AppColors.textHigh,
                            ),
                          ),
                          Text(
                            '$memberCount members',
                            style: TextStyle(
                              color: AppColors.textMedium,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // REPLACED: Info button with three-dot menu
                    // NEW: Enhanced three-dot menu
                    IconButton(
                      icon: Icon(Feather.more_vertical, color: AppColors.primaryLavender),
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
              color: AppColors.elevation,
              child: Row(
                children: [
                  // Inside the Typing indicators Container
                  Text(
                    '${_typingStatus.keys.length} ${_typingStatus.keys.length == 1 ? 'person is' : 'people are'} typing...',
                    style: TextStyle(
                      color: AppColors.primaryLavender,
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
          child: CircularProgressIndicator(color: AppColors.primaryLavender),
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
                                      border: Border.all(color: AppColors.primaryLavender, width: 1.5),
                                    ),
                                    child: CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.elevation,
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
                                          border: Border.all(color: AppColors.primaryLavender, width: 1.5),
                                        ),
                                        child: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: AppColors.elevation,
                                          child: const Icon(Feather.user, size: 16, color: AppColors.textDisabled),
                                        ),
                                      );
                                    }

                                    final profileImageUrl = snapshot.data!;
                                    return Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primaryLavender, width: 1.5),
                                      ),
                                      child: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: AppColors.elevation,
                                        backgroundImage: profileImageUrl.isNotEmpty
                                            ? CachedNetworkImageProvider(profileImageUrl)
                                            : null,
                                        child: profileImageUrl.isEmpty
                                            ? const Icon(Feather.user, size: 16, color: AppColors.textDisabled)
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
                  color: isMe ? AppColors.primaryLavender : AppColors.surface,
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
                            color: AppColors.textHigh,
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
                              style: TextStyle(color: isMe ? AppColors.textOnSecondary : AppColors.textHigh),
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
                                  color: isMe ? AppColors.textOnSecondary : AppColors.textDisabled,
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
                backgroundColor: AppColors.primaryLavender,
                child: Icon(Feather.arrow_down,
                    color: AppColors.textOnSecondary, size: 20),
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
              color: AppColors.surface,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply preview (if replying to a message)
                  if (_replyingToMessage != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      color: AppColors.elevation,
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
                                    color: AppColors.textHigh,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _replyingToMessage!['text'] ??
                                      (_replyingToMessage!['type'] == 'image'
                                          ? '📷 Image'
                                          : ''),
                                  style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              ),
                          ),
                          IconButton(
                            icon: Icon(Feather.x, size: 18, color: AppColors.textHigh),
                            onPressed: _cancelReply,
                          ),
                        ],
                      ),
                    ),
                  // Standard message input row
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Feather.image, color: AppColors.primaryLavender),
                        onPressed: _pickImage,
                      ),
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(maxHeight: 100),
                          child: TextField(
                            controller: _messageController,
                            focusNode: _messageFocusNode,
                            onChanged: (value) => _startTyping(),
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
                              ? Feather.send
                              : Feather.plus,
                          color: AppColors.primaryLavender,
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
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Feather.image, color: AppColors.primaryLavender),
                title: Text('Send Image', style: TextStyle(color: AppColors.textHigh)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: Icon(Feather.file, color: AppColors.primaryLavender),
                title: Text('Send File', style: TextStyle(color: AppColors.textHigh)),
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
                ? AppColors.primaryLavender.withOpacity(0.2)
                : AppColors.elevation),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isMe ? AppColors.primaryLavender : AppColors.textDisabled,
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
                  color: isMe ? AppColors.primaryLavender : AppColors.textMedium,
                ),
              ),
              SizedBox(height: 2),
              Text(
                replyData['text'] ?? 'Media',
                style: TextStyle(fontSize: 12, color: isMe ? AppColors.textOnSecondary : AppColors.textHigh),
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
                color: AppColors.elevation,
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLavender)),
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
              style: TextStyle(color: AppColors.textHigh),
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
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Feather.corner_up_left, color: AppColors.primaryLavender),
                title: Text('Reply', style: TextStyle(color: AppColors.textHigh)),
                onTap: () {
                  Navigator.pop(context);
                  _replyToMessage(messageData);
                },
              ),
              ListTile(
                leading: Icon(Feather.copy, color: AppColors.primaryLavender),
                title: Text('Copy', style: TextStyle(color: AppColors.textHigh)),
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
                  leading: Icon(Feather.download, color: AppColors.primaryLavender),
                  title: Text('Save to gallery', style: TextStyle(color: AppColors.textHigh)),
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
          title: Text('Group Info', style: TextStyle(color: AppColors.textHigh)),
          backgroundColor: AppColors.surface,
          content: StreamBuilder<DocumentSnapshot>(
            stream: _groupDocRef.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
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
                  Text('Name: $name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  SizedBox(height: 8),
                  if (description.isNotEmpty) Text('Description: $description', style: TextStyle(color: AppColors.textMedium)),
                  SizedBox(height: 8),
                  Text('Category: $category', style: TextStyle(color: AppColors.textMedium)),
                  SizedBox(height: 8),
                  Text('Created: ${DateFormat.yMMMd().format(createdAt.toDate())}', style: TextStyle(color: AppColors.textMedium)),
                  SizedBox(height: 8),
                  Text('Members: $memberCount', style: TextStyle(color: AppColors.textMedium)),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: AppColors.primaryLavender)),
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
          title: Text('Search in Chat', style: TextStyle(color: AppColors.textHigh)),
          content: TextField(
            controller: searchController,
            style: TextStyle(color: AppColors.textHigh),
            decoration: InputDecoration(
              hintText: 'Enter search term...',
              hintStyle: TextStyle(color: AppColors.textDisabled),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: AppColors.elevation,
            ),
          ),
          backgroundColor: AppColors.surface,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textDisabled)),
            ),
            TextButton(
              onPressed: () {
                // Implement search functionality
                _searchInChat(searchController.text);
                Navigator.pop(context);
              },
              child: Text('Search', style: TextStyle(color: AppColors.primaryLavender)),
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
          title: Text('Leave Group', style: TextStyle(color: AppColors.textHigh)),
          content: Text('Are you sure you want to leave this group?', style: TextStyle(color: AppColors.textMedium)),
          backgroundColor: AppColors.surface,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textDisabled)),
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
              child: Text('Leave', style: TextStyle(color: AppColors.error)),
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
          title: Text('Report Group', style: TextStyle(color: AppColors.textHigh)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please describe the issue:', style: TextStyle(color: AppColors.textMedium)),
              SizedBox(height: 8),
              TextField(
                controller: reportController,
                style: TextStyle(color: AppColors.textHigh),
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: AppColors.elevation,
                ),
                maxLines: 3,
              ),
            ],
          ),
          backgroundColor: AppColors.surface,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: AppColors.textDisabled)),
            ),
            TextButton(
              onPressed: () {
                // Implement report functionality
                _submitReport(reportController.text);
                Navigator.pop(context);
              },
              child: Text('Submit Report', style: TextStyle(color: AppColors.primaryLavender)),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Group Media', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
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
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
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
                    color: AppColors.elevation,
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                  ),
                  errorWidget: (context, url, error) => Icon(Feather.alert_circle, color: AppColors.error),
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
        title: Text('Edit Image', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textHigh,
        actions: [
          IconButton(
            icon: Icon(Feather.check, color: AppColors.primaryLavender),
            onPressed: () {
              Navigator.pop(context, {
                'image': _editedImage!,
                'caption': _captionController.text,
              });
            },
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
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
              style: TextStyle(color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: AppColors.elevation,
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
        ..color = AppColors.textOnSecondary
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
      primaryColor: AppColors.primaryLavender,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryLavender,
        secondary: AppColors.secondaryTeal,
        background: AppColors.backgroundDeep,
        surface: AppColors.surface,
        onPrimary: AppColors.textOnSecondary,
        onSecondary: AppColors.textOnSecondary,
        onBackground: AppColors.textHigh,
        onSurface: AppColors.textHigh,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDeep,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryLavender,
        foregroundColor: AppColors.textOnSecondary,
      ),
    ),
    home: GroupsScreen(),
  ));
}
