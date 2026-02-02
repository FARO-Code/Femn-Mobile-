import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MaintenanceService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> wipeAllContent() async {
    final String? userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // List of top-level collections to clear
    final collections = [
      'posts',
      'polls',
      'petitions',
      'groups',
      'discussions',
      'notifications',
    ];

    for (final collection in collections) {
      final snapshot = await _db.collection(collection).get();
      for (final doc in snapshot.docs) {
        // Handle subcollections for specific types
        if (collection == 'groups' || collection == 'discussions') {
          await _deleteSubcollection(doc.reference, 'messages');
        }
        
        // Delete the document itself
        await doc.reference.delete();
      }
    }

    // Clear user-specific signals (AI recommendation data)
    await _deleteSubcollection(_db.collection('users').doc(userId), 'signals');
    
    // Optional: Clear user-specific notifications if they are stored elsewhere
    // (In current app they seem to be in a top-level 'notifications' collection 
    // or maybe user subcollection. Let's check both.)
    await _deleteSubcollection(_db.collection('users').doc(userId), 'notifications');
  }

  static Future<void> _deleteSubcollection(DocumentReference parentDoc, String subcollectionName) async {
    final snapshot = await parentDoc.collection(subcollectionName).get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }
}
