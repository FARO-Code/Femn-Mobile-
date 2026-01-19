import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/services/embers_service.dart';
import 'package:femn/feed/feed_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

enum UploadStatus { idle, uploading, success, error }

class PostUploadService extends ChangeNotifier {
  static final PostUploadService instance = PostUploadService._();
  PostUploadService._();

  UploadStatus status = UploadStatus.idle;
  double progress = 0.0;
  String? errorMessage;
  
  // Data for the "Ghost" post
  File? currentFile;
  File? currentThumbnail;
  String? currentCaption;
  String? currentMediaType;
  String? currentLinkUrl; // ADDED: Store the link URL

  Future<void> startUpload({
    required File file,
    required String caption,
    required String mediaType,
    required BuildContext context, 
    String? linkUrl, // ADDED: Link URL parameter
  }) async {
    // 1. Set State (Triggers Ghost Post)
    status = UploadStatus.uploading;
    progress = 0.05;
    currentFile = file;
    currentCaption = caption;
    currentMediaType = mediaType;
    currentThumbnail = null;
    currentLinkUrl = linkUrl; // Store the link URL
    errorMessage = null;
    notifyListeners(); 

    // --- Generate Thumbnail Immediately for UI ---
    if (mediaType == 'video') {
      try {
        final tempDir = await getTemporaryDirectory();
        final String? thumbPath = await VideoThumbnail.thumbnailFile(
          video: file.path,
          thumbnailPath: tempDir.path,
          imageFormat: ImageFormat.JPEG,
          quality: 50,
        );
        if (thumbPath != null) {
          currentThumbnail = File(thumbPath);
          notifyListeners();
        }
      } catch (e) {
        print("Error generating preview thumbnail: $e");
      }
    }

    String? uploadedStoragePath;
    String mediaId = const Uuid().v4();

    try {
      String currentUserId = FirebaseAuth.instance.currentUser!.uid;
      String ext = file.path.split('.').last;

      // 2. Upload Media
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('posts')
          .child(currentUserId)
          .child('$mediaId.$ext');

      UploadTask task = storageRef.putFile(file);

      task.snapshotEvents.listen((TaskSnapshot snapshot) {
        progress = 0.1 + (0.5 * (snapshot.bytesTransferred / snapshot.totalBytes));
        notifyListeners();
      });

      await task;
      String mediaUrl = await storageRef.getDownloadURL();
      uploadedStoragePath = storageRef.fullPath;

      // 3. Upload Thumbnail (Reuse the one we generated if possible)
      String thumbnailUrl = '';
      if (mediaType == 'video') {
        File? thumbToUpload = currentThumbnail; 
        
        if (thumbToUpload == null) {
          final String? thumbPath = await VideoThumbnail.thumbnailFile(
            video: file.path,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            quality: 75,
          );
          if (thumbPath != null) thumbToUpload = File(thumbPath);
        }

        if (thumbToUpload != null) {
          Reference thumbRef = FirebaseStorage.instance.ref('posts/thumbnails/$mediaId.jpg');
          await thumbRef.putFile(thumbToUpload);
          thumbnailUrl = await thumbRef.getDownloadURL();
        }
      }

      progress = 0.7; 
      notifyListeners();

      // 4. AI Gatekeeper
      final feedService = FeedService();
      
      // Use the thumbnail for AI analysis if video (saves bandwidth)
      File fileToAnalyze = (mediaType == 'video' && currentThumbnail != null) 
          ? currentThumbnail! 
          : file;

      final aiData = await feedService.analyzeContent(
        caption: caption,
        mediaType: mediaType,
        file: fileToAnalyze,
      );

      progress = 0.9; 
      notifyListeners();

      // 5. Security Check
      if (aiData['isSafe'] == false) {
        throw Exception("Safety Block: ${aiData['moderationReason']}");
      }

      // 6. Tags & Mentions
      List<String> hashtags = [];
      RegExp exp = RegExp(r"\B#\w\w+");
      exp.allMatches(caption).forEach((match) {
        hashtags.add(match.group(0)!.substring(1));
      });

      List<String> mentions = [];
      RegExp mentionExp = RegExp(r"\B@\w+");
      mentionExp.allMatches(caption).forEach((match) {
        mentions.add(match.group(0)!.substring(1));
      });

      // 7. Save to Firestore
      DocumentReference postDocRef = await FirebaseFirestore.instance.collection('posts').add({
        'userId': currentUserId,
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'caption': caption,
        'likes': [],
        'comments': 0,
        'timestamp': DateTime.now(),
        'mediaType': mediaType,
        'hashtags': hashtags,
        'mentions': mentions,
        'category': aiData['category'],
        'smartTags': aiData['tags'],
        'visualDescription': aiData['visualDescription'],
        'qualityScore': aiData['qualityScore'],
        'embedding': aiData['embedding'],
        'linkUrl': linkUrl, // ADDED: Save link to Firestore
      });

      try {
         await EmbersService.earnForPost(context, postDocRef.id);
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({
        'posts': FieldValue.increment(1),
      });

      status = UploadStatus.success;
      progress = 1.0;
      notifyListeners();

      await Future.delayed(Duration(seconds: 2));
      _reset();

    } catch (e) {
      print("Upload Failed: $e");
      if (uploadedStoragePath != null) {
        try {
          await FirebaseStorage.instance.ref(uploadedStoragePath).delete();
        } catch (_) {}
      }
      status = UploadStatus.error;
      errorMessage = e.toString().replaceAll("Exception: ", "");
      notifyListeners();
    }
  }

  void consumeError() {
    _reset();
  }

  void _reset() {
    status = UploadStatus.idle;
    progress = 0.0;
    currentFile = null;
    currentThumbnail = null;
    currentCaption = null;
    currentMediaType = null;
    currentLinkUrl = null; // Reset link URL
    errorMessage = null;
    notifyListeners();
  }
}