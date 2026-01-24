import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../customization/colors.dart';
import '../../widgets/femn_background.dart';
import 'package:femn/circle/polls.dart';

class PollDetailScreen extends StatelessWidget {
  final String pollId;

  const PollDetailScreen({Key? key, required this.pollId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.elevation.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Feather.arrow_left, color: AppColors.textHigh, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: FemnBackground(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('polls').doc(pollId).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error loading poll', style: TextStyle(color: AppColors.error)));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(child: Text('Poll not found', style: TextStyle(color: AppColors.textMedium)));
            }
            
            // Just display the PollCard in a centered view
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 80),
                child: PollCard(
                  pollSnapshot: snapshot.data!,
                  cardMarginVertical: 8,
                  cardMarginHorizontal: 0,
                  cardInternalPadding: 16,
                  borderRadiusValue: 16,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
