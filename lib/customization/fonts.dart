import 'package:flutter/material.dart';
import 'package:femn/customization/colors.dart'; // <--- IMPORT YOUR COLORS FILE

// Define the font family name (must match pubspec.yaml)
const String _fontFamily = 'Helvetica';

// Create a TextStyle for regular Helvetica
TextStyle helveticaStyle({
  double fontSize = 16.0,
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textHigh, // Default to Off-White for Dark Mode
}) {
  return TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
}

// Utility functions for very bold text
TextStyle helveticaBoldStyle({
  double fontSize = 16.0,
  Color color = AppColors.textHigh, // Default to Off-White
}) {
  return TextStyle(
    fontFamily: _fontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.bold,
    color: color,
  );
}

// Optional: You can keep your old names if you prefer
// But now they refer to Helvetica instead of Google Fonts
final primaryFont = _fontFamily; 
final secondaryFont = _fontFamily;

// Keep your utility functions but rename them to reflect Helvetica
TextStyle primaryTextStyle({
  double fontSize = 16.0,
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textHigh,
}) {
  return helveticaStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

TextStyle secondaryTextStyle({
  double fontSize = 16.0,
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textHigh,
}) {
  return helveticaStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

// Very bold versions
TextStyle primaryVeryBoldTextStyle({
  double fontSize = 16.0,
  Color color = AppColors.textHigh,
}) {
  return helveticaBoldStyle(fontSize: fontSize, color: color);
}

TextStyle secondaryVeryBoldTextStyle({
  double fontSize = 16.0,
  Color color = AppColors.textHigh,
}) {
  return helveticaBoldStyle(fontSize: fontSize, color: color);
}
