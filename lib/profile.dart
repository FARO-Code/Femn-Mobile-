import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth.dart';
import 'package:femn/post.dart';
import 'package:femn/colors.dart'; // <--- IMPORT COLORS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'addpost.dart';
import 'settings.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// ======== NEW: AccountBadge Widget ========
class AccountBadge extends StatelessWidget {
  final String accountType;
  final bool isVerified;

  const AccountBadge({
    required this.accountType,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;

    switch (accountType) {
      case 'organization':
        icon = isVerified ? Icons.verified : Icons.business;
        color = isVerified ? Colors.blueAccent : Colors.greenAccent; // Brighter for dark mode
        label = isVerified ? 'Verified Organization' : 'Organization';
        break;
      case 'therapist':
        icon = isVerified ? Icons.verified_user : Icons.medical_services;
        color = isVerified ? Colors.blueAccent : Colors.purpleAccent; // Brighter for dark mode
        label = isVerified ? 'Verified Therapist' : 'Therapist';
        break;
      default:
        icon = Icons.person;
        color = AppColors.textMedium;
        label = 'Personal';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ======== ProfileScreen ========
class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({required this.userId});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  // New controllers for organization-specific fields
  final TextEditingController _missionStatementController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  bool _isEditing = false;
  File? _profileImageFile;
  bool _isOwnProfile = false;
  final Map<String, String?> _profileImageCache = {};

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser!.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fixMissingBioFields();
    });
  }

  // ======== MODIFIED: Profile header builder ========
 Widget _buildProfileHeader(DocumentSnapshot user) {
    // 1. SAFELY EXTRACT DATA AS A MAP
    final userData = user.data() as Map<String, dynamic>? ?? {};

    // 2. CALCULATE NAME CHANGE ELIGIBILITY
    bool canChangeName = true;
    int daysRemaining = 0;
    
    if (userData['lastNameChangeDate'] != null) {
      final Timestamp lastChange = userData['lastNameChangeDate'];
      final date = lastChange.toDate();
      final daysSince = DateTime.now().difference(date).inDays;
      
      if (daysSince < 30) {
        canChangeName = false;
        daysRemaining = 30 - daysSince;
      }
    }

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (_isEditing) {
                  _pickProfileImage();
                }
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.elevation,
                    backgroundImage: (userData['profileImage'] ?? userData['logo'] ?? '').isNotEmpty
                        ? CachedNetworkImageProvider(userData['profileImage'] ?? userData['logo'] ?? '')
                        : AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  if (_isEditing)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_alt, color: Colors.white.withOpacity(0.8)),
                    ),
                ],
              ),
            ),
            if (_isOwnProfile)
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primaryLavender,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.edit,
                      color: AppColors.backgroundDeep,
                      size: 14,
                    ),
                    onPressed: () {
                      if (_isEditing) {
                        _saveProfileChanges();
                      } else {
                        setState(() {
                          _isEditing = true;
                        });
                      }
                    },
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 8),

        AccountBadge(
          accountType: userData['accountType'] ?? 'personal',
          isVerified: userData['isVerified'] ?? false,
        ),
        SizedBox(height: 8),

        _isEditing
            ? Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    // Disable field if they are within the 30-day limit
                    enabled: canChangeName,
                    style: TextStyle(
                      color: canChangeName ? AppColors.textHigh : AppColors.textDisabled
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      filled: true,
                      fillColor: AppColors.elevation,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  
                  // ======== NEW: WARNING WIDGET ========
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: canChangeName 
                            ? Colors.orange.withOpacity(0.15) // Warning color
                            : AppColors.error.withOpacity(0.15), // Error/Locked color
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: canChangeName ? Colors.orange : AppColors.error,
                          width: 1
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canChangeName ? Icons.warning_amber_rounded : Icons.lock_clock,
                            color: canChangeName ? Colors.orange : AppColors.error,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              canChangeName
                                  ? "Note: You can only change your name once every 30 days."
                                  : "Name change locked. You can change it again in $daysRemaining days.",
                              style: TextStyle(
                                fontSize: 12,
                                color: canChangeName ? Colors.orange : AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // =====================================
                ],
              )
            : Text(
                userData['fullName'] ?? userData['organizationName'] ?? 'No Name',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
        
        SizedBox(height: 2),
        Text('@${userData['username'] ?? ''}', style: TextStyle(color: AppColors.textMedium)),
        SizedBox(height: 8),

        if (userData['accountType'] == 'organization') ..._buildOrganizationProfile(user),
        if (userData['accountType'] == 'therapist') ..._buildTherapistProfile(user),

        if ((userData['accountType'] ?? 'personal') == 'personal')
          _isEditing
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0), // Add spacing after warning
                  child: TextFormField(
                    controller: _bioController,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      filled: true,
                      fillColor: AppColors.elevation,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    maxLines: 2,
                  ),
                )
              : Text(
                  userData['bio'] ?? 'No bio yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMedium),
                ),
      ],
    );
  }

  // ======== Helper: Organization Profile Fields ========
  List<Widget> _buildOrganizationProfile(DocumentSnapshot user) {
    // Convert to map for safe access in helper methods too
    final userData = user.data() as Map<String, dynamic>? ?? {};

    if (!_isEditing) {
      _missionStatementController.text = userData['missionStatement'] ?? '';
      _websiteController.text = userData['website'] ?? '';
      _phoneController.text = userData['phone'] ?? '';
      _addressController.text = userData['address'] ?? '';
    }

    return [
      if (userData['category'] != null)
        Text(
          userData['category'],
          style: TextStyle(
            color: AppColors.textDisabled,
            fontWeight: FontWeight.w500,
          ),
        ),
      if (userData['missionStatement'] != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            userData['missionStatement'],
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMedium),
          ),
        ),
      if (userData['website'] != null && (userData['website'] as String).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: InkWell(
            onTap: () {
              // TODO: Launch URL
            },
            child: Text(
              userData['website'],
              style: TextStyle(
                color: AppColors.secondaryTeal,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      _isEditing
          ? Column(
              children: [
                _buildTextField(controller: _missionStatementController, label: 'Mission Statement', maxLines: 2),
                SizedBox(height: 8),
                _buildTextField(controller: _websiteController, label: 'Website (optional)'),
                SizedBox(height: 8),
                _buildTextField(controller: _phoneController, label: 'Phone'),
                SizedBox(height: 8),
                _buildTextField(controller: _addressController, label: 'Address'),
                SizedBox(height: 8),
                _buildTextField(controller: _bioController, label: 'About Us', maxLines: 3),
              ],
            )
          : Text(
              userData['bio'] ?? 'No description yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium),
            ),
    ];
  }

  // ======== Helper: Therapist Profile Fields ========
  List<Widget> _buildTherapistProfile(DocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>? ?? {};

    return [
      if (userData['specialization'] != null && (userData['specialization'] as List?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (userData['specialization'] as List).map<Widget>((spec) {
              return Chip(
                label: Text(
                  spec.toString(),
                  style: TextStyle(fontSize: 12, color: AppColors.textHigh),
                ),
                backgroundColor: AppColors.elevation,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
      if (userData['experienceLevel'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            userData['experienceLevel'],
            style: TextStyle(
              color: AppColors.textDisabled,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (userData['region'] != null && (userData['region'] as String).isNotEmpty)
        Text(
          userData['region'],
          style: TextStyle(
            color: AppColors.textDisabled,
          ),
        ),
      if (userData['availableHours'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Available: ${userData['availableHours']}',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      _isEditing
          ? _buildTextField(controller: _bioController, label: 'Professional Bio', maxLines: 3)
          : Text(
              userData['bio'] ?? 'No bio yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium),
            ),
      if (userData['languages'] != null && (userData['languages'] as List?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (userData['languages'] as List).map<Widget>((lang) {
              return Chip(
                label: Text(
                  lang.toString(),
                  style: TextStyle(fontSize: 12, color: AppColors.textHigh),
                ),
                backgroundColor: AppColors.secondaryTeal.withOpacity(0.2),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
    ];
  }

  Widget _buildTextField({required TextEditingController controller, required String label, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      style: TextStyle(color: AppColors.textHigh),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textMedium),
        filled: true,
        fillColor: AppColors.elevation,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      maxLines: maxLines,
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = File(pickedFile.path);
      });
      await _uploadProfileImage();
    }
  }

  // ======== MODIFIED: Save Logic with 30-Day Restriction ========
  Future<void> _saveProfileChanges() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      // FIXED: Get data as Map first to safely check accountType
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};
      
      Map<String, dynamic> updateData = {
        'bio': _bioController.text,
      };

      // Check Name Change Restriction
      String currentName = userData['fullName'] ?? '';
      String newName = _fullNameController.text.trim();

      if (newName != currentName) {
        Timestamp? lastChange = userData['lastNameChangeDate'];
        if (lastChange != null) {
          final date = lastChange.toDate();
          final daysSinceChange = DateTime.now().difference(date).inDays;

          if (daysSinceChange < 30) {
            final daysRemaining = 30 - daysSinceChange;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You can only change your name once every 30 days. Please try again in $daysRemaining days.'),
                backgroundColor: AppColors.error,
              ),
            );
            return; // Abort save if name change is invalid
          }
        }
        // Update name and set new timestamp
        updateData['fullName'] = newName;
        updateData['lastNameChangeDate'] = FieldValue.serverTimestamp();
      }

      String accountType = userData['accountType'] ?? 'personal';

      if (accountType == 'organization') {
        updateData['missionStatement'] = _missionStatementController.text;
        updateData['website'] = _websiteController.text;
        updateData['phone'] = _phoneController.text;
        updateData['address'] = _addressController.text;
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(updateData);

      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImageFile == null) return;
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$currentUserId.jpg');
      await storageRef.putFile(_profileImageFile!);
      final downloadURL = await storageRef.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({'profileImage': downloadURL}, SetOptions(merge: true));
      _profileImageCache[currentUserId] = downloadURL;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
    } catch (e, st) {
      print('Error uploading profile image: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile picture: $e')),
      );
    }
  }

  Future<void> fixMissingBioFields() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .set({'bio': ''}, SetOptions(merge: true));
        print('Bio field added successfully');
      }
    } catch (e) {
      print('Error adding bio field: $e');
    }
  }

  Future<String?> _getProfileImageUrl(String uid) async {
    if (_profileImageCache.containsKey(uid)) return _profileImageCache[uid];
    try {
      final possiblePaths = [
        'profile_images/$uid.jpg',
        'profile_images/$uid.jpeg',
        'profile_images/$uid.png',
        'profile_images/$uid.webp',
      ];
      String? found;
      for (final p in possiblePaths) {
        try {
          final url = await FirebaseStorage.instance.ref().child(p).getDownloadURL();
          found = url;
          break;
        } catch (e) {
          // ignore
        }
      }
      _profileImageCache[uid] = found;
      return found;
    } catch (e) {
      print('Unexpected error getting profile image url for $uid: $e');
      _profileImageCache[uid] = null;
      return null;
    }
  }

  Future<void> backfillProfileImages() async {
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      int updated = 0;
      for (final doc in usersSnap.docs) {
        final uid = doc.id;
        final data = doc.data();
        final existing = (data['profileImage'] ?? '') as String;
        if (existing.isNotEmpty) continue;
        final url = await _getProfileImageUrl(uid);
        if (url != null && url.isNotEmpty) {
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'profileImage': url,
          }, SetOptions(merge: true));
          updated++;
        }
      }
      print('Backfill complete, updated $updated user(s)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backfill complete, updated $updated user(s)')),
      );
    } catch (e) {
      print('Backfill failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backfill failed: $e')),
      );
    }
  }

  Widget _buildPostsGrid(String userId, bool isOwnProfile) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts', style: TextStyle(color: AppColors.error)));
        }
        final posts = snapshot.hasData ? snapshot.data!.docs : [];
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: isOwnProfile ? posts.length + 1 : posts.length,
            itemBuilder: (context, index) {
              if (isOwnProfile && index == 0) {
                return _buildCreatePostButton();
              }
              final postIndex = isOwnProfile ? index - 1 : index;
              if (postIndex < 0 || postIndex >= posts.length) {
                return Container();
              }
              var post = posts[postIndex];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostDetailScreen(postId: post.id, userId: userId),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    child: post['mediaType'] == 'image'
                        ? CachedNetworkImage(
                            imageUrl: post['mediaUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: AppColors.elevation,
                              child: Icon(Icons.image, color: AppColors.textDisabled),
                            ),
                            errorWidget: (context, url, error) => Icon(Icons.error, color: AppColors.error),
                          )
                        : Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(Icons.play_arrow, color: Colors.white),
                            ),
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

  Widget _buildCreatePostButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddPostScreen()),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: const BorderSide(color: AppColors.primaryLavender, width: 1.5),
        ),
        color: AppColors.elevation, // Dark container
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Feather.plus_circle,
                  size: 40,
                  color: AppColors.primaryLavender,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create Post',
                  style: TextStyle(
                    color: AppColors.primaryLavender,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final isOwnProfile = widget.userId == currentUserId;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: Icon(Feather.settings, color: AppColors.textHigh),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    );
                  },
                ),
              ]
            : null,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('User not found', style: TextStyle(color: AppColors.textHigh)));
          }
          // We don't cast here because we pass the snapshot to _buildProfileHeader
          // which now handles the casting safely.
          var user = snapshot.data!;
          // But for text controller initialization, we should access data safely
          var userData = user.data() as Map<String, dynamic>? ?? {};

          if (!_isEditing) {
            _fullNameController.text = userData['fullName'] ?? '';
            _bioController.text = userData['bio'] ?? '';
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildProfileHeader(user),
                    SizedBox(height: 4),
                    ProfileStatsWidget(
                      userId: widget.userId,
                      isOwnProfile: isOwnProfile,
                    ),
                    if (!isOwnProfile) SizedBox(height: 16),
                    if (!isOwnProfile)
                      ElevatedButton(
                        onPressed: () async {
                          List followers = List.from(userData['followers'] ?? []);
                          if (followers.contains(currentUserId)) {
                            await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                              'followers': FieldValue.arrayRemove([currentUserId]),
                            });
                            await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                              'following': FieldValue.arrayRemove([widget.userId]),
                            });
                          } else {
                            await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                              'followers': FieldValue.arrayUnion([currentUserId]),
                            });
                            await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                              'following': FieldValue.arrayUnion([widget.userId]),
                            });
                            await FirebaseFirestore.instance.collection('notifications').add({
                              'type': 'follow',
                              'fromUserId': currentUserId,
                              'toUserId': widget.userId,
                              'timestamp': DateTime.now(),
                              'read': false,
                            });
                          }
                        },
                        child: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
                          builder: (context, userSnapshot) {
                            if (userSnapshot.hasData) {
                              var data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                              List followers = List.from(data['followers'] ?? []);
                              return Text(followers.contains(currentUserId) ? 'Unfollow' : 'Follow',
                                  style: TextStyle(color: AppColors.backgroundDeep));
                            }
                            return Text('Follow', style: TextStyle(color: AppColors.backgroundDeep));
                          },
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryLavender,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(child: _buildPostsGrid(widget.userId, isOwnProfile)),
            ],
          );
        },
      ),
    );
  }
}

// =============== Rest of file (unchanged logic, updated colors) ===============

class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  const OtherUserProfileScreen({required this.userId});
  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>? ?? {};
      final followers = List<String>.from(data['followers'] ?? []);
      setState(() {
        _isFollowing = followers.contains(currentUserId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Profile', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          if (!snapshot.hasData) {
            return Center(child: Text('User not found', style: TextStyle(color: AppColors.textHigh)));
          }
          final user = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.elevation,
                      backgroundImage: (user['profileImage'] ?? '').isNotEmpty
                          ? CachedNetworkImageProvider(user['profileImage'])
                          : AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    SizedBox(height: 8),
                    Text(
                      user['fullName'] ?? 'No Name',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                    ),
                    SizedBox(height: 2),
                    Text('@${user['username'] ?? ''}', style: TextStyle(color: AppColors.textMedium)),
                    SizedBox(height: 0),
                    Text(user['bio'] ?? 'No bio yet', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMedium)),
                    SizedBox(height: 4),
                    ProfileStatsWidget(userId: widget.userId, isOwnProfile: false),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (_isFollowing) {
                          await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                            'followers': FieldValue.arrayRemove([currentUserId]),
                          });
                          await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                            'following': FieldValue.arrayRemove([widget.userId]),
                          });
                        } else {
                          await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                            'followers': FieldValue.arrayUnion([currentUserId]),
                          });
                          await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                            'following': FieldValue.arrayUnion([widget.userId]),
                          });
                        }
                        setState(() {
                          _isFollowing = !_isFollowing;
                        });
                      },
                      child: Text(_isFollowing ? 'Unfollow' : 'Follow', style: TextStyle(color: _isFollowing ? AppColors.textHigh : AppColors.backgroundDeep)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? AppColors.elevation : AppColors.secondaryTeal,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('userId', isEqualTo: widget.userId)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading posts', style: TextStyle(color: AppColors.error)));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No posts yet', style: TextStyle(color: AppColors.textMedium)));
                    }
                    final posts = snapshot.data!.docs;
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: MasonryGridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        itemCount: posts.length,
                        itemBuilder: (context, index) {
                          var post = posts[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PostDetailScreen(postId: post.id, userId: widget.userId),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: Container(
                                child: post['mediaType'] == 'image'
                                    ? CachedNetworkImage(
                                        imageUrl: post['mediaUrl'],
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: AppColors.elevation,
                                          child: Icon(Icons.image, color: AppColors.textDisabled),
                                        ),
                                        errorWidget: (context, url, error) => Icon(Icons.error, color: AppColors.error),
                                      )
                                    : Container(
                                        color: Colors.black,
                                        child: Center(
                                          child: Icon(Icons.play_arrow, color: Colors.white),
                                        ),
                                      ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers;
  const FollowListScreen({required this.userId, required this.showFollowers});
  @override
  _FollowListScreenState createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isOwnProfile = false;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text(widget.showFollowers ? 'Followers' : 'Following', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(child: Text('User not found', style: TextStyle(color: AppColors.textHigh)));
          }
          final userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
          final List<String> userIds = List<String>.from(
            widget.showFollowers ? (userData['followers'] ?? []) : (userData['following'] ?? []),
          );
          if (userIds.isEmpty) {
            return Center(
              child: Text(widget.showFollowers ? 'No followers yet' : 'Not following anyone', style: TextStyle(color: AppColors.textMedium)),
            );
          }
          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              final userId = userIds[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                builder: (context, userSnapshot) {
                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(leading: CircleAvatar(backgroundColor: AppColors.elevation), title: Text('Loading...', style: TextStyle(color: AppColors.textDisabled)));
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(leading: CircleAvatar(backgroundColor: AppColors.elevation), title: Text('User not found', style: TextStyle(color: AppColors.textDisabled)));
                  }
                  final user = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  return _buildUserTile(
                    user['uid'] ?? userId,
                    user['username'] ?? 'Unknown',
                    user['fullName'] ?? 'No Name',
                    user['profileImage'] ?? '',
                    isFollowing: _isOwnProfile
                        ? null
                        : List.from(userData['followers'] ?? []).contains(currentUserId),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildUserTile(
    String userId,
    String username,
    String fullName,
    String profileImage, {
    bool? isFollowing,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.elevation,
        backgroundImage: profileImage.isNotEmpty
            ? CachedNetworkImageProvider(profileImage)
            : AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      title: Text(username, style: TextStyle(color: AppColors.textHigh)),
      subtitle: Text(fullName, style: TextStyle(color: AppColors.textMedium)),
      trailing: _isOwnProfile
          ? null
          : isFollowing == null
              ? null
              : ElevatedButton(
                  onPressed: () async {
                    if (isFollowing) {
                      await FirebaseFirestore.instance.collection('users').doc(userId).update({
                        'followers': FieldValue.arrayRemove([currentUserId]),
                      });
                      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                        'following': FieldValue.arrayRemove([userId]),
                      });
                    } else {
                      await FirebaseFirestore.instance.collection('users').doc(userId).update({
                        'followers': FieldValue.arrayUnion([currentUserId]),
                      });
                      await FirebaseFirestore.instance.collection('users').doc(currentUserId).update({
                        'following': FieldValue.arrayUnion([userId]),
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? AppColors.elevation : AppColors.secondaryTeal,
                    foregroundColor: isFollowing ? AppColors.textHigh : AppColors.backgroundDeep,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: Text(isFollowing ? 'Following' : 'Follow'),
                ),
      onTap: () {
        if (userId == currentUserId) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => OtherUserProfileScreen(userId: userId)));
        }
      },
    );
  }
}

class ProfileStatsWidget extends StatelessWidget {
  final String userId;
  final bool isOwnProfile;
  ProfileStatsWidget({required this.userId, required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface, // Dark Card
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.elevation, width: 1),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(
                label: "Posts",
                stream: FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: userId).snapshots(),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FollowListScreen(userId: userId, showFollowers: true),
                    ),
                  );
                },
                child: _buildStatFuture("Followers", userId, true),
              ),
              GestureDetector(
                onTap: isOwnProfile
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FollowListScreen(userId: userId, showFollowers: false),
                          ),
                        );
                      }
                    : null,
                child: _buildStatFuture("Following", userId, false),
              ),
              _buildEmbersStat(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmbersStat(String userId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, snapshot) {
        int embers = 0;
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          embers = data['embers'] ?? 0;
        }
        return Column(
          children: [
            Text(
              "Embers",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLavender),
            ),
            const SizedBox(height: 2),
            Text(
              embers.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStat({
    required String label,
    required Stream<QuerySnapshot> stream,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLavender),
        ),
        const SizedBox(height: 2),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatFuture(String label, String userId, bool followers) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLavender),
        ),
        const SizedBox(height: 2),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
              List list = List.from(data[followers ? 'followers' : 'following'] ?? []);
              return Text(
                list.length.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
              );
            }
            return const Text(
              "0",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
            );
          },
        ),
      ],
    );
  }
}