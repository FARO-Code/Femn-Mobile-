import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth.dart';
import 'package:femn/post.dart';
import 'package:femn/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'addpost.dart';
import 'settings.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:video_player/video_player.dart';
import 'package:femn/twin_finder.dart';
import 'package:femn/upload_service.dart'; // Add this
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

// ======== AccountBadge Widget ========
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
        color = isVerified ? Colors.blueAccent : Colors.greenAccent;
        label = isVerified ? 'Verified Organization' : 'Organization';
        break;
      case 'therapist':
        icon = isVerified ? Icons.verified_user : Icons.medical_services;
        color = isVerified ? Colors.blueAccent : Colors.purpleAccent;
        label = isVerified ? 'Verified Therapist' : 'Therapist';
        break;
      default:
        icon = Icons.person;
        color = AppColors.textMedium;
        label = 'Personal';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
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

// ======== Post Grid With Preview Logic (Orchestrator) ========
class PostGridWithPreview extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;
  final Widget? createPostButton;
  const PostGridWithPreview({
    required this.userId,
    required this.isOwnProfile,
    this.createPostButton,
  });

  @override
  _PostGridWithPreviewState createState() => _PostGridWithPreviewState();
}

class _PostGridWithPreviewState extends State<PostGridWithPreview> {
  final ValueNotifier<String?> _activeVideoIdNotifier = ValueNotifier(null);
  List<DocumentSnapshot> _posts = [];
  int _currentSequenceIndex = 0;
  List<String> _videoIds = [];

  // ADDED: Listener for Upload Service
  @override
  void initState() {
    super.initState();
    PostUploadService.instance.addListener(_onUploadStateChanged);
  }

  @override
  void dispose() {
    PostUploadService.instance.removeListener(_onUploadStateChanged);
    _activeVideoIdNotifier.dispose();
    super.dispose();
  }

  // Handle Error Popups here
  void _onUploadStateChanged() {
    final service = PostUploadService.instance;
    if (service.status == UploadStatus.error && service.errorMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(service.errorMessage!),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 4),
          ),
        );
        service.consumeError(); // Reset service state
      }
    }
    // Rebuild to show/hide ghost post
    if (mounted) setState(() {});
  }

  void _startVideoSequence(List<DocumentSnapshot> posts) {
    _videoIds = posts
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['mediaType'] == 'video';
        })
        .map((doc) => doc.id)
        .toList();

    if (_videoIds.isEmpty) {
      _activeVideoIdNotifier.value = null;
      return;
    }
    _currentSequenceIndex = 0;
    _playNextInSequence();
  }

  void _playNextInSequence() {
    if (!mounted) return;

    if (_currentSequenceIndex >= _videoIds.length) {
      _currentSequenceIndex = 0; // Loop
    }

    if (_videoIds.isEmpty) return;
    String postIdToPlay = _videoIds[_currentSequenceIndex];
    _activeVideoIdNotifier.value = postIdToPlay;
  }

  void _handleVideoFinished(String postId) {
    if (_videoIds.contains(postId) && _activeVideoIdNotifier.value == postId) {
      _currentSequenceIndex++;
      _playNextInSequence();
    }
  }

 @override
  Widget build(BuildContext context) {
    // Check if we are uploading
    final uploadService = PostUploadService.instance;
    final bool isUploading = widget.isOwnProfile && uploadService.status == UploadStatus.uploading;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
        }

        final newPosts = snapshot.hasData ? snapshot.data!.docs : <DocumentSnapshot>[];
        if (newPosts.length != _posts.length) {
          _posts = newPosts;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startVideoSequence(_posts);
          });
        }

        // Calculate total items for Grid
        // 1. Create Button (if own profile)
        // 2. Ghost Post (if uploading & own profile)
        // 3. Actual Posts
        int itemCount = _posts.length;
        if (widget.isOwnProfile) itemCount++; // Create Button
        if (isUploading) itemCount++; // Ghost Post

        if (itemCount == 0) {
          return Center(child: Text('No posts yet', style: TextStyle(color: AppColors.textMedium)));
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              
              // --- SLOT 0: Create Post Button (Own Profile) ---
              if (widget.isOwnProfile && index == 0) {
                return widget.createPostButton ?? Container();
              }

              // --- SLOT 1: Ghost Uploading Post (If Uploading) ---
              if (isUploading && index == 1) {
                return _buildGhostUploadItem(uploadService);
              }

              // --- REMAINING SLOTS: Real Posts ---
              // Calculate the actual index in the _posts list
              int offset = 0;
              if (widget.isOwnProfile) offset++;
              if (isUploading) offset++;
              
              final postIndex = index - offset;
              
              if (postIndex < 0 || postIndex >= _posts.length) return Container();

              var post = _posts[postIndex];
              var postData = post.data() as Map<String, dynamic>;

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
                    child: postData['mediaType'] == 'image'
                        ? CachedNetworkImage(
                            imageUrl: postData['mediaUrl'],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: AppColors.elevation),
                            errorWidget: (context, url, error) => const Icon(Icons.error, color: AppColors.error),
                          )
                        : VideoGridItem(
                            url: postData['mediaUrl'],
                            thumbnailUrl: postData['thumbnailUrl'],
                            postId: post.id,
                            activePostIdNotifier: _activeVideoIdNotifier,
                            onVideoFinished: () => _handleVideoFinished(post.id),
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

  // --- NEW WIDGET: The Ghost Upload Item ---
  Widget _buildGhostUploadItem(PostUploadService service) {
    
    // Determine what to show as the background
    Widget backgroundWidget;
    
    if (service.currentMediaType == 'video') {
      if (service.currentThumbnail != null) {
        // Show generated thumbnail
        backgroundWidget = Image.file(
          service.currentThumbnail!,
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.5),
        );
      } else {
        // Show placeholder while thumbnail generates
        backgroundWidget = Container(
          color: Colors.black,
          child: Center(child: Icon(FeatherIcons.video, color: Colors.white24)),
        );
      }
    } else {
      // It's an image
      backgroundWidget = Image.file(
        service.currentFile!,
        fit: BoxFit.cover,
        opacity: const AlwaysStoppedAnimation(0.5),
      );
    }

    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background (Image or Video Thumbnail)
            backgroundWidget,
            
            // 2. Dark Overlay
            Container(color: Colors.black45),

            // 3. Circular Progress & Icon
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 40, 
                        height: 40,
                        child: CircularProgressIndicator(
                          value: service.progress,
                          color: AppColors.primaryLavender,
                          backgroundColor: Colors.white24,
                          strokeWidth: 4,
                        ),
                      ),
                      Icon(
                        service.progress >= 0.9 ? FeatherIcons.check : FeatherIcons.upload,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    service.progress >= 0.9 ? "Finalizing..." : "Posting...",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======== Video Grid Item ========
class VideoGridItem extends StatefulWidget {
  final String url;
  final String? thumbnailUrl;
  final String postId;
  final ValueNotifier<String?>? activePostIdNotifier;
  final VoidCallback? onVideoFinished;

  const VideoGridItem({
    required this.url,
    this.thumbnailUrl,
    required this.postId,
    this.activePostIdNotifier,
    this.onVideoFinished,
  });

  @override
  _VideoGridItemState createState() => _VideoGridItemState();
}

class _VideoGridItemState extends State<VideoGridItem> {
  VideoPlayerController? _controller;
  bool _shouldPlay = false;
  Timer? _playDurationTimer;

  @override
  void initState() {
    super.initState();
    widget.activePostIdNotifier?.addListener(_checkPlaybackStatus);
  }

  @override
  void dispose() {
    widget.activePostIdNotifier?.removeListener(_checkPlaybackStatus);
    _playDurationTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  void _checkPlaybackStatus() {
    final isActive = widget.activePostIdNotifier?.value == widget.postId;
    if (isActive) {
      _initializeAndPlay();
    } else {
      _disposeController();
    }
  }

  Future<void> _initializeAndPlay() async {
    if (_controller != null) return;
    if (mounted) setState(() => _shouldPlay = true);

    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await _controller!.initialize();
      _controller!.setVolume(0.0);

      if (widget.activePostIdNotifier?.value == widget.postId) {
        await _controller!.play();
        if (mounted) setState(() {});

        _playDurationTimer?.cancel();
        _playDurationTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            _disposeController();
            widget.onVideoFinished?.call();
          }
        });
      } else {
        _disposeController();
      }
    } catch (e) {
      print("Error playing video preview: $e");
      _disposeController();
      widget.onVideoFinished?.call();
    }
  }

  void _disposeController() {
    _playDurationTimer?.cancel();
    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
    }
    if (mounted && _shouldPlay) {
      setState(() => _shouldPlay = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget thumbnailWidget;
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      thumbnailWidget = CachedNetworkImage(
        imageUrl: widget.thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(color: AppColors.elevation),
        errorWidget: (context, url, error) => Container(
          color: Colors.red.withOpacity(0.2),
          child: const Icon(Icons.broken_image, color: Colors.red),
        ),
      );
    } else {
      thumbnailWidget = Container(
        color: AppColors.elevation,
        child: Center(
          child: Icon(Feather.video, color: AppColors.textDisabled, size: 30),
        ),
      );
    }

    double aspectRatio = 9 / 16;
    if (_controller != null && _controller!.value.isInitialized) {
      aspectRatio = _controller!.value.aspectRatio;
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: thumbnailWidget),
          if (_controller != null && _controller!.value.isInitialized)
            Positioned.fill(child: VideoPlayer(_controller!)),
          if (_shouldPlay && (_controller == null || !_controller!.value.isInitialized))
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
  final TextEditingController _missionStatementController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isEditing = false;
  File? _profileImageFile;
  bool _isOwnProfile = false;

  // New State for Personality Visibility
  bool _showPersonality = true;

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser!.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fixMissingBioFields();
    });
  }

  Widget _buildProfileHeader(DocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>? ?? {};
    bool canChangeName = true;
    int daysRemaining = 0;

    // Initialize Toggle State from DB when not editing
    if (!_isEditing) {
      _showPersonality = userData['showPersonality'] ?? true;
    }

    if (userData['lastNameChangeDate'] != null) {
      final Timestamp lastChange = userData['lastNameChangeDate'];
      final date = lastChange.toDate();
      final daysSince = DateTime.now().difference(date).inDays;
      if (daysSince < 30) {
        canChangeName = false;
        daysRemaining = 30 - daysSince;
      }
    }

    // Personality Data
    String? personalityType = userData['personalityType'];
    String? personalityTitle = userData['personalityTitle'];

    return Column(
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () {
                if (_isEditing) _pickProfileImage();
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.elevation,
                    backgroundImage: (userData['profileImage'] ?? userData['logo'] ?? '').isNotEmpty
                        ? CachedNetworkImageProvider(userData['profileImage'] ?? userData['logo'] ?? '')
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  if (_isEditing)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white),
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
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.edit,
                      color: AppColors.backgroundDeep,
                      size: 14,
                    ),
                    onPressed: () {
                      if (_isEditing)
                        _saveProfileChanges();
                      else
                        setState(() => _isEditing = true);
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        AccountBadge(
          accountType: userData['accountType'] ?? 'personal',
          isVerified: userData['isVerified'] ?? false,
        ),
        const SizedBox(height: 8),

        // --- PERSONALITY TYPE DISPLAY ---
        if (!_isEditing && _showPersonality && personalityType != null)
          Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.elevation,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: AppColors.secondaryTeal.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Feather.zap, size: 12, color: AppColors.secondaryTeal),
                SizedBox(width: 6),
                Text(
                  "$personalityType - $personalityTitle",
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        _isEditing
            ? Column(
                children: [
                  TextFormField(
                    controller: _fullNameController,
                    enabled: canChangeName,
                    style: TextStyle(
                      color: canChangeName ? AppColors.textHigh : AppColors.textDisabled,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      filled: true,
                      fillColor: AppColors.elevation,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  // --- VISIBILITY TOGGLE IN EDIT MODE ---
                  if (personalityType != null)
                    SwitchListTile(
                      activeColor: AppColors.primaryLavender,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Show Twin Finder Personality",
                        style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                      ),
                      value: _showPersonality,
                      onChanged: (val) {
                        setState(() => _showPersonality = val);
                      },
                    ),

                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: canChangeName
                            ? Colors.orange.withOpacity(0.15)
                            : AppColors.error.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: canChangeName ? Colors.orange : AppColors.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canChangeName ? Icons.warning_amber_rounded : Icons.lock_clock,
                            color: canChangeName ? Colors.orange : AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
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
                ],
              )
            : Text(
                userData['fullName'] ?? userData['organizationName'] ?? 'No Name',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
              ),
        const SizedBox(height: 2),
        Text(
          '@${userData['username'] ?? ''}',
          style: const TextStyle(color: AppColors.textMedium),
        ),
        const SizedBox(height: 8),

        if (userData['accountType'] == 'organization') ..._buildOrganizationProfile(user),
        if (userData['accountType'] == 'therapist') ..._buildTherapistProfile(user),
        if ((userData['accountType'] ?? 'personal') == 'personal')
          _isEditing
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextFormField(
                    controller: _bioController,
                    style: const TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      filled: true,
                      fillColor: AppColors.elevation,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 2,
                  ),
                )
              : Text(
                  userData['bio'] ?? 'No bio yet',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMedium),
                ),
      ],
    );
  }

  List<Widget> _buildOrganizationProfile(DocumentSnapshot user) {
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
          style: const TextStyle(color: AppColors.textDisabled, fontWeight: FontWeight.w500),
        ),
      if (userData['missionStatement'] != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            userData['missionStatement'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textMedium,
            ),
          ),
        ),
      if (userData['website'] != null && (userData['website'] as String).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            userData['website'],
            style: const TextStyle(
              color: AppColors.secondaryTeal,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      _isEditing
          ? Column(
              children: [
                _buildTextField(
                  controller: _missionStatementController,
                  label: 'Mission Statement',
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _websiteController,
                  label: 'Website (optional)',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _bioController,
                  label: 'About Us',
                  maxLines: 3,
                )
              ],
            )
          : Text(
              userData['bio'] ?? 'No description yet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium),
            ),
    ];
  }

  List<Widget> _buildTherapistProfile(DocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>? ?? {};

    return [
      if (userData['specialization'] != null && (userData['specialization'] as List?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (userData['specialization'] as List)
                .map<Widget>((spec) => Chip(
                      label: Text(
                        spec.toString(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textHigh),
                      ),
                      backgroundColor: AppColors.elevation,
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ),
      if (userData['experienceLevel'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            userData['experienceLevel'],
            style: const TextStyle(color: AppColors.textDisabled, fontWeight: FontWeight.w500),
          ),
        ),
      if (userData['region'] != null && (userData['region'] as String).isNotEmpty)
        Text(
          userData['region'],
          style: const TextStyle(color: AppColors.textDisabled),
        ),
      if (userData['availableHours'] != null)
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            'Available: ${userData['availableHours']}',
            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w500),
          ),
        ),
      _isEditing
          ? _buildTextField(
              controller: _bioController,
              label: 'Professional Bio',
              maxLines: 3,
            )
          : Text(
              userData['bio'] ?? 'No bio yet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMedium),
            ),
      if (userData['languages'] != null && (userData['languages'] as List?)?.isNotEmpty == true)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: (userData['languages'] as List)
                .map<Widget>((lang) => Chip(
                      label: Text(
                        lang.toString(),
                        style: const TextStyle(fontSize: 12, color: AppColors.textHigh),
                      ),
                      backgroundColor: AppColors.secondaryTeal.withOpacity(0.2),
                      visualDensity: VisualDensity.compact,
                    ))
                .toList(),
          ),
        ),
    ];
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: AppColors.textHigh),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.elevation,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      maxLines: maxLines,
    );
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _profileImageFile = File(pickedFile.path));
      await _uploadProfileImage();
    }
  }

  Future<void> _saveProfileChanges() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      Map<String, dynamic> updateData = {
        'bio': _bioController.text,
        'showPersonality': _showPersonality, // ✅ SAVE TOGGLE STATE
      };

      if (_fullNameController.text.trim() != (userData['fullName'] ?? '')) {
        if (userData['lastNameChangeDate'] != null &&
            DateTime.now().difference((userData['lastNameChangeDate'] as Timestamp).toDate()).inDays < 30) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Name change locked for 30 days.'), backgroundColor: AppColors.error),
          );
          return;
        }
        updateData['fullName'] = _fullNameController.text.trim();
        updateData['lastNameChangeDate'] = FieldValue.serverTimestamp();
      }

      if (userData['accountType'] == 'organization') {
        updateData['missionStatement'] = _missionStatementController.text;
        updateData['website'] = _websiteController.text;
        updateData['phone'] = _phoneController.text;
        updateData['address'] = _addressController.text;
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(updateData);
      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImageFile == null) return;
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_images/${widget.userId}.jpg');
      await ref.putFile(_profileImageFile!);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set(
            {'profileImage': url},
            SetOptions(merge: true),
          );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> fixMissingBioFields() async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).set(
            {'bio': ''},
            SetOptions(merge: true),
          );
    } catch (_) {}
  }

  Widget _buildPostsGrid(String userId, bool isOwnProfile) {
    return PostGridWithPreview(
      userId: userId,
      isOwnProfile: isOwnProfile,
      createPostButton: isOwnProfile ? _buildCreatePostButton() : null,
    );
  }

  Widget _buildCreatePostButton() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddPostScreen()),
      ),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.elevation,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: AppColors.primaryLavender, width: 1.5),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Feather.plus_circle, size: 40, color: AppColors.primaryLavender),
              SizedBox(height: 8),
              Text(
                'Create Post',
                style: TextStyle(
                  color: AppColors.primaryLavender,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        actions: _isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Feather.settings, color: AppColors.textHigh),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  ),
                ),
              ]
            : null,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          if (!snapshot.hasData) return const Center(child: Text('User not found'));

          var user = snapshot.data!;
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
                    const SizedBox(height: 4),
                    ProfileStatsWidget(userId: widget.userId, isOwnProfile: _isOwnProfile),
                    if (!_isOwnProfile) const SizedBox(height: 16),
                    if (!_isOwnProfile)
                      ElevatedButton(
                        onPressed: () async {
                          List f = List.from(userData['followers'] ?? []);
                          if (f.contains(FirebaseAuth.instance.currentUser!.uid)) {
                            await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                              'followers': FieldValue.arrayRemove([FirebaseAuth.instance.currentUser!.uid])
                            });
                            await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
                              'following': FieldValue.arrayRemove([widget.userId])
                            });
                          } else {
                            await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                              'followers': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid])
                            });
                            await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
                              'following': FieldValue.arrayUnion([widget.userId])
                            });
                            await FirebaseFirestore.instance.collection('notifications').add({
                              'type': 'follow',
                              'fromUserId': FirebaseAuth.instance.currentUser!.uid,
                              'toUserId': widget.userId,
                              'timestamp': DateTime.now(),
                              'read': false,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLavender),
                        child: Text(
                          List.from(userData['followers'] ?? []).contains(FirebaseAuth.instance.currentUser!.uid)
                              ? 'Unfollow'
                              : 'Follow',
                          style: const TextStyle(color: AppColors.backgroundDeep),
                        ),
                      )
                  ],
                ),
              ),
              Expanded(child: _buildPostsGrid(widget.userId, _isOwnProfile)),
            ],
          );
        },
      ),
    );
  }
}

// ======== Other User Profile Screen ========
class OtherUserProfileScreen extends StatefulWidget {
  final String userId;
  const OtherUserProfileScreen({required this.userId});

  @override
  _OtherUserProfileScreenState createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _checkIfFollowing();
  }

  void _checkIfFollowing() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (doc.exists) {
      setState(() => _isFollowing = List<String>.from(doc.data()?['followers'] ?? []).contains(FirebaseAuth.instance.currentUser!.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));

          final user = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          // ✅ CHECK PERSONALITY VISIBILITY FROM DB
          bool showPersonality = user['showPersonality'] ?? true;
          String? personalityType = user['personalityType'];
          String? personalityTitle = user['personalityTitle'];

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
                          : const AssetImage('assets/default_avatar.png') as ImageProvider,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user['fullName'] ?? 'No Name',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user['username'] ?? ''}',
                      style: const TextStyle(color: AppColors.textMedium),
                    ),

                    // --- SHOW PERSONALITY IF ENABLED ---
                    if (showPersonality && personalityType != null)
                      Container(
                        margin: EdgeInsets.symmetric(vertical: 6),
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.elevation,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.secondaryTeal.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Feather.zap, size: 12, color: AppColors.secondaryTeal),
                            SizedBox(width: 6),
                            Text(
                              "$personalityType - $personalityTitle",
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    Text(
                      user['bio'] ?? 'No bio yet',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMedium),
                    ),
                    const SizedBox(height: 4),
                    ProfileStatsWidget(userId: widget.userId, isOwnProfile: false),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (_isFollowing) {
                          await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                            'followers': FieldValue.arrayRemove([FirebaseAuth.instance.currentUser!.uid])
                          });
                          await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
                            'following': FieldValue.arrayRemove([widget.userId])
                          });
                        } else {
                          await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
                            'followers': FieldValue.arrayUnion([FirebaseAuth.instance.currentUser!.uid])
                          });
                          await FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).update({
                            'following': FieldValue.arrayUnion([widget.userId])
                          });
                        }
                        setState(() => _isFollowing = !_isFollowing);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing ? AppColors.elevation : AppColors.secondaryTeal,
                      ),
                      child: Text(
                        _isFollowing ? 'Unfollow' : 'Follow',
                        style: TextStyle(
                          color: _isFollowing ? AppColors.textHigh : AppColors.backgroundDeep,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                child: PostGridWithPreview(
                  userId: widget.userId,
                  isOwnProfile: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ======== Follow List Screen ========
class FollowListScreen extends StatefulWidget {
  final String userId;
  final bool showFollowers;
  const FollowListScreen({required this.userId, required this.showFollowers});

  @override
  _FollowListScreenState createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text(widget.showFollowers ? 'Followers' : 'Following', style: const TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(widget.userId).snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));

          final u = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final ids = List<String>.from(widget.showFollowers ? (u['followers'] ?? []) : (u['following'] ?? []));

          if (ids.isEmpty)
            return Center(
              child: Text(
                widget.showFollowers ? 'No followers yet' : 'Not following anyone',
                style: const TextStyle(color: AppColors.textMedium),
              ),
            );

          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, index) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(ids[index]).get(),
              builder: (context, snap) {
                final user = snap.data?.data() as Map<String, dynamic>? ?? {};
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.elevation,
                    backgroundImage: (user['profileImage'] ?? '').isNotEmpty
                        ? CachedNetworkImageProvider(user['profileImage'])
                        : const AssetImage('assets/default_avatar.png') as ImageProvider,
                  ),
                  title: Text(user['username'] ?? 'Loading...', style: const TextStyle(color: AppColors.textHigh)),
                  subtitle: Text(user['fullName'] ?? '', style: const TextStyle(color: AppColors.textMedium)),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ids[index] == FirebaseAuth.instance.currentUser!.uid
                          ? ProfileScreen(userId: ids[index])
                          : OtherUserProfileScreen(userId: ids[index]),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// ======== Profile Stats Widget ========
class ProfileStatsWidget extends StatelessWidget {
  final String userId;
  final bool isOwnProfile;
  const ProfileStatsWidget({required this.userId, required this.isOwnProfile});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: AppColors.elevation, width: 1),
            boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat("Posts", FirebaseFirestore.instance.collection('posts').where('userId', isEqualTo: userId).snapshots().map((s) => s.docs.length)),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FollowListScreen(userId: userId, showFollowers: true)),
                ),
                child: _buildStatFuture("Followers", userId, true),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FollowListScreen(userId: userId, showFollowers: false)),
                ),
                child: _buildStatFuture("Following", userId, false),
              ),
              _buildEmbersStat(userId),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, Stream<int> stream) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLavender)),
          const SizedBox(height: 2),
          StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) => Text(
              (snapshot.data ?? 0).toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
            ),
          )
        ],
      );

  Widget _buildStatFuture(String label, String userId, bool f) => Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLavender)),
          const SizedBox(height: 2),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
            builder: (context, snapshot) => Text(
              (List.from((snapshot.data?.data() as Map?)?[f ? 'followers' : 'following'] ?? [])).length.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
            ),
          )
        ],
      );

  Widget _buildEmbersStat(String userId) => Column(
        children: [
          const Text("Embers", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLavender)),
          const SizedBox(height: 2),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
            builder: (context, snapshot) => Text(
              ((snapshot.data?.data() as Map?)?['embers'] ?? 0).toString(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh),
            ),
          )
        ],
      );
}