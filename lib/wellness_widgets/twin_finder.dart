import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/customization/colors.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

// --- CONFIGURATION ---
// ⚠️ REPLACE WITH YOUR ACTUAL API KEY
const String _kGeminiApiKey = "AIzaSyBM7gJsKazBd2gGXKuHdfJM1iATDXi8cfM"; 

class TwinFinderScreen extends StatefulWidget {
  @override
  _TwinFinderScreenState createState() => _TwinFinderScreenState();
}

class _TwinFinderScreenState extends State<TwinFinderScreen> {
  // AI Model
  late GenerativeModel _model;
  
  // State
  List<Map<String, dynamic>> _history = []; // Stores Q&A history
  Map<String, dynamic>? _currentQuestion;
  
  // Prefetch Buffer
  Map<String, dynamic>? _prefetchedData; // Can be a question OR a result
  bool _isPrefetching = false;

  bool _isLoading = true; // For the very first load
  bool _isFinished = false;
  bool _checkingExisting = true; // New: for initial Firebase check

  // Result Data
  String? _resultArchetype;
  String? _resultTitle;
  String? _resultDescription;
  
  // Progress Management
  int _questionCount = 0;
  final int _minQuestions = 10;
  final int _maxQuestions = 25;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _kGeminiApiKey);
    _checkExistingResult();
  }

  // --- 1. CHECK FOR EXISTING RESULT ---
  Future<void> _checkExistingResult() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()!.containsKey('personalityType')) {
        final data = doc.data()!;
        setState(() {
          _resultArchetype = data['personalityType'];
          _resultTitle = data['personalityTitle'];
          _resultDescription = data['personalityDesc'];
          _isFinished = true;
          _checkingExisting = false;
          _isLoading = false;
        });
      } else {
        // No result found → start fresh test
        setState(() => _checkingExisting = false);
        _startSession();
      }
    } catch (e) {
      // On error (e.g., network), just start the test
      setState(() => _checkingExisting = false);
      _startSession();
    }
  }

  // --- 2. AI LOGIC ---
  Future<void> _startSession() async {
    // 1. Fetch the very first question (Blocking load)
    await _fetchDataFromAI(isPrefetch: false);
  }

  /// The core function to talk to Gemini
  /// [isPrefetch]: If true, saves to buffer. If false, updates UI immediately.
  Future<void> _fetchDataFromAI({required bool isPrefetch}) async {
    if (isPrefetch) {
      _isPrefetching = true;
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final historyJson = jsonEncode(_history);
      
      final prompt = '''
      Act as an expert psychologist performing a personality assessment (Jungian Cognitive Functions).
      
      Current Session History (JSON): $historyJson
      Question Count: $_questionCount
      
      RULES:
      1. Analyze the history to determine the user's likely cognitive stack.
      2. If Question Count >= $_minQuestions AND you are >90% certain of the type, or if Question Count >= $_maxQuestions, output the RESULT JSON.
      3. Otherwise, generate the next best question to narrow down the possibilities.
      
      FORMAT 1 (Next Question):
      {
        "type": "question",
        "text": "The scenario text...",
        "optionA": "The Option A text (e.g. Focus on facts)",
        "optionB": "The Option B text (e.g. Focus on concepts)",
        "trait": "The specific axis being tested (e.g. Si/Ni)"
      }

      FORMAT 2 (Result):
      {
        "type": "result",
        "archetype": "The 4 Letter Code (e.g. INFJ)",
        "title": "The Archetype Name (e.g. The Advocate)",
        "description": "A 2-sentence description of their personality."
      }
      
      RETURN ONLY RAW JSON. NO MARKDOWN.
      ''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      String? cleanJson = response.text?.replaceAll('```json', '').replaceAll('```', '').trim();
      
      if (cleanJson != null) {
        final data = jsonDecode(cleanJson);
        
        if (isPrefetch) {
          _prefetchedData = data;
          _isPrefetching = false;
          print("✅ Background Prefetch Complete");
        } else {
          _processIncomingData(data);
        }
      }
    } catch (e) {
      print("AI Error: $e");
      if (isPrefetch) _isPrefetching = false;
      // In production, consider showing error UI or retry
    }
  }

  void _processIncomingData(Map<String, dynamic> data) {
    if (data['type'] == 'result') {
      _finishTest(data);
    } else {
      setState(() {
        _currentQuestion = data;
        _isLoading = false;
      });
      // 🚀 Prefetch next item as soon as current question is displayed
      _fetchDataFromAI(isPrefetch: true); 
    }
  }

  void _handleAnswer(int value) {
    if (_currentQuestion == null) return;

    String answerText = "";
    if (value == 0) answerText = "Strongly preferred Option A: ${_currentQuestion!['optionA']}";
    if (value == 1) answerText = "Slightly preferred Option A";
    if (value == 2) answerText = "Slightly preferred Option B";
    if (value == 3) answerText = "Strongly preferred Option B: ${_currentQuestion!['optionB']}";

    _history.add({
      "question": _currentQuestion!['text'],
      "trait_tested": _currentQuestion!['trait'],
      "user_choice_value": value, 
      "interpretation": answerText
    });

    _questionCount++;

    Future.delayed(const Duration(milliseconds: 300), () {
      _loadNextFromBuffer();
    });
  }

  Future<void> _loadNextFromBuffer() async {
    if (_prefetchedData != null) {
      final nextData = _prefetchedData!;
      _prefetchedData = null;
      _processIncomingData(nextData);
    } else {
      setState(() => _isLoading = true);
      if (!_isPrefetching) {
        await _fetchDataFromAI(isPrefetch: false);
      } else {
        await _fetchDataFromAI(isPrefetch: false);
      }
    }
  }

  Future<void> _finishTest(Map<String, dynamic> resultData) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    // Save to Firestore with default visibility set to true
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'personalityType': resultData['archetype'],
      'personalityTitle': resultData['title'],
      'personalityDesc': resultData['description'],
      'personalityTestDate': DateTime.now(),
      'showPersonality': true, // Default to visible
    });

    setState(() {
      _isFinished = true;
      _resultArchetype = resultData['archetype'];
      _resultTitle = resultData['title'];
      _resultDescription = resultData['description'];
      _isLoading = false;
    });
  }

  // --- RETAKE LOGIC ---
  Future<void> _retakeTest() async {
    setState(() {
      _isLoading = true;
      _isFinished = false;
      _history.clear();
      _questionCount = 0;
      _prefetchedData = null;
      _currentQuestion = null;
    });

    // Clear previous result from Firestore
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'personalityType': FieldValue.delete(),
      'personalityTitle': FieldValue.delete(),
      'personalityDesc': FieldValue.delete(),
      'showPersonality': FieldValue.delete(),
    });

    // Start fresh
    await _startSession();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Feather.x, color: AppColors.textMedium),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Twin Finder",
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _checkingExisting
            ? Center(child: CircularProgressIndicator(color: AppColors.primaryLavender))
            : (_isFinished ? _buildResultView() : _buildQuizView()),
      ),
    );
  }

  Widget _buildQuizView() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryLavender),
            SizedBox(height: 16),
            Text(
              "Syncing...", 
              style: TextStyle(color: AppColors.textMedium, fontStyle: FontStyle.italic),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
          ],
        ),
      );
    }

    return Padding(
      key: ValueKey(_questionCount), 
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          SizedBox(height: 20),
          LinearPercentIndicator(
            lineHeight: 6.0,
            percent: (_questionCount / _maxQuestions).clamp(0.0, 1.0),
            backgroundColor: AppColors.elevation,
            progressColor: AppColors.secondaryTeal,
            barRadius: Radius.circular(10),
            animation: true,
            animateFromLastPercent: true,
          ),
          SizedBox(height: 10),
          Text(
            "Question ${_questionCount + 1}",
            style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                )
              ],
              border: Border.all(color: AppColors.elevation),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentQuestion!['text'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
          Spacer(),
          _buildSpectrumOptions(),
          Spacer(),
        ],
      ),
    );
  }

  Widget _buildSpectrumOptions() {
    return Column(
      children: [
        Text(
          _currentQuestion!['optionA'].toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryTeal, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
        ),
        SizedBox(height: 20),
        Container(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSpectrumButton(0, Colors.teal, 60), 
              _buildSpectrumButton(1, Colors.teal.withOpacity(0.6), 45),
              _buildSpectrumButton(2, AppColors.primaryLavender.withOpacity(0.6), 45), 
              _buildSpectrumButton(3, AppColors.primaryLavender, 60),
            ],
          ),
        ),
        SizedBox(height: 20),
        Text(
          _currentQuestion!['optionB'].toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSpectrumButton(int value, Color color, double size) {
    return GestureDetector(
      onTap: () => _handleAnswer(value),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.elevation,
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)
          ]
        ),
        child: Center(
          child: Container(
            width: size * 0.4,
            height: size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack);
  }

  Widget _buildResultView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Feather.check_circle, size: 80, color: AppColors.secondaryTeal)
                .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            SizedBox(height: 24),
            Text(
              "Personality Analysis",
              style: TextStyle(color: AppColors.textMedium, fontSize: 16),
            ),
            SizedBox(height: 12),
            Text(
              "You are The ${_resultTitle ?? '...'}",
              style: TextStyle(color: AppColors.textHigh, fontSize: 26, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.elevation,
                borderRadius: BorderRadius.circular(20)
              ),
              child: Text(
                _resultArchetype ?? "",
                style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 18),
              ),
            ),
            SizedBox(height: 16),
            Text(
              _resultDescription ?? "",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMedium, fontSize: 14),
            ),
            SizedBox(height: 40),
            
            // DONE BUTTON
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryLavender,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: Text("Close", style: TextStyle(color: AppColors.backgroundDeep, fontSize: 16, fontWeight: FontWeight.bold)),
            ),

            SizedBox(height: 16),
            
            // RETAKE BUTTON
            TextButton(
              onPressed: _retakeTest,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Feather.refresh_ccw, size: 14, color: AppColors.textMedium),
                  SizedBox(width: 8),
                  Text("Retake Test", style: TextStyle(color: AppColors.textMedium)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}