import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/colors.dart'; // <--- IMPORT COLORS
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';

// --- Custom Imports ---
import 'package:femn/profile.dart';
import 'package:femn/search.dart';
import 'journal.dart'; 
import 'package:femn/period_tracker.dart';
import 'tracker.dart'; 
// import 'period_tracker.dart'; // Make sure this file exists and is updated

class WellnessScreen extends StatefulWidget {
  @override
  _WellnessScreenState createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  late Future<void> _refreshWellness;

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  void initState() {
    super.initState();
    _refreshWellness = _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep, // Deep background
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(55),
        child: AppBar(
          backgroundColor: AppColors.backgroundDeep,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // FEMN Logo
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.elevation, // Dark container
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset('assets/femnlogo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 8),
            Text(
              'You',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh,),
            ),
            ],
          ),
          actions: [
            // Search Button
            Container(
              width: 42,
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevation,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Feather.search,
                  color: AppColors.primaryLavender,
                  size: 22,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SearchScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),

            // User Avatar
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .get(),
              builder: (context, snapshot) {
                Widget avatar;
                if (snapshot.connectionState == ConnectionState.waiting ||
                    !snapshot.hasData ||
                    !snapshot.data!.exists) {
                  avatar = Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
                } else {
                  final user = snapshot.data!;
                  final profileImage = user['profileImage'] ?? '';
                  avatar = profileImage.isNotEmpty
                      ? Image(image: CachedNetworkImageProvider(profileImage), fit: BoxFit.cover)
                      : Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
                }

                return GestureDetector(
                  onTap: () => _showProfileMenu(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.elevation,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(child: avatar),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),

      body: RefreshIndicator(
        color: AppColors.primaryLavender,
        backgroundColor: AppColors.surface,
        onRefresh: _onRefresh,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 5.0),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            itemCount: 13, // Matches the orderedItems length
            cacheExtent: 1000,
            itemBuilder: (context, index) {
              return _buildWellnessCard(index);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWellnessCard(int index) {
    // 1. Define all available items
    final List<Map<String, dynamic>> wellnessItems = [
      { // Index 0
        'name': 'Pinks & Level',
        'icon': Feather.bar_chart,
        'description': 'Track your pink levels',
      },
      { // Index 1
        'name': 'Achievements',
        'icon': Feather.award,
        'description': 'View your accomplishments',
      },
      { // Index 2
        'name': 'MBTI Match',
        'icon': Feather.users,
        'description': 'Personality matching tool',
      },
      { // Index 3
        'name': 'Contributions',
        'icon': Feather.star,
        'description': 'Your community contributions',
      },
      { // Index 4
        'name': 'Wellness Journal',
        'icon': Feather.book,
        'description': 'Track your mental health',
        'onTap': (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => JournalScreen()),
          );
        },
      },
      { // Index 5
        'name': 'Streaks',
        'icon': Feather.activity,
        'description': 'Maintain your streaks',
      },
      // --- UPDATED PERIOD TRACKER BUTTON ---
      { // Index 6
  'name': 'Period Tracker',
  'icon': Feather.calendar,
  'description': 'Track your cycle',
  'onTap': (context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PeriodTrackerScreen()),
    );
  },
},
      // ----------------------------------------
      { // Index 7
        'name': 'Literature Archive',
        'icon': Feather.book_open,
        'description': 'Read educational content',
      },
      { // Index 8
        'name': 'Self-defense',
        'icon': Feather.shield,
        'description': 'Learn self-defense techniques',
      },
      { // Index 9
        'name': 'Mood Boards',
        'icon': Feather.layout,
        'description': 'Visualize your mood',
      },
      { // Index 10
        'name': 'Check-in Timer',
        'icon': Feather.clock,
        'description': 'Set check-in reminders',
      },
      { // Index 11
        'name': 'Safety Heatmaps',
        'icon': Feather.map_pin,
        'description': 'View safety information',
      },
      { // Index 12
        'name': 'Activity Tracker',
        'icon': Feather.trending_up,
        'description': 'Track your petitions & polls',
        'onTap': (context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TrackerScreen()),
          );
        },
      },
    ];

    // 2. Order them (Most important items at the top)
    final orderedItems = [
      wellnessItems[4],  // Wellness Journal (Index 4)
      wellnessItems[6],  // Period Tracker (Index 6)
      wellnessItems[5],  // Streaks (Index 5)
      wellnessItems[9],  // Mood Boards (Index 9)
      wellnessItems[10], // Check-in Timer (Index 10)
      wellnessItems[1],  // Achievements (Index 1)
      wellnessItems[3],  // Contributions (Index 3)
      wellnessItems[0],  // Pinks & Level (Index 0)
      wellnessItems[2],  // MBTI Match (Index 2)
      wellnessItems[7],  // Literature Archive (Index 7)
      wellnessItems[8],  // Self-defense (Index 8)
      wellnessItems[11], // Safety Heatmaps (Index 11)
      wellnessItems[12], // Activity Tracker (Index 12)
    ];

    final item = orderedItems[index];
    final double borderRadiusValue = 20.0;
    
    // Randomized height for Staggered Grid effect
    final random = Random();
    final double minHeight = 120;
    final double maxHeight = 200;
    final double cardHeight = minHeight + random.nextInt((maxHeight - minHeight).toInt());

    return GestureDetector(
      onTap: () {
        if (item['onTap'] != null) {
          item['onTap'](context);
        } else {
          print('Tapped on: ${item['name']}');
        }
      },
      child: Container(
        height: cardHeight,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface, // Dark Surface
          borderRadius: BorderRadius.circular(borderRadiusValue),
          border: Border.all(color: AppColors.elevation, width: 1), // Subtle border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item['icon'], size: 50, color: AppColors.primaryLavender),
            const SizedBox(height: 12),
            Text(
              item['name'],
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.textHigh, // Off-white
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                item['description'],
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textMedium, // Light Gray
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ProfileScreen(userId: FirebaseAuth.instance.currentUser!.uid),
      ),
    );
  }
}