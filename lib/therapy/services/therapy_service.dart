import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/therapy_models.dart';

class TherapyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- Session Management ---

  Future<String?> bookTherapist(String therapistId, SessionType type, String problemDescription) async {
    try {
      final String clientId = _auth.currentUser!.uid;
      
      // Check therapist capacity (Max 3 active clients)
      final therapistDoc = await _firestore.collection('users').doc(therapistId).get();
      final activeClients = therapistDoc.data()?['activeClients'] ?? 0;
      
      if (activeClients >= 3) {
        return "Therapist is currently at maximum capacity (3/3 clients).";
      }

      // Create Session
      final sessionRef = _firestore.collection('therapy_sessions').doc();
      final session = TherapySession(
        id: sessionRef.id,
        therapistId: therapistId,
        clientId: clientId,
        type: type,
        status: SessionStatus.pending,
        startTime: DateTime.now(),
        problemDescription: problemDescription,
      );

      await sessionRef.set(session.toMap());

      // Update Therapist active count (or maybe only on acceptance? 
      // User said they can manage up to 3, so we should check capacity on booking but increment on acceptance)
      // Actually, let's increment a 'pendingCount' if we want, or just leave it for now.
      
      // Create Notification for Therapist
      await _firestore.collection('notifications').add({
        'toUserId': therapistId,
        'fromUserId': clientId,
        'type': 'therapy_booking',
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
        'sessionId': sessionRef.id,
      });

      return null; // Success
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> acceptSession(String sessionId) async {
    final sessionDoc = await _firestore.collection('therapy_sessions').doc(sessionId).get();
    if (!sessionDoc.exists) return;
    
    final data = sessionDoc.data()!;
    final therapistId = data['therapistId'];
    final clientId = data['clientId'];

    // Update session status
    await _firestore.collection('therapy_sessions').doc(sessionId).update({
      'status': SessionStatus.active.index,
    });

    // Update therapist active clients
    await _firestore.collection('users').doc(therapistId).update({
      'activeClients': FieldValue.increment(1),
      'totalClients': FieldValue.increment(1),
    });

    // Create a chat if it doesn't exist
    final chatsQuery = await _firestore.collection('chats')
        .where('participants', arrayContains: therapistId)
        .get();

    bool chatExists = false;
    for (var doc in chatsQuery.docs) {
      if (List.from(doc['participants']).contains(clientId)) {
        chatExists = true;
        break;
      }
    }

    if (!chatExists) {
      await _firestore.collection('chats').add({
        'participants': [therapistId, clientId],
        'lastMessage': 'Therapy session accepted. You can now chat.',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': {therapistId: 0, clientId: 1},
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // Notify Client
    await _firestore.collection('notifications').add({
      'toUserId': clientId,
      'fromUserId': therapistId,
      'type': 'therapy_accepted',
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'sessionId': sessionId,
    });
  }

  Future<void> completeSession(String sessionId, String therapistId) async {
    await _firestore.collection('therapy_sessions').doc(sessionId).update({
      'status': SessionStatus.completed.index,
      'endTime': FieldValue.serverTimestamp(),
    });
    
    await _firestore.collection('users').doc(therapistId).update({
      'activeClients': FieldValue.increment(-1),
    });
  }

  // --- Ratings & Reviews ---

  Future<void> rateTherapist(String therapistId, double rating, String comment) async {
    final String reviewerId = _auth.currentUser!.uid;
    final reviewRef = _firestore.collection('therapist_reviews').doc();
    
    await reviewRef.set({
      'id': reviewRef.id,
      'therapistId': therapistId,
      'reviewerId': reviewerId,
      'rating': rating,
      'comment': comment,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update Average Rating
    final therapistDoc = await _firestore.collection('users').doc(therapistId).get();
    final data = therapistDoc.data()!;
    final currentAvg = (data['averageRating'] ?? 0.0).toDouble();
    final totalRatings = data['totalRatings'] ?? 0;
    
    final newTotal = totalRatings + 1;
    final newAvg = ((currentAvg * totalRatings) + rating) / newTotal;

    await _firestore.collection('users').doc(therapistId).update({
      'averageRating': newAvg,
      'totalRatings': newTotal,
    });

    // Check for Verification (500 clients + mostly 5 stars?)
    // Simplified: Check if totalClients >= 500 and averageRating >= 4.5
    if (newTotal >= 500 && newAvg >= 4.5) {
      await _firestore.collection('users').doc(therapistId).update({'isVerified': true});
    }
  }

  // --- Reporting ---

  Future<void> reportTherapist(String therapistId, String reason) async {
    final reportRef = _firestore.collection('therapist_reports').doc();
    await reportRef.set({
      'id': reportRef.id,
      'therapistId': therapistId,
      'reporterId': _auth.currentUser!.uid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('users').doc(therapistId).update({
      'reportCount': FieldValue.increment(1),
    });
  }

  // --- Search & Filtering ---

  Stream<QuerySnapshot> getTherapists({
    String? region,
    String? situation,
    int? age,
    String? ethnicity,
    String? gender,
    bool? isLgbtqPlus,
    String? religion,
    String? ageRange,
    String? language,
    String? livedExperience,
  }) {
    Query query = _firestore.collection('users').where('accountType', isEqualTo: 'therapist');

    if (region != null && region.isNotEmpty && region != 'All') {
      query = query.where('region', isEqualTo: region);
    }

    if (situation != null && situation.isNotEmpty) {
      // Specialty matching
      query = query.where('specialization', arrayContains: situation);
    }

    if (livedExperience != null && livedExperience.isNotEmpty) {
      query = query.where('livedExperiences', arrayContains: livedExperience);
    }

    if (language != null && language.isNotEmpty && language != 'All') {
      query = query.where('languages', arrayContains: language);
    }

    if (ethnicity != null && ethnicity.isNotEmpty && ethnicity != 'All') {
      query = query.where('ethnicity', isEqualTo: ethnicity);
    }

    if (gender != null && gender.isNotEmpty && gender != 'All') {
      query = query.where('gender', isEqualTo: gender);
    }

    if (isLgbtqPlus != null && isLgbtqPlus == true) {
      query = query.where('isLgbtqPlus', isEqualTo: true);
    }

    if (religion != null && religion.isNotEmpty && religion != 'All') {
      query = query.where('religion', isEqualTo: religion);
    }

    if (ageRange != null && ageRange.isNotEmpty && ageRange != 'All') {
      query = query.where('ageRange', isEqualTo: ageRange);
    }

    return query.snapshots();
  }
}
