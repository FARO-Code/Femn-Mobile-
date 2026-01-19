import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart' as vai;
import 'dart:math';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:femn/feed/personalized_feed_service.dart';

class FeedService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PersonalizedFeedService _personalizedFeed = PersonalizedFeedService();

  // --- 1. THE "SENSES": MULTIMODAL AI ANALYSIS ---
  Future<Map<String, dynamic>> analyzeContent({
    required String caption,
    required String mediaType,
    File? file,
  }) async {
    print("🧠 ALGORITHM [Input]: Analyzing content...");

    try {
      // Using the latest model for 2026
      final model = vai.FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.5-flash', 
        generationConfig: vai.GenerationConfig(
          responseMimeType: 'application/json',
          temperature: 0.4, // Lower temperature for more factual/strict responses
        ),
      );

      List<vai.Part> parts = [];
      
      // --- THE SUPER PROMPT ---
      final promptText = '''
      You are the safety and recommendation engine for 'Femn'. 
      
      INPUT: A ${mediaType == 'video' ? 'video thumbnail' : 'photo'} and caption: "$caption".

      PHASE 1: STRICT SAFETY CHECK
      Analyze the image and caption for the following prohibited categories:
      1. Dangerous Acts: Challenges, self-harm, eating disorders.
      2. Sexual Content: Nudity (genitalia/nipples), sexually suggestive poses, pornographic intent.
      3. Violence/Gore: Open wounds, torture, extreme blood, dead bodies.
      4. Illegal: Drugs, weapons, criminal instructions.
      5. Hate/Harassment: Slurs, targeted abuse, symbols of hate groups.
      
      If ANY of these are found, set "isSafe" to false and stop analysis.

      PHASE 2: DEEP CULTURAL & VISUAL IDENTIFICATION
      If safe, identify the content with high specificity:
      1. ENTITIES: Name specific characters (e.g., "Kris", "Anubis"), franchises (e.g., "Deltarune", "Undertale"), or celebrities.
      2. CONTEXT: Identify the era (e.g., "Ancient Egypt"), genre (e.g., "Indie RPG"), or activity.
      3. AESTHETICS: Identify the art style (e.g., "Pixel Art", "Oil Painting") and specific Color Palette names (e.g., "Sepia", "Neon Cyberpunk").

      PHASE 3: SMART TAGGING (Generate exactly 15 tags)
      Combine:
      - Specific Tags: (e.g., "Deltarune", "Toby Fox", "Susie")
      - Niche Tags: (e.g., "Cozy Gaming", "Dark Academia", "Witchy Vibes")
      - Visual Tags: (e.g., "Silhouette", "Warm Tones")

      RETURN JSON STRUCTURE:
      {
        "isSafe": boolean,
        "moderationReason": "Reason if unsafe, otherwise null",
        "category": "String (One of: Feminism, Gaming, Art, History, Wellness, Politics, Tech, Lifestyle)",
        "tags": ["tag1", "tag2", ...],
        "visualDescription": "Detailed summary",
        "qualityScore": Integer (1-10)
      }
      ''';
      
      parts.add(vai.TextPart(promptText));

      if (file != null && await file.exists()) {
        final bytes = await file.readAsBytes();
        String mimeType = file.path.endsWith('.png') ? 'image/png' : 'image/jpeg';
        parts.add(vai.InlineDataPart(mimeType, Uint8List.fromList(bytes)));
      }

      final contentResponse = await model.generateContent([vai.Content.multi(parts)]);
      
      // Default Safety Fallback
      bool isSafe = false; 
      String moderationReason = "AI Analysis Failed";
      String category = 'General';
      List<String> tags = [];
      String visualDesc = "";
      int qualityScore = 0;

      if (contentResponse.text != null) {
        try {
          final cleanedText = contentResponse.text!.replaceAll('```json', '').replaceAll('```', '');
          final data = jsonDecode(cleanedText);
          
          isSafe = data['isSafe'] ?? false;
          moderationReason = data['moderationReason'] ?? "Unknown Safety Risk";
          
          if (isSafe) {
            category = data['category'] ?? 'General';
            tags = List<String>.from(data['tags'] ?? []);
            visualDesc = data['visualDescription'] ?? "";
            qualityScore = data['qualityScore'] ?? 5;
            
            print("🧠 ALGORITHM [Identity]: Identified: $tags");
          } else {
            print("🛑 ALGORITHM [Blocked]: Content flagged as unsafe: $moderationReason");
          }

        } catch (e) {
          print("⚠️ ALGORITHM [Error]: JSON Parsing failed. Defaulting to unsafe for security.");
        }
      }

      return {
        'isSafe': isSafe,
        'moderationReason': moderationReason,
        'category': category,
        'tags': tags,
        'embedding': List.filled(768, 0.0), // Placeholder until embedding is fixed
        'visualDescription': visualDesc,
        'qualityScore': qualityScore,
      };

    } catch (e) {
      print("🛑 ALGORITHM [Critical Fail]: $e");
      return {
        'isSafe': false,
        'moderationReason': "System Error",
      };
    }
  }

  // --- 3. SMART FEED GENERATION (Unchanged from working version) ---
  Future<List<DocumentSnapshot>> getSmartFeed() async {
    try {
      return await _personalizedFeed.getPersonalizedFeed(limit: 20);
    } catch (e) {
      print('Error getting personalized feed: $e');
      // Fallback to recent posts
      final safetyQuery = await _db.collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      return safetyQuery.docs;
    }
  }
  
  Future<List<DocumentSnapshot>> getPaginatedFeed(DocumentSnapshot lastDocument) async {
    try {
      return await _personalizedFeed.getPersonalizedFeed(
        limit: 10,
        lastDocument: lastDocument,
      );
    } catch (e) {
      print('Error getting paginated personalized feed: $e');
      return [];
    }
  }
  
  // Add this method for "See More" functionality
  Future<List<DocumentSnapshot>> getPostsForTag(String tag) async {
    try {
      final query = await _db.collection('posts')
          .where('smartTags', arrayContains: tag)
          .where('timestamp', isGreaterThan: DateTime.now().subtract(Duration(days: 60)))
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      return query.docs;
    } catch (e) {
      return [];
    }
  }
}