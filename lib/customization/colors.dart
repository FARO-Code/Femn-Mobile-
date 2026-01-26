import 'package:flutter/material.dart';

class AppColors {
  // --- 1. The Core Palette ---
  static const Color primaryLavender = Color(0xFFAD80BF); // Main buttons, active tabs, links
  static const Color secondaryTeal = Color.fromARGB(255, 15, 103, 117);   // Secondary containers, chips
  static const Color accentMustard = Color(0xFFBA8736);   // FAB, "New" badges, highlights

  // --- 2. The Backgrounds ("Tinted Grays") ---
  // A near-black with a hint of purple warmth
  static const Color backgroundDeep = Color(0xFF120E13); 
  // Slightly lighter, used for card backgrounds/lists
  static const Color surface = Color(0xFF1E1B24);        
  // Lighter still, for bottom sheets, nav bars, or inactive buttons
  static const Color elevation = Color(0xFF2D2636);      

  // --- 3. Text Hierarchy (On Dark Backgrounds) ---
  static const Color textHigh = Color(0xFFE6E1E5);       // Headings (Off-white)
  static const Color textMedium = Color(0xFFCAC4D0);     // Body (Light Gray)
  static const Color textDisabled = Color(0xFF49454F);   // Hints/Disabled (Dark Gray)

  // --- 4. Semantic Colors (Functional) ---
  static const Color error = Color(0xFFFFB4AB);          // Soft Red
  static const Color success = Color(0xFFA5D6A7);        // Soft Green
  static const Color warning = Color(0xFFBA8736);        // (Same as Mustard)
  
  // --- 5. Helpers ---
  // A helper to quickly get white text for your Teal containers (since they are dark)
  static const Color textOnSecondary = Colors.white;
  // A helper for icons on dark backgrounds
  static const Color iconDefault = Color(0xFFAD80BF); 
}
