import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:femn/customization/colors.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../models/therapy_models.dart';
import '../services/therapy_service.dart';

import 'package:femn/hub_screens/profile.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:femn/hub_screens/chatscreen.dart';

class TherapistDashboard extends StatefulWidget {
  @override
  _TherapistDashboardState createState() => _TherapistDashboardState();
}

class _TherapistDashboardState extends State<TherapistDashboard> {
  final TherapyService _therapyService = TherapyService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Client Dashboard', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Pending Requests'),
            _buildPendingRequests(),
            _buildSectionHeader('Active Clients'),
            _buildActiveClients(),
            _buildSectionHeader('History (Completed)'),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('therapy_sessions')
          .where('therapistId', isEqualTo: _uid)
          .where('status', isEqualTo: SessionStatus.completed.index)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No completed journeys yet.', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final sessionData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final session = TherapySession.fromMap(sessionData, snapshot.data!.docs[index].id);
            return _buildHistoryCard(session);
          },
        );
      },
    );
  }

  Widget _buildHistoryCard(TherapySession session) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(session.clientId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final clientName = userData['fullName'] ?? 'Anonymous Client';
        return ListTile(
          leading: Icon(Feather.clock, color: AppColors.textDisabled),
          title: Text(clientName, style: TextStyle(color: AppColors.textHigh)),
          subtitle: Text(session.type == SessionType.oneDay ? 'Rescue' : 'Journey', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
          trailing: Icon(Feather.chevron_right, color: AppColors.textDisabled),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: session.clientId))),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildPendingRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('therapy_sessions')
          .where('therapistId', isEqualTo: _uid)
          .where('status', isEqualTo: SessionStatus.pending.index)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No pending requests.', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final sessionData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final session = TherapySession.fromMap(sessionData, snapshot.data!.docs[index].id);
            return _buildPendingCard(session);
          },
        );
      },
    );
  }

  Widget _buildActiveClients() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('therapy_sessions')
          .where('therapistId', isEqualTo: _uid)
          .where('status', isEqualTo: SessionStatus.active.index)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('No active clients.', style: TextStyle(color: AppColors.textDisabled, fontSize: 13)),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final sessionData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final session = TherapySession.fromMap(sessionData, snapshot.data!.docs[index].id);
            return _buildClientCard(session);
          },
        );
      },
    );
  }

  Widget _buildPendingCard(TherapySession session) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(session.clientId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final clientName = userData['fullName'] ?? 'Anonymous Client';
        final username = userData['username'] ?? 'User';
        final profileImage = userData['profileImage'] ?? '';

        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.elevation,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: session.clientId))),
                    child: CircleAvatar(
                      backgroundImage: profileImage.isNotEmpty ? CachedNetworkImageProvider(profileImage) : null,
                      backgroundColor: AppColors.surface,
                      child: profileImage.isEmpty ? Icon(Feather.user, color: AppColors.textDisabled) : null,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: session.clientId))),
                          child: Text(clientName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                        ),
                        Text('@$username', style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text(session.type == SessionType.oneDay ? 'Rescue' : 'Journey', style: TextStyle(color: AppColors.secondaryTeal, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 12),
              Text('Problem:', style: TextStyle(color: AppColors.textMedium, fontSize: 12, fontWeight: FontWeight.bold)),
              Text(session.problemDescription.isNotEmpty ? session.problemDescription : 'No description provided.', 
                style: TextStyle(color: AppColors.textHigh, fontSize: 13, fontStyle: FontStyle.italic)),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _therapyService.acceptSession(session.id),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryTeal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Implement decline logic if needed
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.error), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('Decline', style: TextStyle(color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClientCard(TherapySession session) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(session.clientId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final clientName = userData['fullName'] ?? 'Anonymous Client';
        final profileImage = userData['profileImage'] ?? '';

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.elevation, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: session.clientId))),
                        child: CircleAvatar(
                          backgroundImage: profileImage.isNotEmpty ? CachedNetworkImageProvider(profileImage) : null,
                          backgroundColor: AppColors.elevation,
                          child: profileImage.isEmpty ? Icon(Feather.user, color: AppColors.textDisabled) : null,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: session.clientId))),
                            child: Text(clientName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textHigh)),
                          ),
                          Text(session.type == SessionType.oneDay ? 'One-Day Rescue' : 'Multi-Day Journey', 
                            style: TextStyle(color: AppColors.secondaryTeal, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Feather.message_circle, color: AppColors.secondaryTeal),
                        onPressed: () => _navigateToChat(session.clientId, clientName, profileImage),
                        tooltip: 'Message Client',
                      ),
                      IconButton(
                        icon: Icon(Feather.check_circle, color: AppColors.success),
                        onPressed: () => _therapyService.completeSession(session.id, _uid),
                        tooltip: 'Mark Complete',
                      ),
                    ],
                  ),
                ],
              ),
              Divider(color: AppColors.elevation, height: 24),
              Text('Timeline Goals', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh)),
              SizedBox(height: 8),
              ...session.timeline.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: InkWell(
                  onTap: () => _navigateToChat(session.clientId, clientName, profileImage),
                  child: Row(
                    children: [
                      Icon(item.isCompleted ? Feather.check_square : Feather.square, 
                        size: 16, color: item.isCompleted ? AppColors.success : AppColors.textDisabled),
                      SizedBox(width: 8),
                      Expanded(child: Text(item.title, style: TextStyle(color: AppColors.textMedium, fontSize: 13))),
                    ],
                  ),
                ),
              )).toList(),
              TextButton.icon(
                onPressed: () => _showAddGoalDialog(session.id),
                icon: Icon(Feather.plus, size: 16),
                label: Text('Add Goal'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryLavender),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddGoalDialog(String sessionId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Add Timeline Goal', style: TextStyle(color: AppColors.textHigh)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textHigh),
          decoration: InputDecoration(
            hintText: 'Goal title...',
            hintStyle: TextStyle(color: AppColors.textDisabled),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final newItem = TimelineItem(
                  title: controller.text,
                  description: '',
                  timestamp: DateTime.now(),
                );
                await FirebaseFirestore.instance.collection('therapy_sessions').doc(sessionId).update({
                  'timeline': FieldValue.arrayUnion([newItem.toMap()])
                });
                Navigator.pop(c);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _navigateToChat(String clientId, String clientName, String profileImage) async {
    final chatQuery = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: _uid)
        .get();

    String? chatId;
    for (var doc in chatQuery.docs) {
      if ((doc['participants'] as List).contains(clientId)) {
        chatId = doc.id;
        break;
      }
    }

    if (chatId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (c) => ChatScreen(
        chatId: chatId!,
        otherUserId: clientId,
        otherUserName: clientName,
        otherUserProfileImage: profileImage,
      )));
    }
  }
}
