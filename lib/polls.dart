import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:femn/colors.dart'; // <--- IMPORT COLORS
import 'groups.dart'; // Assuming GroupsScreen is defined here

// --- New Poll Creation Screen ---
class PollCreationScreen extends StatefulWidget {
  @override
  _PollCreationScreenState createState() => _PollCreationScreenState();
}

class _PollCreationScreenState extends State<PollCreationScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();
  
  final List<_PollOptionInput> _optionInputs = [
    _PollOptionInput(controller: TextEditingController(), image: null),
    _PollOptionInput(controller: TextEditingController(), image: null),
  ];
  
  List<String> _hashtags = [];
  String _selectedAgeRating = '13-17';
  String _selectedDuration = '7';
  
  final List<String> _ageRatings = ['13-17', '18-25', '26+'];
  final List<Map<String, String>> _durations = [
    {'value': '7', 'label': '1 Week'},
    {'value': '30', 'label': '1 Month'},
  ];
  
  bool _isLoading = false;
  late String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
  }

  // Helper method to upload option images
  Future<String?> _uploadOptionImage(File imageFile) async {
    try {
      final String fileName = 'poll_options/${Uuid().v4()}.jpg';
      final Reference ref = _storage.ref().child(fileName);
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading option image: $e");
      return null;
    }
  }

  Future<void> _createPoll() async {
    final String question = _questionController.text.trim();
    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Poll question is required')),
      );
      return;
    }

    // Validate options
    List<Map<String, dynamic>> optionsData = [];
    bool hasValidOption = false;
    for (var input in _optionInputs) {
      final String text = input.controller.text.trim();
      if (text.isNotEmpty) {
        hasValidOption = true;
        String? imageUrl;
        if (input.image != null) {
          imageUrl = await _uploadOptionImage(input.image!);
        }
        optionsData.add({'text': text, 'imageUrl': imageUrl});
      }
    }

    if (!hasValidOption || optionsData.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('At least two valid options are required')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String pollId = Uuid().v4();
      final FieldValue timestamp = FieldValue.serverTimestamp();

      final int durationDays = int.parse(_selectedDuration);
      final Timestamp expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(days: durationDays)),
      );

      final Map<String, dynamic> pollData = {
        'id': pollId,
        'question': question,
        'options': optionsData,
        'createdBy': _currentUserId,
        'createdAt': timestamp,
        'expiresAt': expiresAt,
        'totalVotes': 0,
        'voters': [],
        'ageRating': _selectedAgeRating,
        'hashtags': _hashtags,
        'type': 'poll',
      };

      await _firestore.collection('polls').doc(pollId).set(pollData);

      // Show success and navigate back to groups screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Poll created successfully!')),
      );

      // Navigate back to groups screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => GroupsScreen()),
      );

    } catch (e) {
      print("Error creating poll: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create poll. Please try again.')),
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
            color: AppColors.primaryLavender.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: AppColors.primaryLavender),
        ),
        SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textHigh,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionInputField(
    _PollOptionInput optionInput,
    int index,
    int totalOptions,
    Function(File?) onImagePicked,
    VoidCallback onRemove,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.elevation, // Darker input background
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: optionInput.controller,
                  style: TextStyle(color: AppColors.textHigh),
                  decoration: InputDecoration(
                    hintText: 'Option ${index + 1}',
                    hintStyle: TextStyle(color: AppColors.textDisabled),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Image Picker Button
              GestureDetector(
                onTap: () async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? pickedImage = 
                      await picker.pickImage(source: ImageSource.gallery);
                  if (pickedImage != null) {
                    onImagePicked(File(pickedImage.path));
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.textDisabled),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: optionInput.image != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.file(optionInput.image!, 
                              fit: BoxFit.cover))
                      : Icon(Icons.add_a_photo, 
                          size: 20, color: AppColors.textMedium),
                ),
              ),
            ],
          ),
          // Remove Button (only if more than 2 options)
          if (totalOptions > 2)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRemove,
                child: Text(
                  'Remove Option',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    backgroundColor: AppColors.backgroundDeep, // Deep background
    appBar: AppBar(
      title: Text(
        'Create New Poll',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textHigh,
        ),
      ),
      backgroundColor: AppColors.backgroundDeep,
      foregroundColor: AppColors.textHigh,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: AppColors.primaryLavender),
        // Navigate to GroupsScreen instead of popping
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => GroupsScreen()), 
          );
        },
      ),
    ),
      body: Container(
        // Subtle dark gradient background
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundDeep,
              Color(0xFF1A1620), // Slightly lighter dark
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
                    color: AppColors.surface, // Surface Card
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
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
                          Icon(Icons.poll, color: AppColors.primaryLavender, size: 24),
                          SizedBox(width: 10),
                          Text(
                            'Create Your Poll',
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
                        'Ask a question and let the community vote!',
                        style: TextStyle(
                          color: AppColors.textMedium,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Poll Question
                _buildSectionHeader('Poll Question', Icons.question_answer),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: AppColors.elevation,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _questionController,
                    style: TextStyle(color: AppColors.textHigh),
                    decoration: InputDecoration(
                      labelText: 'What would you like to ask?',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.elevation,
                      prefixIcon: Icon(Icons.edit, color: AppColors.primaryLavender),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    maxLines: 2,
                  ),
                ),
                SizedBox(height: 20),

                // Poll Options
                _buildSectionHeader('Poll Options', Icons.list),
                SizedBox(height: 8),
                Text(
                  'Add at least 2 options for people to vote on',
                  style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                ),
                SizedBox(height: 12),
                ...List.generate(_optionInputs.length, (index) {
                  return _buildOptionInputField(
                    _optionInputs[index],
                    index,
                    _optionInputs.length,
                    (File? newImage) {
                      setState(() {
                        _optionInputs[index].image = newImage;
                      });
                    },
                    () {
                      setState(() {
                        _optionInputs.removeAt(index);
                      });
                    },
                  );
                }),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryLavender, width: 1),
                  ),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _optionInputs.add(_PollOptionInput(
                            controller: TextEditingController(), image: null));
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: AppColors.primaryLavender, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Add Another Option',
                          style: TextStyle(color: AppColors.primaryLavender, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Duration Selection
                _buildSectionHeader('Poll Duration', Icons.timer),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: AppColors.elevation,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedDuration,
                    dropdownColor: AppColors.surface,
                    style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                    iconEnabledColor: AppColors.primaryLavender,
                    items: _durations.map((duration) {
                      return DropdownMenuItem<String>(
                        value: duration['value'],
                        child: Text(duration['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDuration = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'How long should the poll run?',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.elevation,
                      prefixIcon: Icon(Icons.schedule, color: AppColors.primaryLavender),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Age Rating
                _buildSectionHeader('Age Rating', Icons.people),
                SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: AppColors.elevation,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedAgeRating,
                    dropdownColor: AppColors.surface,
                    style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                    iconEnabledColor: AppColors.primaryLavender,
                    items: _ageRatings.map((rating) {
                      return DropdownMenuItem<String>(
                        value: rating,
                        child: Text(rating),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAgeRating = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Who should see this poll?',
                      labelStyle: TextStyle(color: AppColors.textMedium),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.elevation,
                      prefixIcon: Icon(Icons.people_outline, color: AppColors.primaryLavender),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20),
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
                    color: AppColors.elevation,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
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
                      prefixIcon: Icon(Icons.tag, color: AppColors.primaryLavender),
                      suffixIcon: IconButton(
                        icon: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLavender,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add, color: AppColors.backgroundDeep, size: 18),
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
                          color: AppColors.secondaryTeal.withOpacity(0.2), // Teal for tags
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
                                child: Icon(Icons.close, size: 16, color: AppColors.secondaryTeal),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                SizedBox(height: 30),

                // Create Poll Button
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryLavender.withOpacity(0.3),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createPoll,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 55),
                      backgroundColor: AppColors.primaryLavender,
                      foregroundColor: AppColors.backgroundDeep,
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
                              color: AppColors.backgroundDeep,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.poll, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Create Poll',
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

// Helper class to hold option text and image
class _PollOptionInput {
  final TextEditingController controller;
  File? image;

  _PollOptionInput({required this.controller, this.image});
}

// --- 2. Widget for Poll Card in the Grid ---
class PollCard extends StatefulWidget {
  final DocumentSnapshot pollSnapshot;
  final double cardMarginVertical;
  final double cardMarginHorizontal;
  final double cardInternalPadding;
  final double borderRadiusValue;

  const PollCard({
    Key? key,
    required this.pollSnapshot,
    required this.cardMarginVertical,
    required this.cardMarginHorizontal,
    required this.cardInternalPadding,
    required this.borderRadiusValue,
  }) : super(key: key);

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late Map<String, dynamic> _pollData;
  late String _currentUserId;
  String? _userVote; // Tracks the user's current vote

  @override
  void initState() {
    super.initState();
    _currentUserId = _auth.currentUser!.uid;
    _loadPollData();
  }

  void _loadPollData() {
    _pollData = widget.pollSnapshot.data() as Map<String, dynamic>;
    List<dynamic> voters = _pollData['voters'] ?? [];
    // Check if the current user has already voted
    for (var voteEntry in voters) {
      if (voteEntry is Map<String, dynamic> &&
          voteEntry['userId'] == _currentUserId) {
        _userVote = voteEntry['optionText']; // Store the option text they voted for
        break;
      }
    }
  }

  Future<void> _vote(String optionText) async {
    if (_userVote != null) return; // Prevent re-voting

    try {
      final DocumentReference pollRef =
          _firestore.collection('polls').doc(widget.pollSnapshot.id);

      // Update the main poll document
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(pollRef);
        if (!snapshot.exists) return;

        Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
        List<dynamic> voters = List.from(data['voters'] ?? []);
        int totalVotes = data['totalVotes'] ?? 0;

        // Add the user's vote to the list
        voters.add({'userId': _currentUserId, 'optionText': optionText});
        totalVotes += 1;

        transaction.update(pollRef, {
          'voters': voters,
          'totalVotes': totalVotes,
        });
      });

      // Fetch the updated poll data immediately after voting
      final DocumentSnapshot updatedSnapshot = await pollRef.get();
      if (updatedSnapshot.exists) {
        setState(() {
          _pollData = updatedSnapshot.data() as Map<String, dynamic>;
          _userVote = optionText; // Update local state
          
          // Update the voters list from the fresh data
          List<dynamic> voters = _pollData['voters'] ?? [];
          for (var voteEntry in voters) {
            if (voteEntry is Map<String, dynamic> &&
                voteEntry['userId'] == _currentUserId) {
              _userVote = voteEntry['optionText'];
              break;
            }
          }
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote recorded!')),
      );
    } catch (e) {
      print("Error voting: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to vote. Please try again.')),
      );
    }
  }

  Widget _buildVotingOption(
      String text, String? imageUrl, VoidCallback onTap, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Circular option indicator - thicker border when selected
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryLavender,
                  width: isSelected ? 3.0 : 1.5, // Thicker border when selected
                ),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) =>
                            const Icon(Icons.error, size: 16),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryLavender,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, // Thicker font when selected
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsOption(
      String text, String? imageUrl, double percentage, bool isUserVote) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          // Circular option indicator - thicker border for user's vote
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isUserVote ? AppColors.accentMustard : AppColors.primaryLavender, // Mustard highlight if user voted
                width: isUserVote ? 3.0 : 1.5,
              ),
            ),
            child: imageUrl != null && imageUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) =>
                          const Icon(Icons.error, size: 16),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textHigh,
                fontWeight: isUserVote ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryLavender,
              fontWeight: isUserVote ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final String question = _pollData['question'] ?? 'No question';
    final List<dynamic> optionsData = _pollData['options'] ?? [];
    final int totalVotes = _pollData['totalVotes'] ?? 0;
    // final String ageRating = _pollData['ageRating'] ?? '13-17';
    // final List<dynamic> hashtagsList = _pollData['hashtags'] ?? [];

    int? daysLeft;
    if (_pollData['expiresAt'] != null) {
      final Timestamp expiresAt = _pollData['expiresAt'];
      final DateTime now = DateTime.now();
      daysLeft = expiresAt.toDate().difference(now).inDays;
    }

    // Limit options to 6 for display
    List<dynamic> displayOptions =
        optionsData.length > 6 ? optionsData.take(6).toList() : optionsData;

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: widget.cardMarginVertical,
        horizontal: widget.cardMarginHorizontal,
      ),
      padding: EdgeInsets.all(widget.cardInternalPadding),
      decoration: BoxDecoration(
        color: AppColors.surface, // Surface card color
        borderRadius: BorderRadius.circular(widget.borderRadiusValue),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Title
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textHigh, // Off-white heading
            ),
          ),
          const SizedBox(height: 16),

          // Options
          ...displayOptions.asMap().entries.map((entry) {
            // int index = entry.key;
            dynamic option = entry.value;
            String optionText = option is Map<String, dynamic>
                ? (option['text'] ?? '')
                : option.toString();
            // String? optionImageUrl =
            //     option is Map<String, dynamic> ? option['imageUrl'] : null;

            int optionVoteCount = 0;
            if (_pollData['voters'] is List) {
              optionVoteCount = (_pollData['voters'] as List)
                  .where((vote) =>
                      vote is Map<String, dynamic> &&
                      vote['optionText'] == optionText)
                  .length;
            }

            double percentage =
                totalVotes > 0 ? (optionVoteCount / totalVotes) : 0;

            bool isUserVote = _userVote == optionText;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: InkWell(
                onTap: _userVote == null ? () => _vote(optionText) : null,
                borderRadius: BorderRadius.circular(30),
                splashColor: AppColors.primaryLavender.withOpacity(0.2),
                child: Stack(
                  children: [
                    // Background pill
                    Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.elevation, // Dark container for option
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    // Animated fill
                    if (_userVote != null)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: percentage),
                        duration: const Duration(milliseconds: 700),
                        builder: (context, value, child) {
                          return FractionallySizedBox(
                            widthFactor: value > 0 ? value : 0.001, // Avoid 0 width issues
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                color: isUserVote 
                                    ? AppColors.secondaryTeal // Active/Selected fill
                                    : AppColors.primaryLavender.withOpacity(0.5), // Other options fill
                              ),
                            ),
                          );
                        },
                      ),
                    // Option Text + Percent Badge
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              optionText,
                              style: TextStyle(
                                fontWeight: isUserVote ? FontWeight.bold : FontWeight.w500,
                                color: isUserVote ? Colors.white : AppColors.textHigh, // White text on Teal, High on Elevation
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_userVote != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(percentage * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 12),

          // Days left mini pill
          if (daysLeft != null && daysLeft >= 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accentMustard.withOpacity(0.8), // Mustard for alert
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 3,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$daysLeft days left',
                style: const TextStyle(
                  color: AppColors.backgroundDeep,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}