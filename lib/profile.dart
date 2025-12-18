import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth.dart';
import 'package:femn/post.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'addpost.dart';
import 'settings.dart';

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
        color = isVerified ? Colors.blue : Colors.green;
        label = isVerified ? 'Verified Organization' : 'Organization';
        break;
      case 'therapist':
        icon = isVerified ? Icons.verified_user : Icons.medical_services;
        color = isVerified ? Colors.blue : Colors.purple;
        label = isVerified ? 'Verified Therapist' : 'Therapist';
        break;
      default:
        icon = Icons.person;
        color = Colors.grey;
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

  // ======== NEW: Profile header builder ========
  Widget _buildProfileHeader(DocumentSnapshot user) {
    return Column(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: (user['profileImage'] ?? user['logo'] ?? '').isNotEmpty
                  ? CachedNetworkImageProvider(user['profileImage'] ?? user['logo'] ?? '')
                  : AssetImage('assets/default_avatar.png') as ImageProvider,
            ),
            if (_isOwnProfile)
              Positioned(
                bottom: 0,
                right: 0,
                child: CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.edit,
                      color: Colors.white,
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

        // Account Badge
        AccountBadge(
          accountType: user['accountType'] ?? 'personal',
          isVerified: user['isVerified'] ?? false,
        ),
        SizedBox(height: 8),

        _isEditing
            ? TextFormField(
                controller: _fullNameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              )
            : Text(
                user['fullName'] ?? user['organizationName'] ?? 'No Name',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
        SizedBox(height: 2),
        Text('@${user['username']}'),
        SizedBox(height: 8),

        // Organization-specific fields
        if (user['accountType'] == 'organization') ..._buildOrganizationProfile(user),

        // Therapist-specific fields
        if (user['accountType'] == 'therapist') ..._buildTherapistProfile(user),

        // Personal account bio
        if (user['accountType'] == 'personal')
          _isEditing
              ? TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                )
              : Text(
                  user['bio'] ?? 'No bio yet',
                  textAlign: TextAlign.center,
                ),
      ],
    );
  }

  // ======== Helper: Organization Profile Fields ========
  List<Widget> _buildOrganizationProfile(DocumentSnapshot user) {
    // Initialize controllers on first build if not editing
    if (!_isEditing) {
      _missionStatementController.text = user['missionStatement'] ?? '';
      _websiteController.text = user['website'] ?? '';
      _phoneController.text = user['phone'] ?? '';
      _addressController.text = user['address'] ?? '';
    }

    return [
      if (user['category'] != null)
        Text(
          user['category'],
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      if (user['missionStatement'] != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            user['missionStatement'],
            textAlign: TextAlign.center,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ),
      if (user['website'] != null && user['website'].isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: InkWell(
            onTap: () {
              // TODO: Launch URL
            },
            child: Text(
              user['website'],
              style: TextStyle(
                color: Colors.blue.shade600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      _isEditing
          ? Column(
              children: [
                TextFormField(
                  controller: _missionStatementController,
                  decoration: InputDecoration(
                    labelText: 'Mission Statement',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _websiteController,
                  decoration: InputDecoration(
                    labelText: 'Website (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 8),
                TextFormField(
                  controller: _bioController,
                  decoration: InputDecoration(
                    labelText: 'About Us',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            )
          : Text(
              user['bio'] ?? 'No description yet',
              textAlign: TextAlign.center,
            ),
    ];
  }

  // ======== Helper: Therapist Profile Fields ========
  List<Widget> _buildTherapistProfile(DocumentSnapshot user) {
    return [
      if (user['specialization'] != null && (user['specialization'] as List?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (user['specialization'] as List).map<Widget>((spec) {
              return Chip(
                label: Text(
                  spec.toString(),
                  style: TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.purple.shade50,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
      if (user['experienceLevel'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            user['experienceLevel'],
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      if (user['region'] != null && user['region'].isNotEmpty)
        Text(
          user['region'],
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
      if (user['availableHours'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Available: ${user['availableHours']}',
            style: TextStyle(
              color: Colors.green.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      _isEditing
          ? TextFormField(
              controller: _bioController,
              decoration: InputDecoration(
                labelText: 'Professional Bio',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            )
          : Text(
              user['bio'] ?? 'No bio yet',
              textAlign: TextAlign.center,
            ),
      if (user['languages'] != null && (user['languages'] as List?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (user['languages'] as List).map<Widget>((lang) {
              return Chip(
                label: Text(
                  lang.toString(),
                  style: TextStyle(fontSize: 12),
                ),
                backgroundColor: Colors.blue.shade50,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ),
    ];
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

  // ======== UPDATED: Save Profile with account-type fields ========
  Future<void> _saveProfileChanges() async {
    try {
      Map<String, dynamic> updateData = {
        'fullName': _fullNameController.text,
        'bio': _bioController.text,
      };

      // Fetch current accountType to conditionally save fields
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      String? accountType = userDoc['accountType'];

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
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts'));
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
                              color: Colors.grey[300],
                              child: Icon(Icons.image, color: Colors.grey[400]),
                            ),
                            errorWidget: (context, url, error) => Icon(Icons.error),
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
          side: const BorderSide(color: Color(0xFFFFB7C5), width: 1.5),
        ),
        color: const Color(0xFFFFE1E0),
        elevation: 0,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_circle_outline,
                  size: 40,
                  color: Color(0xFFE56982),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create Post',
                  style: TextStyle(
                    color: Color(0xFFE56982),
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
      appBar: AppBar(
        title: Text('Profile'),
        actions: isOwnProfile
            ? [
                IconButton(
                  icon: Icon(Icons.settings),
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
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('User not found'));
          }
          var user = snapshot.data!;

          // Initialize controllers safely (avoid re-initializing while editing)
          if (!_isEditing) {
            _fullNameController.text = user['fullName'] ?? '';
            _bioController.text = user['bio'] ?? '';
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
                          List followers = List.from(user['followers']);
                          if (followers.contains(currentUserId)) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .update({
                              'followers': FieldValue.arrayRemove([currentUserId]),
                            });
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .update({
                              'following': FieldValue.arrayRemove([widget.userId]),
                            });
                          } else {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(widget.userId)
                                .update({
                              'followers': FieldValue.arrayUnion([currentUserId]),
                            });
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(currentUserId)
                                .update({
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
                              List followers = List.from(userSnapshot.data!['followers']);
                              return Text(followers.contains(currentUserId) ? 'Unfollow' : 'Follow');
                            }
                            return Text('Follow');
                          },
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

// =============== Rest of file (unchanged from original) ===============

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
      final followers = List<String>.from(userDoc['followers'] ?? []);
      setState(() {
        _isFollowing = followers.contains(currentUserId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('User not found'));
          }
          var user = snapshot.data!;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: user['profileImage'].isNotEmpty
                          ? CachedNetworkImageProvider(user['profileImage'])
                          : AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    SizedBox(height: 8),
                    Text(
                      user['fullName'],
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text('@${user['username']}'),
                    SizedBox(height: 0),
                    Text(user['bio'] ?? 'No bio yet', textAlign: TextAlign.center),
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
                      child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
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
                      return Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error loading posts'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No posts yet'));
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
                                          color: Colors.grey[300],
                                          child: Icon(Icons.image, color: Colors.grey[400]),
                                        ),
                                        errorWidget: (context, url, error) => Icon(Icons.error),
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
      appBar: AppBar(title: Text(widget.showFollowers ? 'Followers' : 'Following')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return Center(child: Text('User not found'));
          }
          final userData = userSnapshot.data!;
          final List<String> userIds = List<String>.from(
            widget.showFollowers ? userData['followers'] : userData['following'],
          );
          if (userIds.isEmpty) {
            return Center(
              child: Text(widget.showFollowers ? 'No followers yet' : 'Not following anyone'),
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
                    return ListTile(
                      leading: CircleAvatar(),
                      title: Text('Loading...'),
                    );
                  }
                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return ListTile(
                      leading: CircleAvatar(),
                      title: Text('User not found'),
                    );
                  }
                  final user = userSnapshot.data!;
                  return _buildUserTile(
                    user['uid'],
                    user['username'],
                    user['fullName'],
                    user['profileImage'],
                    isFollowing: _isOwnProfile
                        ? null
                        : List.from(userData['followers']).contains(currentUserId),
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
        backgroundImage: profileImage.isNotEmpty
            ? CachedNetworkImageProvider(profileImage)
            : AssetImage('assets/default_avatar.png') as ImageProvider,
      ),
      title: Text(username),
      subtitle: Text(fullName),
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
                    backgroundColor: isFollowing ? Colors.grey[300] : Theme.of(context).colorScheme.secondary,
                    foregroundColor: isFollowing ? Colors.black : Colors.white,
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
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.75,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE1E0),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFFFB7C5), width: 1),
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
          embers = snapshot.data!['embers'] ?? 0;
        }
        return Column(
          children: [
            Text(
              "Embers",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE56982)),
            ),
            const SizedBox(height: 2),
            Text(
              embers.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE56982)),
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE56982)),
        ),
        const SizedBox(height: 2),
        StreamBuilder<QuerySnapshot>(
          stream: stream,
          builder: (context, snapshot) {
            int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return Text(
              count.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE56982)),
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
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFE56982)),
        ),
        const SizedBox(height: 2),
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List list = List.from(snapshot.data![followers ? 'followers' : 'following']);
              return Text(
                list.length.toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE56982)),
              );
            }
            return const Text(
              "0",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFE56982)),
            );
          },
        ),
      ],
    );
  }
}