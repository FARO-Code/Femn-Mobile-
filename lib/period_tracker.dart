import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart'; // Using Feather Icons
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:femn/colors.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:femn/profile.dart';

// --- 1. Data Models ---

class DailyLog {
  final DateTime date;
  final String? flowIntensity;
  final List<String> symptoms;
  final List<String> moods;
  final bool sexualActivity;
  final bool protectedSex;
  final String? notes;

  DailyLog({
    required this.date,
    this.flowIntensity,
    this.symptoms = const [],
    this.moods = const [],
    this.sexualActivity = false,
    this.protectedSex = false,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'flowIntensity': flowIntensity,
      'symptoms': symptoms,
      'moods': moods,
      'sexualActivity': sexualActivity,
      'protectedSex': protectedSex,
      'notes': notes,
    };
  }

  factory DailyLog.fromDoc(Map<String, dynamic> data) {
    return DailyLog(
      date: (data['date'] as Timestamp).toDate(),
      flowIntensity: data['flowIntensity'],
      symptoms: List<String>.from(data['symptoms'] ?? []),
      moods: List<String>.from(data['moods'] ?? []),
      sexualActivity: data['sexualActivity'] ?? false,
      protectedSex: data['protectedSex'] ?? false,
      notes: data['notes'],
    );
  }
}

class HistoricalCycle {
  final DateTime startDate;
  final DateTime endDate;
  final List<DailyLog> logs;
  final int periodLength;

  HistoricalCycle({
    required this.startDate,
    required this.endDate,
    required this.logs,
    required this.periodLength,
  });

  int get length => endDate.difference(startDate).inDays + 1;
}

// --- 2. Cycle Logic Service ---

class CycleService {
  static const int kDefaultCycleLength = 28;

  static DateTime predictNextPeriod(DateTime lastPeriodStart, {int avgCycle = kDefaultCycleLength}) {
    return lastPeriodStart.add(Duration(days: avgCycle));
  }

  // --- NEW: Calculate Phase/Season ---
  static CyclePhaseData? getCurrentPhase(DateTime? lastPeriodStart, int cycleLength) {
    if (lastPeriodStart == null) return null;

    final now = DateTime.now();
    final diff = now.difference(lastPeriodStart).inDays;
    
    // Normalize day to current cycle (1-based index)
    // If diff is 30 and cycle is 28, day is 2.
    int currentDay = (diff % cycleLength) + 1; 

    // Logic for Seasons
    // Winter (Menstruation): Days 1-5
    if (currentDay <= 5) {
      return CyclePhaseData(
        seasonName: "Winter",
        phaseName: "Menstruation",
        bgColor: Color(0xFF102A43), // Midnight Navy
        textColor: Color(0xFFD9E2EC), // Frosty Ice Blue
        icon: Feather.cloud_snow,
      );
    }
    // Summer (Ovulation): Approx 14 days before end of cycle (+/- 1 day)
    // For 28 days, Ovulation is ~14. Range 13-15.
    int ovulationDay = cycleLength - 14; 
    if (currentDay >= ovulationDay - 1 && currentDay <= ovulationDay + 1) {
      return CyclePhaseData(
        seasonName: "Summer",
        phaseName: "Ovulation",
        bgColor: Color(0xFFFFD700), // Solar Gold
        textColor: Color(0xFF4E342E), // Dark Earth Brown
        icon: Feather.sun,
      );
    }
    // Spring (Follicular): After Winter, Before Summer
    if (currentDay > 5 && currentDay < ovulationDay - 1) {
      return CyclePhaseData(
        seasonName: "Spring",
        phaseName: "Follicular",
        bgColor: Color(0xFF98FB98), // Pale Mint Green
        textColor: Color(0xFF1B5E20), // Deep Fern Green
        icon: Feather.cloud_drizzle, // or a flower/sprout icon if available
      );
    }
    // Autumn (Luteal): After Summer, until end
    return CyclePhaseData(
      seasonName: "Autumn",
      phaseName: "Luteal",
      bgColor: Color(0xFFC0392B), // Deep Rust
      textColor: Color(0xFFFDF2E9), // Warm Vanilla
      icon: Feather.wind,
    );
  }
}

// --- 3. Security Service (User Specific) ---
class SecurityService {
  // Keys are now dynamic based on UID to prevent multi-user conflict
  static String _pinKey(String uid) => 'user_journal_pin_$uid';
  static String _lockEnabledKey(String uid) => 'journal_lock_enabled_$uid';

  static Future<bool> isLockEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lockEnabledKey(uid)) ?? false;
  }

  static Future<void> setLockEnabled(String uid, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockEnabledKey(uid), enabled);
  }

  static Future<bool> checkPin(String uid, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedPin = prefs.getString(_pinKey(uid));
    return storedPin == pin;
  }

  static Future<void> setPin(String uid, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey(uid), pin);
  }
}

// --- 4. Main Screen ---

class PeriodTrackerScreen extends StatefulWidget {
  @override
  _PeriodTrackerScreenState createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  
  // State
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<String>> _calendarEvents = {}; 
  Map<DateTime, DailyLog> _logsMap = {}; 
  List<HistoricalCycle> _historyCycles = [];
  
  // Settings & Flags
  bool _isPregnancyMode = false;
  int _avgCycleLength = 28;
  DateTime? _lastPeriodStart;
  
  bool _isLoading = true;
  bool _isLocked = false; 
  bool _isFirstTimeSetup = false;
  
  // Chart State
  int _touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedDay = _focusedDay;
    _initialCheck();
  }

  Future<void> _initialCheck() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Check lock specifically for this user
    bool enabled = await SecurityService.isLockEnabled(user.uid);
    if (enabled) {
      setState(() {
        _isLocked = true;
        _isLoading = false;
      });
    } else {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return; 
      }
      final uid = user.uid;

      // 1. Check if settings exist (Determines Onboarding)
      DocumentSnapshot<Map<String, dynamic>> settingsDoc;
      try {
        settingsDoc = await _firestore
            .collection('users')
            .doc(uid)
            .collection('cycle_settings')
            .doc('settings')
            .get();
      } catch (e) {
        rethrow; 
      }

      if (!settingsDoc.exists) {
        setState(() {
          _isFirstTimeSetup = true;
          _isLoading = false;
        });
        return;
      }

      final data = settingsDoc.data()!;
      _isPregnancyMode = data['isPregnancyMode'] ?? false;
      _avgCycleLength = data['avgCycleLength'] ?? 28;
      
      // If manual start date was saved in settings (from onboarding), use it as fallback
      if (data['lastPeriodStart'] != null) {
        _lastPeriodStart = (data['lastPeriodStart'] as Timestamp).toDate();
      }

      // 2. Load Logs
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('cycle_logs')
          .orderBy('date')
          .get();

      final Map<DateTime, DailyLog> logsMap = {};
      final Map<DateTime, List<String>> events = {};
      final List<DailyLog> allLogsList = [];

      for (var doc in snap.docs) {
        final log = DailyLog.fromDoc(doc.data());
        final dateKey = DateTime(log.date.year, log.date.month, log.date.day);

        logsMap[dateKey] = log;
        allLogsList.add(log);

        List<String> markers = [];
        if (log.flowIntensity != null) markers.add('period');
        if (log.sexualActivity) markers.add('intimacy');
        if (log.symptoms.isNotEmpty) markers.add('symptom');
        events[dateKey] = markers;
      }

      _historyCycles = _calculateCycles(allLogsList);

      // If we have history, the latest cycle start is the authority. 
      // If no logs yet, we rely on the onboarding 'lastPeriodStart'.
      if (_historyCycles.isNotEmpty) {
        _lastPeriodStart = _historyCycles.last.startDate;
      }

      if (mounted) {
        setState(() {
          _logsMap = logsMap;
          _calendarEvents = events;
          _isLoading = false;
          _isFirstTimeSetup = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network unavailable. Please checks your internet."),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<HistoricalCycle> _calculateCycles(List<DailyLog> logs) {
    if (logs.isEmpty) return [];
    
    List<HistoricalCycle> cycles = [];
    logs.sort((a, b) => a.date.compareTo(b.date));

    List<DailyLog> currentCycleLogs = [];
    DateTime? cycleStart;
    DateTime? lastFlowDate;
    int currentPeriodDays = 0;

    for (var log in logs) {
      bool isFlow = log.flowIntensity != null;

      if (isFlow) {
        // If gap is large, it's a new cycle
        if (lastFlowDate != null && log.date.difference(lastFlowDate!).inDays > 10) {
          if (cycleStart != null) {
            cycles.add(HistoricalCycle(
              startDate: cycleStart,
              endDate: log.date.subtract(Duration(days: 1)),
              logs: List.from(currentCycleLogs),
              periodLength: currentPeriodDays,
            ));
          }
          cycleStart = log.date;
          currentCycleLogs = [];
          currentPeriodDays = 0;
        }
        
        if (cycleStart == null) cycleStart = log.date;
        lastFlowDate = log.date;
        currentPeriodDays++;
      }
      
      if (cycleStart != null) {
        currentCycleLogs.add(log);
      }
    }

    if (cycleStart != null) {
      cycles.add(HistoricalCycle(
        startDate: cycleStart,
        endDate: DateTime.now(),
        logs: currentCycleLogs,
        periodLength: currentPeriodDays,
      ));
    }

    return cycles.reversed.toList();
  }

  // --- 🎨 UI Helper for Circular Buttons ---
  Widget _buildCircleAction({required Widget child, required VoidCallback onTap}) {
    return Container(
      width: 42, height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.elevation,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: child,
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Lock Screen Check
    if (_isLocked) {
      return PinScreen(
        mode: PinMode.unlock,
        onSuccess: () {
          setState(() => _isLocked = false);
          _loadData();
        },
      );
    }

    // 2. Loading State
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDeep, 
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
      );
    }

    // 3. Onboarding Check
    if (_isFirstTimeSetup) {
      return OnboardingWizard(
        onCompleted: () async {
          // Refresh data to load the newly saved settings
          await _loadData();
        },
      );
    }

    // 4. Main App Content
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        foregroundColor: AppColors.textHigh,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.elevation,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 2)),
                ],
              ),
              child: ClipOval(
                child: Image.asset('assets/femnlogo.png', fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(Feather.circle, color: AppColors.primaryLavender),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text('Flow', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          ],
        ),
        actions: [
          // 1. PDF Button (Left)
          _buildCircleAction(
            child: Icon(Feather.file_text, color: AppColors.primaryLavender, size: 22),
            onTap: _generatePDFReport,
          ),
          const SizedBox(width: 8),

          // 2. Settings Button (Middle)
          _buildCircleAction(
            child: Icon(Feather.settings, color: AppColors.primaryLavender, size: 22),
            onTap: _showSettingsModal,
          ),
          const SizedBox(width: 8),
          
          // 3. Profile Picture (Far Right)
          FutureBuilder<DocumentSnapshot>(
            future: _firestore.collection('users').doc(_auth.currentUser?.uid).get(),
            builder: (context, snapshot) {
              Widget avatar;
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || !snapshot.data!.exists) {
                avatar = Image.asset('assets/default_avatar.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Feather.user, color: AppColors.textMedium));
              } else {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final String profileImage = userData['profileImage'] ?? '';
                avatar = profileImage.isNotEmpty
                  ? CachedNetworkImage(imageUrl: profileImage, fit: BoxFit.cover)
                  : Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
              }

              return GestureDetector(
                onTap: () {
                  final uid = _auth.currentUser!.uid; 
                  Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => ProfileScreen(userId: uid))
                  );
                },
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.elevation,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 15, offset: const Offset(0, 2))],
                  ),
                  child: ClipOval(child: avatar),
                ),
              );
            },
          ),
          const SizedBox(width: 16), // Extra padding on right
        ],
      ),

      body: Column(
        children: [
          Container(
            color: AppColors.backgroundDeep,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryLavender,
              unselectedLabelColor: AppColors.textMedium,
              indicatorColor: AppColors.primaryLavender,
              tabs: [
                Tab(text: "Calendar"),
                Tab(text: "Insights"),
                Tab(text: "History"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCalendarTab(),
                _buildInsightsTab(),
                _buildHistoryTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogSheet(_selectedDay ?? DateTime.now()),
        backgroundColor: AppColors.accentMustard,
        icon: Icon(Feather.plus, color: AppColors.backgroundDeep), // Feather Icon
        label: Text("Log", style: TextStyle(color: AppColors.backgroundDeep, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- 📅 Tab 1: Calendar ---
  Widget _buildCalendarTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          if (_lastPeriodStart != null && !_isPregnancyMode) ...[
            SizedBox(height: 16),
            _buildCycleDashboard(),
          ],
          if (_isPregnancyMode) ...[
             SizedBox(height: 16),
             _buildPregnancyDashboard(),
          ],
          
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) {
              final dateKey = DateTime(day.year, day.month, day.day);
              return _calendarEvents[dateKey] ?? [];
            },
            calendarStyle: CalendarStyle(
              defaultTextStyle: TextStyle(color: AppColors.textHigh),
              weekendTextStyle: TextStyle(color: AppColors.textMedium),
              todayDecoration: BoxDecoration(color: AppColors.secondaryTeal.withOpacity(0.5), shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: AppColors.primaryLavender, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: AppColors.accentMustard, shape: BoxShape.circle),
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(color: AppColors.textHigh, fontSize: 18, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(Feather.chevron_left, color: AppColors.primaryLavender), // Feather
              rightChevronIcon: Icon(Feather.chevron_right, color: AppColors.primaryLavender), // Feather
            ),
          ),
          Divider(color: AppColors.textDisabled),
          if (_selectedDay != null) _buildDayDetail(_selectedDay!),
        ],
      ),
    );
  }

  Widget _buildCycleDashboard() {
    // Safety check in case _lastPeriodStart is null (shouldn't be here if logic is correct)
    if (_lastPeriodStart == null) return SizedBox();

    final nextPeriod = CycleService.predictNextPeriod(_lastPeriodStart!, avgCycle: _avgCycleLength);
    final daysUntil = nextPeriod.difference(DateTime.now()).inDays;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoPill("Next Period", "$daysUntil Days", Feather.droplet, AppColors.primaryLavender), // Feather
          _buildInfoPill("Phase", "Luteal", Feather.clock, AppColors.secondaryTeal), // Feather
        ],
      ),
    );
  }

  Widget _buildPregnancyDashboard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primaryLavender)
      ),
      child: Row(
        children: [
           CircularPercentIndicator(
             radius: 35.0, lineWidth: 8.0, percent: 0.3,
             center: Text("12\nWeeks", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textHigh)),
             progressColor: AppColors.primaryLavender, backgroundColor: AppColors.elevation,
           ),
           SizedBox(width: 20),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text("Baby is the size of a Plum!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textHigh)),
                 Text("Keep tracking your vitamins.", style: TextStyle(color: AppColors.textMedium)),
               ],
             ),
           )
        ],
      ),
    );
  }

  Widget _buildInfoPill(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        CircleAvatar(backgroundColor: AppColors.elevation, radius: 20, child: Icon(icon, color: color, size: 20)),
        SizedBox(height: 8),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textHigh)),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
      ],
    );
  }

  Widget _buildDayDetail(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    final log = _logsMap[dateKey];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('EEEE, MMM d').format(date), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 10),
          if (log == null) Text("No data logged.", style: TextStyle(color: AppColors.textDisabled)),
          if (log != null) ...[
            if (log.flowIntensity != null) _buildDetailRow("Flow", log.flowIntensity!, Feather.droplet, AppColors.error), // Feather
            if (log.moods.isNotEmpty) _buildDetailRow("Mood", log.moods.join(", "), Feather.smile, AppColors.accentMustard), // Feather
            if (log.symptoms.isNotEmpty) _buildDetailRow("Symptoms", log.symptoms.join(", "), Feather.activity, AppColors.primaryLavender), // Feather
          ]
        ],
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 8),
          Text("$title: ", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textMedium))),
        ],
      ),
    );
  }

  // --- 📈 Tab 2: Insights (Animated Pie Chart) ---
  Widget _buildInsightsTab() {
    Map<String, int> stats = {'Cramps': 0, 'Headache': 0, 'Bloating': 0, 'Acne': 0};
    _logsMap.values.forEach((log) {
      for (var s in log.symptoms) {
        if (stats.containsKey(s)) stats[s] = (stats[s] ?? 0) + 1;
      }
    });

    int total = 0;
    stats.forEach((_, v) => total += v);
    
    // Prepare Data for Pie Chart
    List<PieChartSectionData> showingSections() {
      return List.generate(stats.length, (i) {
        final isTouched = i == _touchedIndex;
        final fontSize = isTouched ? 20.0 : 14.0;
        final radius = isTouched ? 110.0 : 100.0;
        
        final key = stats.keys.elementAt(i);
        final value = stats[key] ?? 0;
        final percent = total > 0 ? (value / total) * 100 : 0;

        Color color;
        switch (i) {
          case 0: color = AppColors.primaryLavender; break;
          case 1: color = AppColors.secondaryTeal; break;
          case 2: color = AppColors.accentMustard; break;
          default: color = AppColors.error;
        }

        return PieChartSectionData(
          color: color,
          value: value.toDouble(),
          title: '${percent.toStringAsFixed(0)}%',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: const Color(0xffffffff),
          ),
          badgeWidget: isTouched ? Container(
             padding: EdgeInsets.all(4),
             color: Colors.white,
             child: Text(key, style: TextStyle(fontSize: 10, color: Colors.black)),
          ) : null,
          badgePositionPercentageOffset: .98,
        );
      });
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text("Symptom Patterns", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 20),
          
          // Large Pie Chart Container
          SizedBox(
            height: 350, // Make it large so screen doesn't feel empty
            child: total == 0 
            ? Center(child: Text("Not enough data yet", style: TextStyle(color: AppColors.textDisabled)))
            : PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          _touchedIndex = -1;
                          return;
                        }
                        _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2, // Space between slices
                  centerSpaceRadius: 40, // Donut style
                  sections: showingSections(),
                ),
                swapAnimationDuration: Duration(milliseconds: 800), // Smooth Animation
                swapAnimationCurve: Curves.easeInOutQuint,
              ),
          ),
          
          SizedBox(height: 30),
          // Legend
          Wrap(
            spacing: 16, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: List.generate(stats.length, (i) {
               final key = stats.keys.elementAt(i);
               Color color;
                switch (i) {
                  case 0: color = AppColors.primaryLavender; break;
                  case 1: color = AppColors.secondaryTeal; break;
                  case 2: color = AppColors.accentMustard; break;
                  default: color = AppColors.error;
                }
               return Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Container(width: 12, height: 12, color: color),
                   SizedBox(width: 4),
                   Text(key, style: TextStyle(color: AppColors.textMedium))
                 ],
               );
            }),
          )
        ],
      ),
    );
  }

  // --- 📜 Tab 3: History (The "Cycle Stream") ---

  Widget _buildHistoryTab() {
    if (_historyCycles.isEmpty) {
      return Center(
        child: Text("Log your periods to see history.", style: TextStyle(color: AppColors.textMedium)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _historyCycles.length,
      itemBuilder: (context, index) {
        final cycle = _historyCycles[index];
        return _buildCycleCard(cycle);
      },
    );
  }

  Widget _buildCycleCard(HistoricalCycle cycle) {
    final isRegular = (cycle.length - _avgCycleLength).abs() <= 3;
    final regularityLabel = isRegular ? "Regular" : (cycle.length > _avgCycleLength ? "Late" : "Early");
    final regularityColor = isRegular ? AppColors.success : AppColors.accentMustard;
    
    List<Widget> miniMapSegments = [];
    for (int i = 0; i < cycle.length && i < 30; i++) {
      final date = cycle.startDate.add(Duration(days: i));
      final dateKey = DateTime(date.year, date.month, date.day);
      final log = _logsMap[dateKey];
      final isFlow = log?.flowIntensity != null;
      
      miniMapSegments.add(
        Expanded(
          child: Container(
            height: 6,
            margin: EdgeInsets.symmetric(horizontal: 0.5),
            decoration: BoxDecoration(
              color: isFlow ? AppColors.primaryLavender : AppColors.elevation,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        )
      );
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 16),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.elevation),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.all(16),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('MMMM yyyy').format(cycle.startDate),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textHigh),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: regularityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(regularityLabel, style: TextStyle(color: regularityColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildCycleStat("Cycle Length", "${cycle.length} Days", cycle.length != _avgCycleLength),
                  SizedBox(width: 20),
                  _buildCycleStat("Period", "${cycle.periodLength} Days", false),
                  Spacer(),
                  Text(
                    "${DateFormat('MMM d').format(cycle.startDate)} - ${DateFormat('MMM d').format(cycle.endDate)}",
                    style: TextStyle(fontSize: 12, color: AppColors.textMedium),
                  )
                ],
              ),
              SizedBox(height: 12),
              Row(children: miniMapSegments),
            ],
          ),
          
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: AppColors.elevation.withOpacity(0.5)),
              child: Column(
                children: cycle.logs.map((log) {
                  final cycleDay = log.date.difference(cycle.startDate).inDays + 1;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Day $cycleDay", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLavender)),
                              Text(DateFormat('MMM d').format(log.date), style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
                            ],
                          ),
                        ),
                        
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (log.flowIntensity != null)
                                _buildMicroTag(Feather.droplet, log.flowIntensity!, AppColors.error), // Feather
                              if (log.symptoms.isNotEmpty)
                                ...log.symptoms.map((s) => _buildMicroTag(Feather.activity, s, AppColors.primaryLavender)), // Feather
                              if (log.moods.isNotEmpty)
                                ...log.moods.map((m) => _buildMicroTag(Feather.smile, m, AppColors.accentMustard)), // Feather
                              if (log.sexualActivity)
                                _buildMicroTag(Feather.heart, "Intimacy", Colors.pink), // Feather
                              if (log.notes != null && log.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                    "\"${log.notes}\"",
                                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.textMedium),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCycleStat(String label, String value, bool isDeviation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: 14, 
          color: isDeviation ? AppColors.accentMustard : AppColors.textHigh
        )),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
      ],
    );
  }

  Widget _buildMicroTag(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.elevation)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: AppColors.textMedium)),
        ],
      ),
    );
  }

  // --- 📝 Daily Log Sheet Widget ---

  void _showLogSheet(DateTime date) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundDeep,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: DailyLogSheet(
            date: date,
            onSave: (log) async {
              final uid = _auth.currentUser!.uid;
              final dateKey = DateTime(log.date.year, log.date.month, log.date.day);
              await _firestore
                  .collection('users')
                  .doc(uid)
                  .collection('cycle_logs')
                  .doc(dateKey.toIso8601String())
                  .set(log.toMap());
              
              await _loadData(); 
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  // --- ⚙️ Settings Modal ---
  void _showSettingsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cycle Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  SizedBox(height: 20),
                  
                  // Pregnancy Toggle
                  SwitchListTile(
                    title: Text("Pregnancy Mode", style: TextStyle(color: AppColors.textHigh)),
                    subtitle: Text("Pause period predictions", style: TextStyle(color: AppColors.textMedium)),
                    value: _isPregnancyMode,
                    activeColor: AppColors.primaryLavender,
                    onChanged: (val) {
                      setModalState(() => _isPregnancyMode = val);
                      setState(() => _isPregnancyMode = val);
                      final uid = _auth.currentUser!.uid;
                      _firestore.collection('users').doc(uid).collection('cycle_settings').doc('settings').set({
                        'isPregnancyMode': val,
                      }, SetOptions(merge: true));
                    },
                  ),
                  Divider(color: AppColors.elevation),
                  
                  // Custom Input for Cycle Length
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Text("Average Cycle Length (Days)", style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.elevation,
                      borderRadius: BorderRadius.circular(12)
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Feather.minus, color: AppColors.primaryLavender),
                          onPressed: () {
                             if (_avgCycleLength > 20) {
                               setModalState(() => _avgCycleLength--);
                               setState(() => _avgCycleLength = _avgCycleLength);
                               _saveCycleLength(_avgCycleLength);
                             }
                          },
                        ),
                        Text("$_avgCycleLength", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                        IconButton(
                          icon: Icon(Feather.plus, color: AppColors.primaryLavender),
                          onPressed: () {
                             if (_avgCycleLength < 60) {
                               setModalState(() => _avgCycleLength++);
                               setState(() => _avgCycleLength = _avgCycleLength);
                               _saveCycleLength(_avgCycleLength);
                             }
                          },
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text("Typical cycles range from 21 to 35 days.", style: TextStyle(color: AppColors.textDisabled, fontSize: 12, fontStyle: FontStyle.italic)),
                  ),
                  SizedBox(height: 20),
                  
                  // Toggle Lock
                  ListTile(
                    title: Text("App Lock", style: TextStyle(color: AppColors.textHigh)),
                    subtitle: Text("Enable PIN protection", style: TextStyle(color: AppColors.textMedium)),
                    trailing: Icon(Feather.lock, color: AppColors.primaryLavender),
                    onTap: () {
                       Navigator.pop(context);
                       _setupPin();
                    },
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }
  
  void _setupPin() {
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => PinScreen(
        mode: PinMode.setup, 
        onSuccess: () async {
          final uid = _auth.currentUser!.uid;
          await SecurityService.setLockEnabled(uid, true);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lock enabled")));
        }
      ))
    );
  }

  void _saveCycleLength(int length) {
    final uid = _auth.currentUser!.uid;
    _firestore.collection('users').doc(uid).collection('cycle_settings').doc('settings').set({
      'avgCycleLength': length,
    }, SetOptions(merge: true));
  }

  // --- 📄 PDF Report ---
  Future<void> _generatePDFReport() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Column(
              children: [
                pw.Text("Femn Cycle Report", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Table.fromTextArray(context: context, data: <List<String>>[
                  <String>['Date', 'Flow', 'Symptoms'],
                  ..._logsMap.values.map((l) => [
                    DateFormat('yyyy-MM-dd').format(l.date),
                    l.flowIntensity ?? '-',
                    l.symptoms.join(', ')
                  ]).toList()
                ]),
              ],
            )
          );
        },
      ),
    );
  }
}

// --- 5. Onboarding Wizard ---

class OnboardingWizard extends StatefulWidget {
  final VoidCallback onCompleted;
  OnboardingWizard({required this.onCompleted});

  @override
  _OnboardingWizardState createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  
  // Data to Collect
  DateTime _lastPeriod = DateTime.now();
  int _cycleLength = 28;
  int _periodLength = 5;
  bool _isRegular = true;
  bool _hormonalBirthControl = false;
  String _goal = "Track my cycle";
  bool _enablePin = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / 4,
                backgroundColor: AppColors.elevation,
                color: AppColors.primaryLavender,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _controller,
                physics: NeverScrollableScrollPhysics(), // Prevent swiping, force button use
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _buildStepBasics(),
                  _buildStepHistory(),
                  _buildStepGoals(),
                  _buildStepSecurity(),
                ],
              ),
            ),
            
            // Bottom Nav
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(duration: Duration(milliseconds: 300), curve: Curves.ease),
                      child: Text("Back", style: TextStyle(color: AppColors.textMedium)),
                    )
                  else
                    SizedBox(),
                    
                  ElevatedButton(
                    onPressed: _handleNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLavender,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12)
                    ),
                    child: Text(
                      _currentPage == 3 ? "Finish" : "Next", 
                      style: TextStyle(color: AppColors.backgroundDeep, fontWeight: FontWeight.bold)
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
  
  void _handleNext() async {
    if (_currentPage < 3) {
      _controller.nextPage(duration: Duration(milliseconds: 300), curve: Curves.ease);
    } else {
      // Save all data
      await _saveAndFinish();
    }
  }

  Future<void> _saveAndFinish() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('cycle_settings')
        .doc('settings')
        .set({
          'lastPeriodStart': Timestamp.fromDate(_lastPeriod),
          'avgCycleLength': _cycleLength,
          'avgPeriodLength': _periodLength,
          'isRegular': _isRegular,
          'hormonalBirthControl': _hormonalBirthControl,
          'goal': _goal,
          'isPregnancyMode': false,
        });

    if (_enablePin) {
       // Navigate to PIN setup, then finish
       await Navigator.push(
         context, 
         MaterialPageRoute(builder: (context) => PinScreen(
           mode: PinMode.setup, 
           onSuccess: () async {
             await SecurityService.setLockEnabled(user.uid, true);
             Navigator.pop(context); // Close pin screen
           }
         ))
       );
    }
    
    widget.onCompleted();
  }

  // --- Step 1: Basics ---
  Widget _buildStepBasics() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("The Basics", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 10),
          Text("These are mandatory for accurate predictions.", style: TextStyle(color: AppColors.textMedium)),
          SizedBox(height: 30),
          
          Text("When did your last period start?", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 10),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context, 
                initialDate: _lastPeriod, 
                firstDate: DateTime(2020), 
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: ColorScheme.light(primary: AppColors.primaryLavender),
                    ),
                    child: child!,
                  );
                }
              );
              if (d != null) setState(() => _lastPeriod = d);
            },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.elevation, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat.yMMMMd().format(_lastPeriod), style: TextStyle(color: AppColors.textHigh)),
                  Icon(Feather.calendar, color: AppColors.primaryLavender)
                ],
              ),
            ),
          ),
          
          SizedBox(height: 30),
          Text("Typical Cycle Length: $_cycleLength days", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          Slider(
            value: _cycleLength.toDouble(),
            min: 21, max: 45, divisions: 24,
            activeColor: AppColors.primaryLavender,
            inactiveColor: AppColors.elevation,
            onChanged: (v) => setState(() => _cycleLength = v.toInt()),
          ),
          
          SizedBox(height: 10),
          Text("Typical Period Duration: $_periodLength days", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          Slider(
            value: _periodLength.toDouble(),
            min: 1, max: 10, divisions: 9,
            activeColor: AppColors.secondaryTeal,
            inactiveColor: AppColors.elevation,
            onChanged: (v) => setState(() => _periodLength = v.toInt()),
          ),
        ],
      ),
    );
  }

  // --- Step 2: History ---
  Widget _buildStepHistory() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Context", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 10),
          Text("Help us filter outliers.", style: TextStyle(color: AppColors.textMedium)),
          SizedBox(height: 30),
          
          SwitchListTile(
            title: Text("Is your cycle regular?", style: TextStyle(color: AppColors.textHigh)),
            subtitle: Text("Doesn't vary by more than a few days", style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
            value: _isRegular,
            activeColor: AppColors.primaryLavender,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _isRegular = v),
          ),
          Divider(color: AppColors.elevation),
          SwitchListTile(
            title: Text("Hormonal Birth Control?", style: TextStyle(color: AppColors.textHigh)),
            subtitle: Text("Pill, IUD, etc. (May affect predictions)", style: TextStyle(color: AppColors.textMedium, fontSize: 12)),
            value: _hormonalBirthControl,
            activeColor: AppColors.accentMustard,
            contentPadding: EdgeInsets.zero,
            onChanged: (v) => setState(() => _hormonalBirthControl = v),
          ),
        ],
      ),
    );
  }

  // --- Step 3: Goals ---
  Widget _buildStepGoals() {
    final goals = ["Track my cycle", "Track symptoms", "Get pregnant", "Avoid pregnancy"];
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your Goal", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 30),
          ...goals.map((g) => RadioListTile(
            title: Text(g, style: TextStyle(color: AppColors.textHigh)),
            value: g,
            groupValue: _goal,
            activeColor: AppColors.primaryLavender,
            onChanged: (v) => setState(() => _goal = v.toString()),
          )).toList()
        ],
      ),
    );
  }
  
  // --- Step 4: Security ---
  Widget _buildStepSecurity() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Privacy", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
          SizedBox(height: 10),
          Text("Keep your health data private.", style: TextStyle(color: AppColors.textMedium)),
          SizedBox(height: 30),
          
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _enablePin ? AppColors.primaryLavender : AppColors.elevation, width: 2)
            ),
            child: Column(
              children: [
                Icon(Feather.lock, size: 40, color: _enablePin ? AppColors.primaryLavender : AppColors.textDisabled),
                SizedBox(height: 20),
                SwitchListTile(
                  title: Text("Enable PIN Lock", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                  subtitle: Text("Secure app entry", style: TextStyle(color: AppColors.textMedium)),
                  value: _enablePin,
                  activeColor: AppColors.primaryLavender,
                  onChanged: (v) => setState(() => _enablePin = v),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- 📝 Daily Log Sheet Widget ---
class DailyLogSheet extends StatefulWidget {
  final DateTime date;
  final Function(DailyLog) onSave;

  DailyLogSheet({required this.date, required this.onSave});

  @override
  _DailyLogSheetState createState() => _DailyLogSheetState();
}

class _DailyLogSheetState extends State<DailyLogSheet> {
  String? _flow;
  List<String> _symptoms = [];
  List<String> _moods = [];
  bool _sexualActivity = false;
  bool _protected = false;
  TextEditingController _notesController = TextEditingController();

  final List<String> _flowOptions = ['Spotting', 'Light', 'Medium', 'Heavy', 'Clotting'];
  final List<String> _symptomOptions = ['Cramps', 'Headache', 'Bloating', 'Acne', 'Nausea'];
  final List<String> _moodOptions = ['Happy', 'Sad', 'Anxious', 'Irritable', 'Energetic'];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20),
      children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textDisabled, borderRadius: BorderRadius.circular(2)))),
        SizedBox(height: 20),
        Text("Log for ${DateFormat('MMM d').format(widget.date)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
        SizedBox(height: 20),
        
        _buildSectionHeader("Flow Intensity"),
        Wrap(
          spacing: 8,
          children: _flowOptions.map((f) => ChoiceChip(
            label: Text(f),
            selected: _flow == f,
            onSelected: (val) => setState(() => _flow = val ? f : null),
            selectedColor: AppColors.primaryLavender,
            backgroundColor: AppColors.elevation,
            labelStyle: TextStyle(color: _flow == f ? AppColors.backgroundDeep : AppColors.textHigh),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.elevation)),
          )).toList(),
        ),

        SizedBox(height: 20),
        _buildSectionHeader("Symptoms"),
        Wrap(
          spacing: 8,
          children: _symptomOptions.map((s) => FilterChip(
            label: Text(s),
            selected: _symptoms.contains(s),
            onSelected: (val) => setState(() => val ? _symptoms.add(s) : _symptoms.remove(s)),
            selectedColor: AppColors.secondaryTeal,
            backgroundColor: AppColors.elevation,
            labelStyle: TextStyle(color: _symptoms.contains(s) ? Colors.white : AppColors.textHigh),
            checkmarkColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.elevation)),
          )).toList(),
        ),

        SizedBox(height: 20),
        _buildSectionHeader("Mood"),
        Wrap(
          spacing: 8,
          children: _moodOptions.map((m) => FilterChip(
            label: Text(m),
            selected: _moods.contains(m),
            onSelected: (val) => setState(() => val ? _moods.add(m) : _moods.remove(m)),
            selectedColor: AppColors.accentMustard,
            backgroundColor: AppColors.elevation,
            labelStyle: TextStyle(color: _moods.contains(m) ? AppColors.backgroundDeep : AppColors.textHigh),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.elevation)),
          )).toList(),
        ),

        SizedBox(height: 20),
        _buildSectionHeader("Intimacy"),
        SwitchListTile(
          title: Text("Sexual Activity", style: TextStyle(color: AppColors.textHigh)), 
          value: _sexualActivity, 
          activeColor: AppColors.primaryLavender, 
          onChanged: (val) => setState(() => _sexualActivity = val)
        ),
        if (_sexualActivity) CheckboxListTile(
          title: Text("Protected?", style: TextStyle(color: AppColors.textHigh)), 
          value: _protected, 
          activeColor: AppColors.primaryLavender, 
          onChanged: (val) => setState(() => _protected = val ?? false)
        ),

        SizedBox(height: 20),
        _buildSectionHeader("Notes"),
        TextField(
          controller: _notesController, 
          style: TextStyle(color: AppColors.textHigh),
          decoration: InputDecoration(
            hintText: "Add notes...", 
            hintStyle: TextStyle(color: AppColors.textDisabled),
            filled: true,
            fillColor: AppColors.elevation,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          ), 
          maxLines: 3
        ),

        SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            final log = DailyLog(
              date: widget.date,
              flowIntensity: _flow,
              symptoms: _symptoms,
              moods: _moods,
              sexualActivity: _sexualActivity,
              protectedSex: _protected,
              notes: _notesController.text,
            );
            widget.onSave(log);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLavender, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: EdgeInsets.symmetric(vertical: 16)),
          child: Text("Save Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.backgroundDeep)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)));
  }
}

// --- 6. PIN Screen ---

enum PinMode { setup, verify, unlock }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final VoidCallback onSuccess;

  PinScreen({required this.mode, required this.onSuccess});

  @override
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _input = "";
  String _tempPin = "";
  String _message = "Enter PIN";

  @override
  void initState() {
    super.initState();
    _updateMessage();
  }

  void _updateMessage() {
    setState(() {
      if (widget.mode == PinMode.setup) {
        _message = _tempPin.isEmpty ? "Create a 4-digit PIN" : "Confirm your PIN";
      } else if (widget.mode == PinMode.unlock) {
        _message = "Welcome Back";
      } else {
        _message = "Enter current PIN";
      }
    });
  }

  void _onKeyPress(String val) async {
    if (_input.length < 4) {
      setState(() => _input += val);
    }
    if (_input.length == 4) {
      _handleSubmit();
    }
  }

  void _handleSubmit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return; // Should not happen in this flow

    if (widget.mode == PinMode.unlock || widget.mode == PinMode.verify) {
      bool isValid = await SecurityService.checkPin(uid, _input);
      if (isValid) {
        widget.onSuccess();
      } else {
        setState(() {
          _input = "";
          _message = "Incorrect PIN";
        });
      }
    } else if (widget.mode == PinMode.setup) {
      if (_tempPin.isEmpty) {
        setState(() {
          _tempPin = _input;
          _input = "";
          _updateMessage();
        });
      } else {
        if (_input == _tempPin) {
          await SecurityService.setPin(uid, _input);
          widget.onSuccess();
        } else {
          setState(() {
            _input = "";
            _tempPin = "";
            _message = "Mismatch. Start over.";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)]),
              child: Icon(Feather.lock, size: 40, color: AppColors.primaryLavender), // Feather
            ),
            SizedBox(height: 30),
            Text(_message, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
            SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  margin: EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _input.length ? AppColors.primaryLavender : AppColors.elevation,
                  ),
                );
              }),
            ),
            SizedBox(height: 50),
            _buildNumPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumPad() {
    return Container(
      width: 280,
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 1.5,
        physics: NeverScrollableScrollPhysics(),
        children: [
          ...List.generate(9, (i) => _buildNumBtn("${i + 1}")),
          SizedBox(), 
          _buildNumBtn("0"),
          IconButton(
            icon: Icon(Feather.delete, color: AppColors.primaryLavender), // Feather delete
            onPressed: () {
              if (_input.isNotEmpty) setState(() => _input = _input.substring(0, _input.length - 1));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNumBtn(String val) {
    return GestureDetector(
      onTap: () => _onKeyPress(val),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface),
        child: Center(
          child: Text(val, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
        ),
      ),
    );
  }
}

class CyclePhaseData {
  final String seasonName; // Winter, Spring, Summer, Autumn
  final String phaseName;  // Menstruation, Follicular, etc.
  final Color bgColor;
  final Color textColor;
  final IconData icon;

  CyclePhaseData({
    required this.seasonName,
    required this.phaseName,
    required this.bgColor,
    required this.textColor,
    required this.icon,
  });
}