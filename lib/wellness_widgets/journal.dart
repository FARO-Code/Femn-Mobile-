import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:femn/hub_screens/profile.dart'; 
import 'package:femn/auth/auth.dart'; 
import 'package:femn/customization/colors.dart'; 
import '../services/streak_service.dart';

// --- 1. Security Service (Updated for UID) ---
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

// --- 2. Main Journal Screen ---

class JournalScreen extends StatefulWidget {
  @override
  _JournalScreenState createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLocked = true;
  bool _isLoading = true;
  
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _filterMood; 

  @override
  void initState() {
    super.initState();
    _checkLockStatus();
  }

  Future<void> _checkLockStatus() async {
    final user = _auth.currentUser;
    if (user != null) {
      bool enabled = await SecurityService.isLockEnabled(user.uid);
      if (!enabled) {
        setState(() {
          _isLocked = false;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
       setState(() => _isLoading = false);
    }
  }

  // --- Helper for Circular Buttons ---
  Widget _buildFemnActionButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 42,
      height: 42,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.elevation, // Dark container
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.primaryLavender, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(backgroundColor: AppColors.backgroundDeep, body: Center(child: CircularProgressIndicator(color: AppColors.primaryLavender)));

    if (_isLocked) {
      return PinScreen(
        mode: PinMode.unlock,
        onSuccess: () => setState(() => _isLocked = false),
      );
    }

    final currentUserId = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      
      // --- App Bar ---
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
            const SizedBox(width: 8),
            const Text(
              'Journal',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textHigh),
            ),
          ],
        ),
        actions: [
          // 1. Calendar Button
          _buildFemnActionButton(
            icon: Feather.calendar, 
            onTap: _showCalendarModal
          ),

          // 2. Settings Button (Moved to middle)
          _buildFemnActionButton(
            icon: Feather.settings, 
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (context) => JournalSettingsScreen())
              );
            }
          ),
          
          // 3. User Profile Button
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
            builder: (context, snapshot) {
              Widget avatar;
              if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData || !snapshot.data!.exists) {
                avatar = Image.asset('assets/default_avatar.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => Icon(Feather.user, color: AppColors.textMedium));
              } else {
                final user = snapshot.data!.data() as Map<String, dynamic>;
                final profileImage = user['profileImage'] ?? '';
                avatar = profileImage.isNotEmpty
                    ? CachedNetworkImage(imageUrl: profileImage, fit: BoxFit.cover)
                    : Image.asset('assets/default_avatar.png', fit: BoxFit.cover);
              }

              return GestureDetector(
                onTap: () {
                    Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: currentUserId),
                    ),
                  );
                },
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.elevation,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
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

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ComposeEntryScreen())),
        backgroundColor: AppColors.accentMustard, // Mustard for FAB
        elevation: 4,
        icon: Icon(Feather.edit_2, color: AppColors.backgroundDeep),
        label: Text("Write", style: TextStyle(color: AppColors.backgroundDeep, fontWeight: FontWeight.bold)),
      ),

      body: Column(
        children: [
          SizedBox(height: 10),
          _buildMoodFilterBar(),
          Expanded(child: _buildJournalList()),
        ],
      ),
    );
  }

  // --- Mood Filter ---
  Widget _buildMoodFilterBar() {
    final moods = ["All", "😭", "😟", "😐", "🙂", "😍"];
    return Container(
      height: 45,
      margin: EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16),
        itemCount: moods.length,
        itemBuilder: (context, index) {
          final mood = moods[index];
          final isSelected = (mood == "All" && _filterMood == null) || mood == _filterMood;
          return GestureDetector(
            onTap: () => setState(() => _filterMood = mood == "All" ? null : mood),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                // Teal for selected, Elevation (dark gray) for unselected
                color: isSelected ? AppColors.secondaryTeal : AppColors.elevation,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Center(
                child: Text(
                  mood,
                  style: TextStyle(
                    fontSize: 16,
                    color: isSelected ? Colors.white : AppColors.textMedium,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Calendar Modal ---
  void _showCalendarModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 550,
        decoration: BoxDecoration(
          color: AppColors.surface, // Dark Surface
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.textDisabled, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 20),
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
                Navigator.pop(context);
              },
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: AppColors.textHigh),
                weekendTextStyle: TextStyle(color: AppColors.textMedium),
                selectedDecoration: BoxDecoration(color: AppColors.primaryLavender, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: AppColors.secondaryTeal.withOpacity(0.5), shape: BoxShape.circle),
                todayTextStyle: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false, 
                titleCentered: true,
                titleTextStyle: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold, fontSize: 18),
                leftChevronIcon: Icon(Feather.chevron_left, color: AppColors.primaryLavender),
                rightChevronIcon: Icon(Feather.chevron_right, color: AppColors.primaryLavender),
              ),
            ),
            if (_selectedDay != null)
              TextButton(
                onPressed: () {
                  setState(() => _selectedDay = null);
                  Navigator.pop(context);
                },
                child: Text("Clear Date Filter", style: TextStyle(color: AppColors.error)),
              )
          ],
        ),
      ),
    );
  }

  // --- Journal List ---
  Widget _buildJournalList() {
    Query query = FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .collection('journal')
        .orderBy('timestamp', descending: true);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));

        var docs = snapshot.data!.docs;

        if (_selectedDay != null) {
          docs = docs.where((doc) {
            final ts = (doc['timestamp'] as Timestamp).toDate();
            return isSameDay(ts, _selectedDay);
          }).toList();
        }

        if (_filterMood != null) {
          docs = docs.where((doc) => doc['mood'] == _filterMood).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Feather.file_text, size: 48, color: AppColors.textDisabled),
                SizedBox(height: 10),
                Text("No entries found", style: TextStyle(color: AppColors.textMedium)),
              ],
            ),
          );
        }

        return MasonryGridView.count(
          padding: EdgeInsets.all(16),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            data['id'] = docs[index].id; 
            return _buildJournalCard(data);
          },
        );
      },
    );
  }

  Widget _buildJournalCard(Map<String, dynamic> data) {
    final date = (data['timestamp'] as Timestamp).toDate();
    final mood = data['mood'] ?? '😐';
    final content = data['content'] ?? '';
    final hasAudio = data['voiceNotePath'] != null;
    final hasImage = data['imagePath'] != null;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => JournalDetailScreen(data: data)),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface, // Dark Card
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('MMM d').format(date), style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(mood, style: TextStyle(fontSize: 18)),
              ],
            ),
            SizedBox(height: 8),
            if (hasImage) 
               Padding(
                 padding: const EdgeInsets.only(bottom: 8.0),
                 child: ClipRRect(
                   borderRadius: BorderRadius.circular(12),
                   child: Image.file(File(data['imagePath']), height: 80, width: double.infinity, fit: BoxFit.cover),
                 ),
               ),
            Text(content, maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textMedium)),
            if (hasAudio) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Feather.mic, size: 14, color: AppColors.secondaryTeal),
                  SizedBox(width: 4),
                  Text("Audio Note", style: TextStyle(fontSize: 10, color: AppColors.secondaryTeal))
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// --- 3. Journal Settings Screen ---

class JournalSettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Journal Settings", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.arrow_left, color: AppColors.textHigh),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: AppColors.backgroundDeep,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.elevation, shape: BoxShape.circle),
                child: Icon(Feather.lock, color: AppColors.primaryLavender),
              ),
              title: Text("Security & PIN", style: TextStyle(color: AppColors.textHigh)),
               trailing: Icon(Feather.chevron_right, size: 16, color: AppColors.textDisabled),
              onTap: () {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => SecuritySettingsScreen()));
              },
            ),
            Divider(color: AppColors.textDisabled),
            Spacer(),
          ],
        ),
      ),
    );
  }
}


// --- 4. Journal Detail Screen (View Full Entry) ---

class JournalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const JournalDetailScreen({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = (data['timestamp'] as Timestamp).toDate();
    final mood = data['mood'] ?? '😐';
    final content = data['content'] ?? '';
    final String? imagePath = data['imagePath'];
    final String? voiceNotePath = data['voiceNotePath'];
    final String? docPath = data['docPath'];
    final List<dynamic> tags = data['tags'] ?? [];
    final String weather = data['locationWeather'] ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(icon: Icon(Feather.arrow_left, color: AppColors.textHigh), onPressed: () => Navigator.pop(context)),
        title: Text(DateFormat('MMMM d, yyyy').format(date), style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        actions: [
           Center(child: Padding(
             padding: const EdgeInsets.only(right: 16.0),
             child: Text(mood, style: TextStyle(fontSize: 24)),
           ))
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (weather.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(children: [Icon(Feather.map_pin, size: 14, color: AppColors.textMedium), SizedBox(width: 4), Text(weather, style: TextStyle(color: AppColors.textMedium))]),
              ),

            if (imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(imagePath), width: double.infinity, fit: BoxFit.cover),
              ),
            SizedBox(height: 20),
            
            // Audio Player Logic for Detail View
            if (voiceNotePath != null)
              VoiceMessagePlayer(path: voiceNotePath),

            SizedBox(height: 20),
            Text(content, style: TextStyle(fontSize: 16, height: 1.6, color: AppColors.textHigh)),
            
            if (docPath != null)
              Container(
                margin: EdgeInsets.only(top: 20),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.elevation, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [Icon(Feather.file_text, color: AppColors.secondaryTeal), SizedBox(width: 8), Text("Document Attached", style: TextStyle(color: AppColors.textHigh))]),
              ),

            if (tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20.0),
                child: Wrap(
                  spacing: 8,
                  children: tags.map((t) => Chip(
                    label: Text("#$t", style: TextStyle(color: AppColors.primaryLavender)), 
                    backgroundColor: AppColors.elevation
                  )).toList(),
                ),
              )
          ],
        ),
      ),
    );
  }
}

// --- 5. Voice Player Widget ---

class VoiceMessagePlayer extends StatefulWidget {
  final String path;
  const VoiceMessagePlayer({required this.path});

  @override
  _VoiceMessagePlayerState createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if(mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if(mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if(mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // 
        await _audioPlayer.play(DeviceFileSource(widget.path));
      }
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(_isPlaying ? Feather.pause_circle : Feather.play_circle, color: AppColors.primaryLavender, size: 32),
            onPressed: _togglePlay,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Voice Note", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                LinearProgressIndicator(
                  value: _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0,
                  color: AppColors.primaryLavender,
                  backgroundColor: AppColors.elevation,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Text(_formatDuration(_duration), style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }
}

// --- 6. PIN Screen (Updated for UID) ---

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
    if (uid == null) return; // Handle gracefully if no user

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
              child: Icon(Feather.lock, size: 40, color: AppColors.primaryLavender),
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
            icon: Icon(Feather.delete, color: AppColors.primaryLavender),
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

// --- 7. Security Settings Screen ---

class SecuritySettingsScreen extends StatefulWidget {
  @override
  _SecuritySettingsScreenState createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  bool _isLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  void _loadState() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      bool enabled = await SecurityService.isLockEnabled(uid);
      setState(() => _isLockEnabled = enabled);
    }
  }

  void _toggleLock(bool val) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (val) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PinScreen(
        mode: PinMode.setup,
        onSuccess: () async {
          await SecurityService.setLockEnabled(uid, true);
          setState(() => _isLockEnabled = true);
          Navigator.pop(context);
        },
      )));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PinScreen(
        mode: PinMode.verify,
        onSuccess: () async {
          await SecurityService.setLockEnabled(uid, false);
          setState(() => _isLockEnabled = false);
          Navigator.pop(context);
        },
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text("Security", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)), 
        backgroundColor: AppColors.backgroundDeep, 
        iconTheme: IconThemeData(color: AppColors.textHigh), 
        elevation: 0,
        leading: IconButton(icon: Icon(Feather.arrow_left), onPressed: () => Navigator.pop(context)),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SwitchListTile(
            activeColor: AppColors.primaryLavender,
            title: Text("App Lock", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textHigh)),
            subtitle: Text("Require PIN to open journal", style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
            value: _isLockEnabled,
            onChanged: _toggleLock,
          ),
          if (_isLockEnabled)
            ListTile(
              title: Text("Change PIN", style: TextStyle(color: AppColors.textHigh)),
              trailing: Icon(Feather.chevron_right, size: 14, color: AppColors.textDisabled),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => PinScreen(
                  mode: PinMode.verify,
                  onSuccess: () {
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PinScreen(
                      mode: PinMode.setup,
                      onSuccess: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PIN Updated")));
                      },
                    )));
                  },
                )));
              },
            ),
        ],
      ),
    );
  }
}

// --- 8. Compose Screen ---

class ComposeEntryScreen extends StatefulWidget {
  @override
  _ComposeEntryScreenState createState() => _ComposeEntryScreenState();
}

class _ComposeEntryScreenState extends State<ComposeEntryScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  
  String _mood = "😐";
  double _intensity = 5.0;
  bool _isMoodExpanded = false;
  List<String> _tags = [];
  
  String _weatherInfo = "Detecting location...";

  String? _imagePath;
  String? _docPath;
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  String? _recordingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _fetchWeather() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        setState(() {
          _weatherInfo = "24°C • Sunny • Abuja"; // Simulated based on context
        });
      } else {
        setState(() => _weatherInfo = "Location denied");
      }
    } catch (e) {
      setState(() => _weatherInfo = "Weather unavailable");
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) setState(() => _imagePath = photo.path);
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) setState(() => _docPath = result.files.single.path);
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    }
  }

  Future<void> _playVoiceNote() async {
    if (_recordingPath != null) {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
        setState(() => _isPlaying = true);
        _audioPlayer.onPlayerComplete.listen((event) => setState(() => _isPlaying = false));
      }
    }
  }

  Future<void> _saveEntry() async {
    if (_contentController.text.isEmpty && _imagePath == null && _recordingPath == null) return;
    
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).collection('journal').add({
      'content': _contentController.text,
      'mood': _mood,
      'intensity': _intensity,
      'tags': _tags,
      'locationWeather': _weatherInfo,
      'imagePath': _imagePath,
      'docPath': _docPath,
      'voiceNotePath': _recordingPath,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await StreakService.updateStreakOnEntry();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(icon: Icon(Feather.x, color: AppColors.textHigh), onPressed: () => Navigator.pop(context)),
        title: Text("New Entry", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton(
                onPressed: _saveEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLavender,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                ),
                child: Text("Save", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.backgroundDeep)),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weather
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Icon(Feather.map_pin, size: 14, color: AppColors.secondaryTeal),
                  SizedBox(width: 6),
                  Text(_weatherInfo, style: TextStyle(fontSize: 12, color: AppColors.textMedium)),
                ],
              ),
            ),

            // Expandable Mood
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isMoodExpanded = !_isMoodExpanded),
                    child: Row(
                      children: [
                        Text("Mood: $_mood", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textHigh)),
                        Spacer(),
                        Icon(_isMoodExpanded ? Feather.chevron_up : Feather.chevron_down, color: AppColors.textDisabled),
                      ],
                    ),
                  ),
                  if (_isMoodExpanded) ...[
                    SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ["😭", "😟", "😐", "🙂", "😍"].map((m) => GestureDetector(
                        onTap: () => setState(() => _mood = m),
                        child: Text(m, style: TextStyle(fontSize: 32)),
                      )).toList(),
                    ),
                    Slider(
                      value: _intensity,
                      min: 1, max: 10,
                      activeColor: AppColors.primaryLavender,
                      inactiveColor: AppColors.elevation,
                      onChanged: (v) => setState(() => _intensity = v),
                    ),
                  ]
                ],
              ),
            ),
            
            // Editor
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                minLines: 8,
                style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.textHigh),
                decoration: InputDecoration(
                  hintText: "What's on your mind today?",
                  filled: true,
                  fillColor: AppColors.elevation,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  hintStyle: TextStyle(color: AppColors.textDisabled),
                  contentPadding: EdgeInsets.all(20),
                ),
              ),
            ),

            // Attachments Display
            if (_imagePath != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(File(_imagePath!), height: 180, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              
            if (_recordingPath != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(_isPlaying ? Feather.pause : Feather.play, color: AppColors.primaryLavender),
                      onPressed: _playVoiceNote,
                    ),
                    Text("Voice Note Recorded", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold)),
                    Spacer(),
                    IconButton(icon: Icon(Feather.trash_2, color: AppColors.error, size: 20), onPressed: () => setState(() => _recordingPath = null)),
                  ],
                ),
              ),

             if (_docPath != null)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.elevation, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    Icon(Feather.file_text, color: AppColors.secondaryTeal),
                    SizedBox(width: 8),
                    Expanded(child: Text("Document Attached", style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold))),
                    IconButton(icon: Icon(Feather.x, color: AppColors.textDisabled, size: 20), onPressed: () => setState(() => _docPath = null)),
                  ],
                ),
              ),

            // Tags
            SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._tags.map((t) => Chip(
                    label: Text("#$t", style: TextStyle(fontSize: 12, color: AppColors.primaryLavender)),
                    backgroundColor: AppColors.elevation,
                    deleteIcon: Icon(Feather.x, size: 14, color: AppColors.primaryLavender),
                    onDeleted: () => setState(() => _tags.remove(t)),
                  )),
                  Container(
                    width: 100,
                    child: TextField(
                      controller: _tagController,
                      style: TextStyle(fontSize: 12, color: AppColors.textHigh),
                      decoration: InputDecoration(
                        hintText: "+ Tag",
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.elevation,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        hintStyle: TextStyle(color: AppColors.textDisabled),
                      ),
                      onSubmitted: (val) {
                        if (val.isNotEmpty) {
                          setState(() {
                            _tags.add(val);
                            _tagController.clear();
                          });
                        }
                      },
                    ),
                  )
                ],
              ),
            ),

            SizedBox(height: 20),
            Divider(height: 1, color: AppColors.textDisabled),
            
            // Bottom Action Bar
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(Feather.mic, _isRecording ? "Stop" : "Voice", _isRecording ? AppColors.error : AppColors.primaryLavender, _toggleRecording),
                  _buildActionButton(Feather.camera, "Photo", AppColors.primaryLavender, _takePhoto),
                  _buildActionButton(Feather.file_text, "Doc", AppColors.primaryLavender, _pickDocument),
                ],
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.elevation, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMedium, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}