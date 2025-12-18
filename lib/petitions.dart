import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// Colors
const Color primaryPink = Color(0xFFE56982);
const Color bgWhite = Color(0xFFFFE1E0);

final List<String> _ageRatings = ['13-17', '18-25', '26+'];

// Enhanced Petition Model with Comments, Analytics, and Discussion Settings
class Petition {
  final String id;
  final String title;
  final String description;
  final String fullStory;
  final int goal;
  final int currentSignatures;
  final String createdBy;
  final String? bannerImageUrl;
  final String ageRating;
  final List<String> hashtags;
  final List<String> signers;
  final List<PetitionSignature> signaturesWithComments;
  final Timestamp createdAt;
  final Timestamp? deadline;
  final int views;
  final int shares;
  final List<String> tags;
  final bool isFeatured;
  final String category;

  // Discussion settings
  final bool discussionEnabled;
  final List<String> discussionModerators;
  final Map<String, dynamic>? discussionSettings;

  Petition({
    required this.id,
    required this.title,
    required this.description,
    required this.fullStory,
    required this.goal,
    required this.currentSignatures,
    required this.createdBy,
    this.bannerImageUrl,
    required this.ageRating,
    required this.hashtags,
    required this.signers,
    required this.signaturesWithComments,
    required this.createdAt,
    this.deadline,
    this.views = 0,
    this.shares = 0,
    this.tags = const [],
    this.isFeatured = false,
    this.category = 'General',
    this.discussionEnabled = true,
    this.discussionModerators = const [],
    this.discussionSettings,
  });

  factory Petition.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<PetitionSignature> signatures = [];
    if (data['signaturesWithComments'] != null) {
      signatures = (data['signaturesWithComments'] as List)
          .map((sig) => PetitionSignature.fromMap(sig))
          .toList();
    }

    return Petition(
      id: data['id'] ?? doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      fullStory: data['fullStory'] ?? '',
      goal: data['goal'] ?? 0,
      currentSignatures: data['currentSignatures'] ?? 0,
      createdBy: data['createdBy'] ?? '',
      bannerImageUrl: data['bannerImageUrl'],
      ageRating: data['ageRating'] ?? '13-17',
      hashtags: List<String>.from(data['hashtags'] ?? []),
      signers: List<String>.from(data['signers'] ?? []),
      signaturesWithComments: signatures,
      createdAt: data['createdAt'] ?? Timestamp.now(),
      deadline: data['deadline'],
      views: data['views'] ?? 0,
      shares: data['shares'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      isFeatured: data['isFeatured'] ?? false,
      category: data['category'] ?? 'General',
      discussionEnabled: data['discussionEnabled'] ?? true,
      discussionModerators: List<String>.from(data['discussionModerators'] ?? []),
      discussionSettings: data['discussionSettings'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'fullStory': fullStory,
      'goal': goal,
      'currentSignatures': currentSignatures,
      'createdBy': createdBy,
      'bannerImageUrl': bannerImageUrl,
      'ageRating': ageRating,
      'hashtags': hashtags,
      'signers': signers,
      'signaturesWithComments': signaturesWithComments.map((sig) => sig.toMap()).toList(),
      'createdAt': createdAt,
      'deadline': deadline,
      'views': views,
      'shares': shares,
      'tags': tags,
      'isFeatured': isFeatured,
      'category': category,
      'discussionEnabled': discussionEnabled,
      'discussionModerators': discussionModerators,
      'discussionSettings': discussionSettings,
    };
  }

  bool get hasDeadline => deadline != null;
  bool get isExpired => hasDeadline && deadline!.toDate().isBefore(DateTime.now());
  int get daysLeft {
    if (!hasDeadline) return -1;
    final now = DateTime.now();
    final end = deadline!.toDate();
    final difference = end.difference(now).inDays;
    return difference >= 0 ? difference : 0;
  }
  double get progress => goal > 0 ? currentSignatures / goal : 0.0;
}

class PetitionSignature {
  final String userId;
  final String username;
  final String? profileImage;
  final String? comment;
  final Timestamp signedAt;
  final bool isPublic;

  PetitionSignature({
    required this.userId,
    required this.username,
    this.profileImage,
    this.comment,
    required this.signedAt,
    this.isPublic = true,
  });

  factory PetitionSignature.fromMap(Map<String, dynamic> data) {
    return PetitionSignature(
      userId: data['userId'],
      username: data['username'],
      profileImage: data['profileImage'],
      comment: data['comment'],
      signedAt: data['signedAt'],
      isPublic: data['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'profileImage': profileImage,
      'comment': comment,
      'signedAt': signedAt,
      'isPublic': isPublic,
    };
  }
}

// Discussion Message Model
class DiscussionMessage {
  final String id;
  final String petitionId;
  final String userId;
  final String username;
  final String? userProfileImage;
  final String text;
  final Timestamp timestamp;
  final String? replyToId;
  final String? replyToUsername;
  final String? replyToText;
  final Map<String, List<String>> reactions; // emoji -> list of user IDs
  final bool isDeleted;
  final String? deletedReason;

  DiscussionMessage({
    required this.id,
    required this.petitionId,
    required this.userId,
    required this.username,
    this.userProfileImage,
    required this.text,
    required this.timestamp,
    this.replyToId,
    this.replyToUsername,
    this.replyToText,
    this.reactions = const {},
    this.isDeleted = false,
    this.deletedReason,
  });

  factory DiscussionMessage.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, List<String>> reactions = {};
    if (data['reactions'] != null) {
      final reactionsMap = Map<String, dynamic>.from(data['reactions']);
      reactionsMap.forEach((key, value) {
        reactions[key] = List<String>.from(value);
      });
    }

    return DiscussionMessage(
      id: doc.id,
      petitionId: data['petitionId'],
      userId: data['userId'],
      username: data['username'],
      userProfileImage: data['userProfileImage'],
      text: data['text'],
      timestamp: data['timestamp'],
      replyToId: data['replyToId'],
      replyToUsername: data['replyToUsername'],
      replyToText: data['replyToText'],
      reactions: reactions,
      isDeleted: data['isDeleted'] ?? false,
      deletedReason: data['deletedReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'petitionId': petitionId,
      'userId': userId,
      'username': username,
      'userProfileImage': userProfileImage,
      'text': text,
      'timestamp': timestamp,
      'replyToId': replyToId,
      'replyToUsername': replyToUsername,
      'replyToText': replyToText,
      'reactions': reactions,
      'isDeleted': isDeleted,
      'deletedReason': deletedReason,
    };
  }

  bool get hasReplies => false; // You can implement threading later
  int get totalReactions => reactions.values.fold(0, (sum, userList) => sum + userList.length);

  List<String> getUserReactions(String userId) {
    return reactions.entries
        .where((entry) => entry.value.contains(userId))
        .map((entry) => entry.key)
        .toList();
  }
}

// Enhanced Petition Creation Screen
class EnhancedPetitionCreationScreen extends StatefulWidget {
  @override
  _EnhancedPetitionCreationScreenState createState() => _EnhancedPetitionCreationScreenState();
}

class _EnhancedPetitionCreationScreenState extends State<EnhancedPetitionCreationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _fullStoryController = TextEditingController();
  final TextEditingController _goalController = TextEditingController(text: '100');
  final TextEditingController _hashtagController = TextEditingController();
  String _selectedAgeRating = '13-17';
  String _selectedCategory = 'General';
  List<String> _hashtags = [];
  List<String> _tags = [];
  File? _bannerImage;
  DateTime? _deadline;
  bool _isLoading = false;

  final List<String> _categories = [
    'General',
    'Environment',
    'Human Rights',
    'Education',
    'Health',
    'Politics',
    'Animal Rights',
    'Social Justice',
    'Technology',
    'Other'
  ];

  Future<void> _pickBannerImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _bannerImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _deadline = picked;
      });
    }
  }

  Future<String?> _uploadBannerImage(String petitionId) async {
    if (_bannerImage == null) return null;
    try {
      final ref = _storage.ref().child('petition_banners').child('$petitionId.jpg');
      final uploadTask = ref.putFile(_bannerImage!);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading banner image: $e");
      return null;
    }
  }

  Future<void> _createEnhancedPetition() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final fullStory = _fullStoryController.text.trim();
    final goalText = _goalController.text.trim();
    final currentUserId = _auth.currentUser?.uid;

    if (title.isEmpty || description.isEmpty || goalText.isEmpty || currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Title, Description, and Goal are required.')),
      );
      return;
    }

    int goal;
    try {
      goal = int.parse(goalText);
      if (goal <= 0) throw FormatException("Goal must be positive");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goal must be a valid positive number.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final petitionId = Uuid().v4();
      final timestamp = FieldValue.serverTimestamp();
      String? bannerImageUrl;
      if (_bannerImage != null) {
        bannerImageUrl = await _uploadBannerImage(petitionId);
      }

      final petitionData = {
        'id': petitionId,
        'title': title,
        'description': description,
        'fullStory': fullStory,
        'goal': goal,
        'currentSignatures': 0,
        'createdBy': currentUserId,
        'createdAt': timestamp,
        'signers': [],
        'signaturesWithComments': [],
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
        'tags': _tags,
        'bannerImageUrl': bannerImageUrl,
        'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'views': 0,
        'shares': 0,
        'category': _selectedCategory,
        'isFeatured': false,
        'discussionEnabled': true,
        'discussionModerators': [currentUserId],
        'discussionSettings': null,
      };

      await _firestore.collection('petitions').doc(petitionId).set(petitionData);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EnhancedPetitionDetailScreen(petitionId: petitionId),
        ),
      );
    } catch (e) {
      print("Error creating petition: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create petition. Please try again.')),
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
            color: primaryPink.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: primaryPink),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B4E6B),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Create Enhanced Petition',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF0F5),
              Color(0xFFFFF9FB),
            ],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.1),
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
                          Icon(Icons.flag, color: primaryPink, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Start Your Movement',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8B4E6B),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Fill in the details below to create your petition and make a difference!',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Petition Title
                _buildSectionHeader('Petition Title', Icons.title),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'What change do you want to see?',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.edit, color: primaryPink),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 20),
                // Short Description
                _buildSectionHeader('Short Description', Icons.description),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Brief description of your petition...',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                      contentPadding: EdgeInsets.all(20),
                    ),
                    maxLines: 3,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 20),
                // Full Story
                _buildSectionHeader('Full Story', Icons.article),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _fullStoryController,
                    decoration: InputDecoration(
                      labelText: 'Tell the complete story behind your petition...',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                      contentPadding: EdgeInsets.all(20),
                    ),
                    maxLines: 6,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 20),
                // Signature Goal
                _buildSectionHeader('Signature Goal', Icons.people_alt),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _goalController,
                    decoration: InputDecoration(
                      labelText: 'How many signatures do you need?',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.flag, color: primaryPink),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 20),
                // Category Selection
                _buildSectionHeader('Category', Icons.category),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Select Category',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.category, color: primaryPink),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                    dropdownColor: Colors.white,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(height: 20),
                // Deadline Selection
                _buildSectionHeader('Deadline', Icons.calendar_today),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today, color: primaryPink),
                    ),
                    title: Text(
                      _deadline == null 
                          ? 'Add Deadline (Optional)' 
                          : 'Deadline: ${DateFormat('MMM d, yyyy').format(_deadline!)}',
                      style: TextStyle(
                        color: _deadline != null ? primaryPink : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: _deadline != null 
                        ? Text('${_deadline!.difference(DateTime.now()).inDays} days from now')
                        : Text('Set an end date for your petition'),
                    trailing: ElevatedButton(
                      onPressed: _selectDeadline,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink.withOpacity(0.1),
                        foregroundColor: primaryPink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(_deadline == null ? 'Add' : 'Change'),
                    ),
                    onTap: _selectDeadline,
                  ),
                ),
                SizedBox(height: 20),
                // Banner Image Upload
                _buildSectionHeader('Banner Image', Icons.image),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: primaryPink.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.photo_library, color: primaryPink),
                    ),
                    title: Text(
                      _bannerImage != null ? 'Image Selected' : 'Add Banner Image',
                      style: TextStyle(
                        color: _bannerImage != null ? primaryPink : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text('Make your petition visually appealing'),
                    trailing: ElevatedButton(
                      onPressed: _pickBannerImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryPink.withOpacity(0.1),
                        foregroundColor: primaryPink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Upload'),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                // Hashtags
                _buildSectionHeader('Hashtags', Icons.tag),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _hashtagController,
                    decoration: InputDecoration(
                      labelText: 'Add relevant hashtags',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.tag, color: primaryPink),
                      suffixIcon: IconButton(
                        icon: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primaryPink,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add, color: Colors.white, size: 18),
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
                            colors: [Color(0xFFFFE3ED), Color(0xFFFFF0F5)],
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
                                  color: Color(0xFF8B4E6B),
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
                                child: Icon(Icons.close, size: 16, color: Color(0xFF8B4E6B)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                SizedBox(height: 20),
                // Age Rating
                _buildSectionHeader('Age Rating', Icons.people),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.05),
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
                        child: Text(rating),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedAgeRating = value!;
                      });
                    },
                    decoration: InputDecoration(
                      labelText: 'Who should see this petition?',
                      labelStyle: TextStyle(color: Colors.grey[800]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.people_outline, color: primaryPink),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    dropdownColor: Colors.white,
                    style: TextStyle(fontSize: 16, color: Colors.black),
                    iconEnabledColor: primaryPink,
                  ),
                ),
                SizedBox(height: 30),
                // Create Petition Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPink.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createEnhancedPetition,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      backgroundColor: primaryPink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.create, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Create Enhanced Petition',
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
      ),
    );
  }
}

// Petition Discussion Screen (New Implementation)
class PetitionDiscussionScreen extends StatefulWidget {
  final String petitionId;
  final bool isSigned;
  final bool isCreator;

  const PetitionDiscussionScreen({
    Key? key,
    required this.petitionId,
    required this.isSigned,
    required this.isCreator,
  }) : super(key: key);

  @override
  _PetitionDiscussionScreenState createState() => _PetitionDiscussionScreenState();
}

class _PetitionDiscussionScreenState extends State<PetitionDiscussionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _currentUserId;
  Petition? _petition;
  List<DiscussionMessage> _messages = [];
  bool _isLoading = true;
  DiscussionMessage? _replyingTo;
  bool _isSending = false;

  // Available emojis for reactions
  final List<String> _availableReactions = ['❤️', '👍', '😢', '😄', '😡'];
  DiscussionMessage? _selectedMessageForReaction;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _loadPetition();
    _loadMessages();
  }

  Future<void> _loadPetition() async {
    try {
      final doc = await _firestore.collection('petitions').doc(widget.petitionId).get();
      if (doc.exists) {
        setState(() {
          _petition = Petition.fromDocument(doc);
        });
      }
    } catch (e) {
      print("Error loading petition: $e");
    }
  }

  Stream<List<DiscussionMessage>> _getMessagesStream() {
    return _firestore
        .collection('petition_discussions')
        .doc(widget.petitionId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DiscussionMessage.fromDocument(doc))
            .toList());
  }

  void _loadMessages() {
    setState(() {
      _isLoading = true;
    });

    _getMessagesStream().listen((messages) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      
      // Auto-scroll to bottom when new messages arrive
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }, onError: (error) {
      print("Error loading messages: $error");
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    if (!widget.isSigned && !widget.isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('You must sign the petition to participate in discussion')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>;

      final messageId = Uuid().v4();
      final message = DiscussionMessage(
        id: messageId,
        petitionId: widget.petitionId,
        userId: _currentUserId,
        username: userData['username'] ?? 'User',
        userProfileImage: userData['profileImage'],
        text: _messageController.text.trim(),
        timestamp: Timestamp.now(),
        replyToId: _replyingTo?.id,
        replyToUsername: _replyingTo?.username,
        replyToText: _replyingTo != null ? 
            (_replyingTo!.text.length > 50 
                ? '${_replyingTo!.text.substring(0, 50)}...' 
                : _replyingTo!.text) 
            : null,
      );

      await _firestore
          .collection('petition_discussions')
          .doc(widget.petitionId)
          .collection('messages')
          .doc(messageId)
          .set(message.toMap());

      _messageController.clear();
      _cancelReply();

    } catch (e) {
      print("Error sending message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  void _startReply(DiscussionMessage message) {
    setState(() {
      _replyingTo = message;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  Future<void> _toggleReaction(String messageId, String emoji) async {
    try {
      final messageRef = _firestore
          .collection('petition_discussions')
          .doc(widget.petitionId)
          .collection('messages')
          .doc(messageId);

      final messageDoc = await messageRef.get();
      if (!messageDoc.exists) return;

      final message = DiscussionMessage.fromDocument(messageDoc);
      final currentReactions = Map<String, List<String>>.from(message.reactions);
      final usersWhoReacted = currentReactions[emoji] ?? [];

      if (usersWhoReacted.contains(_currentUserId)) {
        // Remove reaction
        usersWhoReacted.remove(_currentUserId);
        if (usersWhoReacted.isEmpty) {
          currentReactions.remove(emoji);
        } else {
          currentReactions[emoji] = usersWhoReacted;
        }
      } else {
        // Add reaction
        usersWhoReacted.add(_currentUserId);
        currentReactions[emoji] = usersWhoReacted;
      }

      await messageRef.update({'reactions': currentReactions});
      _hideReactionMenu();

    } catch (e) {
      print("Error toggling reaction: $e");
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      final messageRef = _firestore
          .collection('petition_discussions')
          .doc(widget.petitionId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'isDeleted': true,
        'deletedReason': 'deleted_by_user',
        'text': '[Message deleted]',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message deleted')),
      );
    } catch (e) {
      print("Error deleting message: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete message')),
      );
    }
  }

  Future<void> _adminDeleteMessage(String messageId, String reason) async {
    if (!widget.isCreator && !_isModerator()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Only moderators can delete messages')),
      );
      return;
    }

    try {
      final messageRef = _firestore
          .collection('petition_discussions')
          .doc(widget.petitionId)
          .collection('messages')
          .doc(messageId);

      await messageRef.update({
        'isDeleted': true,
        'deletedReason': reason,
        'text': '[Message removed by moderator]',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message removed by moderator')),
      );
    } catch (e) {
      print("Error in admin delete: $e");
    }
  }

  bool _isModerator() {
    return widget.isCreator || 
           (_petition?.discussionModerators.contains(_currentUserId) ?? false);
  }

  void _showReactionMenu(DiscussionMessage message) {
    setState(() {
      _selectedMessageForReaction = message;
    });
  }

  void _hideReactionMenu() {
    setState(() {
      _selectedMessageForReaction = null;
    });
  }

  void _showAdminActions(DiscussionMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moderator Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Remove Message'),
                subtitle: Text('Remove this message from discussion'),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveReasonDialog(message.id);
                },
              ),
              if (_isModerator() && !_petition!.discussionModerators.contains(message.userId))
                ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: primaryPink),
                  title: Text('Make Moderator'),
                  subtitle: Text('Grant moderator privileges to this user'),
                  onTap: () {
                    Navigator.pop(context);
                    _makeModerator(message.userId);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showRemoveReasonDialog(String messageId) {
    showDialog(
      context: context,
      builder: (context) {
        String reason = 'inappropriate_content';
        return AlertDialog(
          title: Text('Remove Message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select removal reason:'),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: reason,
                items: [
                  DropdownMenuItem(value: 'inappropriate_content', child: Text('Inappropriate Content')),
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
                  DropdownMenuItem(value: 'off_topic', child: Text('Off-topic')),
                ],
                onChanged: (value) {
                  reason = value!;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _adminDeleteMessage(messageId, reason);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _makeModerator(String userId) async {
    try {
      await _firestore.collection('petitions').doc(widget.petitionId).update({
        'discussionModerators': FieldValue.arrayUnion([userId]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User added as moderator')),
      );
    } catch (e) {
      print("Error making moderator: $e");
    }
  }

  Widget _buildMessageBubble(DiscussionMessage message) {
    final isCurrentUser = message.userId == _currentUserId;
    final isModerator = _isModerator();
    final userReactions = message.getUserReactions(_currentUserId);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.userProfileImage != null
                  ? CachedNetworkImageProvider(message.userProfileImage!)
                  : null,
              child: message.userProfileImage == null ? Icon(Icons.person, size: 16) : null,
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser) ...[
                  Row(
                    children: [
                      Text(
                        message.username,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_petition?.discussionModerators.contains(message.userId) ?? false)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.verified, size: 12, color: primaryPink),
                        ),
                      if (message.userId == _petition?.createdBy)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.flag, size: 12, color: Colors.orange),
                        ),
                    ],
                  ),
                  SizedBox(height: 2),
                ],
                GestureDetector(
                  onLongPress: () {
                    if (isCurrentUser || isModerator) {
                      _showMessageOptions(message, isCurrentUser);
                    }
                  },
                  onTap: () {
                    if (!isCurrentUser) {
                      _showReactionMenu(message);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrentUser ? primaryPink.withOpacity(0.1) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview
                        if (message.replyToId != null)
                          Container(
                            padding: EdgeInsets.all(8),
                            margin: EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Replying to ${message.replyToUsername}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  message.replyToText ?? '',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        // Message text
                        Text(
                          message.isDeleted ? message.text : message.text,
                          style: TextStyle(
                            color: message.isDeleted ? Colors.grey : Colors.black87,
                            fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                        // Reactions
                        if (message.reactions.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: message.reactions.entries.map((entry) {
                              return Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: userReactions.contains(entry.key) 
                                      ? primaryPink.withOpacity(0.2)
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(entry.key),
                                    SizedBox(width: 4),
                                    Text(
                                      entry.value.length.toString(),
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(message.timestamp.toDate()),
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
          if (isCurrentUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundImage: message.userProfileImage != null
                  ? CachedNetworkImageProvider(message.userProfileImage!)
                  : null,
              child: message.userProfileImage == null ? Icon(Icons.person, size: 16) : null,
            ),
          ],
        ],
      ),
    );
  }

  void _showMessageOptions(DiscussionMessage message, bool isCurrentUser) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentUser)
                ListTile(
                  leading: Icon(Icons.reply, color: primaryPink),
                  title: Text('Reply'),
                  onTap: () {
                    Navigator.pop(context);
                    _startReply(message);
                  },
                ),
              if (isCurrentUser)
                ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Message'),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message.id);
                  },
                ),
              if (_isModerator() && !isCurrentUser)
                ListTile(
                  leading: Icon(Icons.admin_panel_settings, color: Colors.orange),
                  title: Text('Moderator Actions'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminActions(message);
                  },
                ),
              ListTile(
                leading: Icon(Icons.cancel, color: Colors.grey),
                title: Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionMenu() {
    if (_selectedMessageForReaction == null) return SizedBox.shrink();

    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _availableReactions.map((emoji) {
            return GestureDetector(
              onTap: () {
                _toggleReaction(_selectedMessageForReaction!.id, emoji);
              },
              child: Container(
                padding: EdgeInsets.all(8),
                child: Text(
                  emoji,
                  style: TextStyle(fontSize: 24),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo!.username}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  _replyingTo!.text.length > 50 
                      ? '${_replyingTo!.text.substring(0, 50)}...' 
                      : _replyingTo!.text,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18),
            onPressed: _cancelReply,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isSigned && !widget.isCreator) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Discussion'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Discussion Locked',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You need to sign the petition to participate in the discussion',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Back to Petition'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Discussion'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_isModerator())
            IconButton(
              icon: Icon(Icons.admin_panel_settings, color: primaryPink),
              onPressed: () {
                // Show moderator tools
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Moderator tools - long press messages to manage')),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          _buildReplyPreview(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.forum, size: 64, color: Colors.grey[300]),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.only(bottom: 80),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageBubble(_messages[index]);
                            },
                          ),
                          _buildReactionMenu(),
                        ],
                      ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _messageController.text.trim().isEmpty || _isSending
                      ? Colors.grey
                      : primaryPink,
                  child: IconButton(
                    icon: _isSending
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Enhanced Petition Detail Screen
class EnhancedPetitionDetailScreen extends StatefulWidget {
  final String petitionId;
  const EnhancedPetitionDetailScreen({Key? key, required this.petitionId}) : super(key: key);

  @override
  _EnhancedPetitionDetailScreenState createState() => _EnhancedPetitionDetailScreenState();
}

class _EnhancedPetitionDetailScreenState extends State<EnhancedPetitionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;
  Petition? _petition;
  bool _isLoading = true;
  int _currentTab = 0;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _signatureCommentController = TextEditingController();
  bool _showSignatureDialog = false;
  bool _isSigning = false;
  bool _signatureIsPublic = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _loadPetition();
    _incrementViews();
  }

  Future<void> _loadPetition() async {
    try {
      final doc = await _firestore.collection('petitions').doc(widget.petitionId).get();
      if (doc.exists) {
        setState(() {
          _petition = Petition.fromDocument(doc);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading petition: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _incrementViews() async {
    await _firestore.collection('petitions').doc(widget.petitionId).update({
      'views': FieldValue.increment(1),
    });
  }

  Future<void> _signPetitionWithComment(String comment, bool isPublic) async {
    if (_isSigning || _petition == null) return;
    setState(() {
      _isSigning = true;
    });

    try {
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final signature = PetitionSignature(
        userId: _currentUserId,
        username: userData['username'] ?? 'User',
        profileImage: userData['profileImage'],
        comment: comment.isNotEmpty ? comment : null,
        signedAt: Timestamp.now(),
        isPublic: isPublic,
      );

      await _firestore.runTransaction((transaction) async {
        final petitionDoc = await transaction.get(_firestore.collection('petitions').doc(widget.petitionId));
        if (!petitionDoc.exists) throw Exception('Petition not found');
        final currentSigners = List<String>.from(petitionDoc['signers'] ?? []);
        if (currentSigners.contains(_currentUserId)) {
          throw Exception('You have already signed this petition');
        }
        final currentSignaturesWithComments = List<Map<String, dynamic>>.from(petitionDoc['signaturesWithComments'] ?? []);
        transaction.update(_firestore.collection('petitions').doc(widget.petitionId), {
          'currentSignatures': FieldValue.increment(1),
          'signers': FieldValue.arrayUnion([_currentUserId]),
          'signaturesWithComments': FieldValue.arrayUnion([signature.toMap()]),
        });
      });

      await _loadPetition();
      setState(() {
        _showSignatureDialog = false;
        _signatureCommentController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for signing the petition!')),
      );
    } catch (e) {
      print("Error signing petition: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign petition: $e')),
      );
    } finally {
      setState(() {
        _isSigning = false;
      });
    }
  }

  void _showShareOptions() {
    if (_petition == null) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share Petition', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.link, color: primaryPink),
                title: Text('Copy Link'),
                onTap: () {
                  _copyPetitionLink();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: primaryPink),
                title: Text('Share via...'),
                onTap: () {
                  _sharePetition();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(FontAwesome.whatsapp, color: Colors.green),
                title: Text('Share on WhatsApp'),
                onTap: () {
                  _shareOnWhatsApp();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: primaryPink),
                title: Text('Generate Shareable Image'),
                onTap: () {
                  _generateShareableImage();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _copyPetitionLink() {
    final link = 'https://yourapp.com/petitions/${_petition!.id}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Link copied to clipboard')),
    );
  }

  void _sharePetition() {
    if (_petition == null) return;
    final shareText = '''
📢 Check out this petition: "${_petition!.title}"
${_petition!.description}
${_petition!.currentSignatures} people have already signed! Help reach ${_petition!.goal} signatures.
#${_petition!.hashtags.isNotEmpty ? _petition!.hashtags.first : 'Petition'}
''';
    Share.share(shareText);
    // Track the share
    _firestore.collection('petitions').doc(widget.petitionId).update({
      'shares': FieldValue.increment(1),
    });
  }

  Future<void> _shareOnWhatsApp() async {
    if (_petition == null) return;
    final shareText = 'Check out this petition: "${_petition!.title}" - ${_petition!.description}';
    final url = 'https://wa.me/?text=${Uri.encodeComponent(shareText)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  void _generateShareableImage() {
    // This would generate a shareable image with the petition details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Shareable image feature coming soon!')),
    );
  }

  Widget _buildStoryTab() {
    if (_petition == null) return Container();
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_petition!.bannerImageUrl != null && _petition!.bannerImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _petition!.bannerImageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: Icon(Icons.error),
                ),
              ),
            ),
          SizedBox(height: 16),
          // Creator Info
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(_petition!.createdBy).get(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final creator = snapshot.data!;
                final creatorData = creator.data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: creatorData['profileImage'] != null 
                        ? CachedNetworkImageProvider(creatorData['profileImage'])
                        : null,
                    child: creatorData['profileImage'] == null ? Icon(Icons.person) : null,
                  ),
                  title: Text(creatorData['username'] ?? 'User'),
                  subtitle: Text('Petition Creator'),
                  onTap: () {
                    // Navigate to creator profile
                  },
                );
              }
              return ListTile(
                leading: CircleAvatar(child: Icon(Icons.person)),
                title: Text('Loading...'),
                subtitle: Text('Petition Creator'),
              );
            },
          ),
          SizedBox(height: 16),
          Text(_petition!.title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(_petition!.description, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
          SizedBox(height: 16),
          Text('Full Story', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(_petition!.fullStory, style: TextStyle(fontSize: 16, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSignaturesTab() {
    if (_petition == null) return Container();
    final publicSignatures = _petition!.signaturesWithComments
        .where((sig) => sig.isPublic && sig.comment != null)
        .toList();
    if (publicSignatures.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.comment, size: 64, color: Colors.grey[300]),
            SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to leave a comment when signing!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: publicSignatures.length,
      itemBuilder: (context, index) {
        final signature = publicSignatures[index];
        return Card(
          margin: EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: signature.profileImage != null 
                          ? CachedNetworkImageProvider(signature.profileImage!)
                          : null,
                      child: signature.profileImage == null ? Icon(Icons.person) : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signature.username,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Signed ${DateFormat('MMM d, yyyy').format(signature.signedAt.toDate())}',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                if (signature.comment != null)
                  Text(
                    signature.comment!,
                    style: TextStyle(fontSize: 14, height: 1.4),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscussionTab() {
    if (_petition == null) return Container();
    return PetitionDiscussionScreen(
      petitionId: widget.petitionId,
      isSigned: _petition!.signers.contains(_currentUserId),
      isCreator: _petition!.createdBy == _currentUserId,
    );
  }

  Widget _buildTabButton(String text, int tabIndex) {
    final isSelected = _currentTab == tabIndex;
    return Expanded(
      child: TextButton(
        onPressed: () {
          setState(() {
            _currentTab = tabIndex;
          });
        },
        style: TextButton.styleFrom(
          backgroundColor: isSelected ? primaryPink.withOpacity(0.1) : Colors.transparent,
          shape: RoundedRectangleBorder(),
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? primaryPink : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showSignatureWithCommentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Sign Petition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add an optional comment to your signature:'),
                SizedBox(height: 12),
                TextField(
                  controller: _signatureCommentController,
                  decoration: InputDecoration(
                    hintText: 'Why are you signing this petition?',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _signatureIsPublic,
                      onChanged: (value) {
                        setState(() {
                          _signatureIsPublic = value ?? true;
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Make my signature and comment public',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isSigning ? null : () {
                _signPetitionWithComment(_signatureCommentController.text.trim(), _signatureIsPublic);
                Navigator.pop(context);
              },
              child: _isSigning 
                  ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Sign Petition'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryPink,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_petition == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('Petition not found')),
      );
    }

    final isSigned = _petition!.signers.contains(_currentUserId);
    final isCreator = _petition!.createdBy == _currentUserId;
    final isExpired = _petition!.isExpired;

    return Scaffold(
      appBar: AppBar(
        title: Text('Petition Details'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: primaryPink),
            onPressed: _showShareOptions,
          ),
          if (isCreator)
            IconButton(
              icon: Icon(Icons.analytics, color: primaryPink),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PetitionAnalyticsScreen(petitionId: widget.petitionId),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Progress Header
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _petition!.progress,
                  backgroundColor: Colors.grey[300],
                  color: primaryPink,
                  minHeight: 8,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_petition!.currentSignatures} signatures',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Goal: ${_petition!.goal}',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
                if (_petition!.hasDeadline)
                  Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      _petition!.isExpired 
                          ? 'This petition has ended'
                          : '${_petition!.daysLeft} days left',
                      style: TextStyle(
                        color: _petition!.isExpired ? Colors.red : primaryPink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: Colors.white,
            child: Row(
              children: [
                _buildTabButton('Story', 0),
                _buildTabButton('Comments', 1),
                _buildTabButton('Discussion', 2),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: _currentTab == 0 ? _buildStoryTab() :
            _currentTab == 1 ? _buildSignaturesTab() :
            _buildDiscussionTab(),
          ),
        ],
      ),
      // Sign Button
      bottomNavigationBar: !isSigned && !isExpired
          ? Container(
              padding: EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _showSignatureWithCommentDialog,
                child: Text('Sign This Petition'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: primaryPink,
                  foregroundColor: Colors.white,
                ),
              ),
            )
          : isSigned
            ? Container(
                padding: EdgeInsets.all(16),
                child: Text(
                  '✓ You have signed this petition',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              )
            : null,
    );
  }
}

// Petition Analytics Screen
class PetitionAnalyticsScreen extends StatefulWidget {
  final String petitionId;
  const PetitionAnalyticsScreen({Key? key, required this.petitionId}) : super(key: key);

  @override
  _PetitionAnalyticsScreenState createState() => _PetitionAnalyticsScreenState();
}

class _PetitionAnalyticsScreenState extends State<PetitionAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Petition? _petition;
  List<SignatureDay> _signatureHistory = [];

  @override
  void initState() {
    super.initState();
    _loadPetition();
    _loadSignatureHistory();
  }

  Future<void> _loadPetition() async {
    final doc = await _firestore.collection('petitions').doc(widget.petitionId).get();
    if (doc.exists) {
      setState(() {
        _petition = Petition.fromDocument(doc);
      });
    }
  }

  Future<void> _loadSignatureHistory() async {
    // Simulate signature history data
    setState(() {
      _signatureHistory = [
        SignatureDay(day: DateTime.now().subtract(Duration(days: 6)), count: 5),
        SignatureDay(day: DateTime.now().subtract(Duration(days: 5)), count: 12),
        SignatureDay(day: DateTime.now().subtract(Duration(days: 4)), count: 8),
        SignatureDay(day: DateTime.now().subtract(Duration(days: 3)), count: 20),
        SignatureDay(day: DateTime.now().subtract(Duration(days: 2)), count: 15),
        SignatureDay(day: DateTime.now().subtract(Duration(days: 1)), count: 25),
        SignatureDay(day: DateTime.now(), count: _petition?.currentSignatures ?? 0),
      ];
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 30, color: primaryPink),
              SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(title, style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureChart() {
    if (_signatureHistory.isEmpty) return Container();
    final maxCount = _signatureHistory.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    return Container(
      height: 200,
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: _signatureHistory.map((day) {
          final height = (day.count / maxCount) * 150;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(day.count.toString(), style: TextStyle(fontSize: 12)),
                SizedBox(height: 4),
                Container(
                  height: height,
                  margin: EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: primaryPink,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 4),
                Text(DateFormat('E').format(day.day), style: TextStyle(fontSize: 10)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEngagementMetrics() {
    if (_petition == null) return Container();
    final conversionRate = _petition!.views > 0 
        ? (_petition!.currentSignatures / _petition!.views * 100) 
        : 0;
    final avgDaily = _petition!.createdAt.toDate().difference(DateTime.now()).inDays.abs();
    final avgDailySignatures = avgDaily > 0 ? (_petition!.currentSignatures / avgDaily) : _petition!.currentSignatures.toDouble();
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow('Conversion Rate', '${conversionRate.toStringAsFixed(1)}%'),
            Divider(),
            _buildMetricRow('Avg. Daily Signatures', '${avgDailySignatures.toStringAsFixed(1)}'),
            Divider(),
            _buildMetricRow('Total Views', _petition!.views.toString()),
            Divider(),
            _buildMetricRow('Shares', _petition!.shares.toString()),
            Divider(),
            _buildMetricRow('Days Running', avgDaily.toString()),
            Divider(),
            _buildMetricRow('Days Remaining', _petition!.daysLeft > 0 ? _petition!.daysLeft.toString() : 'Ended'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: primaryPink)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_petition == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Petition Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Row(
              children: [
                _buildStatCard('Signatures', _petition!.currentSignatures.toString(), Icons.people),
                SizedBox(width: 16),
                _buildStatCard('Views', _petition!.views.toString(), Icons.visibility),
                SizedBox(width: 16),
                _buildStatCard('Shares', _petition!.shares.toString(), Icons.share),
              ],
            ),
            SizedBox(height: 24),
            // Progress towards goal
            Text('Progress Towards Goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: _petition!.progress,
              backgroundColor: Colors.grey[300],
              color: primaryPink,
              minHeight: 12,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(_petition!.progress * 100).toStringAsFixed(1)}% complete'),
                Text('${_petition!.currentSignatures}/${_petition!.goal} signatures'),
              ],
            ),
            SizedBox(height: 24),
            // Signature Growth Chart
            Text('Signature Growth (Last 7 Days)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Card(
              child: _buildSignatureChart(),
            ),
            SizedBox(height: 24),
            // Engagement Metrics
            Text('Engagement Metrics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            _buildEngagementMetrics(),
          ],
        ),
      ),
    );
  }
}

class SignatureDay {
  final DateTime day;
  final int count;
  SignatureDay({required this.day, required this.count});
}

// Enhanced Petitions Screen (Main List)
class EnhancedPetitionsScreen extends StatefulWidget {
  @override
  _EnhancedPetitionsScreenState createState() => _EnhancedPetitionsScreenState();
}

class _EnhancedPetitionsScreenState extends State<EnhancedPetitionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Petitions'),
        backgroundColor: primaryPink,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('petitions').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryPink));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.how_to_vote, size: 50, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No petitions yet', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Be the first to create a petition!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          final petitions = snapshot.data!.docs.map((doc) => Petition.fromDocument(doc)).toList();
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: petitions.length,
              itemBuilder: (context, index) {
                final petition = petitions[index];
                return _buildEnhancedPetitionCard(context, petition);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => EnhancedPetitionCreationScreen()),
          );
        },
        backgroundColor: primaryPink,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEnhancedPetitionCard(BuildContext context, Petition petition) {
    final bool isSigned = petition.signers.contains(_currentUserId);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EnhancedPetitionDetailScreen(petitionId: petition.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Image
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              child: petition.bannerImageUrl != null && petition.bannerImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: petition.bannerImageUrl!,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: Colors.grey[300]),
                      errorWidget: (context, url, error) => Icon(Icons.error),
                    )
                  : Container(
                      height: 100,
                      color: Colors.grey[300],
                      child: Icon(Icons.how_to_vote, color: Colors.grey[500]),
                    ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge for signed status or deadline
                  Row(
                    children: [
                      if (isSigned)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SIGNED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (petition.hasDeadline && !isSigned)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: petition.isExpired ? Colors.red : primaryPink,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            petition.isExpired ? 'ENDED' : '${petition.daysLeft}d',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 6),
                  // Title
                  Text(
                    petition.title.length > 35 
                        ? '${petition.title.substring(0, 35)}...' 
                        : petition.title,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Description
                  Text(
                    petition.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // Progress Bar
                  LinearProgressIndicator(
                    value: petition.progress,
                    backgroundColor: Colors.grey[300],
                    color: primaryPink,
                  ),
                  SizedBox(height: 4),
                  // Signature Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${petition.currentSignatures}/${petition.goal}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                      Text(
                        '${(petition.progress * 100).toInt()}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryPink),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  // Category and Age Rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        petition.category,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      Text(
                        petition.ageRating,
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
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

// Helper navigation functions
void showEnhancedPetitionDetails(BuildContext context, Petition petition, bool isSigned) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EnhancedPetitionDetailScreen(petitionId: petition.id),
    ),
  );
}

void showCreateEnhancedPetitionModal(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EnhancedPetitionCreationScreen(),
    ),
  );
}