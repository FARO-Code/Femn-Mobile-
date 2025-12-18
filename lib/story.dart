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
import 'package:femn/embers_service.dart';

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
    // Don't need to show success snackbar here - EmbersService already shows one
    
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Create Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 16),
        
        if (_mediaFile != null) _buildMediaPreview(),
        if (_mediaFile != null) SizedBox(height: 16),
        
        if (_mediaFile != null)
          TextField(
            controller: _captionController,
            decoration: InputDecoration(
              hintText: 'Add a caption...',
              border: OutlineInputBorder(),
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
            ),
            ElevatedButton.icon(
              onPressed: () => _pickMedia(ImageSource.gallery),
              icon: Icon(Icons.photo_library),
              label: Text('Gallery'),
            ),
          ],
        ),
        
        if (_mediaFile != null) SizedBox(height: 16),
        
        if (_mediaFile != null)
          _isUploading
              ? CircularProgressIndicator()
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
      child: _mediaType == 'image'
          ? Image.file(_mediaFile!, fit: BoxFit.cover)
          : Icon(Icons.play_arrow, size: 50, color: Colors.white),
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
        _mediaType = 'image'; // Simplified to image for now
      });
    }
  }

  Future<void> _takeStory() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        _pickedStory = File(pickedFile.path);
        _mediaType = 'image'; // Simplified to image for now
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
        'expiresAt': DateTime.now().add(Duration(hours: 24)), // 24-hour expiry
        'viewers': [], // List of user IDs who viewed the story
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
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Upload a Story', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  _isUploading
                      ? CircularProgressIndicator()
                      : _pickedStory != null
                          ? Column(
                              children: [
                                _mediaType == 'image'
                                    ? Image.file(_pickedStory!, height: 200)
                                    : Container(
                                        height: 200,
                                        color: Colors.black,
                                        child: Center(
                                          child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                                        ),
                                      ),
                                SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: _uploadStory,
                                      child: Text('Upload'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() {
                                          _pickedStory = null;
                                          _mediaType = null;
                                        });
                                      },
                                      child: Text('Cancel'),
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
                                ),
                                ElevatedButton.icon(
                                  onPressed: _takeStory,
                                  icon: Icon(Icons.camera_alt),
                                  label: Text('Camera'),
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
                return Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No stories available'));
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
                  final latestStory = userStories.first; // Most recent story

                  bool isOwnStory = userId == currentUserId;
                  bool isSeen = userStories.every((story) => List.from(story['viewers']).contains(currentUserId));

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoryViewerScreen(
                            userId: userId,
                            stories: userStories, username: '', profileImage: '',
                            // Removed isOwnStory: isOwnStory,
                            // You might need to pass username and profileImage if they are required
                            // by the StoryViewerScreen constructor in your actual code.
                            // Check the constructor definition.
                            // Example (if needed):
                            // username: latestStory['username'], 
                            // profileImage: latestStory['profileImage'],
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
                              color: isOwnStory
                                  ? Colors.blue
                                  : (isSeen ? Colors.grey : Theme.of(context).colorScheme.secondary),
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: latestStory['mediaType'] == 'image'
                                ? CachedNetworkImage(
                                    imageUrl: latestStory['mediaUrl'],
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(color: Colors.grey[300]),
                                    errorWidget: (context, url, error) => Icon(Icons.error),
                                  )
                                : Container(
                                    color: Colors.black,
                                    child: Icon(Icons.play_arrow, color: Colors.white),
                                  ),
                          ),
                        ),
                        // User Info Overlay
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                            ),
                            child: Text(
                              isOwnStory ? 'Your Story' : latestStory['username'],
                              style: TextStyle(color: Colors.white, fontSize: 10),
                              overflow: TextOverflow.ellipsis,
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
// --- UPDATED STORY VIEWER SCREEN ---
// Ensure the class definition and constructor match the parameters you are passing
class StoryViewerScreen extends StatefulWidget {
  final String userId;
  final List<DocumentSnapshot> stories;
  final String username;
  final String profileImage;

  // Note: isOwnStory is removed from the constructor parameters
  // as it's not defined in the original constructor and causes an error.
  // We can calculate it inside the state if needed.

  const StoryViewerScreen({
    Key? key,
    required this.userId,
    required this.stories,
    required this.username,
    required this.profileImage,
    // required this.isOwnStory, // Removed this line causing the error
  }) : super(key: key);

  @override
  _StoryViewerScreenState createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  late Timer _timer;
  final Duration _storyDuration = Duration(seconds: 5);
  late bool _isOwnStory; // Add a variable to track if it's the current user's story

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Determine if these are the current user's own stories
    _isOwnStory = widget.userId == FirebaseAuth.instance.currentUser!.uid;
    _startTimer();
    if (!_isOwnStory) { // Only mark as seen if it's not the user's own story
      _markAsSeen();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(_storyDuration, (timer) {
      if (_currentIndex < widget.stories.length - 1) {
        _nextStory();
      } else {
        Navigator.pop(context); // Close screen after last story
      }
    });
  }

  void _markAsSeen() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    // No need to check _isOwnStory again here as it's checked in initState
    // Iterate through the stories passed to this screen instance
    for (var story in widget.stories) {
      final viewers = List.from(story['viewers'] ?? []); // Handle potential null
      if (!viewers.contains(currentUserId)) {
        try {
          await FirebaseFirestore.instance.collection('stories').doc(story.id).update({
            'viewers': FieldValue.arrayUnion([currentUserId])
          });
        } catch (e) {
          print("Error marking story as seen: $e");
          // Optionally handle error (e.g., show snackbar if critical)
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
    // Check bounds to prevent index errors
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
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Story content
            PageView.builder(
              controller: _pageController,
              itemCount: widget.stories.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                 if (index >= widget.stories.length) {
                   // Extra safety check for PageView itemBuilder
                   return Container(); // Return empty widget if index is out of bounds
                 }
                final story = widget.stories[index];
                return Stack(
                  children: [
                    // Media - Handle potential loading errors
                    Builder(
                      builder: (context) {
                        if (story['mediaType'] == 'image') {
                          return CachedNetworkImage(
                            imageUrl: story['mediaUrl'],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            placeholder: (context, url) => Center(child: CircularProgressIndicator(color: Colors.white)),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(Icons.error, color: Colors.white),
                            ),
                          );
                        } else {
                          // Placeholder for video or other types
                          return Container(
                            color: Colors.black,
                            child: Center(
                              child: Icon(Icons.play_arrow, color: Colors.white, size: 50),
                            ),
                          );
                        }
                      }
                    ),
                    // Caption - Check for null or empty
                    if ((story['caption'] as String?)?.isNotEmpty == true)
                      Positioned(
                        bottom: 100,
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
              top: 40,
              left: 16,
              right: 16,
              child: Row(
                children: widget.stories.asMap().entries.map((entry) {
                  int index = entry.key;
// Not directly used here, but available
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
                            // Animated progress for current story
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
                            // Completed stories
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          // Upcoming stories remain the background color (white30)
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
             // User info and close button row
            Positioned(
              top: 60,
              left: 16,
              right: 16, // Extend to the right to accommodate close button
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space between items
                children: [
                  // User info (left side)
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: widget.profileImage.isNotEmpty
                            ? CachedNetworkImageProvider(widget.profileImage)
                            : AssetImage('assets/default_avatar.png') as ImageProvider,
                        // Add error handling if needed for profile image
                      ),
                      SizedBox(width: 12),
                      Text(
                        widget.username,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 8),
                      Text(
                        timeago.format(currentStory['timestamp'].toDate()),
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  // Close button (right side)
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