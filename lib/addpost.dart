import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/app.dart' hide ProfileScreen;
import 'package:femn/colors.dart';
import 'package:femn/profile.dart';
import 'package:femn/custom_camera_screen.dart'; // Import Custom Camera
import 'package:femn/custom_gallery_screen.dart'; // Import Custom Gallery
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:femn/embers_service.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
// import 'package:video_player/video_player.dart'; // Uncomment if you want actual video playback preview

class AddPostScreen extends StatefulWidget {
  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _mediaFile;
  String _mediaType = 'image'; // 'image' or 'video'
  bool _isUploading = false;

  // Constraints
  final int _maxFileSize = 15 * 1024 * 1024 * 1024; // 15 GB in bytes

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  // --- Navigation & File Handling ---

  Future<void> _openCustomGallery() async {
    // Navigate to the TikTok/Pinterest style gallery
    final File? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomGalleryScreen()),
    );

    if (result != null) {
      _processSelectedFile(result);
    }
  }

  Future<void> _openCustomCamera() async {
    // Navigate to the in-app camera (Photo/Video toggle)
    final File? result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CustomCameraScreen()),
    );

    if (result != null) {
      _processSelectedFile(result);
    }
  }

  void _processSelectedFile(File file) async {
    String type = _getFileType(file.path);
    
    // Validate File Size
    int sizeInBytes = await file.length();
    if (sizeInBytes > _maxFileSize) {
      _showError('File is too large. Max size is 15GB.');
      return;
    }

    // If valid, update state
    setState(() {
      _mediaFile = file;
      _mediaType = type;
    });
  }

  String _getFileType(String path) {
    String ext = path.split('.').last.toLowerCase();
    if (['mp4', 'mov', 'avi', 'mkv'].contains(ext)) return 'video';
    return 'image';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: AppColors.backgroundDeep)),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // --- Upload Logic ---

  Future<void> _uploadPost() async {
    if (_mediaFile == null) return;
    setState(() {
      _isUploading = true;
    });
    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String mediaId = Uuid().v4();
      String ext = _mediaFile!.path.split('.').last;
      
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(currentUserId)
          .child('$mediaId.$ext');

      print('Uploading file: ${_mediaFile!.path}');

      if (_mediaFile!.existsSync()) {
        await storageRef.putFile(_mediaFile!);
        String mediaUrl = await storageRef.getDownloadURL();

        DocumentReference postDocRef = await FirebaseFirestore.instance.collection('posts').add({
          'userId': currentUserId,
          'mediaUrl': mediaUrl,
          'caption': _captionController.text,
          'likes': [],
          'comments': 0,
          'timestamp': DateTime.now(),
          'mediaType': _mediaType,
        });

        // 🔥 ADD EMBERS FOR POST CREATION
        final result = await EmbersService.earnForPost(context, postDocRef.id);
        if (!result.success) {
          print('Failed to award Embers: ${result.message}');
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .update({
          'posts': FieldValue.increment(1),
        });

        _captionController.clear();
        setState(() {
          _mediaFile = null;
          _isUploading = false;
        });

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: currentUserId,
            ),
          ),
        );
      } else {
        setState(() => _isUploading = false);
        _showError('File does not exist. Please select a new file.');
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showError('Error uploading post: $e');
    }
  }

  // --- Widgets ---

  Widget _buildSplitCircleButton() {
    double size = 200.0;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Create Post",
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2
          ),
        ),
        SizedBox(height: 30),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 5),
              )
            ],
          ),
          child: ClipOval(
            child: Row(
              children: [
                // LEFT HALF: Upload (Opens Custom Gallery)
                Expanded(
                  child: Material(
                    color: AppColors.primaryLavender,
                    child: InkWell(
                      onTap: _openCustomGallery, 
                      child: Container(
                        height: double.infinity,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FeatherIcons.uploadCloud, color: AppColors.backgroundDeep, size: 32),
                            SizedBox(height: 8),
                            Text(
                              "Upload",
                              style: TextStyle(
                                color: AppColors.backgroundDeep,
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // RIGHT HALF: Capture (Opens Custom Camera)
                Expanded(
                  child: Material(
                    color: AppColors.elevation, 
                    child: InkWell(
                      onTap: _openCustomCamera,
                      child: Container(
                        height: double.infinity,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: AppColors.backgroundDeep, width: 1)
                          )
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FeatherIcons.camera, color: AppColors.primaryLavender, size: 32),
                            SizedBox(height: 8),
                            Text(
                              "Capture",
                              style: TextStyle(
                                color: AppColors.primaryLavender,
                                fontWeight: FontWeight.bold,
                                fontSize: 16
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          "Photos • Videos • GIFs",
          style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
        )
      ],
    );
  }

  Widget _buildUploadProgress() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryLavender)),
              SizedBox(height: 16),
              Text(
                'Uploading...',
                style: TextStyle(color: AppColors.textHigh, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _mediaType == 'image'
            ? Image.file(_mediaFile!, fit: BoxFit.contain)
            : Stack(
                alignment: Alignment.center,
                children: [
                  // Placeholder for Video - Use VideoPlayer package for real preview
                  Container(color: Colors.black),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FeatherIcons.video, color: Colors.white, size: 48),
                      SizedBox(height: 12),
                      Text(
                        "Video Selected",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCaptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: TextField(
        controller: _captionController,
        style: TextStyle(color: AppColors.textHigh, fontSize: 16),
        maxLines: null,
        decoration: InputDecoration(
          labelText: 'Add a caption...',
          labelStyle: TextStyle(color: AppColors.textMedium),
          filled: true,
          fillColor: AppColors.elevation,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primaryLavender, width: 1),
          ),
          prefixIcon: Icon(FeatherIcons.edit2, color: AppColors.textDisabled, size: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(FeatherIcons.arrowLeft, color: AppColors.primaryLavender),
          onPressed: () {
            if (_mediaFile != null) {
              setState(() {
                _mediaFile = null;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: _mediaFile != null 
          ? Text(
              'New Post',
              style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
            )
          : null,
        actions: [
          if (_mediaFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(FeatherIcons.check, color: AppColors.primaryLavender),
                onPressed: _isUploading ? null : _uploadPost,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                if (_mediaFile != null) ...[
                  _buildMediaPreview(),
                  _buildCaptionField(),
                ] else
                  Container(
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Center(
                      child: _buildSplitCircleButton(),
                    ),
                  ),
              ],
            ),
          ),
          if (_isUploading) _buildUploadProgress(),
        ],
      ),
    );
  }
}