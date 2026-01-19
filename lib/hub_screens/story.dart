import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import 'package:femn/services/embers_service.dart';
import 'package:femn/customization/colors.dart'; // <--- IMPORT COLORS

// --- STORY CREATION MODAL ---
class StoryCreationModal extends StatefulWidget {
  @override
  _StoryCreationModalState createState() => _StoryCreationModalState();
}

class _StoryCreationModalState extends State<StoryCreationModal> {
  File? _mediaFile;
  String? _mediaType;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickMedia(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        _mediaFile = File(pickedFile.path);
        _mediaType = 'image';
      });
    }
  }

  Future<void> _uploadStory() async {
    if (_mediaFile == null) return;
    
    setState(() { _isUploading = true; });
    
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      
      // Check if user has enough embers first
      final hasEnoughEmbers = await EmbersService.hasSufficientEmbers(1);
      if (!hasEnoughEmbers) {
        // The EmbersService will automatically show a snackbar via the button check
        setState(() { _isUploading = false; });
        return;
      }
      
      // Upload media
      String storyId = Uuid().v4();
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child(currentUserId)
          .child('$storyId.jpg');
      
      await storageRef.putFile(_mediaFile!);
      String mediaUrl = await storageRef.getDownloadURL();

      // Create story document and get reference
      DocumentReference storyDocRef = await FirebaseFirestore.instance.collection('stories').add({
        'userId': currentUserId,
        'username': userDoc['username'],
        'profileImage': userDoc['profileImage'],
        'mediaUrl': mediaUrl,
        'caption': _captionController.text,
        'mediaType': _mediaType,
        'timestamp': DateTime.now(),
        'expiresAt': DateTime.now().add(Duration(hours: 24)),
        'viewers': [],
      });

      // 🔥 DEDUCT 1 EMBER FOR STORY CREATION
      final result = await EmbersService.processEmbersTransaction(
        context: context,
        amount: -1,
        actionType: 'story_creation',
        referenceId: storyDocRef.id,
        insufficientFundsMessage: 'Need 1 Ember to create a story',
      );

      if (!result.success) {
        // If embers deduction failed, delete the story and show error
        await storyDocRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create story: ${result.message}')),
        );
        return;
      }

      await Future.delayed(Duration(milliseconds: 500));
      Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading story: $e')),
      );
    } finally {
      setState(() { _isUploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface, // Dark surface
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Create Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 16),
          
          if (_mediaFile != null) _buildMediaPreview(),
          if (_mediaFile != null) SizedBox(height: 16),
          
          if (_mediaFile != null)
            TextField(
              controller: _captionController,
              style: TextStyle(color: AppColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.elevation,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 2,
            ),
          
          if (_mediaFile != null) SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _pickMedia(ImageSource.camera),
                icon: Icon(Icons.camera_alt),
                label: Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.elevation,
                  foregroundColor: AppColors.primaryLavender,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _pickMedia(ImageSource.gallery),
                icon: Icon(Icons.photo_library),
                label: Text('Gallery'),
                 style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.elevation,
                  foregroundColor: AppColors.primaryLavender,
                ),
              ),
            ],
          ),
          
          if (_mediaFile != null) SizedBox(height: 16),
          
          if (_mediaFile != null)
            _isUploading
                ? CircularProgressIndicator(color: AppColors.primaryLavender)
                : ElevatedButton(
                    onPressed: () async {
                      // Check embers balance before uploading
                      final hasEnoughEmbers = await EmbersService.hasSufficientEmbers(1);
                      if (!hasEnoughEmbers) {
                        // This will trigger the EmbersService to show the snackbar
                        await EmbersService.processEmbersTransaction(
                          context: context,
                          amount: -1,
                          actionType: 'story_creation_check',
                          showSnackBar: true,
                        );
                        return;
                      }
                      
                      // If they have enough embers, proceed with upload
                      await _uploadStory();
                    },
                    child: Text('Share Story'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLavender,
                      foregroundColor: AppColors.backgroundDeep,
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _mediaType == 'image'
            ? Image.file(_mediaFile!, fit: BoxFit.cover)
            : Center(child: Icon(Icons.play_arrow, size: 50, color: Colors.white)),
      ),
    );
  }
}


// --- STORIES TAB ---
class StoriesTab extends StatefulWidget {
  @override
  _StoriesTabState createState() => _StoriesTabState();
}

class _StoriesTabState extends State<StoriesTab> {
  File? _pickedStory;
  bool _isUploading = false;
  String? _mediaType; // 'image' or 'video'

  Future<void> _pickStory() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _pickedStory = File(pickedFile.path);
        _mediaType = 'image'; 
      });
    }
  }

  Future<void> _takeStory() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _pickedStory = File(pickedFile.path);
        _mediaType = 'image'; 
      });
    }
  }

  Future<void> _uploadStory() async {
    if (_pickedStory == null || _mediaType == null) return;

    setState(() {
      _isUploading = true;
    });

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
      final username = userDoc['username'];
      final profileImage = userDoc['profileImage'];

      // Upload media to Firebase Storage
      String storyId = Uuid().v4();
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('stories')
          .child(currentUserId)
          .child('$storyId.${_mediaType == 'image' ? 'jpg' : 'mp4'}');
      await storageRef.putFile(_pickedStory!);
      String mediaUrl = await storageRef.getDownloadURL();

      // Add story to Firestore with expiration (e.g., 24 hours)
      await FirebaseFirestore.instance.collection('stories').add({
        'userId': currentUserId,
        'username': username,
        'profileImage': profileImage,
        'mediaUrl': mediaUrl,
        'mediaType': _mediaType,
        'timestamp': DateTime.now(),
        'expiresAt': DateTime.now().add(Duration(hours: 24)), 
        'viewers': [], 
      });

      setState(() {
        _pickedStory = null;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Story uploaded!')),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      print('Error uploading story: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading story: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Column(
      children: [
        // Upload Story Section
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 2,
            color: AppColors.surface, // Dark card
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Upload a Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  SizedBox(height: 10),
                  _isUploading
                      ? CircularProgressIndicator(color: AppColors.primaryLavender)
                      : _pickedStory != null
                          ? Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _mediaType == 'image'
                                      ? Image.file(_pickedStory!, height: 200, fit: BoxFit.cover)
                                      : Container(
                                          height: 200,
                                          color: Colors.black,
                                          child: Center(
                                            child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                                          ),
                                        ),
                                ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _uploadStory,
                                      child: Text('Upload'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLavender, foregroundColor: AppColors.backgroundDeep),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _pickedStory = null;
                                          _mediaType = null;
                                        });
                                      },
                                      child: Text('Cancel'),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: AppColors.backgroundDeep),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickStory,
                                  icon: Icon(Icons.photo_library),
                                  label: Text('Gallery'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.elevation, foregroundColor: AppColors.primaryLavender),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _takeStory,
                                  icon: Icon(Icons.camera_alt),
                                  label: Text('Camera'),
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.elevation, foregroundColor: AppColors.primaryLavender),
                                ),
                              ],
                            ),
                ],
              ),
            ),
          ),
        ),
        // View Stories Section
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stories')
                .where('expiresAt', isGreaterThan: DateTime.now())
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No stories available', style: TextStyle(color: AppColors.textMedium)));
              }

              // Group stories by user
              Map<String, List<DocumentSnapshot>> groupedStories = {};
              for (var doc in snapshot.data!.docs) {
                final userId = doc['userId'];
                if (!groupedStories.containsKey(userId)) {
                  groupedStories[userId] = [];
                }
                groupedStories[userId]!.add(doc);
              }

              return GridView.builder(
                padding: EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: groupedStories.length,
                itemBuilder: (context, index) {
                  final userId = groupedStories.keys.elementAt(index);
                  final userStories = groupedStories[userId]!;
                  final latestStory = userStories.first; 

                  bool isOwnStory = userId == currentUserId;
                  bool isSeen = userStories.every((story) => List.from(story['viewers']).contains(currentUserId));

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryViewerScreen(
                            userId: userId,
                            stories: userStories, 
                            username: latestStory['username'] ?? '', 
                            profileImage: latestStory['profileImage'] ?? '',
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        // Story Thumbnail
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              // Lavender for Own, Teal for Unseen, Grey for Seen
                              color: isOwnStory
                                  ? AppColors.primaryLavender
                                  : (isSeen ? AppColors.textDisabled : AppColors.secondaryTeal),
                              width: 2.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: latestStory['mediaType'] == 'image'
                                ? CachedNetworkImage(
                                    imageUrl: latestStory['mediaUrl'],
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    placeholder: (context, url) => Container(color: AppColors.elevation),
                                    errorWidget: (context, url, error) => Icon(Icons.error, color: AppColors.error),
                                  )
                                : Container(
                                    color: Colors.black,
                                    child: Center(
                                      child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
                                    ),
                                  ),
                          ),
                        ),
                        // User Info Overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                            ),
                            child: Text(
                              isOwnStory ? 'Your Story' : (latestStory['username'] ?? 'User'),
                              style: TextStyle(color: Colors.white, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- STORY VIEWER SCREEN ---
class StoryViewerScreen extends StatefulWidget {
  final String userId;
  final List<DocumentSnapshot> stories;
  final String username;
  final String profileImage;

  const StoryViewerScreen({
    Key? key,
    required this.userId,
    required this.stories,
    required this.username,
    required this.profileImage,
  }) : super(key: key);

  @override
  _StoryViewerScreenState createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  late Timer _timer;
  final Duration _storyDuration = Duration(seconds: 5);
  late bool _isOwnStory; 

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _isOwnStory = widget.userId == FirebaseAuth.instance.currentUser!.uid;
    _startTimer();
    if (!_isOwnStory) { 
      _markAsSeen();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(_storyDuration, (timer) {
      if (_currentIndex < widget.stories.length - 1) {
        _nextStory();
      } else {
        Navigator.pop(context); 
      }
    });
  }

  void _markAsSeen() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    for (var story in widget.stories) {
      final viewers = List.from(story['viewers'] ?? []); 
      if (!viewers.contains(currentUserId)) {
        try {
          await FirebaseFirestore.instance.collection('stories').doc(story.id).update({
            'viewers': FieldValue.arrayUnion([currentUserId])
          });
        } catch (e) {
          print("Error marking story as seen: $e");
        }
      }
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void _previousStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _pageController.previousPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

   @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stories.isEmpty || _currentIndex >= widget.stories.length) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("No stories to display", style: TextStyle(color: Colors.white))),
      );
    }

    final currentStory = widget.stories[_currentIndex];
    return GestureDetector(
      onTapDown: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        if (details.globalPosition.dx < screenWidth / 2) {
          _previousStory();
        } else {
          _nextStory();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black, // Full screen media is usually black bg
        body: Stack(
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              itemCount: widget.stories.length,
              physics: NeverScrollableScrollPhysics(), // Disable swipe to not interfere with tap logic
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                 if (index >= widget.stories.length) return Container();
                final story = widget.stories[index];
                return Stack(
                  children: [
                    // Media
                    Center(
                      child: story['mediaType'] == 'image'
                          ? CachedNetworkImage(
                              imageUrl: story['mediaUrl'],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              placeholder: (context, url) => Center(child: CircularProgressIndicator(color: Colors.white)),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(Icons.error, color: Colors.white),
                              ),
                            )
                          : Container(
                              color: Colors.black,
                              child: Center(
                                child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                              ),
                            ),
                    ),
                    // Caption overlay
                    if ((story['caption'] as String?)?.isNotEmpty == true)
                      Positioned(
                        bottom: 40,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: EdgeInsets.all(16),
                          color: Colors.black54,
                          child: Text(
                            story['caption'],
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            // Progress bars
            Positioned(
              top: 50,
              left: 10,
              right: 10,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                  int index = entry.key;
                  return Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Stack(
                        children: [
                          if (index == _currentIndex)
                            // Animated progress
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: _storyDuration,
                              builder: (context, value, child) {
                                return FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: value,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                );
                              },
                            )
                          else if (index < _currentIndex)
                            // Completed
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
             // User info and close button
            Positioned(
              top: 65,
              left: 16,
              right: 16, 
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: widget.profileImage.isNotEmpty
                            ? CachedNetworkImageProvider(widget.profileImage)
                            : AssetImage('assets/default_avatar.png') as ImageProvider,
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.username,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            timeago.format(currentStory['timestamp'].toDate()),
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
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