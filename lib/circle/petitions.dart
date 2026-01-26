import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/customization/colors.dart';
import 'package:femn/customization/layout.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../feed/personalized_feed_service.dart'; // Import Service
import 'package:google_fonts/google_fonts.dart'; // <--- IMPORT COLORS
import '../services/notification_service.dart';

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
  final List<String> collaborators;
  final List<String> externalLinks;
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
    this.collaborators = const [],
    this.externalLinks = const [],
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
      discussionModerators: List<String>.from(
        data['discussionModerators'] ?? [],
      ),
      collaborators: List<String>.from(data['collaborators'] ?? []),
      externalLinks: List<String>.from(data['externalLinks'] ?? []),
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
      'signaturesWithComments': signaturesWithComments
          .map((sig) => sig.toMap())
          .toList(),
      'createdAt': createdAt,
      'deadline': deadline,
      'views': views,
      'shares': shares,
      'tags': tags,
      'isFeatured': isFeatured,
      'category': category,
      'discussionEnabled': discussionEnabled,
      'discussionModerators': discussionModerators,
      'collaborators': collaborators,
      'externalLinks': externalLinks,
      'discussionSettings': discussionSettings,
    };
  }

  bool get hasDeadline => deadline != null;
  bool get isExpired =>
      hasDeadline && deadline!.toDate().isBefore(DateTime.now());
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

  bool get hasReplies => false;
  int get totalReactions =>
      reactions.values.fold(0, (sum, userList) => sum + userList.length);

  List<String> getUserReactions(String userId) {
    return reactions.entries
        .where((entry) => entry.value.contains(userId))
        .map((entry) => entry.key)
        .toList();
  }
}

// Enhanced Petition Creation Screen
class EnhancedPetitionCreationScreen extends StatefulWidget {
  final Petition? existingPetition;
  const EnhancedPetitionCreationScreen({Key? key, this.existingPetition})
    : super(key: key);

  @override
  _EnhancedPetitionCreationScreenState createState() =>
      _EnhancedPetitionCreationScreenState();
}

class _EnhancedPetitionCreationScreenState
    extends State<EnhancedPetitionCreationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _fullStoryController = TextEditingController();
  final TextEditingController _goalController = TextEditingController(
    text: '100',
  );
  final TextEditingController _hashtagController = TextEditingController();
  String _selectedAgeRating = '13-17';
  String _selectedCategory = 'General';
  List<String> _hashtags = [];
  List<String> _tags = [];
  final List<String> _externalLinks = ['', '']; // Max 2 links
  final List<String> _collaborators = [];
  File? _bannerImage;
  String? _existingBannerUrl;
  DateTime? _deadline;
  bool _isLoading = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPetition != null) {
      _isEditing = true;
      _titleController.text = widget.existingPetition!.title;
      _descriptionController.text = widget.existingPetition!.description;
      _fullStoryController.text = widget.existingPetition!.fullStory;
      _goalController.text = widget.existingPetition!.goal.toString();
      _selectedAgeRating = widget.existingPetition!.ageRating;
      _selectedCategory = widget.existingPetition!.category;
      _hashtags = List<String>.from(widget.existingPetition!.hashtags);
      _collaborators.addAll(widget.existingPetition!.collaborators);
      _existingBannerUrl = widget.existingPetition!.bannerImageUrl;
      _deadline = widget.existingPetition!.deadline?.toDate();

      // Load links
      for (
        int i = 0;
        i < widget.existingPetition!.externalLinks.length && i < 2;
        i++
      ) {
        _externalLinks[i] = widget.existingPetition!.externalLinks[i];
      }
    }
  }

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
    'Other',
  ];

  Future<void> _pickBannerImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Banner',
            toolbarColor: AppColors.backgroundDeep,
            toolbarWidgetColor: AppColors.textHigh,
            activeControlsWidgetColor: AppColors.primaryLavender,
            backgroundColor: Colors.transparent,
            statusBarColor: AppColors.backgroundDeep,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Banner',
            aspectRatioLockEnabled: true,
            resetButtonHidden: false,
            rotateButtonsHidden: false,
            rotateClockwiseButtonHidden: false,
            aspectRatioPickerButtonHidden: true,
            hidesNavigationBar: false,
          ),
        ],
        aspectRatio: CropAspectRatio(
          ratioX: 9,
          ratioY: 16,
        ), // Consistent Vertical Crop
      );

      if (croppedFile != null) {
        setState(() {
          _bannerImage = File(croppedFile.path);
          _existingBannerUrl =
              null; // Preference local over existing during edit
        });
      }
    }
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryLavender,
              onPrimary: AppColors.backgroundDeep,
              surface: AppColors.surface,
              onSurface: AppColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
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
      final ref = _storage
          .ref()
          .child('petition_banners')
          .child('$petitionId.jpg');
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

    if (title.isEmpty ||
        description.isEmpty ||
        fullStory.isEmpty ||
        goalText.isEmpty ||
        (_bannerImage == null && _existingBannerUrl == null) ||
        currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Title, Description, Full Story, Goal, and Banner Image are mandatory.',
          ),
        ),
      );
      return;
    }

    // Validate links: Maximum 2, only GoFundMe, TikTok, Instagram
    List<String> validLinks = _externalLinks
        .where((l) => l.trim().isNotEmpty)
        .map((l) => l.trim())
        .toList();
    if (validLinks.length > 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 2 attachment links allowed.')),
      );
      return;
    }

    for (String link in validLinks) {
      bool isAllowed =
          link.contains('gofundme.com') ||
          link.contains('tiktok.com') ||
          link.contains('instagram.com');
      if (!isAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Allowed links: GoFundMe, TikTok, and Instagram only.',
            ),
          ),
        );
        return;
      }
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
      final petitionId = _isEditing ? widget.existingPetition!.id : Uuid().v4();
      String? bannerImageUrl = _existingBannerUrl;
      if (_bannerImage != null) {
        bannerImageUrl = await _uploadBannerImage(petitionId);
      }

      final petitionData = {
        'id': petitionId,
        'title': title,
        'description': description,
        'fullStory': fullStory,
        'goal': goal,
        'createdBy': _isEditing
            ? widget.existingPetition!.createdBy
            : currentUserId,
        'createdAt': _isEditing
            ? widget.existingPetition!.createdAt
            : FieldValue.serverTimestamp(),
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
        'bannerImageUrl': bannerImageUrl,
        'deadline': _deadline != null ? Timestamp.fromDate(_deadline!) : null,
        'category': _selectedCategory,
        'collaborators': _collaborators,
        'externalLinks': validLinks,
        'discussionModerators': _isEditing
            ? widget.existingPetition!.discussionModerators
            : [currentUserId],
      };

      if (_isEditing) {
        await _firestore
            .collection('petitions')
            .doc(petitionId)
            .update(petitionData);
      } else {
        petitionData['currentSignatures'] = 0;
        petitionData['signers'] = [];
        petitionData['signaturesWithComments'] = [];
        petitionData['views'] = 0;
        petitionData['shares'] = 0;
        petitionData['isFeatured'] = false;
        petitionData['discussionEnabled'] = true;
        await _firestore
            .collection('petitions')
            .doc(petitionId)
            .set(petitionData);

        // Send notifications to followers
        final userDoc = await _firestore
            .collection('users')
            .doc(currentUserId)
            .get();
        final username = userDoc.data()?['username'] ?? 'User';
        NotificationService().sendPetitionCreatedNotification(
          creatorId: currentUserId,
          creatorUsername: username,
          petitionId: petitionId,
          petitionTitle: title,
          bannerImageUrl: bannerImageUrl,
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              EnhancedPetitionDetailScreen(petitionId: petitionId),
        ),
      );
    } catch (e) {
      print("Error saving petition: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save petition. Please try again.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon, {
    bool isMandatory = false,
  }) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryLavender),
        ),
        SizedBox(width: 10),
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textHigh,
              ),
            ),
            if (isMandatory)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Petition' : 'Create Enhanced Petition',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textHigh,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Feather.flag,
                          color: AppColors.primaryLavender,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Start Your Movement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Fill in the details below to create your petition and make a difference!',
                      style: TextStyle(
                        color: AppColors.textMedium,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // Petition Title
              _buildSectionHeader(
                'Petition Title',
                Feather.type,
                isMandatory: true,
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
                ),
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                  decoration: InputDecoration(
                    labelText: 'What change do you want to see?',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(
                      Feather.edit_2,
                      color: AppColors.primaryLavender,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Short Description
              _buildSectionHeader(
                'Short Description',
                Feather.file_text,
                isMandatory: true,
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
                ),
                child: TextField(
                  controller: _descriptionController,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                  decoration: InputDecoration(
                    labelText: 'Brief description of your petition...',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.all(20),
                  ),
                  maxLines: 3,
                ),
              ),
              SizedBox(height: 20),
              // Full Story
              _buildSectionHeader(
                'Full Story',
                Feather.file_text,
                isMandatory: true,
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
                ),
                child: TextField(
                  controller: _fullStoryController,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                  decoration: InputDecoration(
                    labelText:
                        'Tell the complete story behind your petition...',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.all(20),
                  ),
                  maxLines: 6,
                ),
              ),
              SizedBox(height: 20),
              // Signature Goal
              _buildSectionHeader(
                'Signature Goal',
                Feather.users,
                isMandatory: true,
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
                ),
                child: TextField(
                  controller: _goalController,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                  decoration: InputDecoration(
                    labelText: 'How many signatures do you need?',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(
                      Feather.flag,
                      color: AppColors.primaryLavender,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(height: 20),
              // Category Selection
              _buildSectionHeader('Category', Feather.grid),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
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
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(
                      Feather.grid,
                      color: AppColors.primaryLavender,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                  dropdownColor: AppColors.surface,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                  iconEnabledColor: AppColors.primaryLavender,
                ),
              ),
              SizedBox(height: 20),
              // Deadline Selection
              _buildSectionHeader('Deadline', Feather.calendar),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.elevation,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLavender.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Feather.calendar,
                      color: AppColors.primaryLavender,
                    ),
                  ),
                  title: Text(
                    _deadline == null
                        ? 'Add Deadline (Optional)'
                        : 'Deadline: ${DateFormat('MMM d, yyyy').format(_deadline!)}',
                    style: TextStyle(
                      color: _deadline != null
                          ? AppColors.primaryLavender
                          : AppColors.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: _deadline != null
                      ? Text(
                          '${_deadline!.difference(DateTime.now()).inDays} days from now',
                          style: TextStyle(color: AppColors.textMedium),
                        )
                      : Text(
                          'Set an end date for your petition',
                          style: TextStyle(color: AppColors.textDisabled),
                        ),
                  trailing: ElevatedButton(
                    onPressed: _selectDeadline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLavender.withOpacity(
                        0.1,
                      ),
                      foregroundColor: AppColors.primaryLavender,
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
              _buildSectionHeader(
                'Banner Image',
                Feather.image,
                isMandatory: true,
              ),
              SizedBox(height: 8),
              if (_bannerImage != null || _existingBannerUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: _bannerImage != null
                        ? Image.file(
                            _bannerImage!,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : CachedNetworkImage(
                            imageUrl: _existingBannerUrl!,
                            height: 300,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.elevation,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLavender.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Feather.image,
                      color: AppColors.primaryLavender,
                    ),
                  ),
                  title: Text(
                    (_bannerImage != null || _existingBannerUrl != null)
                        ? 'Image Selected'
                        : 'Add Banner Image',
                    style: TextStyle(
                      color:
                          (_bannerImage != null || _existingBannerUrl != null)
                          ? AppColors.primaryLavender
                          : AppColors.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    'Make your petition visually appealing',
                    style: TextStyle(color: AppColors.textDisabled),
                  ),
                  trailing: ElevatedButton(
                    onPressed: _pickBannerImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLavender.withOpacity(
                        0.1,
                      ),
                      foregroundColor: AppColors.primaryLavender,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      (_bannerImage != null || _existingBannerUrl != null)
                          ? 'Change'
                          : 'Upload',
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Hashtags
              _buildSectionHeader('Hashtags', Feather.hash),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
                ),
                child: TextField(
                  controller: _hashtagController,
                  style: TextStyle(color: AppColors.textHigh),
                  decoration: InputDecoration(
                    labelText: 'Add relevant hashtags',
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(
                      Feather.hash,
                      color: AppColors.primaryLavender,
                    ),
                    suffixIcon: IconButton(
                      icon: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLavender,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Feather.plus,
                          color: AppColors.backgroundDeep,
                          size: 18,
                        ),
                      ),
                      onPressed: () {
                        String newTag = _hashtagController.text
                            .trim()
                            .replaceAll('#', '');
                        if (newTag.isNotEmpty && !_hashtags.contains(newTag)) {
                          setState(() {
                            _hashtags.add(newTag);
                          });
                          _hashtagController.clear();
                        }
                      },
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) {
                    String newTag = _hashtagController.text.trim().replaceAll(
                      '#',
                      '',
                    );
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
                        color: AppColors.secondaryTeal.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$tag',
                              style: TextStyle(
                                color: AppColors.secondaryTeal,
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
                              child: Icon(
                                Feather.x,
                                size: 16,
                                color: AppColors.secondaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              SizedBox(height: 20),
              // Age Rating
              _buildSectionHeader('Age Rating', Feather.users),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.elevation,
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
                    labelStyle: TextStyle(color: AppColors.textMedium),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(
                      Feather.users,
                      color: AppColors.primaryLavender,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  dropdownColor: AppColors.surface,
                  style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                  iconEnabledColor: AppColors.primaryLavender,
                ),
              ),
              SizedBox(height: 24),

              // External Links
              _buildSectionHeader('Support Links (Max 2)', Feather.link),
              SizedBox(height: 8),
              Text(
                'Add GoFundMe, TikTok, or Instagram links to support your cause.',
                style: TextStyle(color: AppColors.textMedium, fontSize: 12),
              ),
              SizedBox(height: 8),
              ...List.generate(
                2,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: AppColors.elevation,
                    ),
                    child: TextField(
                      onChanged: (v) => _externalLinks[index] = v,
                      style: TextStyle(color: AppColors.textHigh),
                      decoration: InputDecoration(
                        hintText: 'Link ${index + 1} (GoFundMe/Social)',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.elevation,
                        prefixIcon: Icon(
                          Feather.link,
                          color: AppColors.primaryLavender,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),
              // Collaborators Management
              _buildSectionHeader('Collaborators', Feather.user_plus),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: AppColors.elevation,
                ),
                child: TextField(
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty &&
                        !_collaborators.contains(v.trim())) {
                      setState(() {
                        _collaborators.add(v.trim());
                      });
                    }
                  },
                  style: TextStyle(color: AppColors.textHigh),
                  decoration: InputDecoration(
                    hintText: 'Add collaborator username',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: AppColors.elevation,
                    prefixIcon: Icon(
                      Feather.user_plus,
                      color: AppColors.primaryLavender,
                    ),
                  ),
                ),
              ),
              if (_collaborators.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Wrap(
                    spacing: 8,
                    children: _collaborators
                        .map(
                          (c) => Chip(
                            label: Text(
                              c,
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: AppColors.surface,
                            deleteIcon: Icon(
                              Feather.x,
                              size: 14,
                              color: AppColors.error,
                            ),
                            onDeleted: () =>
                                setState(() => _collaborators.remove(c)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),

              SizedBox(height: 30),
              // Create/Edit Petition Button
              Container(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEnhancedPetition,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLavender,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: AppColors.backgroundDeep,
                        )
                      : Text(
                          _isEditing
                              ? 'Save Changes'
                              : 'Create Enhanced Petition',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.backgroundDeep,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 20),
            ],
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
  _PetitionDiscussionScreenState createState() =>
      _PetitionDiscussionScreenState();
}

class _PetitionDiscussionScreenState extends State<PetitionDiscussionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late String _currentUserId;
  String? _currentUsername;
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
    _fetchCurrentUsername();
    _loadPetition();
    _loadMessages();
  }

  Future<void> _fetchCurrentUsername() async {
    final userDoc = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .get();
    if (userDoc.exists) {
      if (mounted) {
        setState(() {
          _currentUsername = userDoc.data()?['username'];
        });
      }
    }
  }

  Future<void> _loadPetition() async {
    try {
      final doc = await _firestore
          .collection('petitions')
          .doc(widget.petitionId)
          .get();
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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => DiscussionMessage.fromDocument(doc))
              .toList(),
        );
  }

  void _loadMessages() {
    setState(() {
      _isLoading = true;
    });

    _getMessagesStream().listen(
      (messages) {
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
      },
      onError: (error) {
        print("Error loading messages: $error");
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) return;
    if (!widget.isSigned && !widget.isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You must sign the petition to participate in discussion',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
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
        replyToText: _replyingTo != null
            ? (_replyingTo!.text.length > 50
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message')));
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
      final currentReactions = Map<String, List<String>>.from(
        message.reactions,
      );
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message deleted')));
    } catch (e) {
      print("Error deleting message: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message')));
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Message removed by moderator')));
    } catch (e) {
      print("Error in admin delete: $e");
    }
  }

  bool _isModerator() {
    if (_petition == null) return false;
    final currentUserId = _auth.currentUser?.uid;
    return widget.isCreator ||
        _petition!.createdBy == currentUserId ||
        _petition!.discussionModerators.contains(currentUserId) ||
        (_currentUsername != null &&
            _petition!.collaborators.contains(_currentUsername));
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
      backgroundColor: AppColors.surface,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moderator Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Feather.trash_2, color: AppColors.error),
                title: Text(
                  'Remove Message',
                  style: TextStyle(color: AppColors.textHigh),
                ),
                subtitle: Text(
                  'Remove this message from discussion',
                  style: TextStyle(color: AppColors.textMedium),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveReasonDialog(message.id);
                },
              ),
              if (_isModerator() &&
                  !_petition!.discussionModerators.contains(message.userId))
                ListTile(
                  leading: Icon(
                    Feather.shield,
                    color: AppColors.primaryLavender,
                  ),
                  title: Text(
                    'Make Moderator',
                    style: TextStyle(color: AppColors.textHigh),
                  ),
                  subtitle: Text(
                    'Grant moderator privileges to this user',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
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
          backgroundColor: AppColors.surface,
          title: Text(
            'Remove Message',
            style: TextStyle(color: AppColors.textHigh),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select removal reason:',
                style: TextStyle(color: AppColors.textMedium),
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: reason,
                dropdownColor: AppColors.surface,
                style: TextStyle(color: AppColors.textHigh),
                items: [
                  DropdownMenuItem(
                    value: 'inappropriate_content',
                    child: Text('Inappropriate Content'),
                  ),
                  DropdownMenuItem(value: 'spam', child: Text('Spam')),
                  DropdownMenuItem(
                    value: 'harassment',
                    child: Text('Harassment'),
                  ),
                  DropdownMenuItem(
                    value: 'off_topic',
                    child: Text('Off-topic'),
                  ),
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
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textMedium),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _adminDeleteMessage(messageId, reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.backgroundDeep,
              ),
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('User added as moderator')));
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
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isCurrentUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundImage: message.userProfileImage != null
                  ? CachedNetworkImageProvider(message.userProfileImage!)
                  : null,
              child: message.userProfileImage == null
                  ? Icon(Feather.user, size: 16)
                  : null,
              backgroundColor: AppColors.elevation,
            ),
            SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isCurrentUser) ...[
                  Row(
                    children: [
                      Text(
                        message.username,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMedium,
                        ),
                      ),
                      if (_petition?.discussionModerators.contains(
                            message.userId,
                          ) ??
                          false)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Feather.check_circle,
                            size: 12,
                            color: AppColors.primaryLavender,
                          ),
                        ),
                      if (message.userId == _petition?.createdBy)
                        Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Feather.flag,
                            size: 12,
                            color: AppColors.accentMustard,
                          ),
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
                      color: isCurrentUser
                          ? AppColors.secondaryTeal
                          : AppColors.elevation,
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
                              color: AppColors.backgroundDeep.withOpacity(0.3),
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
                                    color: AppColors.textMedium,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  message.replyToText ?? '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMedium,
                                  ),
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
                            color: message.isDeleted
                                ? AppColors.textDisabled
                                : (isCurrentUser
                                      ? Colors.white
                                      : AppColors.textHigh),
                            fontStyle: message.isDeleted
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                        // Reactions
                        if (message.reactions.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: message.reactions.entries.map((entry) {
                              return Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: userReactions.contains(entry.key)
                                      ? AppColors.primaryLavender.withOpacity(
                                          0.2,
                                        )
                                      : AppColors.backgroundDeep.withOpacity(
                                          0.5,
                                        ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(entry.key),
                                    SizedBox(width: 4),
                                    Text(
                                      entry.value.length.toString(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textHigh,
                                      ),
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
                  style: TextStyle(fontSize: 10, color: AppColors.textDisabled),
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
              child: message.userProfileImage == null
                  ? Icon(Feather.user, size: 16)
                  : null,
              backgroundColor: AppColors.elevation,
            ),
          ],
        ],
      ),
    );
  }

  void _showMessageOptions(DiscussionMessage message, bool isCurrentUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentUser)
                ListTile(
                  leading: Icon(
                    Feather.corner_up_left,
                    color: AppColors.primaryLavender,
                  ),
                  title: Text(
                    'Reply',
                    style: TextStyle(color: AppColors.textHigh),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startReply(message);
                  },
                ),
              if (isCurrentUser)
                ListTile(
                  leading: Icon(Feather.trash_2, color: AppColors.error),
                  title: Text(
                    'Delete Message',
                    style: TextStyle(color: AppColors.textHigh),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteMessage(message.id);
                  },
                ),
              if (_isModerator() && !isCurrentUser)
                ListTile(
                  leading: Icon(Feather.shield, color: AppColors.accentMustard),
                  title: Text(
                    'Moderator Actions',
                    style: TextStyle(color: AppColors.textHigh),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminActions(message);
                  },
                ),
              ListTile(
                leading: Icon(Feather.x_circle, color: AppColors.textMedium),
                title: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMedium),
                ),
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
          color: AppColors.surface,
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
                child: Text(emoji, style: TextStyle(fontSize: 24)),
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
      color: AppColors.elevation,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo!.username}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.primaryLavender,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  _replyingTo!.text.length > 50
                      ? '${_replyingTo!.text.substring(0, 50)}...'
                      : _replyingTo!.text,
                  style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Feather.x, size: 18, color: AppColors.textMedium),
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
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            'Discussion',
            style: TextStyle(color: AppColors.textHigh),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.primaryLavender),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Feather.lock, size: 64, color: AppColors.textDisabled),
              SizedBox(height: 16),
              Text(
                'Discussion Locked',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'You need to sign the petition to participate in the discussion',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMedium),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Back to Petition'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLavender,
                  foregroundColor: AppColors.backgroundDeep,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Discussion', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        actions: [
          if (_isModerator())
            IconButton(
              icon: Icon(Feather.shield, color: AppColors.primaryLavender),
              onPressed: () {
                // Show moderator tools
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Moderator tools - long press messages to manage',
                    ),
                  ),
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
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLavender,
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Feather.message_square,
                          size: 64,
                          color: AppColors.textDisabled,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textMedium,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(color: AppColors.textMedium),
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
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.elevation,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: TextStyle(color: AppColors.textHigh),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor:
                      _messageController.text.trim().isEmpty || _isSending
                      ? AppColors.textDisabled
                      : AppColors.primaryLavender,
                  child: IconButton(
                    icon: _isSending
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.backgroundDeep,
                            ),
                          )
                        : Icon(Feather.send, color: AppColors.backgroundDeep),
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
  const EnhancedPetitionDetailScreen({Key? key, required this.petitionId})
    : super(key: key);

  @override
  _EnhancedPetitionDetailScreenState createState() =>
      _EnhancedPetitionDetailScreenState();
}

class _EnhancedPetitionDetailScreenState
    extends State<EnhancedPetitionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PersonalizedFeedService _feedService = PersonalizedFeedService();

  late String _currentUserId;
  Petition? _petition;
  bool _isLoading = true;
  int _currentTab = 0;
  final TextEditingController _signatureCommentController =
      TextEditingController();
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
      final doc = await _firestore
          .collection('petitions')
          .doc(widget.petitionId)
          .get();
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
    // 1. Update Global Counter
    await _firestore.collection('petitions').doc(widget.petitionId).update({
      'views': FieldValue.increment(1),
    });

    // 2. Record Signal for Personalization & Funnel
    if (_currentUserId.isNotEmpty) {
      _feedService.recordInteraction(
        type: 'view',
        postId: widget.petitionId,
        authorId:
            _petition?.createdBy, // Might be null initially, but that's ok
        collection: 'petitions',
        source:
            'profile', // Assuming mostly accessed from profile for now, or pass via widget
      );
    }
  }

  Future<void> _signPetitionWithComment(String comment, bool isPublic) async {
    if (_isSigning || _petition == null) return;
    setState(() {
      _isSigning = true;
    });

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final signature = PetitionSignature(
        userId: _currentUserId,
        username: userData['username'] ?? 'User',
        profileImage: userData['profileImage'],
        comment: comment.isNotEmpty ? comment : null,
        signedAt: Timestamp.now(),
        isPublic: isPublic,
      );

      bool justReachedGoal = false;
      List<String> allSigners = [];

      await _firestore.runTransaction((transaction) async {
        final petitionDoc = await transaction.get(
          _firestore.collection('petitions').doc(widget.petitionId),
        );
        if (!petitionDoc.exists) throw Exception('Petition not found');

        allSigners = List<String>.from(petitionDoc['signers'] ?? []);
        if (allSigners.contains(_currentUserId)) {
          throw Exception('You have already signed this petition');
        }

        final int currentCount = petitionDoc['currentSignatures'] ?? 0;
        final int goal = petitionDoc['goal'] ?? 0;
        if (currentCount + 1 >= goal && currentCount < goal) {
          justReachedGoal = true;
        }

        allSigners.add(_currentUserId);

        transaction.update(
          _firestore.collection('petitions').doc(widget.petitionId),
          {
            'currentSignatures': FieldValue.increment(1),
            'signers': FieldValue.arrayUnion([_currentUserId]),
            'signaturesWithComments': FieldValue.arrayUnion([
              signature.toMap(),
            ]),
          },
        );
      });

      if (justReachedGoal && _petition != null) {
        NotificationService().sendPetitionGoalReachedNotification(
          petitionId: widget.petitionId,
          petitionTitle: _petition!.title,
          signerIds: allSigners,
          bannerImageUrl: _petition!.bannerImageUrl,
        );
      }

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to sign petition: $e')));
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
      backgroundColor: AppColors.surface,
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share Petition',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Feather.link, color: AppColors.primaryLavender),
                title: Text(
                  'Copy Link',
                  style: TextStyle(color: AppColors.textHigh),
                ),
                onTap: () {
                  _copyPetitionLink();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(
                  Feather.share_2,
                  color: AppColors.primaryLavender,
                ),
                title: Text(
                  'Share via...',
                  style: TextStyle(color: AppColors.textHigh),
                ),
                onTap: () {
                  _sharePetition();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(FontAwesome.whatsapp, color: Colors.green),
                title: Text(
                  'Share on WhatsApp',
                  style: TextStyle(color: AppColors.textHigh),
                ),
                onTap: () {
                  _shareOnWhatsApp();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Feather.camera, color: AppColors.primaryLavender),
                title: Text(
                  'Generate Shareable Image',
                  style: TextStyle(color: AppColors.textHigh),
                ),
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
    // final link = 'https://yourapp.com/petitions/${_petition!.id}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Link copied to clipboard')));
  }

  void _sharePetition() {
    if (_petition == null) return;
    final shareText =
        '''
📢 Check out this petition: "${_petition!.title}"
${_petition!.description}
${_petition!.currentSignatures} people have already signed! Help reach ${_petition!.goal} signatures.
#${_petition!.hashtags.isNotEmpty ? _petition!.hashtags.first : 'Petition'}
''';
    Share.share(shareText);

    // Increment Share
    _feedService.recordInteraction(
      type: 'share',
      postId: widget.petitionId,
      authorId: _petition?.createdBy,
      collection: 'petitions',
    );
  }

  Future<void> _shareOnWhatsApp() async {
    if (_petition == null) return;
    final shareText =
        'Check out this petition: "${_petition!.title}" - ${_petition!.description}';
    final url = 'https://wa.me/?text=${Uri.encodeComponent(shareText)}';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open WhatsApp')));
    }
  }

  void _generateShareableImage() {
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
          if (_petition!.bannerImageUrl != null &&
              _petition!.bannerImageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: _petition!.bannerImageUrl!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: AppColors.elevation,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryLavender,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: AppColors.elevation,
                  child: Icon(Feather.alert_circle, color: AppColors.error),
                ),
              ),
            ),
          SizedBox(height: 16),
          // Creator Info
          FutureBuilder<DocumentSnapshot>(
            future: _firestore
                .collection('users')
                .doc(_petition!.createdBy)
                .get(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final creator = snapshot.data!;
                final creatorData = creator.data() as Map<String, dynamic>;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: creatorData['profileImage'] != null
                        ? CachedNetworkImageProvider(
                            creatorData['profileImage'],
                          )
                        : null,
                    backgroundColor: AppColors.elevation,
                    child: creatorData['profileImage'] == null
                        ? Icon(Feather.user)
                        : null,
                  ),
                  title: Text(
                    creatorData['username'] ?? 'User',
                    style: TextStyle(color: AppColors.textHigh),
                  ),
                  subtitle: Text(
                    'Petition Creator',
                    style: TextStyle(color: AppColors.primaryLavender),
                  ),
                  onTap: () {
                    // Navigate to creator profile
                  },
                );
              }
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(Feather.user),
                  backgroundColor: AppColors.elevation,
                ),
                title: Text(
                  'Loading...',
                  style: TextStyle(color: AppColors.textHigh),
                ),
                subtitle: Text(
                  'Petition Creator',
                  style: TextStyle(color: AppColors.textMedium),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          Text(
            _petition!.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _petition!.description,
            style: TextStyle(fontSize: 16, color: AppColors.textMedium),
          ),
          SizedBox(height: 16),
          Text(
            'Full Story',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _petition!.fullStory,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppColors.textHigh,
            ),
          ),
          if (_petition!.externalLinks.isNotEmpty) ...[
            SizedBox(height: 24),
            Text(
              'Support & More Info',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 8),
            ..._petition!.externalLinks.map((link) {
              IconData icon = Feather.link;
              if (link.contains('gofundme.com')) icon = Feather.heart;
              if (link.contains('tiktok.com'))
                icon = FontAwesome.music; // Closest for TikTok
              if (link.contains('instagram.com')) icon = FontAwesome.instagram;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.elevation,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(icon, color: AppColors.primaryLavender),
                    title: Text(
                      link,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primaryLavender,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () async {
                      final uri = Uri.parse(link);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
              );
            }).toList(),
          ],
          SizedBox(height: 32),
          Text(
            'Updates & Announcements',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('petitions')
                .doc(_petition!.id)
                .collection('announcements')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLavender,
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.elevation,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: AppColors.surface, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      'No official updates yet.',
                      style: TextStyle(
                        color: AppColors.textDisabled,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: snapshot.data!.docs
                    .map((doc) => _buildAnnouncementCard(doc))
                    .toList(),
              );
            },
          ),
          SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = data['timestamp'] as Timestamp?;
    final dateStr = timestamp != null
        ? DateFormat('MMM d, yyyy • HH:mm').format(timestamp.toDate())
        : 'Recently';

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLavender.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLavender.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Feather.volume_2,
                  color: AppColors.primaryLavender,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Text(
                'OFFICIAL UPDATE',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLavender,
                  letterSpacing: 1.2,
                ),
              ),
              Spacer(),
              Text(
                dateStr,
                style: TextStyle(fontSize: 10, color: AppColors.textDisabled),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            data['title'] ?? 'Update',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textHigh,
            ),
          ),
          SizedBox(height: 8),
          Text(
            data['body'] ?? '',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textMedium,
            ),
          ),
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
            Icon(
              Feather.message_circle,
              size: 64,
              color: AppColors.textDisabled,
            ),
            SizedBox(height: 16),
            Text(
              'No comments yet',
              style: TextStyle(fontSize: 18, color: AppColors.textMedium),
            ),
            SizedBox(height: 8),
            Text(
              'Be the first to leave a comment when signing!',
              style: TextStyle(color: AppColors.textDisabled),
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
          color: AppColors.surface,
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
                      backgroundColor: AppColors.elevation,
                      backgroundImage: signature.profileImage != null
                          ? CachedNetworkImageProvider(signature.profileImage!)
                          : null,
                      child: signature.profileImage == null
                          ? Icon(Feather.user, color: AppColors.textMedium)
                          : null,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            signature.username,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh,
                            ),
                          ),
                          Text(
                            'Signed ${DateFormat('MMM d, yyyy').format(signature.signedAt.toDate())}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textDisabled,
                            ),
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
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColors.textHigh,
                    ),
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
          backgroundColor: isSelected
              ? AppColors.primaryLavender.withOpacity(0.1)
              : Colors.transparent,
          shape: RoundedRectangleBorder(),
          padding: EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? AppColors.primaryLavender
                : AppColors.textMedium,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _openSignatureDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Sign Petition',
              style: TextStyle(
                color: AppColors.textHigh,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Show your support for this movement by adding your signature.',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: _signatureIsPublic,
                        activeColor: AppColors.primaryLavender,
                        onChanged: (value) {
                          setState(() {
                            _signatureIsPublic = value ?? true;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Make my signature public',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        this.setState(() {
                          _currentTab = 1; // Switch to Discussion tab
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.primaryLavender.withOpacity(
                          0.1,
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        Feather.message_square,
                        color: AppColors.primaryLavender,
                        size: 20,
                      ),
                      label: Text(
                        'Join the Discussion instead',
                        style: TextStyle(color: AppColors.primaryLavender),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMedium),
                ),
              ),
              ElevatedButton(
                onPressed: _isSigning
                    ? null
                    : () {
                        _signPetitionWithComment('', _signatureIsPublic);
                        Navigator.pop(context);
                      },
                child: _isSigning
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.backgroundDeep,
                        ),
                      )
                    : Text(
                        'Sign Petition',
                        style: TextStyle(color: AppColors.backgroundDeep),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLavender,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLavender),
        ),
      );
    }
    if (_petition == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: Center(
          child: Text(
            'Petition not found',
            style: TextStyle(color: AppColors.textHigh),
          ),
        ),
      );
    }

    final isSigned = _petition!.signers.contains(_currentUserId);
    final isCreator = _petition!.createdBy == _currentUserId;
    final isExpired = _petition!.isExpired;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Petition Details',
          style: TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Feather.share_2, color: AppColors.primaryLavender),
            onPressed: _showShareOptions,
          ),
          if (isCreator ||
              _petition!.collaborators.contains(_auth.currentUser?.displayName))
            IconButton(
              icon: Icon(Feather.edit_2, color: AppColors.primaryLavender),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EnhancedPetitionCreationScreen(
                      existingPetition: _petition,
                    ),
                  ),
                ).then((_) => _loadPetition());
              },
            ),
          if (isCreator) ...[
            IconButton(
              icon: Icon(Feather.grid, color: AppColors.primaryLavender),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PetitionManagementDashboard(petition: _petition!),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Feather.bar_chart_2, color: AppColors.primaryLavender),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PetitionAnalyticsScreen(petitionId: widget.petitionId),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Progress Header
          Container(
            padding: EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: _petition!.progress,
                  backgroundColor: AppColors.elevation,
                  color: AppColors.primaryLavender,
                  minHeight: 8,
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_petition!.currentSignatures} signatures',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textHigh,
                      ),
                    ),
                    Text(
                      'Goal: ${_petition!.goal}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textMedium,
                      ),
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
                        color: _petition!.isExpired
                            ? AppColors.error
                            : AppColors.secondaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Tabs
          Container(
            color: AppColors.backgroundDeep,
            child: Row(
              children: [
                _buildTabButton('Story', 0),
                _buildTabButton('Discussion', 1),
              ],
            ),
          ),
          // Tab Content
          Expanded(
            child: _currentTab == 0 ? _buildStoryTab() : _buildDiscussionTab(),
          ),
        ],
      ),
      // Sign Button
      bottomNavigationBar: !isSigned && !isExpired
          ? Container(
              padding: EdgeInsets.all(16),
              color: AppColors.backgroundDeep,
              child: ElevatedButton(
                onPressed: _openSignatureDialog,
                child: Text(
                  'Sign This Petition',
                  style: TextStyle(color: AppColors.backgroundDeep),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: AppColors.primaryLavender,
                  foregroundColor: AppColors.backgroundDeep,
                ),
              ),
            )
          : isSigned
          ? Container(
              padding: EdgeInsets.all(16),
              color: AppColors.backgroundDeep,
              child: Text(
                '✓ You have signed this petition',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.success,
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
  const PetitionAnalyticsScreen({Key? key, required this.petitionId})
    : super(key: key);

  @override
  _PetitionAnalyticsScreenState createState() =>
      _PetitionAnalyticsScreenState();
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
    final doc = await _firestore
        .collection('petitions')
        .doc(widget.petitionId)
        .get();
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
        SignatureDay(
          day: DateTime.now().subtract(Duration(days: 5)),
          count: 12,
        ),
        SignatureDay(day: DateTime.now().subtract(Duration(days: 4)), count: 8),
        SignatureDay(
          day: DateTime.now().subtract(Duration(days: 3)),
          count: 20,
        ),
        SignatureDay(
          day: DateTime.now().subtract(Duration(days: 2)),
          count: 15,
        ),
        SignatureDay(
          day: DateTime.now().subtract(Duration(days: 1)),
          count: 25,
        ),
        SignatureDay(
          day: DateTime.now(),
          count: _petition?.currentSignatures ?? 0,
        ),
      ];
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        color: AppColors.surface,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 30, color: AppColors.primaryLavender),
              SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
              Text(title, style: TextStyle(color: AppColors.textMedium)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignatureChart() {
    if (_signatureHistory.isEmpty) return Container();

    return Container(
      height: 250,
      padding: EdgeInsets.fromLTRB(10, 20, 20, 10),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.elevation, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < _signatureHistory.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('E').format(_signatureHistory[idx].day),
                        style: TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: AppColors.textDisabled,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.right,
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (_signatureHistory.length - 1).toDouble(),
          minY: 0,
          maxY:
              (_signatureHistory
                  .map((e) => e.count.toDouble())
                  .reduce((a, b) => a > b ? a : b) *
              1.2),
          lineBarsData: [
            LineChartBarData(
              spots: _signatureHistory
                  .asMap()
                  .entries
                  .map(
                    (e) => FlSpot(e.key.toDouble(), e.value.count.toDouble()),
                  )
                  .toList(),
              isCurved: true,
              gradient: LinearGradient(
                colors: [AppColors.primaryLavender, AppColors.secondaryTeal],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryLavender.withOpacity(0.3),
                    AppColors.primaryLavender.withOpacity(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEngagementMetrics() {
    if (_petition == null) return Container();
    final conversionRate = _petition!.views > 0
        ? (_petition!.currentSignatures / _petition!.views * 100)
        : 0;
    final avgDaily = _petition!.createdAt
        .toDate()
        .difference(DateTime.now())
        .inDays
        .abs();
    final avgDailySignatures = avgDaily > 0
        ? (_petition!.currentSignatures / avgDaily)
        : _petition!.currentSignatures.toDouble();
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMetricRow(
              'Conversion Rate',
              '${conversionRate.toStringAsFixed(1)}%',
            ),
            Divider(color: AppColors.elevation),
            _buildMetricRow(
              'Avg. Daily Signatures',
              '${avgDailySignatures.toStringAsFixed(1)}',
            ),
            Divider(color: AppColors.elevation),
            _buildMetricRow('Total Views', _petition!.views.toString()),
            Divider(color: AppColors.elevation),
            _buildMetricRow('Shares', _petition!.shares.toString()),
            Divider(color: AppColors.elevation),
            _buildMetricRow('Days Running', avgDaily.toString()),
            Divider(color: AppColors.elevation),
            _buildMetricRow(
              'Days Remaining',
              _petition!.daysLeft > 0
                  ? _petition!.daysLeft.toString()
                  : 'Ended',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemographicChart() {
    return Container(
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 50,
          sections: [
            PieChartSectionData(
              value: 45,
              color: AppColors.primaryLavender,
              title: '13-17',
              radius: 60,
              titleStyle: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              badgeWidget: Icon(Feather.book, color: Colors.white, size: 16),
              badgePositionPercentageOffset: 1.2,
            ),
            PieChartSectionData(
              value: 35,
              color: AppColors.secondaryTeal,
              title: '18-25',
              radius: 55,
              titleStyle: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              badgeWidget: Icon(
                Feather.briefcase,
                color: Colors.white,
                size: 16,
              ),
              badgePositionPercentageOffset: 1.2,
            ),
            PieChartSectionData(
              value: 20,
              color: AppColors.accentMustard,
              title: '26+',
              radius: 50,
              titleStyle: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              badgeWidget: Icon(Feather.home, color: Colors.white, size: 16),
              badgePositionPercentageOffset: 1.2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficSourceChart() {
    return Container(
      height: 200,
      padding: EdgeInsets.symmetric(vertical: 20),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const titles = ['Direct', 'Social', 'Search', 'Referral'];
                  if (value.toInt() < titles.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        titles[value.toInt()],
                        style: TextStyle(
                          color: AppColors.textDisabled,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: 40,
                  color: AppColors.primaryLavender,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: 75,
                  color: AppColors.secondaryTeal,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
            BarChartGroupData(
              x: 2,
              barRods: [
                BarChartRodData(
                  toY: 55,
                  color: AppColors.accentMustard,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
            BarChartGroupData(
              x: 3,
              barRods: [
                BarChartRodData(
                  toY: 30,
                  color: AppColors.error,
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
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
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textHigh,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryLavender,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_petition == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: AppColors.backgroundDeep),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primaryLavender),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Petition Analytics',
          style: TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Insights',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 16),
            // Overview Cards
            Row(
              children: [
                _buildStatCard(
                  'Signatures',
                  _petition!.currentSignatures.toString(),
                  Feather.users,
                ),
                SizedBox(width: 12),
                _buildStatCard(
                  'Views',
                  _petition!.views.toString(),
                  Feather.eye,
                ),
                SizedBox(width: 12),
                _buildStatCard(
                  'Shares',
                  _petition!.shares.toString(),
                  Feather.share_2,
                ),
              ],
            ),
            SizedBox(height: 32),

            Text(
              'Signature Velocity',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildSignatureChart(),
              ),
            ),
            SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Age Demographic',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildDemographicChart(),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),

            Text(
              'Traffic Sources',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 16),
            Card(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildTrafficSourceChart(),
            ),
            SizedBox(height: 32),

            Text(
              'Detailed Engagement',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 16),
            _buildEngagementMetrics(),
            SizedBox(height: 40),
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
  _EnhancedPetitionsScreenState createState() =>
      _EnhancedPetitionsScreenState();
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Enhanced Petitions',
          style: TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('petitions')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const GridShimmerSkeleton();
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Feather.check_square,
                    size: 50,
                    color: AppColors.textDisabled,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No petitions yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Be the first to create a petition!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textDisabled),
                  ),
                ],
              ),
            );
          }
          final petitions = snapshot.data!.docs
              .map((doc) => Petition.fromDocument(doc))
              .toList();
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: ResponsiveLayout.getColumnCount(context),
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
            MaterialPageRoute(
              builder: (context) => EnhancedPetitionCreationScreen(),
            ),
          );
        },
        backgroundColor: AppColors.accentMustard,
        child: Icon(Feather.plus, color: AppColors.backgroundDeep),
      ),
    );
  }

  Widget _buildEnhancedPetitionCard(BuildContext context, Petition petition) {
    final bool isSigned = petition.signers.contains(_currentUserId);
    return Card(
      color: AppColors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  EnhancedPetitionDetailScreen(petitionId: petition.id),
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
              child:
                  petition.bannerImageUrl != null &&
                      petition.bannerImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: petition.bannerImageUrl!,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.elevation),
                      errorWidget: (context, url, error) =>
                          Icon(Feather.alert_circle, color: AppColors.error),
                    )
                  : Container(
                      height: 100,
                      color: AppColors.elevation,
                      child: Icon(
                        Feather.check_square,
                        color: AppColors.textDisabled,
                      ),
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
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SIGNED',
                            style: TextStyle(
                              color: AppColors.backgroundDeep,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (petition.hasDeadline && !isSigned)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: petition.isExpired
                                ? AppColors.error
                                : AppColors.secondaryTeal,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            petition.isExpired
                                ? 'ENDED'
                                : '${petition.daysLeft}d',
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textHigh,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  // Description
                  Text(
                    petition.description,
                    style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  // Progress Bar
                  LinearProgressIndicator(
                    value: petition.progress,
                    backgroundColor: AppColors.elevation,
                    color: AppColors.primaryLavender,
                  ),
                  SizedBox(height: 4),
                  // Signature Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${petition.currentSignatures}/${petition.goal}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMedium,
                        ),
                      ),
                      Text(
                        '${(petition.progress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryLavender,
                        ),
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
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textDisabled,
                        ),
                      ),
                      Text(
                        petition.ageRating,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textDisabled,
                        ),
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
void showEnhancedPetitionDetails(
  BuildContext context,
  Petition petition,
  bool isSigned,
) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) =>
          EnhancedPetitionDetailScreen(petitionId: petition.id),
    ),
  );
}

void showCreateEnhancedPetitionModal(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => EnhancedPetitionCreationScreen()),
  );
}

// ========== PETITION MANAGEMENT DASHBOARD ==========

class UserPetitionsDashboard extends StatefulWidget {
  const UserPetitionsDashboard({Key? key}) : super(key: key);

  @override
  _UserPetitionsDashboardState createState() => _UserPetitionsDashboardState();
}

class _UserPetitionsDashboardState extends State<UserPetitionsDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Petition> _myPetitions = [];

  @override
  void initState() {
    super.initState();
    _loadUserPetitions();
  }

  Future<void> _loadUserPetitions() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snapshot = await _firestore
          .collection('petitions')
          .where('createdBy', isEqualTo: uid)
          .get();

      final List<Petition> petitions = snapshot.docs
          .map((doc) => Petition.fromDocument(doc))
          .toList();

      // Also check if user is a collaborator (by username)
      final username = _auth.currentUser?.displayName;
      if (username != null) {
        final collabSnapshot = await _firestore
            .collection('petitions')
            .where('collaborators', arrayContains: username)
            .get();

        for (var doc in collabSnapshot.docs) {
          if (!petitions.any((p) => p.id == doc.id)) {
            petitions.add(Petition.fromDocument(doc));
          }
        }
      }

      setState(() {
        _myPetitions = petitions;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading user petitions: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalSigs = _myPetitions.fold(
      0,
      (sum, item) => sum + item.currentSignatures,
    );
    int totalViews = _myPetitions.fold(0, (sum, item) => sum + item.views);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Causes Management',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppColors.textHigh,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryLavender,
              ),
            )
          : _myPetitions.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadUserPetitions,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.all(20),
                    sliver: SliverToBoxAdapter(
                      child: _buildGlobalSummary(totalSigs, totalViews),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
                        'Your Petitions',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final petition = _myPetitions[index];
                        return _buildManagementItem(petition);
                      }, childCount: _myPetitions.length),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalSummary(int signatures, int views) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryLavender, AppColors.secondaryTeal],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLavender.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Global Performance',
            style: GoogleFonts.outfit(
              color: AppColors.backgroundDeep.withOpacity(0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildGlobalStatItem('Total Signatures', signatures.toString()),
              Container(
                width: 1,
                height: 40,
                color: AppColors.backgroundDeep.withOpacity(0.2),
              ),
              _buildGlobalStatItem('Total Reach', views.toString()),
              Container(
                width: 1,
                height: 40,
                color: AppColors.backgroundDeep.withOpacity(0.2),
              ),
              _buildGlobalStatItem(
                'Active Petitions',
                _myPetitions.length.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.backgroundDeep,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.backgroundDeep.withOpacity(0.6),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Feather.clipboard, size: 80, color: AppColors.elevation),
          SizedBox(height: 16),
          Text(
            'No petitions yet',
            style: TextStyle(
              color: AppColors.textMedium,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first petition to see it here.',
            style: TextStyle(color: AppColors.textDisabled),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EnhancedPetitionCreationScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLavender,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Create Petition',
              style: TextStyle(color: AppColors.backgroundDeep),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementItem(Petition petition) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.elevation, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PetitionManagementDashboard(petition: petition),
            ),
          ).then((_) => _loadUserPetitions());
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: petition.bannerImageUrl ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.elevation,
                        child: Icon(Feather.image),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          petition.title,
                          style: TextStyle(
                            color: AppColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${petition.currentSignatures} / ${petition.goal} signatures',
                          style: TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Feather.chevron_right,
                    size: 16,
                    color: AppColors.textDisabled,
                  ),
                ],
              ),
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: petition.progress,
                backgroundColor: AppColors.elevation,
                color: AppColors.primaryLavender,
                minHeight: 6,
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMiniStat(Feather.eye, '${petition.views}', 'Views'),
                  _buildMiniStat(
                    Feather.message_square,
                    'Active',
                    'Discussion',
                  ),
                  Text(
                    petition.isExpired ? 'Ended' : '${petition.daysLeft}d left',
                    style: TextStyle(
                      color: petition.isExpired
                          ? AppColors.error
                          : AppColors.secondaryTeal,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primaryLavender),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(color: AppColors.textDisabled, fontSize: 10),
        ),
      ],
    );
  }
}

// ========== PETITION MANAGEMENT DASHBOARD ==========
class PetitionManagementDashboard extends StatefulWidget {
  final Petition petition;
  const PetitionManagementDashboard({Key? key, required this.petition})
    : super(key: key);

  @override
  _PetitionManagementDashboardState createState() =>
      _PetitionManagementDashboardState();
}

class _PetitionManagementDashboardState
    extends State<PetitionManagementDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Petition _petition;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _petition = widget.petition;
  }

  void _editPetition() {
    // Show edit modal with current values
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditPetitionModal(
        petition: _petition,
        onUpdated: (updated) {
          setState(() {
            _petition = updated;
          });
        },
      ),
    );
  }

  void _addCollaborator() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Add Collaborator',
          style: TextStyle(color: AppColors.textHigh),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter username',
            hintStyle: TextStyle(color: AppColors.textDisabled),
            fillColor: AppColors.elevation,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          style: TextStyle(color: AppColors.textHigh),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newCollabs = List<String>.from(_petition.collaborators)
                  ..add(controller.text.trim());
                await _firestore
                    .collection('petitions')
                    .doc(_petition.id)
                    .update({'collaborators': newCollabs});
                setState(() {
                  _petition = Petition(
                    id: _petition.id,
                    title: _petition.title,
                    description: _petition.description,
                    fullStory: _petition.fullStory,
                    goal: _petition.goal,
                    currentSignatures: _petition.currentSignatures,
                    createdBy: _petition.createdBy,
                    bannerImageUrl: _petition.bannerImageUrl,
                    ageRating: _petition.ageRating,
                    hashtags: _petition.hashtags,
                    signers: _petition.signers,
                    signaturesWithComments: _petition.signaturesWithComments,
                    createdAt: _petition.createdAt,
                    deadline: _petition.deadline,
                    category: _petition.category,
                    collaborators: newCollabs,
                    externalLinks: _petition.externalLinks,
                  );
                });
                Navigator.pop(context);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Manage Petition',
          style: TextStyle(color: AppColors.textHigh),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Goal Progress',
                            style: TextStyle(color: AppColors.textMedium),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_petition.currentSignatures} / ${_petition.goal}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLavender.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${(_petition.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: AppColors.primaryLavender,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: _petition.progress,
                    backgroundColor: AppColors.elevation,
                    color: AppColors.primaryLavender,
                    minHeight: 10,
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),

            // Stats Grid
            Row(
              children: [
                _buildCompactStat('Views', '${_petition.views}', Feather.eye),
                SizedBox(width: 12),
                _buildCompactStat(
                  'Shares',
                  '${_petition.shares}',
                  Feather.share_2,
                ),
              ],
            ),
            SizedBox(height: 24),

            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 12),
            _buildActionItem(
              'Edit Petition Details',
              Feather.edit_2,
              _editPetition,
            ),
            _buildActionItem(
              'Manage Collaborators',
              Feather.user_plus,
              _addCollaborator,
            ),
            _buildActionItem(
              'View Detailed Analytics',
              Feather.bar_chart_2,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        PetitionAnalyticsScreen(petitionId: _petition.id),
                  ),
                );
              },
            ),
            _buildActionItem(
              'Post Official Announcement',
              Feather.volume_2,
              _sendAnnouncement,
            ),
            _buildActionItem(
              'Export Signature Data (CSV)',
              Feather.download,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Preparing data export... Check your email shortly.',
                    ),
                    backgroundColor: AppColors.secondaryTeal,
                  ),
                );
              },
            ),
            _buildActionItem('Promotion Insights', Feather.trending_up, () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Petition is currently trending in ${_petition.category}!',
                  ),
                ),
              );
            }),

            SizedBox(height: 24),
            Text(
              'Collaborators',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 12),
            if (_petition.collaborators.isEmpty)
              Text(
                'No collaborators added yet.',
                style: TextStyle(color: AppColors.textDisabled),
              )
            else
              Wrap(
                spacing: 8,
                children: _petition.collaborators
                    .map(
                      (c) => Chip(
                        label: Text(
                          c,
                          style: TextStyle(color: AppColors.textHigh),
                        ),
                        backgroundColor: AppColors.elevation,
                        onDeleted: () async {
                          final newCollabs = List<String>.from(
                            _petition.collaborators,
                          )..remove(c);
                          await _firestore
                              .collection('petitions')
                              .doc(_petition.id)
                              .update({'collaborators': newCollabs});
                          setState(() {
                            _petition = Petition(
                              id: _petition.id,
                              title: _petition.title,
                              description: _petition.description,
                              fullStory: _petition.fullStory,
                              goal: _petition.goal,
                              currentSignatures: _petition.currentSignatures,
                              createdBy: _petition.createdBy,
                              bannerImageUrl: _petition.bannerImageUrl,
                              ageRating: _petition.ageRating,
                              hashtags: _petition.hashtags,
                              signers: _petition.signers,
                              signaturesWithComments:
                                  _petition.signaturesWithComments,
                              createdAt: _petition.createdAt,
                              deadline: _petition.deadline,
                              category: _petition.category,
                              collaborators: newCollabs,
                              externalLinks: _petition.externalLinks,
                            );
                          });
                        },
                        deleteIcon: Icon(
                          Feather.x,
                          size: 16,
                          color: AppColors.error,
                        ),
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _sendAnnouncement() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.backgroundDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send Official Update',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'This will notify all signers and appear in the petition story.',
              style: TextStyle(color: AppColors.textDisabled),
            ),
            SizedBox(height: 20),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                hintText: 'Update Title',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: AppColors.textHigh),
            ),
            SizedBox(height: 12),
            TextField(
              controller: bodyController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Tell your supporters what\'s happening...',
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              style: TextStyle(color: AppColors.textHigh),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    bodyController.text.isNotEmpty) {
                  setState(() => _isLoading = true);
                  try {
                    await _firestore
                        .collection('petitions')
                        .doc(_petition.id)
                        .collection('announcements')
                        .add({
                          'title': titleController.text.trim(),
                          'body': bodyController.text.trim(),
                          'timestamp': FieldValue.serverTimestamp(),
                          'authorId': _auth.currentUser?.uid,
                        });

                    // Send notifications to all signers
                    NotificationService().sendPetitionUpdateNotification(
                      petitionId: _petition.id,
                      petitionTitle: _petition.title,
                      updateTitle: titleController.text.trim(),
                      signerIds: _petition.signers,
                      bannerImageUrl: _petition.bannerImageUrl,
                    );

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Announcement successfully posted!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to post announcement: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLavender,
                minimumSize: Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: AppColors.backgroundDeep)
                  : Text(
                      'POST ANNOUNCEMENT',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.backgroundDeep,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.elevation, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLavender.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryLavender, size: 20),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHigh,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textDisabled,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(String title, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevation.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surface, width: 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primaryLavender, size: 22),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Feather.chevron_right,
                size: 14,
                color: AppColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditPetitionModal extends StatefulWidget {
  final Petition petition;
  final Function(Petition) onUpdated;
  const _EditPetitionModal({required this.petition, required this.onUpdated});

  @override
  __EditPetitionModalState createState() => __EditPetitionModalState();
}

class __EditPetitionModalState extends State<_EditPetitionModal> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _storyController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.petition.title);
    _descController = TextEditingController(text: widget.petition.description);
    _storyController = TextEditingController(text: widget.petition.fullStory);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundDeep,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.all(
        20,
      ).copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Petition',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textHigh,
              ),
            ),
            SizedBox(height: 20),
            _buildEditField('Title', _titleController),
            _buildEditField('Description', _descController, maxLines: 2),
            _buildEditField('Full Story', _storyController, maxLines: 5),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      await FirebaseFirestore.instance
                          .collection('petitions')
                          .doc(widget.petition.id)
                          .update({
                            'title': _titleController.text,
                            'description': _descController.text,
                            'fullStory': _storyController.text,
                          });
                      widget.onUpdated(
                        Petition(
                          id: widget.petition.id,
                          title: _titleController.text,
                          description: _descController.text,
                          fullStory: _storyController.text,
                          goal: widget.petition.goal,
                          currentSignatures: widget.petition.currentSignatures,
                          createdBy: widget.petition.createdBy,
                          bannerImageUrl: widget.petition.bannerImageUrl,
                          ageRating: widget.petition.ageRating,
                          hashtags: widget.petition.hashtags,
                          signers: widget.petition.signers,
                          signaturesWithComments:
                              widget.petition.signaturesWithComments,
                          createdAt: widget.petition.createdAt,
                          deadline: widget.petition.deadline,
                          category: widget.petition.category,
                          collaborators: widget.petition.collaborators,
                          externalLinks: widget.petition.externalLinks,
                        ),
                      );
                      Navigator.pop(context);
                    },
              child: _isLoading
                  ? CircularProgressIndicator()
                  : Text('Save Changes'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: AppColors.primaryLavender,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMedium,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: AppColors.textHigh),
          decoration: InputDecoration(
            fillColor: AppColors.elevation,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
