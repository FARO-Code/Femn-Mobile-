// settings.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:femn/auth/auth.dart';
import 'package:femn/customization/colors.dart'; 

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDeep,
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(color: AppColors.textHigh, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.backgroundDeep,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primaryLavender),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- THEMES SECTION ---
            Text(
              "Appearance",
              style: TextStyle(color: AppColors.primaryLavender, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildThemeCard(context, "Default", Color(0xFFAD80BF), Color(0xFF120E13)),
                  _buildThemeCard(context, "Spotify", Color(0xFF1DB954), Color(0xFF121212)),
                  _buildThemeCard(context, "YouTube", Color(0xFFFF0000), Color(0xFF0F0F0F)),
                ],
              ),
            ),
            SizedBox(height: 20),

            Divider(color: AppColors.elevation),
            
            // --- LOGOUT OPTION ---
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.elevation,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout, color: AppColors.error),
              ),
              title: Text(
                "Logout",
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, String name, Color primary, Color bg) {
    return GestureDetector(
      onTap: () {
        // This triggers the instant update via ThemeManager
        //ThemeManager().setTheme(name);
      },
      child: Container(
        margin: EdgeInsets.only(right: 12),
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.elevation, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Color Circle Preview
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(color: primary, width: 3),
              ),
              child: Center(
                child: Icon(Icons.circle, color: primary, size: 12),
              ),
            ),
            SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                color: AppColors.textHigh, 
                fontWeight: FontWeight.bold,
                fontSize: 14
              ),
            ),
          ],
        ),
      ),
    );
  }
}