import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/colors.dart'; 
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
import 'streak_service.dart'; // Make sure to import the new service
import 'twin_finder.dart'; // Import Twin Finder Screen

class WellnessScreen extends StatefulWidget {
  @override
  _WellnessScreenState createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  late Future<void> _refreshWellness;

  Future<void> _onRefresh() async {
    await Future.delayed(Duration(milliseconds: 500));
  setState(() {});  
  }

  @override
  void initState() {
    super.initState();
    _refreshWellness = _onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    
    // Define the data and their specific Bento sizes (Width x Height)
    // Grid has 5 columns total.
    final List<Map<String, dynamic>> bentoItems = [
      {
        'name': 'Wellness Journal',
        'icon': Feather.book,
        'description': 'Track your mental health',
        'crossAxisCellCount': 3, 
        'mainAxisCellCount': 3, 
        'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => JournalScreen())),
        'hasStreak': true, // Custom flag to identify this card
      },
{
        'name': 'Cycle',
        'icon': Feather.calendar,
        'description': 'Track your flow',
        'crossAxisCellCount': 2,
        'mainAxisCellCount': 3,
        'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => PeriodTrackerScreen())),
        'isCycle': true, // <--- ADD THIS FLAG
      },
      {
        'name': 'Activity', // Renamed from Activity Tracker
        'icon': Feather.trending_up,
        'description': 'Petitions & polls',
        'crossAxisCellCount': 3,
        'mainAxisCellCount': 2,
        'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => TrackerScreen())),
      },
// In wellness.dart
{
  'name': 'Twin Finder', 
  'icon': Feather.users,
  'description': 'Find your personality twin',
  'crossAxisCellCount': 2,
  'mainAxisCellCount': 2,
  // Add this line:
  'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => TwinFinderScreen())),
},
      {
        'name': 'Safety Heatmaps',
        'icon': Feather.map_pin,
        'description': 'View safety info',
        'crossAxisCellCount': 2,
        'mainAxisCellCount': 2,
      },
      {
        'name': 'Pinks & Level',
        'icon': Feather.bar_chart,
        'description': 'Track pink levels',
        'crossAxisCellCount': 3,
        'mainAxisCellCount': 2,
      },
      {
        'name': 'Self-defense',
        'icon': Feather.shield,
        'description': 'Learn techniques',
        'crossAxisCellCount': 2,
        'mainAxisCellCount': 2,
      },
      {
        'name': 'Literature Archive',
        'icon': Feather.book_open,
        'description': 'Educational content',
        'crossAxisCellCount': 3,
        'mainAxisCellCount': 2,
      },
      {
        'name': 'Check-in Timer',
        'icon': Feather.clock,
        'description': 'Set reminders',
        'crossAxisCellCount': 5, // Full width banner style
        'mainAxisCellCount': 2,
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
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
                  color: AppColors.elevation,
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
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: StaggeredGrid.count(
              crossAxisCount: 5, // 5 Column Grid
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: bentoItems.map((item) {
                return StaggeredGridTile.count(
                  crossAxisCellCount: item['crossAxisCellCount'],
                  mainAxisCellCount: item['mainAxisCellCount'],
                  child: _buildBentoCard(item),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

Widget _buildBentoCard(Map<String, dynamic> item) {
    // 1. Define Base Content (Icon + Text + Desc)
    Widget cardContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          item['icon'], 
          size: item['mainAxisCellCount'] >= 3 ? 55 : 40,
          color: AppColors.primaryLavender
        ),
        const SizedBox(height: 12),
        Text(
          item['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: item['mainAxisCellCount'] >= 3 ? 18 : 15,
            color: AppColors.textHigh,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if (item['mainAxisCellCount'] >= 2) 
          Text(
            item['description'],
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMedium),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );

    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 2. Logic for Wellness Journal (Streak)
    if (item.containsKey('hasStreak') && item['hasStreak'] == true) {
      
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          int count = 0;
          bool isActive = false;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            count = data['streakCount'] ?? 0;
            final Timestamp? lastLogTs = data['lastStreakDate'];
            
            if (lastLogTs != null) {
              final diff = DateTime.now().difference(lastLogTs.toDate()).inDays;
              // Simple check for UI: Active if logged today or yesterday
              isActive = diff <= 1;
              if (diff > 1 && count > 0) isActive = false; // It's a lost streak
            }
          }

          return GestureDetector(
            onTap: () {
               if (item['onTap'] != null) item['onTap'](context);
            },
            child: Stack(
              children: [
                // Background Container
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: AppColors.elevation, width: 1),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Padding(padding: const EdgeInsets.all(12.0), child: cardContent),
                ),
                // Streak Badge Top Right
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: isActive 
                        ? null // Do nothing if active
                        : () => _showRestorationModal(context, count), // Show restoration if inactive
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.elevation,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isActive ? Colors.orange.withOpacity(0.5) : AppColors.textDisabled.withOpacity(0.3)
                        )
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Ionicons.flame : Ionicons.flame_outline, 
                            size: 16, 
                            color: isActive ? Colors.orange : AppColors.textDisabled
                          ),
                          SizedBox(width: 4),
                          Text(
                            "$count", 
                            style: TextStyle(
                              color: isActive ? AppColors.textHigh : AppColors.textDisabled,
                              fontWeight: FontWeight.bold,
                              fontSize: 12
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          );
        }
      );
    }

    // 3. Logic for Cycle Tracker (Season Badge)
    if (item.containsKey('isCycle') && item['isCycle'] == true) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('cycle_settings')
            .doc('settings')
            .snapshots(),
        builder: (context, snapshot) {
          CyclePhaseData? currentPhase;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final Timestamp? lastPeriod = data['lastPeriodStart'];
            final int avgCycle = data['avgCycleLength'] ?? 28;
            final bool isPregnancy = data['isPregnancyMode'] ?? false;

            if (lastPeriod != null && !isPregnancy) {
              // Calculate Phase using the service created in period_tracker.dart
              currentPhase = CycleService.getCurrentPhase(lastPeriod.toDate(), avgCycle);
            }
          }

          return GestureDetector(
            onTap: () { if (item['onTap'] != null) item['onTap'](context); },
            child: Stack(
              children: [
                // Base Card
                Container(
                  width: double.infinity, height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: AppColors.elevation, width: 1),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
                  ),
                  child: Padding(padding: const EdgeInsets.all(12.0), child: cardContent),
                ),
                
                // Season Badge Top Right
                if (currentPhase != null)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: currentPhase.bgColor,
                        borderRadius: BorderRadius.circular(20), 
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: Offset(0,2))
                        ]
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(currentPhase.icon, size: 12, color: currentPhase.textColor),
                          SizedBox(width: 6),
                          Text(
                            currentPhase.seasonName, // "Winter", "Spring", etc.
                            style: TextStyle(
                              color: currentPhase.textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        }
      );
    }

    // 4. Standard Card Return for all other items
    return GestureDetector(
      onTap: () {
        if (item['onTap'] != null) {
          item['onTap'](context);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: AppColors.elevation, width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: cardContent,
        ),
      ),
    );
  }

  void _showRestorationModal(BuildContext context, int lostStreak) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Ionicons.flame_outline, size: 48, color: AppColors.textDisabled),
            SizedBox(height: 16),
            Text(
              "Streak Extinguished!",
              style: TextStyle(color: AppColors.textHigh, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "You missed a day. You can restore your $lostStreak day streak if it was lost within the last 48 hours.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Let it go"),
                    style: OutlinedButton.styleFrom(
                       foregroundColor: AppColors.textMedium,
                       side: BorderSide(color: AppColors.textDisabled)
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close modal first
                      final result = await StreakService.tryRestoreStreak();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result == "Success" ? "Streak Restored! 🔥" : result),
                          backgroundColor: result == "Success" ? Colors.orange : AppColors.error,
                        )
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text("Restore 🔥"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(FirebaseAuth.instance.currentUser!.uid).get(),
              builder: (context, snapshot) {
                if(!snapshot.hasData) return SizedBox();
                int used = snapshot.data!.get('restorationsUsed') ?? 0;
                // Check month reset logic visually here or trust service
                return Text(
                  "Restorations used this month: $used/3",
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                );
              }
            )
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