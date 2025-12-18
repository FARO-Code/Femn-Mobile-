// embers_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmbersService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // MAIN REUSABLE FUNCTION - Handles everything in one call
  static Future<EmbersResult> processEmbersTransaction({
    required BuildContext context,
    required int amount,
    required String actionType,
    String? referenceId,
    String? successMessage,
    String? insufficientFundsMessage,
    bool showSnackBar = true,
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      final userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
      
      // Check if spending and has sufficient funds
      if (amount < 0) {
        final userDoc = await userRef.get();
        final currentEmbers = userDoc['embers'] ?? 0;
        if (currentEmbers < amount.abs()) {
          final message = insufficientFundsMessage ?? 'Insufficient Embers. Need ${amount.abs()} but only have $currentEmbers.';
          if (showSnackBar) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.orange),
            );
          }
          return EmbersResult(success: false, message: message, newBalance: currentEmbers);
        }
      }
      
      // Process the transaction
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        final currentEmbers = userDoc['embers'] ?? 0;
        final newEmbers = currentEmbers + amount;
        
        transaction.update(userRef, {'embers': newEmbers});
        
        // Record transaction
        await _recordTransaction(
          userId: currentUserId,
          amount: amount,
          actionType: actionType,
          referenceId: referenceId,
          balanceAfter: newEmbers,
        );
      });
      
      // Success message
      final message = successMessage ?? 
        (amount > 0 ? '+$amount Embers!' : '$amount Embers');
      
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: amount > 0 ? Colors.green : Colors.blue,
          ),
        );
      }
      
      return EmbersResult(success: true, message: message, newBalance: await _getCurrentEmbers());
      
    } catch (e) {
      final errorMessage = 'Error processing Embers: $e';
      if (showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
      return EmbersResult(success: false, message: errorMessage, newBalance: 0);
    }
  }

  // SPECIFIC ACTION WRAPPERS - Super simple to use
  static Future<EmbersResult> earnForPost(BuildContext context, String postId) {
    return processEmbersTransaction(
      context: context,
      amount: 5,
      actionType: 'post_creation',
      referenceId: postId,
      successMessage: 'Post created! +5 Embers!',
    );
  }

  static Future<EmbersResult> spendForStory(BuildContext context, String storyId) {
    return processEmbersTransaction(
      context: context,
      amount: -2,
      actionType: 'story_creation', 
      referenceId: storyId,
      insufficientFundsMessage: 'Need 2 Embers to create a story',
    );
  }

  // QUICK CHECK FUNCTION
  static Future<bool> hasSufficientEmbers(int requiredAmount) async {
    final currentEmbers = await _getCurrentEmbers();
    return currentEmbers >= requiredAmount;
  }

  // PRIVATE HELPERS
  static Future<int> _getCurrentEmbers() async {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
    return userDoc['embers'] ?? 0;
  }

  static Future<void> _recordTransaction({
    required String userId,
    required int amount,
    required String actionType,
    String? referenceId,
    required int balanceAfter,
  }) async {
    await FirebaseFirestore.instance.collection('embers_transactions').add({
      'userId': userId,
      'amount': amount,
      'actionType': actionType,
      'referenceId': referenceId,
      'balanceAfter': balanceAfter,
      'timestamp': DateTime.now(),
    });
  }
}

// Simple result class
class EmbersResult {
  final bool success;
  final String message;
  final int newBalance;

  EmbersResult({
    required this.success,
    required this.message,
    required this.newBalance,
  });
}