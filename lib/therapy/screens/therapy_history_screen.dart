import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:femn/customization/colors.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:femn/hub_screens/profile.dart';
import '../models/therapy_models.dart';

class TherapyHistoryScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Your Therapy History', style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('therapy_sessions')
            .where('clientId', isEqualTo: uid)
            .where('status', isEqualTo: SessionStatus.completed.index)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Feather.clock, size: 64, color: AppColors.textDisabled),
                  SizedBox(height: 16),
                  Text('No completed journeys yet.', style: TextStyle(color: AppColors.textMedium)),
                ],
              ),
            );
          }

          final sessions = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final sessionData = sessions[index].data() as Map<String, dynamic>;
              final session = TherapySession.fromMap(sessionData, sessions[index].id);
              return _buildHistoryCard(context, session);
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, TherapySession session) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(session.therapistId).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final therapistName = userData['fullName'] ?? 'Anonymous Therapist';
        
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.elevation, width: 1),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.all(16),
            leading: Icon(Feather.shield, color: AppColors.primaryLavender),
            title: Text(therapistName, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.type == SessionType.oneDay ? 'One-Day Rescue' : 'Multi-Day Journey', 
                  style: TextStyle(color: AppColors.secondaryTeal, fontSize: 12)),
                if (session.endTime != null)
                  Text('Completed on ${session.endTime!.day}/${session.endTime!.month}/${session.endTime!.year}',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 10)),
              ],
            ),
            trailing: Icon(Feather.chevron_right, size: 16, color: AppColors.textDisabled),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => ProfileScreen(userId: session.therapistId))),
          ),
        );
      },
    );
  }
}
