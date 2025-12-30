// settings.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:femn/auth.dart';
import 'package:femn/profile.dart'; // Import ProfileScreen for navigation
import 'package:femn/colors.dart'; // <--- IMPORT COLORS

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep, // Deep background
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primaryLavender),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Option

            Divider(color: AppColors.elevation),
            
            // Logout Option
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.elevation,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout, color: AppColors.error),
              ),
              title: Text(
                "Logout",
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// --- Placeholder/Utility Classes (Refactored for Dark Theme) ---

// If these screens are used elsewhere, they now match the theme. 
// (Note: ProfileScreen in profile.dart likely replaces OtherUserProfileScreen logic, 
// but keeping this consistent just in case).

class OtherUserProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text("Other User Profile", style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
      ),
      body: Center(
        child: Text("This is another user's profile.", style: TextStyle(color: AppColors.textMedium)),
      ),
    );
  }
}

class FollowListScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text("Follow List", style: TextStyle(color: AppColors.textHigh)),
        backgroundColor: AppColors.backgroundDeep,
        iconTheme: IconThemeData(color: AppColors.primaryLavender),
        elevation: 0,
      ),
      body: Center(
        child: Text("List of followers/following.", style: TextStyle(color: AppColors.textMedium)),
      ),
    );
  }
}

class ProfileStatsWidget extends StatelessWidget {
  final int posts;
  final int followers;
  final int following;

  ProfileStatsWidget({
    required this.posts, 
    required this.followers, 
    required this.following
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.elevation),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem("Posts", posts),
          _buildStatItem("Followers", followers),
          _buildStatItem("Following", following),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textHigh,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMedium,
          ),
        ),
      ],
    );
  }
}