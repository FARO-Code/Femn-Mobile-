import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:femn/customization/colors.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'twin_finder_engine.dart';

class TwinFinderScreen extends StatefulWidget {
  @override
  _TwinFinderScreenState createState() => _TwinFinderScreenState();
}

class _TwinFinderScreenState extends State<TwinFinderScreen> {
  // Logic Engine
  final TwinFinderEngine _engine = TwinFinderEngine();
  
  // State
  bool _isLoading = true;
  bool _isFinished = false;
  bool _isCalculating = false; // "Fake" loading phase
  bool _checkingExisting = true; 

  // Result Data
  String? _resultArchetype;
  String? _resultTitle;
  String? _resultDescription;
  int? _resultColor; // Stored as int from hex string

  // Progress for "Calculating" screen
  double _calcProgress = 0.0;
  String _calcStatus = "Analyzing Cognitive Stack...";

  @override
  void initState() {
    super.initState();
    _checkExistingResult();
  }

  Future<void> _checkExistingResult() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()!.containsKey('personalityType')) {
        final data = doc.data()!;
        _loadResult(data);
      } else {
        await _startSession();
      }
    } catch (e) {
      await _startSession();
    }
  }

  void _loadResult(Map<String, dynamic> data) {
      setState(() {
          _resultArchetype = data['personalityType'];
          _resultTitle = data['personalityTitle'];
          _resultDescription = data['personalityDesc'];
          // Fallback legacy calculation for color if missing
          if (data['personalityColor'] != null) {
              _resultColor = data['personalityColor'];
          } else {
             _resultColor = int.parse("0xFF805da1"); // Default Purple
          }

          _isFinished = true;
          _checkingExisting = false;
          _isLoading = false;
        });
  }

  Future<void> _startSession() async {
    setState(() => _checkingExisting = false);
    await _engine.loadQuestions();
    _engine.startSession();
    setState(() => _isLoading = false);
  }

  void _handleAnswer(int value) async {
    _engine.setAnswer(value);
    
    // Auto-advance logic
    Future.delayed(Duration(milliseconds: 250), () {
        _goNext();
    });
    setState(() {});
  }

  void _goNext() {
      // If we are at the end...
      if (_engine.currentIndex >= _engine.totalQuestions - 1) {
          // Check if answered?
          if (_engine.currentAnswer != null) {
              _startCalculationSequence();
          }
      } else {
          _engine.nextQuestion();
          setState(() {});
      }
  }

  void _goBack() {
      _engine.previousQuestion();
      setState(() {});
  }

  // --- CALCULATING SEQUENCE ---
  void _startCalculationSequence() async {
      setState(() {
          _isCalculating = true;
      });

      // Simulate steps
      final steps = [
          "Analyzing Cognitive Functions...",
          "Mapping Dominant Traits...",
          "Resolving Paradoxes...",
          "Finalizing Archetype..."
      ];

      for (int i = 0; i < steps.length; i++) {
          await Future.delayed(Duration(milliseconds: 800));
          if (!mounted) return;
          setState(() {
              _calcStatus = steps[i];
              _calcProgress = (i + 1) / steps.length;
          });
      }

       await Future.delayed(Duration(milliseconds: 500));
       if (!mounted) return;

       final result = _engine.calculateResult();
       _finishTest(result);
  }

  Future<void> _finishTest(Map<String, dynamic> resultData) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    
    // Parse Color
    int colorInt = int.parse(resultData['color']);

    // Save to Firestore
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'personalityType': resultData['archetype'],
      'personalityTitle': resultData['title'],
      'personalityDesc': resultData['description'],
      'personalityColor': colorInt,
      'personalityTestDate': DateTime.now(),
      'showPersonality': true, 
    });

    setState(() {
      _isCalculating = false;
      _isFinished = true;
      _resultArchetype = resultData['archetype'];
      _resultTitle = resultData['title'];
      _resultDescription = resultData['description'];
      _resultColor = colorInt;
    });
  }

  Future<void> _retakeTest() async {
    setState(() {
      _isLoading = true;
      _isFinished = false;
    });
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'personalityType': FieldValue.delete(),
    });
    _engine.startSession();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Assumes background from parent or stack
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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
      if (_checkingExisting) {
          return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));
      }
      if (_isCalculating) {
          return _buildCalculatingView();
      }
      if (_isFinished) {
          return _buildResultView();
      }
      return _buildQuizView();
  }

  // --- LOADING VIEW ---
  Widget _buildCalculatingView() {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                  Stack(
                      alignment: Alignment.center,
                      children: [
                          SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                  value: _calcProgress,
                                  color: AppColors.secondaryTeal,
                                  backgroundColor: AppColors.elevation,
                                  strokeWidth: 8,
                              ),
                          ),
                          Icon(Feather.cpu, color: AppColors.textHigh, size: 32)
                              .animate(onPlay: (c) => c.repeat())
                              .fadeIn(duration: 600.ms)
                              .then().fadeOut(duration: 600.ms),
                      ],
                  ),
                  SizedBox(height: 32),
                  Text(
                      _calcStatus,
                      style: TextStyle(color: AppColors.textHigh, fontSize: 16, fontWeight: FontWeight.bold),
                  ).animate().slideY(begin: 0.1, end: 0),
                  SizedBox(height: 8),
                  Text(
                      "${(_calcProgress * 100).toInt()}% Complete",
                      style: TextStyle(color: AppColors.textMedium, fontSize: 12),
                  ),
              ],
          ),
      );
  }

  // --- QUIZ VIEW ---
  Widget _buildQuizView() {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.primaryLavender));

    final question = _engine.currentQuestion;
    if (question == null) return SizedBox();

    return Column(
      children: [
        Expanded(
          child: Padding(
            key: ValueKey(question['id']), // Animate on change
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                SizedBox(height: 10),
                LinearPercentIndicator(
                  lineHeight: 8.0,
                  percent: _engine.progress.clamp(0.0, 1.0),
                  backgroundColor: AppColors.elevation,
                  progressColor: AppColors.secondaryTeal,
                  barRadius: Radius.circular(10),
                  animation: true,
                  animateFromLastPercent: true,
                ),
                SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Question ${_engine.currentIndex + 1}/${_engine.totalQuestions}",
                        style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                      ),
                      Text(
                        question['category'] ?? "General",
                        style: TextStyle(color: AppColors.primaryLavender, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                // Question Card
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
                        question['text'],
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
                _buildSpectrumOptions(question),
                Spacer(),
              ],
            ),
          ),
        ),
        
        // --- BOTTOM NAVIGATION BAR ---
        Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.elevation)),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    // Previous Button
                     Opacity(
                        opacity: _engine.canGoBack ? 1.0 : 0.3,
                        child: TextButton.icon(
                            icon: Icon(Feather.chevron_left, color: AppColors.textMedium),
                            label: Text("Previous", style: TextStyle(color: AppColors.textMedium)),
                            onPressed: _engine.canGoBack ? _goBack : null,
                        ),
                     ),

                     // Indicator dots or simple spacer
                     Row(
                         children: [
                             Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _engine.currentAnswer != null ? AppColors.secondaryTeal : AppColors.elevation)),
                             SizedBox(width: 4),
                             Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.elevation)),
                         ],
                     ),

                    // Next Button
                    Opacity(
                        opacity: (_engine.currentAnswer != null) ? 1.0 : 0.3, 
                        child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: TextButton.icon(
                                icon: Icon(Feather.chevron_right, color: AppColors.primaryLavender),
                                label: Text("Next", style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold)),
                                onPressed: (_engine.currentAnswer != null) ? _goNext : null,
                            ),
                        ),
                    ),
                ],
            ),
        ),
      ],
    );
  }

  Widget _buildSpectrumOptions(Map<String, dynamic> question) {
      int? selected = _engine.currentAnswer;

    return Column(
      children: [
        Text(
          question['optionA']['text'].toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.secondaryTeal, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 11),
        ),
        SizedBox(height: 20),
        Container(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSpectrumButton(0, Colors.teal, 60, selected == 0), 
              _buildSpectrumButton(1, Colors.teal.withOpacity(0.6), 45, selected == 1),
              _buildSpectrumButton(2, AppColors.primaryLavender.withOpacity(0.6), 45, selected == 2), 
              _buildSpectrumButton(3, AppColors.primaryLavender, 60, selected == 3),
            ],
          ),
        ),
        SizedBox(height: 20),
        Text(
          question['optionB']['text'].toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSpectrumButton(int value, Color color, double size, bool isSelected) {
    return GestureDetector(
      onTap: () => _handleAnswer(value),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        width: isSelected ? size * 1.2 : size,
        height: isSelected ? size * 1.2 : size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.elevation,
          border: Border.all(color: isSelected ? Colors.white : color, width: isSelected ? 3 : 2),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 10, spreadRadius: 1)
          ]
        ),
        child: Center(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: isSelected ? size * 0.6 : size * 0.4,
            height: isSelected ? size * 0.6 : size * 0.4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
            child: isSelected ? Icon(Feather.check, color: Colors.white, size: 16) : null,
          ),
        ),
      ),
    );
  }

  // --- RESULT VIEW ---
  Widget _buildResultView() {
    Color coreColor = Color(_resultColor ?? 0xFF805da1);

    return SingleChildScrollView(
        child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    SizedBox(height: 40),
                    Icon(Feather.check_circle, size: 80, color: coreColor)
                        .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                    SizedBox(height: 24),
                    Text(
                        "Personality Analysis Complete",
                        style: TextStyle(color: AppColors.textMedium, fontSize: 14, letterSpacing: 1.5),
                    ),
                    SizedBox(height: 12),
                    Text(
                        "You are The ${_resultTitle ?? '...'}",
                        style: TextStyle(color: AppColors.textHigh, fontSize: 26, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Container(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                            color: coreColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: coreColor.withOpacity(0.5))
                        ),
                        child: Text(
                            _resultArchetype ?? "",
                            style: TextStyle(color: coreColor, fontWeight: FontWeight.bold, letterSpacing: 2.0, fontSize: 22),
                        ),
                    ),
                    SizedBox(height: 32),
                    
                    // Main Description Card
                    Container(
                        padding: EdgeInsets.all(24),
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.elevation),
                        ),
                        child: Column(
                            children: [
                                Icon(Feather.align_left, color: coreColor, size: 24),
                                SizedBox(height: 16),
                                Text(
                                    _resultDescription ?? "",
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                        color: AppColors.textHigh, 
                                        fontSize: 15,
                                        height: 1.6,
                                        fontFamily: 'Roboto'
                                    ),
                                ),
                            ],
                        ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // DONE BUTTON
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: coreColor,
                                padding: EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                                "Close Analysis", 
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                            ),
                        ),
                    ),

                    SizedBox(height: 16),
                    
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
                    ),
                    SizedBox(height: 20),
                ],
            ),
        ),
    );
  }
}
