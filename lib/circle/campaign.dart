import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/customization/colors.dart'; // <--- IMPORT YOUR COLORS FILE
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'petitions.dart'; // <--- ADD THIS


class CampaignsScreen extends StatefulWidget {
  @override
  _CampaignsScreenState createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> {
  final List<String> _tabs = ['Polls', 'Petitions', 'Events'];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Campaigns', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          bottom: TabBar(
            indicatorColor: AppColors.primaryLavender,
            labelColor: AppColors.primaryLavender,
            unselectedLabelColor: AppColors.textMedium,
            tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
          ),
        ),
        body: TabBarView(
          children: [
            PollsTab(),
            PetitionsTab(),
            EventsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showCreateBottomSheet(context);
          },
          child: Icon(Feather.plus, color: AppColors.backgroundDeep),
          backgroundColor: AppColors.accentMustard, // Mustard for FAB
        ),
      ),
    );
  }

  void _showCreateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Create New', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Feather.bar_chart_2, color: AppColors.primaryLavender),
                title: Text('Poll', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CreatePollScreen()));
                },
              ),
              ListTile(
                leading: Icon(Feather.file_text, color: AppColors.secondaryTeal),
                title: Text('Petition', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EnhancedPetitionCreationScreen()));
                },
              ),
              ListTile(
                leading: Icon(Feather.calendar, color: AppColors.accentMustard),
                title: Text('Event', style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.textHigh)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => CreateEventScreen()));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// Polls Tab with Voting
class PollsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('polls')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerList();
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading polls', style: TextStyle(color: AppColors.error)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No polls yet 👀', Feather.bar_chart_2);
        }
        
        final polls = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: polls.length,
          itemBuilder: (context, index) {
            final poll = polls[index];
            final hasVoted = user != null ? (poll['voters'] as List).contains(user.uid) : false;
            
            return _buildPollCard(poll, context, hasVoted);
          },
        );
      },
    );
  }

  Widget _buildPollCard(DocumentSnapshot poll, BuildContext context, bool hasVoted) {
    final pollData = poll.data() as Map<String, dynamic>?;
    final imageUrl = pollData?['imageUrl'] as String?;
    final description = pollData?['description'] as String?;
    final creatorName = pollData?['creatorName'] as String? ?? 'Unknown';
    final question = pollData?['question'] as String? ?? 'No Question';
    final options = (pollData?['options'] as List?) ?? [];

    final totalVotes = options.fold<int>(0, (sum, option) {
      final opt = option as Map<String, dynamic>;
      return sum + ((opt['votes'] as int?) ?? 0);
    });

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => PollDetailScreen(pollId: poll.id)
          ));
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 150,
                        color: AppColors.elevation,
                        child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                      ),
                      errorWidget: (context, url, error) => Icon(Feather.alert_circle, color: AppColors.error),
                    ),
                  ),
                ),
              Text(
                question,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textHigh),
              ),
              SizedBox(height: 8),
              Text(
                description ?? '',
                style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              ...(options.take(2).map((option) {
                final opt = option as Map<String, dynamic>;
                final text = opt['text'] as String? ?? '';
                final votes = (opt['votes'] as int?) ?? 0;
                final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: AppColors.elevation,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  hasVoted ? AppColors.secondaryTeal : AppColors.textDisabled,
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        text,
                        style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                      ),
                    ],
                  ),
                );
              }).toList()),
              if (options.length > 2)
                Text(
                  '+ ${options.length - 2} more options',
                  style: TextStyle(color: AppColors.primaryLavender, fontSize: 12),
                ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$totalVotes votes • Created by $creatorName',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                  ),
                  if (hasVoted)
                    Icon(Feather.check_circle, color: AppColors.secondaryTeal, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Petitions Tab with Signing
class PetitionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('petitions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerList();
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading petitions', style: TextStyle(color: AppColors.error)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No petitions yet 👀', Feather.file_text);
        }
        
        final petitions = snapshot.data!.docs;
        
        // Extract trending (top 5 by signatures)
        final trendingPetitions = List<DocumentSnapshot>.from(petitions);
        trendingPetitions.sort((a, b) => (b['currentSignatures'] ?? 0).compareTo(a['currentSignatures'] ?? 0));
        final topTrending = trendingPetitions.take(5).toList();

        return ListView(
          padding: EdgeInsets.all(12),
          children: [
            if (topTrending.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Icon(Feather.trending_up, color: AppColors.accentMustard, size: 20),
                    SizedBox(width: 8),
                    Text('Trending Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: topTrending.length,
                  itemBuilder: (context, index) {
                    final petition = topTrending[index];
                    final hasSigned = user != null ? (petition['signers'] as List).contains(user.uid) : false;
                    return Container(
                      width: 280,
                      margin: EdgeInsets.only(right: 12),
                      child: _buildPetitionCard(petition, context, hasSigned, isMini: true),
                    );
                  },
                ),
              ),
              SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text('All Petitions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
              ),
            ],
            ...petitions.map((petition) {
              final hasSigned = user != null ? (petition['signers'] as List).contains(user.uid) : false;
              return _buildPetitionCard(petition, context, hasSigned);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildPetitionCard(DocumentSnapshot petition, BuildContext context, bool hasSigned, {bool isMini = false}) {
    final petitionData = petition.data() as Map<String, dynamic>?;
    final imageUrl = petitionData?['bannerImageUrl'] as String? ?? petitionData?['imageUrl'] as String?;
    final title = petitionData?['title'] as String? ?? 'Untitled Petition';
    final description = petitionData?['description'] as String? ?? '';
    final creatorName = petitionData?['creatorName'] as String? ?? 'Unknown';
    final signatures = (petitionData?['currentSignatures'] as int?) ?? (petitionData?['signatures'] as int?) ?? 0;
    final goal = (petitionData?['goal'] as int?) ?? 1000;
    final progress = goal > 0 ? signatures / goal : 0;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => EnhancedPetitionDetailScreen(petitionId: petition.id)
          ));
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    height: isMini ? 100 : 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: isMini ? 100 : 150,
                      color: AppColors.elevation,
                      child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                    ),
                    errorWidget: (context, url, error) => Icon(Feather.alert_circle, color: AppColors.error),
                  ),
                ),
              ),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMini ? 14 : 18, color: AppColors.textHigh),
              maxLines: isMini ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!isMini) ...[
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
              SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0).toDouble(),
                  backgroundColor: AppColors.elevation,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    hasSigned ? AppColors.success : AppColors.secondaryTeal,
                  ),
                  minHeight: 6,
                ),
              ),

              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$signatures of $goal signatures',
                    style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                  ),
                  if (hasSigned)
                    Icon(Feather.check_circle, color: AppColors.success, size: 16),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Created by $creatorName',
                style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Events Tab
class EventsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('date', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerList();
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error loading events', style: TextStyle(color: AppColors.error)));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState('No events yet 👀', Feather.calendar);
        }
        
        final events = snapshot.data!.docs;
        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final isAttending = user != null ? (event['attendees'] as List).contains(user.uid) : false;
            
            return _buildEventCard(event, context, isAttending);
          },
        );
      },
    );
  }

  Widget _buildEventCard(DocumentSnapshot event, BuildContext context, bool isAttending) {
    final eventData = event.data() as Map<String, dynamic>?;
    final imageUrl = eventData?['imageUrl'] as String?;
    final title = eventData?['title'] as String? ?? 'Untitled Event';
    final description = eventData?['description'] as String?;
    final creatorName = eventData?['creatorName'] as String? ?? 'Unknown';
    final location = eventData?['location'] as String? ?? 'Location TBA';
    final attendeesList = (eventData?['attendees'] as List?) ?? [];
    final attendeesCount = attendeesList.length;

    DateTime date = DateTime.now();
    try {
      final timestamp = eventData?['date'] as Timestamp?;
      if (timestamp != null) {
        date = timestamp.toDate();
      }
    } catch (e) {
      print('Error parsing date for event ${event.id}: $e');
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => EventDetailScreen(eventId: event.id)
          ));
        },
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null && imageUrl.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 150,
                        color: AppColors.elevation,
                        child: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)),
                      ),
                      errorWidget: (context, url, error) => Icon(Feather.alert_circle, color: AppColors.error),
                    ),
                  ),
                ),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textHigh),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Feather.calendar, size: 16, color: AppColors.primaryLavender),
                  SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(date),
                    style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Feather.map_pin, size: 16, color: AppColors.primaryLavender),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                description ?? '',
                style: TextStyle(color: AppColors.textMedium, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$attendeesCount attending • Created by $creatorName',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                  ),
                  if (isAttending)
                    Icon(Feather.check_circle, color: AppColors.success, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Create Poll Screen
class CreatePollScreen extends StatefulWidget {
  @override
  _CreatePollScreenState createState() => _CreatePollScreenState();
}

class _CreatePollScreenState extends State<CreatePollScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [TextEditingController(), TextEditingController()];
  File? _image;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_image == null) return '';
    
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('poll_images')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    await storageRef.putFile(_image!);
    return await storageRef.getDownloadURL();
  }

  Future<void> _createPoll() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final imageUrl = await _uploadImage();
      
      final pollData = {
        'question': _questionController.text,
        'description': _descriptionController.text,
        'options': _optionControllers
            .map<Map<String, dynamic>>((c) => {
                  'text': c.text,
                  'votes': 0,
                })
            .where((option) => (option['text'] as String).isNotEmpty)
            .toList(),
        'creatorId': user.uid,
        'creatorName': user.displayName ?? user.email,
        'createdAt': Timestamp.now(),
        'voters': [],
        'imageUrl': imageUrl,
        'collaborators': [],
      };

      
      await FirebaseFirestore.instance.collection('polls').add(pollData);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating poll: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Create Poll', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        actions: [
          IconButton(
            icon: Icon(Feather.check, color: AppColors.primaryLavender),
            onPressed: _isLoading ? null : _createPoll,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.elevation,
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_image!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Feather.image, size: 40, color: AppColors.textDisabled),
                                  Text('Add Image', style: TextStyle(color: AppColors.textMedium)),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(controller: _questionController, label: 'Question'),
                    SizedBox(height: 16),
                    _buildTextField(controller: _descriptionController, label: 'Description (optional)', maxLines: 3),
                    SizedBox(height: 16),
                    Text('Options', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                    ..._optionControllers.map((controller) => Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: _buildTextField(
                        controller: controller,
                        label: 'Option ${_optionControllers.indexOf(controller) + 1}',
                      ),
                    )).toList(),
                    SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _optionControllers.add(TextEditingController());
                        });
                      },
                      child: Text('+ Add Option', style: TextStyle(color: AppColors.secondaryTeal)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Create Petition Screen
class CreatePetitionScreen extends StatefulWidget {
  @override
  _CreatePetitionScreenState createState() => _CreatePetitionScreenState();
}

class _CreatePetitionScreenState extends State<CreatePetitionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _goalController = TextEditingController(text: '1000');
  File? _image;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_image == null) return '';
    
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('petition_images')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    await storageRef.putFile(_image!);
    return await storageRef.getDownloadURL();
  }

  Future<void> _createPetition() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() { _isLoading = true; });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final imageUrl = await _uploadImage();
      
      final petitionData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'goal': int.tryParse(_goalController.text) ?? 1000,
        'creatorId': user.uid,
        'creatorName': user.displayName ?? user.email,
        'createdAt': Timestamp.now(),
        'signatures': 0,
        'signers': [],
        'imageUrl': imageUrl,
        'collaborators': [],
      };
      
      await FirebaseFirestore.instance.collection('petitions').add(petitionData);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating petition: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Create Petition', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        actions: [
          IconButton(
            icon: Icon(Feather.check, color: AppColors.primaryLavender),
            onPressed: _isLoading ? null : _createPetition,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.elevation,
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_image!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Feather.image, size: 40, color: AppColors.textDisabled),
                                  Text('Add Image', style: TextStyle(color: AppColors.textMedium)),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(controller: _titleController, label: 'Title'),
                    SizedBox(height: 16),
                    _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 5),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _goalController, 
                      label: 'Signature Goal', 
                      keyboardType: TextInputType.number
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Create Event Screen
class CreateEventScreen extends StatefulWidget {
  @override
  _CreateEventScreenState createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  File? _image;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String> _uploadImage() async {
    if (_image == null) return '';
    
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('event_images')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    await storageRef.putFile(_image!);
    return await storageRef.getDownloadURL();
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
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
    
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
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
      
      if (time != null) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      }
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select date and time')),
      );
      return;
    }
    
    setState(() { _isLoading = true; });
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');
      
      final imageUrl = await _uploadImage();
      
      final eventDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
      
      final eventData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'date': Timestamp.fromDate(eventDateTime),
        'creatorId': user.uid,
        'creatorName': user.displayName ?? user.email,
        'createdAt': Timestamp.now(),
        'attendees': [],
        'imageUrl': imageUrl,
        'collaborators': [],
      };
      
      await FirebaseFirestore.instance.collection('events').add(eventData);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating event: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Create Event', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        actions: [
          IconButton(
            icon: Icon(Feather.check, color: AppColors.primaryLavender),
            onPressed: _isLoading ? null : _createEvent,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.elevation,
                        ),
                        child: _image != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_image!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Feather.image, size: 40, color: AppColors.textDisabled),
                                  Text('Add Image', style: TextStyle(color: AppColors.textMedium)),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(controller: _titleController, label: 'Title'),
                    SizedBox(height: 16),
                    _buildTextField(controller: _descriptionController, label: 'Description', maxLines: 3),
                    SizedBox(height: 16),
                    _buildTextField(controller: _locationController, label: 'Location'),
                    SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.elevation,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(
                          _selectedDate == null 
                            ? 'Select Date and Time' 
                            : '${DateFormat('MMM d, yyyy').format(_selectedDate!)} at ${_selectedTime!.format(context)}',
                          style: TextStyle(color: AppColors.textHigh),
                        ),
                        trailing: Icon(Feather.calendar, color: AppColors.primaryLavender),
                        onTap: _selectDateTime,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Reusable Input Field Widget for Create Screens
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return TextFormField(
    controller: controller,
    style: TextStyle(color: AppColors.textHigh),
    maxLines: maxLines,
    keyboardType: keyboardType,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textMedium),
      filled: true,
      fillColor: AppColors.elevation,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.primaryLavender),
      ),
    ),
    validator: (value) => value!.isEmpty ? 'Please enter $label' : null,
  );
}

// Detail Screens with Voting/Signing Functionality
class PollDetailScreen extends StatefulWidget {
  final String pollId;

  const PollDetailScreen({Key? key, required this.pollId}) : super(key: key);

  @override
  _PollDetailScreenState createState() => _PollDetailScreenState();
}

class _PollDetailScreenState extends State<PollDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _selectedOption;
  bool _isLoading = false;

  Future<void> _vote(String optionIndex) async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() { _isLoading = true; });

    try {
      final pollDoc = _firestore.collection('polls').doc(widget.pollId);
      await _firestore.runTransaction((transaction) async {
        final poll = await transaction.get(pollDoc);
        if (!poll.exists) throw Exception('Poll not found');

        final voters = List<String>.from(poll['voters'] ?? []);
        if (voters.contains(user.uid)) {
          throw Exception('You have already voted');
        }

        final options = List<Map<String, dynamic>>.from(poll['options']);
        options[int.parse(optionIndex)]['votes'] = (options[int.parse(optionIndex)]['votes'] as int) + 1;
        voters.add(user.uid);

        transaction.update(pollDoc, {
          'options': options,
          'voters': voters,
        });
      });

      setState(() { _selectedOption = optionIndex; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error voting: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Poll Details', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('polls').doc(widget.pollId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Poll not found', style: TextStyle(color: AppColors.textHigh)));
          }
          
          final poll = snapshot.data!;
          final options = List<Map<String, dynamic>>.from(poll['options']);
          final totalVotes = options.fold<int>(0, (sum, option) => sum + (option['votes'] as int));
          final hasVoted = (poll['voters'] as List).contains(_auth.currentUser?.uid);
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poll['imageUrl'] != null && poll['imageUrl'].isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: poll['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                
                Text(
                  poll['question'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                ),
                
                SizedBox(height: 8),
                
                if (poll['description'] != null && poll['description'].isNotEmpty)
                  Text(
                    poll['description'],
                    style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                  ),
                
                SizedBox(height: 16),
                
                ...options.asMap().entries.map((entry) {
                  final index = entry.key;
                  final option = entry.value;
                  final votes = option['votes'] as int;
                  final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0;
                  
                  return Card(
                    color: AppColors.surface,
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(option['text'], style: TextStyle(color: AppColors.textHigh)),
                      subtitle: hasVoted || _selectedOption != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: AppColors.elevation,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryTeal),
                              ),
                            )
                          : null,
                      trailing: hasVoted || _selectedOption != null
                          ? Text('${percentage.toStringAsFixed(1)}% ($votes votes)', style: TextStyle(color: AppColors.textMedium))
                          : null,
                      onTap: (!hasVoted && _selectedOption == null && !_isLoading)
                          ? () => _vote(index.toString())
                          : null,
                      selected: _selectedOption == index.toString(),
                      tileColor: _selectedOption == index.toString()
                          ? AppColors.primaryLavender.withOpacity(0.1)
                          : null,
                    ),
                  );
                }).toList(),
                
                SizedBox(height: 16),
                
                Text(
                  'Total votes: $totalVotes • Created by ${poll['creatorName']}',
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class PetitionDetailScreen extends StatefulWidget {
  final String petitionId;

  const PetitionDetailScreen({Key? key, required this.petitionId}) : super(key: key);

  @override
  _PetitionDetailScreenState createState() => _PetitionDetailScreenState();
}

class _PetitionDetailScreenState extends State<PetitionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _signPetition() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() { _isLoading = true; });

    try {
      final petitionDoc = _firestore.collection('petitions').doc(widget.petitionId);
      await _firestore.runTransaction((transaction) async {
        final petition = await transaction.get(petitionDoc);
        if (!petition.exists) throw Exception('Petition not found');

        final signers = List<String>.from(petition['signers'] ?? []);
        if (signers.contains(user.uid)) {
          throw Exception('You have already signed this petition');
        }

        transaction.update(petitionDoc, {
          'signatures': FieldValue.increment(1),
          'signers': FieldValue.arrayUnion([user.uid]),
        });
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Petition Details', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('petitions').doc(widget.petitionId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Petition not found', style: TextStyle(color: AppColors.textHigh)));
          }
          
          final petition = snapshot.data!;
          final signatures = petition['signatures'] as int;
          final goal = petition['goal'] as int;
          final progress = signatures / goal;
          final hasSigned = (petition['signers'] as List).contains(_auth.currentUser?.uid);
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (petition['imageUrl'] != null && petition['imageUrl'].isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: petition['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                
                Text(
                  petition['title'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                ),
                
                SizedBox(height: 16),
                
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.elevation,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondaryTeal),
                    minHeight: 10,
                  ),
                ),
                
                SizedBox(height: 8),
                
                Text(
                  '$signatures of $goal signatures',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                ),
                
                SizedBox(height: 16),
                
                Text(
                  petition['description'],
                  style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.textMedium),
                ),
                
                SizedBox(height: 24),
                
                if (!hasSigned)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signPetition,
                      child: _isLoading
                          ? CircularProgressIndicator(color: AppColors.backgroundDeep)
                          : Text('Sign This Petition', style: TextStyle(color: AppColors.backgroundDeep)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryLavender,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                
                if (hasSigned)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Feather.check_circle, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Already Signed', style: TextStyle(color: AppColors.success)),
                        ],
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.success),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                
                SizedBox(height: 16),
                
                Text(
                  'Created by ${petition['creatorName']}',
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class EventDetailScreen extends StatefulWidget {
  final String eventId;

  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> _toggleAttendance() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() { _isLoading = true; });

    try {
      final eventDoc = _firestore.collection('events').doc(widget.eventId);
      final event = await eventDoc.get();
      
      if (!event.exists) throw Exception('Event not found');

      final attendees = List<String>.from(event['attendees'] ?? []);
      final isAttending = attendees.contains(user.uid);

      await eventDoc.update({
        'attendees': isAttending
            ? FieldValue.arrayRemove([user.uid])
            : FieldValue.arrayUnion([user.uid]),
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating attendance: $e')),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text('Event Details', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('events').doc(widget.eventId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Event not found', style: TextStyle(color: AppColors.textHigh)));
          }
          
          final event = snapshot.data!;
          final date = event['date'] != null ? (event['date'] as Timestamp).toDate() : DateTime.now();
          final attendees = (event['attendees'] as List).length;
          final isAttending = (event['attendees'] as List).contains(_auth.currentUser?.uid);
          
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event['imageUrl'] != null && event['imageUrl'].isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: event['imageUrl'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                
                Text(
                  event['title'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh),
                ),
                
                SizedBox(height: 16),
                
                Row(
                  children: [
                    Icon(Feather.calendar, color: AppColors.primaryLavender),
                    SizedBox(width: 12),
                    Text(
                      DateFormat('MMM d, yyyy • h:mm a').format(date),
                      style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                Row(
                  children: [
                    Icon(Feather.map_pin, color: AppColors.primaryLavender),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        event['location'],
                        style: TextStyle(fontSize: 16, color: AppColors.textMedium),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),
                
                Text(
                  event['description'] ?? '',
                  style: TextStyle(fontSize: 16, height: 1.5, color: AppColors.textMedium),
                ),
                
                SizedBox(height: 24),
                
                Row(
                  children: [
                    Icon(Feather.users, color: AppColors.secondaryTeal),
                    SizedBox(width: 8),
                    Text(
                      '$attendees people attending',
                      style: TextStyle(fontSize: 16, color: AppColors.textHigh),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _toggleAttendance,
                    child: _isLoading
                        ? CircularProgressIndicator(color: AppColors.backgroundDeep)
                        : Text(
                            isAttending ? 'Cancel Attendance' : 'Attend Event',
                            style: TextStyle(color: isAttending ? AppColors.textHigh : AppColors.backgroundDeep),
                          ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: isAttending ? AppColors.elevation : AppColors.primaryLavender,
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                Text(
                  'Created by ${event['creatorName']}',
                  style: TextStyle(color: AppColors.textDisabled),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


Widget _buildShimmerList() {
  return ListView.builder(
    padding: EdgeInsets.all(12),
    itemCount: 6,
    itemBuilder: (context, index) {
      return Shimmer.fromColors(
        baseColor: AppColors.elevation,
        highlightColor: AppColors.surface,
        child: Card(
          margin: EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: AppColors.elevation,
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildEmptyState(String message, IconData icon) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: AppColors.textDisabled),
        SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(fontSize: 18, color: AppColors.textMedium),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}