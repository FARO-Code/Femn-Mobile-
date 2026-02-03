import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_widget/home_widget.dart';
import 'package:femn/circle/petitions.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class PetitionWidgetService {
  static const String androidWidgetName = 'PetitionWidgetProvider';

  /// Updates the Home Screen Widget with data from the selected petition
  static Future<void> updateWidget(Petition petition) async {
    try {
      String? localImagePath;

      // Download and save image if available
      if (petition.bannerImageUrl != null && petition.bannerImageUrl!.isNotEmpty) {
        try {
          final directory = await getApplicationSupportDirectory();
          final imagePath = '${directory.path}/widget_banner_${petition.id}.jpg';
          final response = await http.get(Uri.parse(petition.bannerImageUrl!));

          if (response.statusCode == 200) {
            final file = File(imagePath);
            await file.writeAsBytes(response.bodyBytes);
            localImagePath = imagePath;
          }
        } catch (e) {
          print("Error downloading widget image: $e");
        }
      }

      // Save data to SharedPreferences (used by home_widget)
      await HomeWidget.saveWidgetData<String>('petition_title', petition.title);
      await HomeWidget.saveWidgetData<int>('petition_current', petition.currentSignatures);
      await HomeWidget.saveWidgetData<int>('petition_goal', petition.goal);
      await HomeWidget.saveWidgetData<String>('petition_progress', petition.progress.toString());
      await HomeWidget.saveWidgetData<String>('petition_id', petition.id);
      
      if (localImagePath != null) {
        await HomeWidget.saveWidgetData<String>('petition_image_path', localImagePath);
      } else {
         // Clear image path if no image
         await HomeWidget.saveWidgetData<String>('petition_image_path', null);
      }
      
      // Update the widget
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
      print("Petition Widget updated with: ${petition.title}");
    } catch (e) {
      print("Error updating petition widget: $e");
    }
  }

  /// Fetches petitions signed by the current user
  static Future<List<Petition>> getSignedPetitions() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('petitions')
          .where('signers', arrayContains: user.uid)
          .get();

      return snapshot.docs
          .map((doc) => Petition.fromDocument(doc))
          .toList();
    } catch (e) {
      print("Error fetching signed petitions: $e");
      return [];
    }
  }
}
