import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/app.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:femn/embers_service.dart';

// Add Post Screen
class AddPostScreen extends StatefulWidget {
  @override
  _AddPostScreenState createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _mediaFile;
  String _mediaType = 'image';
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      if (file.existsSync()) {
        setState(() {
          _mediaFile = file;
          _mediaType = 'image';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected file does not exist.')),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      File file = File(pickedFile.path);
      if (file.existsSync()) {
        setState(() {
          _mediaFile = file;
          _mediaType = 'image';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Captured file does not exist.')),
        );
      }
    }
  }

  Future<void> _uploadPost() async {
    if (_mediaFile == null) return;
    setState(() {
      _isUploading = true;
    });
    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String mediaId = Uuid().v4();
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(currentUserId)
          .child('$mediaId.${_mediaType == 'image' ? 'jpg' : 'mp4'}');

      // Log the file path for debugging
      print('Uploading file: ${_mediaFile!.path}');

      if (_mediaFile!.existsSync()) {
        await storageRef.putFile(_mediaFile!);
        String mediaUrl = await storageRef.getDownloadURL();

        // ✅ STORE THE DOCUMENT REFERENCE IN A VARIABLE
        DocumentReference postDocRef = await FirebaseFirestore.instance.collection('posts').add({
          'userId': currentUserId,
          'mediaUrl': mediaUrl,
          'caption': _captionController.text,
          'likes': [],
          'comments': 0,
          'timestamp': DateTime.now(),
          'mediaType': _mediaType,
        });

        // 🔥 ADD EMBERS FOR POST CREATION - RIGHT HERE
        final result = await EmbersService.earnForPost(context, postDocRef.id);
        if (!result.success) {
          // Handle failure if needed, but snackbar already shown by EmbersService
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

        // Remove the old success message since EmbersService shows one
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Post uploaded successfully!')),
        // );

        // Navigate to profile screen after successful upload
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => ProfileScreen(
              userId: currentUserId,
            ),
          ),
          (route) => false,
        );
      } else {
        setState(() {
          _isUploading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File does not exist. Please select a new file.')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading post: $e')),
      );
    }
  }

  Widget _buildUploadProgress() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.pink)),
              SizedBox(height: 16),
              Text(
                'Uploading...',
                style: TextStyle(color: Colors.white, fontSize: 16),
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
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _mediaType == 'image'
            ? Image.file(_mediaFile!, fit: BoxFit.cover)
            : Container(), // For video, you'd use a video preview
      ),
    );
  }

  Widget _buildCaptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: TextField(
        controller: _captionController,
        decoration: InputDecoration(
          labelText: 'Add a caption...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        maxLines: null,
        style: TextStyle(fontSize: 16),
        onChanged: (value) {
          // You could add hashtag/mention detection here
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
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
        title: Text(
          'New Post',
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          if (_mediaFile != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: Icon(Icons.check, color: Colors.pink),
                onPressed: _isUploading ? null : _uploadPost,
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Make the whole column scrollable
          SingleChildScrollView(
            child: Column(
              children: [
                if (_mediaFile != null) _buildMediaPreview(),
                if (_mediaFile != null) _buildCaptionField(),
                if (_mediaFile == null)
                  Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library, size: 64, color: Colors.grey.shade400),
                          SizedBox(height: 16),
                          Text('Select a photo to share',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _pickMedia,
                            icon: Icon(Icons.photo_library),
                            label: Text('Choose from Library'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.pink.shade300,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            ),
                          ),
                          SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _takePhoto,
                            icon: Icon(Icons.camera_alt),
                            label: Text('Take Photo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.pink.shade300,
                              side: BorderSide(color: Colors.pink.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_mediaFile != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Row(
                      children: [
                      ],
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