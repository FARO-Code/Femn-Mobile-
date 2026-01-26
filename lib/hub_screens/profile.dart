import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/auth/auth.dart';
import 'package:femn/hub_screens/post.dart';
import 'package:femn/customization/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:femn/customization/layout.dart';
import 'package:image_picker/image_picker.dart';
import '../feed/addpost.dart';
import 'settings.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:video_player/video_player.dart';

import '../../feed/upload_service.dart';
import 'package:femn/circle/petitions.dart';
import 'package:femn/circle/polls.dart';
import 'package:femn/circle/groups.dart';
import 'package:femn/circle/discussions.dart';
import 'package:femn/analytics/screens/analytics_dashboard.dart'; // <--- Analytics Import
import 'package:rxdart/rxdart.dart';
import 'package:shimmer/shimmer.dart';
import 'package:femn/services/notification_service.dart';

// ======== AccountBadge Widget ========
class AccountBadge extends StatelessWidget {
  final String accountType;
  final bool isVerified;
  const AccountBadge({required this.accountType, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String label;
    switch (accountType) {
      case 'organization':
        icon = isVerified ? Feather.check_circle : Feather.briefcase;
        color = isVerified ? Colors.blueAccent : Colors.greenAccent;
        label = isVerified ? 'Verified Organization' : 'Organization';
        break;
      case 'therapist':
        icon = isVerified ? Feather.check_circle : Feather.activity;
        color = isVerified ? Colors.blueAccent : Colors.purpleAccent;
        label = isVerified ? 'Verified Therapist' : 'Therapist';
        break;
      default:
        icon = Feather.user;
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
enum ProfileTabType { activity, saved, liked, polls, petitions }

class PostGridWithPreview extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;
  final Widget? createPostButton;
  final ProfileTabType tabType;

  const PostGridWithPreview({
    required this.userId,
    required this.isOwnProfile,
    this.createPostButton,
    this.tabType = ProfileTabType.activity,
  });

  @override
  _PostGridWithPreviewState createState() => _PostGridWithPreviewState();
}

class _PostGridWithPreviewState extends State<PostGridWithPreview> {
  final ValueNotifier<String?> _activeVideoIdNotifier = ValueNotifier(null);
  List<Map<String, dynamic>> _combinedItems = [];
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

  void _startVideoSequence(List<Map<String, dynamic>> items) {
    _videoIds = items
        .where((item) => item['type'] == 'post')
        .map((item) => item['data'] as DocumentSnapshot)
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

  // Helpers from GroupsScreen for UI state
  bool _isDiscussionArchived(Map<String, dynamic> discussionData) {
    final Timestamp? expiresAt = discussionData['expiresAt'];
    if (expiresAt == null) return false;
    final DateTime expirationDate = expiresAt.toDate();
    return DateTime.now().isAfter(expirationDate);
  }

  int? _getDaysLeft(Map<String, dynamic> discussionData) {
    final Timestamp? expiresAt = discussionData['expiresAt'];
    if (expiresAt == null) return null;
    final DateTime expirationDate = expiresAt.toDate();
    final DateTime now = DateTime.now();
    if (now.isAfter(expirationDate)) return null;
    return expirationDate.difference(now).inDays;
  }

  Stream<List<Map<String, dynamic>>> _getCombinedStream() {
    final firestore = FirebaseFirestore.instance;

    if (widget.tabType == ProfileTabType.activity) {
      final postsStream = firestore
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => {
                    'type': 'post',
                    'data': d,
                    'time': d.data()['timestamp'],
                  },
                )
                .toList(),
          );

      final pollsStream = firestore
          .collection('polls')
          .where('createdBy', isEqualTo: widget.userId)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => {
                    'type': 'poll',
                    'data': d,
                    'time': d.data()['createdAt'],
                  },
                )
                .toList(),
          );

      final groupsStream = firestore
          .collection('groups')
          .where('createdBy', isEqualTo: widget.userId)
          .snapshots()
          .map(
            (s) => s.docs.map((d) {
              final data = d.data() as Map<String, dynamic>;
              final isDiscussion = data['category'] == 'Discussions';
              return {
                'type': isDiscussion ? 'discussion' : 'group',
                'data': d,
                'time': data['createdAt'],
              };
            }).toList(),
          );

      final petitionsStream = firestore
          .collection('petitions')
          .where('createdBy', isEqualTo: widget.userId)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => {
                    'type': 'petition',
                    'data': d,
                    'time': d.data()['createdAt'],
                  },
                )
                .toList(),
          );

      return CombineLatestStream.list([
        postsStream,
        pollsStream,
        groupsStream,
        petitionsStream,
      ]).map((lists) {
        final combined = lists.expand((x) => x).toList();
        combined.sort((a, b) {
          final timeA = (a['time'] as Timestamp?)?.toDate() ?? DateTime(0);
          final timeB = (b['time'] as Timestamp?)?.toDate() ?? DateTime(0);
          return timeB.compareTo(timeA);
        });
        return combined;
      });
    } else if (widget.tabType == ProfileTabType.saved) {
      // Saved posts in User doc
      return firestore.collection('users').doc(widget.userId).snapshots().asyncMap((
        userDoc,
      ) async {
        final savedIds = List<String>.from(userDoc.data()?['savedPosts'] ?? []);
        if (savedIds.isEmpty) return [];

        // Fetch posts in chunks of 10 (Firestore limit is 10 for whereIn, but actually 30 now, let's play safe)
        List<Map<String, dynamic>> results = [];
        for (var i = 0; i < savedIds.length; i += 10) {
          final chunk = savedIds.sublist(
            i,
            i + 10 > savedIds.length ? savedIds.length : i + 10,
          );
          final snap = await firestore
              .collection('posts')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          results.addAll(
            snap.docs.map(
              (d) => {'type': 'post', 'data': d, 'time': d.data()['timestamp']},
            ),
          );
        }
        results.sort(
          (a, b) => ((b['time'] as Timestamp?)?.toDate() ?? DateTime(0))
              .compareTo((a['time'] as Timestamp?)?.toDate() ?? DateTime(0)),
        );
        return results;
      });
    } else if (widget.tabType == ProfileTabType.liked) {
      return firestore
          .collection('posts')
          .where('likes', arrayContains: widget.userId)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => {
                    'type': 'post',
                    'data': d,
                    'time': d.data()['timestamp'],
                  },
                )
                .toList(),
          );
    } else if (widget.tabType == ProfileTabType.polls) {
      return firestore
          .collection('polls')
          .snapshots()
          .map(
            (s) => s.docs
                .where((d) {
                  final voters = List.from(
                    (d.data() as Map<String, dynamic>)['voters'] ?? [],
                  );
                  return voters.any(
                    (v) => v is Map && v['userId'] == widget.userId,
                  );
                })
                .map(
                  (d) => {
                    'type': 'poll',
                    'data': d,
                    'time': d.data()['createdAt'],
                  },
                )
                .toList(),
          );
    } else if (widget.tabType == ProfileTabType.petitions) {
      return firestore
          .collection('petitions')
          .where('signers', arrayContains: widget.userId)
          .snapshots()
          .map(
            (s) => s.docs
                .map(
                  (d) => {
                    'type': 'petition',
                    'data': d,
                    'time': d.data()['createdAt'],
                  },
                )
                .toList(),
          );
    }

    return Stream.value([]);
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are uploading
    final uploadService = PostUploadService.instance;
    final bool isUploading =
        widget.isOwnProfile && uploadService.status == UploadStatus.uploading;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getCombinedStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryLavender),
          );
        }

        final newItems = snapshot.hasData
            ? snapshot.data!
            : <Map<String, dynamic>>[];
        if (newItems.length != _combinedItems.length) {
          _combinedItems = newItems;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startVideoSequence(_combinedItems);
          });
        }

        bool showCreateButton =
            widget.isOwnProfile &&
            widget.tabType == ProfileTabType.activity &&
            widget.createPostButton != null;
        bool showGhostPost =
            widget.isOwnProfile &&
            widget.tabType == ProfileTabType.activity &&
            isUploading;

        int itemCount = _combinedItems.length;
        if (showCreateButton) itemCount++;
        if (showGhostPost) itemCount++;

        if (itemCount == 0) {
          String msg = 'No activity yet';
          if (widget.tabType == ProfileTabType.saved)
            msg = 'No saved posts';
          else if (widget.tabType == ProfileTabType.liked)
            msg = 'No liked posts';
          else if (widget.tabType == ProfileTabType.polls)
            msg = 'No polls participated in';
          else if (widget.tabType == ProfileTabType.petitions)
            msg = 'No petitions signed';
          return Center(
            child: Text(msg, style: TextStyle(color: AppColors.textMedium)),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: MasonryGridView.count(
            crossAxisCount: ResponsiveLayout.getColumnCount(context),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              int offset = 0;
              if (showCreateButton) {
                if (index == 0) return widget.createPostButton!;
                offset++;
              }
              if (showGhostPost) {
                if (index == offset)
                  return _buildGhostUploadItem(uploadService);
                offset++;
              }
              final itemIndex = index - offset;
              if (itemIndex < 0 || itemIndex >= _combinedItems.length)
                return Container();

              final item = _combinedItems[itemIndex];
              Widget child;

              if (item['type'] == 'post') {
                child = _buildPostGridItem(item['data'] as DocumentSnapshot);
              } else {
                child = _buildCircleGridItem(item);
              }

              // Apply Staggered Start for Polls and Petitions
              if (widget.tabType == ProfileTabType.polls ||
                  widget.tabType == ProfileTabType.petitions) {
                int columns = ResponsiveLayout.getColumnCount(context);
                int column = index % columns;
                if ((column == 0 || column == columns - 1) && index < columns) {
                  // Pseudo-random offset based on user ID and column
                  final int seed = widget.userId.hashCode + column;
                  final double staggerOffset =
                      (seed % 35) + 15.0; // 15px to 50px range
                  return Padding(
                    padding: EdgeInsets.only(top: staggerOffset),
                    child: child,
                  );
                }
              }

              return child;
            },
          ),
        );
      },
    );
  }

  Widget _buildPostGridItem(DocumentSnapshot post) {
    var postData = post.data() as Map<String, dynamic>;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetailScreen(
              postId: post.id,
              userId: widget.userId,
              source: 'profile',
            ),
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
                  placeholder: (context, url) =>
                      Container(color: AppColors.elevation),
                  errorWidget: (context, url, error) =>
                      const Icon(Feather.alert_circle, color: AppColors.error),
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
  }

  Widget _buildCircleGridItem(Map<String, dynamic> item) {
    final type = item['type'];
    final doc = item['data'] as DocumentSnapshot;
    final data = doc.data() as Map<String, dynamic>;

    IconData icon;
    String title;
    String description = '';
    Color color;
    String? imageUrl;
    Widget? badge;
    Widget? progressPill;

    switch (type) {
      case 'poll':
        icon = Feather.bar_chart_2;
        title = data['question'] ?? 'Poll';
        color = AppColors.primaryLavender;
        final int? days = _getDaysLeft(data);
        if (days != null) {
          badge = _buildSmallBadge('$days d', AppColors.accentMustard);
        }
        break;
      case 'discussion':
        icon = Feather.message_square;
        title = data['name'] ?? 'Discussion';
        description = data['description'] ?? '';
        color = AppColors.secondaryTeal;
        imageUrl = data['imageUrl'];
        final bool isArchived = _isDiscussionArchived(data);
        final int? days = _getDaysLeft(data);
        if (isArchived) {
          badge = _buildSmallBadge('ARCHIVED', AppColors.textDisabled);
        } else if (days != null) {
          badge = _buildSmallBadge('$days left', AppColors.accentMustard);
        }
        break;
      case 'group':
        icon = Feather.users;
        title = data['name'] ?? 'Group';
        description = data['description'] ?? '';
        color = AppColors.accentMustard;
        imageUrl = data['imageUrl'];
        break;
      case 'petition':
        icon = Feather.check_square;
        final petition = Petition.fromDocument(doc);
        title = petition.title;
        description = petition.description;
        color = AppColors.error;
        imageUrl = petition.bannerImageUrl;
        progressPill = _buildPetitionProgressPill(petition);
        break;
      default:
        icon = Feather.help_circle;
        title = 'Item';
        color = AppColors.textMedium;
    }

    if (type == 'poll') {
      return PollCard(
        pollSnapshot: doc,
        cardMarginVertical: 2,
        cardMarginHorizontal: 2,
        cardInternalPadding: 10,
        borderRadiusValue: 18,
        isCompact: true,
      );
    }

    return Card(
      margin: EdgeInsets.all(2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (type == 'discussion') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DiscussionViewScreen(discussionId: doc.id),
              ),
            );
          } else if (type == 'group') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GroupViewScreen(groupId: doc.id),
              ),
            );
          } else if (type == 'petition') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EnhancedPetitionDetailScreen(petitionId: doc.id),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image / AspectRatio
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: AppColors.elevation,
                                highlightColor: AppColors.surface.withOpacity(
                                  0.5,
                                ),
                                child: Container(color: Colors.white),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: color.withOpacity(0.1),
                                child: Icon(icon, color: color, size: 24),
                              ),
                            )
                          : Container(
                              color: color.withOpacity(0.1),
                              child: Icon(icon, color: color, size: 24),
                            ),
                      if (badge != null)
                        Positioned(top: 4, left: 4, child: badge),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Content - Only show description
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: AppColors.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Progress or Stats Pill
              if (progressPill != null)
                progressPill
              else
                _buildStatsPill(type, data, color, icon),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.backgroundDeep,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPetitionProgressPill(Petition petition) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondaryTeal,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.primaryLavender,
          width: 3 * petition.progress,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Feather.user_check, size: 10, color: AppColors.textOnSecondary),
          const SizedBox(width: 4),
          FittedBox(
            child: Text(
              '${petition.currentSignatures}/${petition.goal}',
              style: const TextStyle(
                color: AppColors.textOnSecondary,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsPill(
    String type,
    Map<String, dynamic> data,
    Color color,
    IconData icon,
  ) {
    String text = '';
    if (type == 'poll') {
      text = '${data['totalVotes'] ?? 0} votes';
    } else {
      text = '${data['memberCount'] ?? 0} members';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: (type == 'discussion' && _isDiscussionArchived(data))
            ? AppColors.textDisabled
            : AppColors.secondaryTeal,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon == Feather.bar_chart_2 ? icon : Feather.users,
            size: 10,
            color: AppColors.textOnSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textOnSecondary,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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
          child: Center(child: Icon(Feather.video, color: Colors.white24)),
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
                        service.progress >= 0.9
                            ? Feather.check
                            : Feather.upload,
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
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
          child: const Icon(Feather.image, color: Colors.red),
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
          if (_shouldPlay &&
              (_controller == null || !_controller!.value.isInitialized))
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
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
  final TextEditingController _missionStatementController =
      TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isEditing = false;
  File? _profileImageFile;
  bool _isOwnProfile = false;

  // New State for Personality Visibility
  bool _showPersonality = true;
  List<AvailabilitySlot> _availabilitySlots = [];

  @override
  void initState() {
    super.initState();
    _isOwnProfile = widget.userId == FirebaseAuth.instance.currentUser!.uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fixMissingBioFields();
    });

    if (!_isOwnProfile) {
      _incrementProfileVisits();
    }
  }

  void _incrementProfileVisits() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'profileVisits': FieldValue.increment(1)});
    } catch (e) {
      print("Error incrementing visits: $e");
    }
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
                    backgroundImage:
                        (userData['profileImage'] ?? userData['logo'] ?? '')
                            .isNotEmpty
                        ? CachedNetworkImageProvider(
                            userData['profileImage'] ?? userData['logo'] ?? '',
                          )
                        : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                  ),
                  if (_isEditing)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Feather.camera, color: Colors.white),
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
                      _isEditing ? Feather.save : Feather.edit,
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
              border: Border.all(
                color: AppColors.secondaryTeal.withOpacity(0.5),
              ),
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
                      color: canChangeName
                          ? AppColors.textHigh
                          : AppColors.textDisabled,
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
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 14,
                        ),
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
                          color: canChangeName
                              ? Colors.orange
                              : AppColors.error,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            canChangeName
                                ? Feather.alert_triangle
                                : Feather.lock,
                            color: canChangeName
                                ? Colors.orange
                                : AppColors.error,
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
                                color: canChangeName
                                    ? Colors.orange
                                    : AppColors.error,
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
                userData['fullName'] ??
                    userData['organizationName'] ??
                    'No Name',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
        const SizedBox(height: 2),
        Text(
          '@${userData['username'] ?? ''}',
          style: const TextStyle(color: AppColors.textMedium),
        ),
        ProfileStatsWidget(userId: user.id, isOwnProfile: _isOwnProfile),
        const SizedBox(height: 8),

        if (userData['accountType'] == 'organization')
          ..._buildOrganizationProfile(user),
        if (userData['accountType'] == 'therapist')
          ..._buildTherapistProfile(user),
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
      _buildAutoBio(userData),
      if (userData['missionStatement'] != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
          child: Text(
            userData['missionStatement'],
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textMedium,
              fontSize: 13,
            ),
          ),
        ),
      if (userData['website'] != null &&
          (userData['website'] as String).isNotEmpty)
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
                _buildTextField(controller: _phoneController, label: 'Phone'),
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
                ),
              ],
            )
          : const SizedBox.shrink(),
    ];
  }

  String _generateAutoBio(Map<String, dynamic> userData) {
    List<String> parts = [];
    final type = userData['accountType'];

    if (type == 'therapist') {
      if (userData['specialization'] is List) {
        final specs = (userData['specialization'] as List).join(', ');
        if (specs.isNotEmpty) parts.add(specs);
      }
      if (userData['experienceLevel'] != null &&
          userData['experienceLevel'].toString().isNotEmpty) {
        parts.add(userData['experienceLevel']);
      }
      if (userData['region'] != null &&
          userData['region'].toString().isNotEmpty) {
        parts.add(userData['region']);
      }
      if (userData['languages'] is List) {
        final langs = (userData['languages'] as List).join(', ');
        if (langs.isNotEmpty) parts.add(langs);
      }
      if (userData['genderPreference'] != null &&
          userData['genderPreference'].toString().isNotEmpty) {
        parts.add(userData['genderPreference']);
      }
    } else if (type == 'organization') {
      if (userData['category'] != null &&
          userData['category'].toString().isNotEmpty) {
        parts.add(userData['category']);
      }
      if (userData['areasOfFocus'] is List) {
        final focus = (userData['areasOfFocus'] as List).join(', ');
        if (focus.isNotEmpty) parts.add(focus);
      }
      if (userData['country'] != null &&
          userData['country'].toString().isNotEmpty) {
        parts.add(userData['country']);
      }
    }
    return parts.join(' || ');
  }

  Widget _buildAutoBio(Map<String, dynamic> userData) {
    final bio = _generateAutoBio(userData);
    if (bio.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
      child: Text(
        bio,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          color: AppColors.textMedium,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }

  List<Widget> _buildTherapistProfile(DocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>? ?? {};

    return [
      _buildAutoBio(userData),
      // Rating Display
      if (userData['accountType'] == 'therapist')
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Feather.star,
                size: 16,
                color: AppColors.accentMustard,
              ),
              const SizedBox(width: 4),
              Text(
                '${(userData['averageRating'] ?? 0.0).toStringAsFixed(1)} (${userData['totalRatings'] ?? 0})',
                style: const TextStyle(
                  color: AppColors.textMedium,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      if (_isEditing && userData['accountType'] == 'therapist')
        _buildAvailabilityField(),
      if (!_isEditing &&
          userData['availability'] != null &&
          (userData['availability'] as List).isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Feather.clock, size: 16, color: AppColors.secondaryTeal),
                  SizedBox(width: 8),
                  Text(
                    'Availability',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...(userData['availability'] as List).map<Widget>((slot) {
                final day = slot['day'];
                final start = TimeOfDay(
                  hour: slot['startHour'] ?? 0,
                  minute: slot['startMinute'] ?? 0,
                );
                final end = TimeOfDay(
                  hour: slot['endHour'] ?? 0,
                  minute: slot['endMinute'] ?? 0,
                );
                return Padding(
                  padding: const EdgeInsets.only(left: 24, bottom: 4),
                  child: Text(
                    '$day: ${start.format(context)} - ${end.format(context)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      if (_isEditing)
        _buildTextField(
          controller: _bioController,
          label: 'Professional Bio',
          maxLines: 3,
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
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>? ?? {};

      Map<String, dynamic> updateData = {
        'bio': _bioController.text,
        'showPersonality': _showPersonality, // ✅ SAVE TOGGLE STATE
      };

      if (_fullNameController.text.trim() != (userData['fullName'] ?? '')) {
        if (userData['lastNameChangeDate'] != null &&
            DateTime.now()
                    .difference(
                      (userData['lastNameChangeDate'] as Timestamp).toDate(),
                    )
                    .inDays <
                30) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name change locked for 30 days.'),
              backgroundColor: AppColors.error,
            ),
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

      if (userData['accountType'] == 'therapist') {
        updateData['availability'] = _availabilitySlots
            .map((s) => s.toMap())
            .toList();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update(updateData);
      setState(() => _isEditing = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _uploadProfileImage() async {
    if (_profileImageFile == null) return;
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'profile_images/${widget.userId}.jpg',
      );
      await ref.putFile(_profileImageFile!);
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'profileImage': url}, SetOptions(merge: true));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile picture updated!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    }
  }

  Future<void> fixMissingBioFields() async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .set({'bio': ''}, SetOptions(merge: true));
    } catch (_) {}
  }

  Widget _buildAvailabilityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: Text(
            'Edit Availability',
            style: TextStyle(
              color: AppColors.primaryLavender,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ..._availabilitySlots.asMap().entries.map((entry) {
          int index = entry.key;
          AvailabilitySlot slot = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 4.0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: slot.day,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 13,
                    ),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _availabilitySlots[index] = slot.copyWith(day: val);
                        });
                      }
                    },
                    items:
                        [
                              'Monday',
                              'Tuesday',
                              'Wednesday',
                              'Thursday',
                              'Friday',
                              'Saturday',
                              'Sunday',
                            ]
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                  ),
                ),
                TextButton(
                  onPressed: () => _selectTime(index, true),
                  child: Text(
                    slot.startTime.format(context),
                    style: const TextStyle(
                      color: AppColors.secondaryTeal,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Text('-', style: TextStyle(color: AppColors.textMedium)),
                TextButton(
                  onPressed: () => _selectTime(index, false),
                  child: Text(
                    slot.endTime.format(context),
                    style: const TextStyle(
                      color: AppColors.secondaryTeal,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Feather.minus_circle,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: () => _removeAvailabilitySlot(index),
                ),
              ],
            ),
          );
        }).toList(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextButton.icon(
            onPressed: _addAvailabilitySlot,
            icon: const Icon(Feather.plus, color: AppColors.success, size: 18),
            label: const Text(
              'Add Slot',
              style: TextStyle(color: AppColors.success, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  void _addAvailabilitySlot() {
    setState(() {
      _availabilitySlots.add(
        AvailabilitySlot(
          day: 'Monday',
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 17, minute: 0),
        ),
      );
    });
  }

  void _removeAvailabilitySlot(int index) {
    setState(() {
      _availabilitySlots.removeAt(index);
    });
  }

  Future<void> _selectTime(int index, bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? _availabilitySlots[index].startTime
          : _availabilitySlots[index].endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _availabilitySlots[index] = _availabilitySlots[index].copyWith(
            startTime: picked,
          );
        } else {
          _availabilitySlots[index] = _availabilitySlots[index].copyWith(
            endTime: picked,
          );
        }
      });
    }
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
              Icon(
                Feather.plus_circle,
                size: 40,
                color: AppColors.primaryLavender,
              ),
              SizedBox(height: 8),
              Text(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: _isOwnProfile
            ? [
                // Analytics Button
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
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
                      Feather.bar_chart_2,
                      color: AppColors.primaryLavender,
                      size: 20,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnalyticsDashboardScreen(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Settings Button
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 8, bottom: 8),
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
                      Feather.settings,
                      color: AppColors.primaryLavender,
                      size: 20,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SettingsScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ]
            : null,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLavender,
              ),
            );
          if (!snapshot.hasData)
            return const Center(child: Text('User not found'));

          var user = snapshot.data!;
          var userData = user.data() as Map<String, dynamic>? ?? {};

          if (!_isEditing) {
            _fullNameController.text = userData['fullName'] ?? '';
            _bioController.text = userData['bio'] ?? '';
            if (userData['availability'] != null) {
              _availabilitySlots = (userData['availability'] as List)
                  .map(
                    (slot) => AvailabilitySlot.fromMap(
                      Map<String, dynamic>.from(slot),
                    ),
                  )
                  .toList();
            }
          }

          return DefaultTabController(
            length: 5,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildProfileHeader(user),
                          const SizedBox(height: 4),

                          // Removed ProfileStatsWidget from here to move it between @ and bio
                          if (!_isOwnProfile) const SizedBox(height: 16),
                          if (!_isOwnProfile)
                            ElevatedButton(
                              onPressed: () async {
                                List f = List.from(userData['followers'] ?? []);
                                if (f.contains(
                                  FirebaseAuth.instance.currentUser!.uid,
                                )) {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.userId)
                                      .update({
                                        'followers': FieldValue.arrayRemove([
                                          FirebaseAuth
                                              .instance
                                              .currentUser!
                                              .uid,
                                        ]),
                                      });
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(
                                        FirebaseAuth.instance.currentUser!.uid,
                                      )
                                      .update({
                                        'following': FieldValue.arrayRemove([
                                          widget.userId,
                                        ]),
                                      });
                                } else {
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(widget.userId)
                                      .update({
                                        'followers': FieldValue.arrayUnion([
                                          FirebaseAuth
                                              .instance
                                              .currentUser!
                                              .uid,
                                        ]),
                                      });
                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(
                                        FirebaseAuth.instance.currentUser!.uid,
                                      )
                                      .update({
                                        'following': FieldValue.arrayUnion([
                                          widget.userId,
                                        ]),
                                      });
                                  // Send notification using service
                                  final currentUser =
                                      FirebaseAuth.instance.currentUser;
                                  if (currentUser != null) {
                                    final currentUserDoc =
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .get();
                                    final followerUsername =
                                        currentUserDoc.data()?['username'] ??
                                        'Someone';
                                    await NotificationService()
                                        .sendFollowNotification(
                                          followedUserId: widget.userId,
                                          followerUsername: followerUsername,
                                        );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryLavender,
                              ),
                              child: Text(
                                List.from(userData['followers'] ?? []).contains(
                                      FirebaseAuth.instance.currentUser!.uid,
                                    )
                                    ? 'Unfollow'
                                    : 'Follow',
                                style: const TextStyle(
                                  color: AppColors.backgroundDeep,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        labelColor: AppColors.primaryLavender,
                        unselectedLabelColor: AppColors.textDisabled,
                        indicatorColor: AppColors.primaryLavender,
                        tabs: [
                          Tab(icon: Icon(Feather.grid, size: 18)),
                          Tab(icon: Icon(Feather.bookmark, size: 18)),
                          Tab(icon: Icon(Feather.heart, size: 18)),
                          Tab(icon: Icon(Feather.bar_chart_2, size: 18)),
                          Tab(icon: Icon(Feather.check_square, size: 18)),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: _isOwnProfile,
                    tabType: ProfileTabType.activity,
                    createPostButton: _isOwnProfile
                        ? _buildCreatePostButton()
                        : null,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: _isOwnProfile,
                    tabType: ProfileTabType.saved,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: _isOwnProfile,
                    tabType: ProfileTabType.liked,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: _isOwnProfile,
                    tabType: ProfileTabType.polls,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: _isOwnProfile,
                    tabType: ProfileTabType.petitions,
                  ),
                ],
              ),
            ),
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
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
    if (doc.exists) {
      setState(
        () => _isFollowing = List<String>.from(
          doc.data()?['followers'] ?? [],
        ).contains(FirebaseAuth.instance.currentUser!.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLavender,
              ),
            );

          final user = snapshot.data?.data() as Map<String, dynamic>? ?? {};

          // ✅ CHECK PERSONALITY VISIBILITY FROM DB
          bool showPersonality = user['showPersonality'] ?? true;
          String? personalityType = user['personalityType'];
          String? personalityTitle = user['personalityTitle'];

          return DefaultTabController(
            length: 5,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: AppColors.elevation,
                            backgroundImage:
                                (user['profileImage'] ?? '').isNotEmpty
                                ? CachedNetworkImageProvider(
                                    user['profileImage'],
                                  )
                                : const AssetImage('assets/default_avatar.png')
                                      as ImageProvider,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user['fullName'] ?? 'No Name',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '@${user['username'] ?? ''}',
                            style: const TextStyle(color: AppColors.textMedium),
                          ),
                          if (showPersonality && personalityType != null)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.elevation,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: AppColors.secondaryTeal.withOpacity(
                                    0.5,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Feather.zap,
                                    size: 12,
                                    color: AppColors.secondaryTeal,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    "$personalityType - $personalityTitle",
                                    style: const TextStyle(
                                      color: AppColors.textHigh,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ProfileStatsWidget(
                            userId: widget.userId,
                            isOwnProfile: false,
                          ),
                          Text(
                            user['bio'] ?? 'No bio yet',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMedium),
                          ),
                          // ProfileStatsWidget moved up
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (_isFollowing) {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.userId)
                                    .update({
                                      'followers': FieldValue.arrayRemove([
                                        FirebaseAuth.instance.currentUser!.uid,
                                      ]),
                                    });
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .update({
                                      'following': FieldValue.arrayRemove([
                                        widget.userId,
                                      ]),
                                    });
                              } else {
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(widget.userId)
                                    .update({
                                      'followers': FieldValue.arrayUnion([
                                        FirebaseAuth.instance.currentUser!.uid,
                                      ]),
                                    });
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(FirebaseAuth.instance.currentUser!.uid)
                                    .update({
                                      'following': FieldValue.arrayUnion([
                                        widget.userId,
                                      ]),
                                    });

                                // Send notification using service
                                final currentUser =
                                    FirebaseAuth.instance.currentUser;
                                if (currentUser != null) {
                                  final currentUserDoc = await FirebaseFirestore
                                      .instance
                                      .collection('users')
                                      .doc(currentUser.uid)
                                      .get();
                                  final followerUsername =
                                      currentUserDoc.data()?['username'] ??
                                      'Someone';
                                  await NotificationService()
                                      .sendFollowNotification(
                                        followedUserId: widget.userId,
                                        followerUsername: followerUsername,
                                      );
                                }
                              }
                              setState(() => _isFollowing = !_isFollowing);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isFollowing
                                  ? AppColors.elevation
                                  : AppColors.secondaryTeal,
                            ),
                            child: Text(
                              _isFollowing ? 'Unfollow' : 'Follow',
                              style: TextStyle(
                                color: _isFollowing
                                    ? AppColors.textHigh
                                    : AppColors.backgroundDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _SliverAppBarDelegate(
                      const TabBar(
                        labelColor: AppColors.primaryLavender,
                        unselectedLabelColor: AppColors.textDisabled,
                        indicatorColor: AppColors.primaryLavender,
                        tabs: [
                          Tab(icon: Icon(Feather.grid, size: 18)),
                          Tab(icon: Icon(Feather.bookmark, size: 18)),
                          Tab(icon: Icon(Feather.heart, size: 18)),
                          Tab(icon: Icon(Feather.bar_chart_2, size: 18)),
                          Tab(icon: Icon(Feather.check_square, size: 18)),
                        ],
                      ),
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: false,
                    tabType: ProfileTabType.activity,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: false,
                    tabType: ProfileTabType.saved,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: false,
                    tabType: ProfileTabType.liked,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: false,
                    tabType: ProfileTabType.polls,
                  ),
                  PostGridWithPreview(
                    userId: widget.userId,
                    isOwnProfile: false,
                    tabType: ProfileTabType.petitions,
                  ),
                ],
              ),
            ),
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.showFollowers ? 'Followers' : 'Following',
          style: const TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting)
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLavender,
              ),
            );

          final u = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
          final ids = List<String>.from(
            widget.showFollowers
                ? (u['followers'] ?? [])
                : (u['following'] ?? []),
          );

          if (ids.isEmpty)
            return Center(
              child: Text(
                widget.showFollowers
                    ? 'No followers yet'
                    : 'Not following anyone',
                style: const TextStyle(color: AppColors.textMedium),
              ),
            );

          return ListView.builder(
            itemCount: ids.length,
            itemBuilder: (context, index) => FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(ids[index])
                  .get(),
              builder: (context, snap) {
                final user = snap.data?.data() as Map<String, dynamic>? ?? {};
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.elevation,
                    backgroundImage: (user['profileImage'] ?? '').isNotEmpty
                        ? CachedNetworkImageProvider(user['profileImage'])
                        : const AssetImage('assets/default_avatar.png')
                              as ImageProvider,
                  ),
                  title: Text(
                    user['username'] ?? 'Loading...',
                    style: const TextStyle(color: AppColors.textHigh),
                  ),
                  subtitle: Text(
                    user['fullName'] ?? '',
                    style: const TextStyle(color: AppColors.textMedium),
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ids[index] == FirebaseAuth.instance.currentUser!.uid
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStat(
            "posts",
            FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: userId)
                .snapshots()
                .map((s) => s.docs.length),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FollowListScreen(userId: userId, showFollowers: true),
              ),
            ),
            child: _buildStatFuture("followers", userId, true),
          ),
          const SizedBox(width: 16),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    FollowListScreen(userId: userId, showFollowers: false),
              ),
            ),
            child: _buildStatFuture("following", userId, false),
          ),
          const SizedBox(width: 16),
          _buildEmbersStat(userId),
        ],
      ),
    );
  }

  Widget _buildStat(String label, Stream<int> stream) => StreamBuilder<int>(
    stream: stream,
    builder: (context, snapshot) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (snapshot.data ?? 0).toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: AppColors.textMedium,
          ),
        ),
      ],
    ),
  );

  Widget _buildStatFuture(
    String label,
    String userId,
    bool f,
  ) => FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
    builder: (context, snapshot) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (List.from(
            (snapshot.data?.data() as Map?)?[f ? 'followers' : 'following'] ??
                [],
          )).length.toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: AppColors.textMedium,
          ),
        ),
      ],
    ),
  );

  Widget _buildEmbersStat(String userId) => StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots(),
    builder: (context, snapshot) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          ((snapshot.data?.data() as Map?)?['embers'] ?? 0).toString(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textHigh,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          "embers",
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.normal,
            color: AppColors.textMedium,
          ),
        ),
      ],
    ),
  );
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.surface.withOpacity(0.8), child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
