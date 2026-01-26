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
import 'streak_service.dart'; 
import 'twin_finder.dart'; 
import 'leakguard/leakguard.dart'; 

// --- Enums & Models ---
enum WidgetType {
  journal,
  cycle,
  activity,
  twinFinder,
  safetyHeatmaps,
  pinksLevel,
  selfDefense,
  literature,
  leakGuard,
  checkInTimer
}

class GridItem {
  final String id;
  final WidgetType type;
  int crossAxisCount;
  int mainAxisCount;

  GridItem({
    required this.id,
    required this.type,
    this.crossAxisCount = 2,
    this.mainAxisCount = 2,
  });
}

class WellnessScreen extends StatefulWidget {
  @override
  _WellnessScreenState createState() => _WellnessScreenState();
}

class _WellnessScreenState extends State<WellnessScreen> {
  // #1 Start with all widgets not being there (Empty List)
  List<GridItem> _activeWidgets = []; 
  bool _isEditMode = false;

  // Define available widgets content
  final Map<WidgetType, Map<String, dynamic>> _widgetDefinitions = {
    WidgetType.journal: {
      'name': 'Wellness Journal', 
      'icon': Feather.book, 
      'desc': 'Track mental health', 
      'hasStreak': true,
      'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => JournalScreen()))
    },
    WidgetType.cycle: {
      'name': 'Cycle', 
      'icon': Feather.calendar, 
      'desc': 'Track your flow', 
      'isCycle': true,
      'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => PeriodTrackerScreen()))
    },
    WidgetType.activity: {
      'name': 'Activity', 
      'icon': Feather.trending_up, 
      'desc': 'Petitions & polls',
      'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => TrackerScreen()))
    },
    WidgetType.twinFinder: {
      'name': 'Twin Finder', 
      'icon': Feather.users, 
      'desc': 'Find personality twin',
      'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => TwinFinderScreen()))
    },
    WidgetType.safetyHeatmaps: {
      'name': 'Safety Heatmaps', 
      'icon': Feather.map_pin, 
      'desc': 'View safety info'
    },
    WidgetType.pinksLevel: {
      'name': 'Pinks & Level', 
      'icon': Feather.bar_chart, 
      'desc': 'Track pink levels'
    },
    WidgetType.selfDefense: {
      'name': 'Self-defense', 
      'icon': Feather.shield, 
      'desc': 'Learn techniques'
    },
    WidgetType.literature: {
      'name': 'Literature', 
      'icon': Feather.book_open, 
      'desc': 'Educational content'
    },
    WidgetType.leakGuard: {
      'name': 'Leak Guard', 
      'icon': Feather.lock, 
      'desc': 'Anti-sextortion tool',
      'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (c) => LeakGuardScreen()))
    },
    WidgetType.checkInTimer: {
      'name': 'Check-in Timer', 
      'icon': Feather.clock, 
      'desc': 'Set reminders'
    },
  };

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

  // --- Logic: Add Widget ---
  void _addWidget(WidgetType type) {
    setState(() {
      // Default sizes based on type
      int cross = 2;
      int main = 2;
      if (type == WidgetType.journal || type == WidgetType.activity || type == WidgetType.literature || type == WidgetType.pinksLevel) { 
        cross = 3; 
      }
      if (type == WidgetType.checkInTimer) { 
        cross = 5; 
        main = 2; 
      } // Banner style
      if (type == WidgetType.cycle) { 
        cross = 2; 
        main = 3; 
      } // Tall for cycle

      _activeWidgets.add(GridItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // unique ID
        type: type,
        crossAxisCount: cross,
        mainAxisCount: main,
      ));
    });
    Navigator.pop(context); // Close drawer
  }

  // --- Logic: Remove Widget ---
  void _removeWidget(int index) {
    setState(() {
      _activeWidgets.removeAt(index);
      if (_activeWidgets.isEmpty) _isEditMode = false;
    });
  }

  // --- Logic: Resize Widget (Geometry) ---
  void _resizeWidget(int index) {
    setState(() {
      var item = _activeWidgets[index];
      // Simple cycle logic: Square -> Wide -> Tall -> Big Square -> Banner
      if (item.crossAxisCount == 2 && item.mainAxisCount == 2) {
        item.crossAxisCount = 3; item.mainAxisCount = 2; // Wide
      } else if (item.crossAxisCount == 3 && item.mainAxisCount == 2) {
        item.crossAxisCount = 2; item.mainAxisCount = 3; // Tall
      } else if (item.crossAxisCount == 2 && item.mainAxisCount == 3) {
        item.crossAxisCount = 4; item.mainAxisCount = 3; // Big Square
      } else if (item.crossAxisCount == 4 && item.mainAxisCount == 3) {
        item.crossAxisCount = 5; item.mainAxisCount = 2; // Banner
      } else {
        item.crossAxisCount = 2; item.mainAxisCount = 2; // Reset to Square
      }
    });
  }

  // --- Logic: Reorder (Move Flow) ---
  void _moveWidget(int index, int direction) {
    // direction -1 = left/up, 1 = right/down
    setState(() {
      if (direction == -1 && index > 0) {
        final item = _activeWidgets.removeAt(index);
        _activeWidgets.insert(index - 1, item);
      } else if (direction == 1 && index < _activeWidgets.length - 1) {
        final item = _activeWidgets.removeAt(index);
        _activeWidgets.insert(index + 1, item);
      }
    });
  }

  // --- UI: Add Menu ---
  void _showAddWidgetMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // #3 Filter out widgets that are already on screen
        final usedTypes = _activeWidgets.map((e) => e.type).toSet();
        final available = WidgetType.values.where((t) => !usedTypes.contains(t)).toList();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Add Widget to Mesh", 
                style: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              available.isEmpty 
                ? Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(child: Text("All widgets added!", 
                      style: TextStyle(color: AppColors.textDisabled))),
                  )
                : Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, 
                        crossAxisSpacing: 10, 
                        mainAxisSpacing: 10
                      ),
                      itemCount: available.length,
                      itemBuilder: (context, index) {
                        final type = available[index];
                        final def = _widgetDefinitions[type]!;
                        return GestureDetector(
                          onTap: () => _addWidget(type),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.elevation)
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(def['icon'], color: AppColors.primaryLavender),
                                SizedBox(height: 8),
                                Text(def['name'], 
                                  style: TextStyle(color: AppColors.textMedium, fontSize: 12), 
                                  textAlign: TextAlign.center)
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      // #5 Clearing Canvas: Tap background to exit edit mode
      body: GestureDetector(
        onTap: () {
          if (_isEditMode) setState(() => _isEditMode = false);
        },
        // #2 Long clicking empty space to add
        onLongPress: () {
          if (!_isEditMode) _showAddWidgetMenu();
        },
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primaryLavender,
          backgroundColor: AppColors.surface,
          child: CustomScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            slivers: [
              // Custom App Bar
              SliverAppBar(
                backgroundColor: AppColors.backgroundDeep,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                title: Row(
                  children: [
                    _buildLogo(),
                    SizedBox(width: 8),
                    Text('You', 
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  ],
                ),
                actions: [
                  _buildCircleButton(Feather.search, 
                    () => Navigator.push(context, MaterialPageRoute(builder: (c) => SearchScreen()))),
                  SizedBox(width: 8),
                  _buildUserAvatar(currentUserId),
                  SizedBox(width: 12),
                ],
              ),

              // The Grid
              SliverPadding(
                padding: EdgeInsets.all(12),
                sliver: _activeWidgets.isEmpty 
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Feather.plus_square, size: 40, color: AppColors.textDisabled),
                            SizedBox(height: 12),
                            Text(
                              "Long press here to add widgets",
                              style: TextStyle(color: AppColors.textMedium),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverToBoxAdapter(
                      child: StaggeredGrid.count(
                        crossAxisCount: 5,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: List.generate(_activeWidgets.length, (index) {
                          final item = _activeWidgets[index];
                          return StaggeredGridTile.count(
                            key: ValueKey(item.id),
                            crossAxisCellCount: item.crossAxisCount,
                            mainAxisCellCount: item.mainAxisCount,
                            child: _buildEditableWrapper(index, item),
                          );
                        }),
                      ),
                    ),
              ),
              // Extra space at bottom
              SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // --- Item Wrapper (Handles Edit Mode) ---
  Widget _buildEditableWrapper(int index, GridItem item) {
    // The actual card content
    Widget content = _buildCardContent(item);

    // #2 Long clicking individual widget to edit
    return GestureDetector(
      onLongPress: () {
        setState(() => _isEditMode = true);
        // HapticFeedback.mediumImpact(); // Optional interaction
      },
      child: Stack(
        children: [
          // The Content
          Positioned.fill(child: content),

          // Edit Overlay
          if (_isEditMode)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),

          // Resize Handle (Bottom Right)
          if (_isEditMode)
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => _resizeWidget(index),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryLavender,
                  child: Icon(Feather.maximize_2, size: 16, color: Colors.white),
                ),
              ),
            ),

          // Delete Handle (Top Left)
          if (_isEditMode)
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => _removeWidget(index),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.error,
                  child: Icon(Feather.x, size: 16, color: Colors.white),
                ),
              ),
            ),
          
          // Move/Reflow Flow Arrows (Top Right - Simplified Drag logic)
          if (_isEditMode)
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  if (index > 0)
                    GestureDetector(
                      onTap: () => _moveWidget(index, -1),
                      child: CircleAvatar(
                        radius: 14, 
                        backgroundColor: Colors.white24, 
                        child: Icon(Feather.chevron_left, size: 16, color: Colors.white)),
                    ),
                  SizedBox(width: 4),
                  if (index < _activeWidgets.length - 1)
                    GestureDetector(
                      onTap: () => _moveWidget(index, 1),
                      child: CircleAvatar(
                        radius: 14, 
                        backgroundColor: Colors.white24, 
                        child: Icon(Feather.chevron_right, size: 16, color: Colors.white)),
                    ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // --- Content Builder ---
  Widget _buildCardContent(GridItem item) {
    final def = _widgetDefinitions[item.type]!;

    // 1. Navigation Logic
    VoidCallback? onTap;
    if (!_isEditMode && def['onTap'] != null) {
      onTap = () => def['onTap'](context);
    }

    Widget baseContent = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(def['icon'], 
          size: item.mainAxisCount >= 3 ? 55 : 40, 
          color: AppColors.primaryLavender),
        SizedBox(height: 12),
        Text(
          def['name'],
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: item.mainAxisCount >= 3 ? 18 : 15,
            color: AppColors.textHigh,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (item.mainAxisCount >= 2) ...[
          SizedBox(height: 4),
          Text(def['desc'], 
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textMedium), 
            textAlign: TextAlign.center, 
            maxLines: 2)
        ]
      ],
    );

    // 2. Special Features Wrappers
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // A. Streak Logic
    if (def['hasStreak'] == true) {
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
              isActive = diff <= 1;
              if (diff > 1 && count > 0) isActive = false;
            }
          }
          return _buildBaseContainer(baseContent, onTap, 
            streakCount: count, streakActive: isActive);
        },
      );
    }

    // B. Cycle Logic
    if (def['isCycle'] == true) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('cycle_settings').doc('settings').snapshots(),
        builder: (context, snapshot) {
          CyclePhaseData? currentPhase;
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final Timestamp? lastPeriod = data['lastPeriodStart'];
            final int avgCycle = data['avgCycleLength'] ?? 28;
            final bool isPregnancy = data['isPregnancyMode'] ?? false;
            if (lastPeriod != null && !isPregnancy) {
              currentPhase = CycleService.getCurrentPhase(lastPeriod.toDate(), avgCycle);
            }
          }
          return _buildBaseContainer(baseContent, onTap, 
            cyclePhase: currentPhase);
        },
      );
    }

    // C. Standard Return
    return _buildBaseContainer(baseContent, onTap);
  }

  Widget _buildBaseContainer(Widget content, VoidCallback? onTap, 
      {int? streakCount, bool? streakActive, CyclePhaseData? cyclePhase}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24.0),
          border: Border.all(color: AppColors.elevation, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            Center(child: Padding(padding: const EdgeInsets.all(12.0), child: content)),
            
            // Streak Badge
            if (streakCount != null)
              Positioned(
                top: 12, 
                right: 12,
                child: GestureDetector(
                  onTap: (streakActive == false) ? () => _showRestorationModal(context, streakCount) : null,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.elevation, 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: streakActive! ? Colors.orange.withOpacity(0.5) : AppColors.textDisabled.withOpacity(0.3))
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          streakActive ? Ionicons.flame : Ionicons.flame_outline, 
                          size: 16, 
                          color: streakActive ? Colors.orange : AppColors.textDisabled),
                        SizedBox(width: 4),
                        Text("$streakCount", 
                          style: TextStyle(
                            color: streakActive ? AppColors.textHigh : AppColors.textDisabled, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),

            // Cycle Badge
            if (cyclePhase != null)
              Positioned(
                top: 12, 
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cyclePhase.bgColor, 
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: Offset(0,2))]
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cyclePhase.icon, size: 12, color: cyclePhase.textColor),
                      SizedBox(width: 6),
                      Text(cyclePhase.seasonName, 
                        style: TextStyle(
                          color: cyclePhase.textColor, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 11)),
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // --- Helpers (Logo, Avatar, etc) ---
  Widget _buildLogo() {
    return Container(
      width: 42, 
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        color: AppColors.elevation,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipOval(child: Image.asset('assets/default_avatar.png', fit: BoxFit.cover)),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 42, 
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle, 
        color: AppColors.elevation),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primaryLavender, size: 22), 
        onPressed: onTap),
    );
  }

  Widget _buildUserAvatar(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        String url = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          url = snapshot.data!.get('profileImage') ?? '';
        }
        return GestureDetector(
          onTap: () => Navigator.push(
            context, 
            MaterialPageRoute(builder: (c) => ProfileScreen(userId: uid))),
          child: Container(
            width: 42, 
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: AppColors.elevation),
            child: ClipOval(
              child: url.isNotEmpty 
                ? Image(image: CachedNetworkImageProvider(url), fit: BoxFit.cover)
                : Image.asset('assets/default_avatar.png', fit: BoxFit.cover),
            ),
          ),
        );
      },
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
}
