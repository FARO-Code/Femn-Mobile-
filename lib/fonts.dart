import 'package:flutter/material.dart';

// Define the font family name (must match pubspec.yaml)
const String _fontFamily = 'Helvetica';

// Create a TextStyle for regular Helvetica
TextStyle helveticaStyle({
  double fontSize = 16.0,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black87,
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
  Color color = Colors.black87,
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
final primaryFont = _fontFamily; // Not used as a font directly anymore
final secondaryFont = _fontFamily;

// Keep your utility functions but rename them to reflect Helvetica
TextStyle primaryTextStyle({
  double fontSize = 16.0,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black87,
}) {
  return helveticaStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

TextStyle secondaryTextStyle({
  double fontSize = 16.0,
  FontWeight fontWeight = FontWeight.normal,
  Color color = Colors.black87,
}) {
  return helveticaStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);
}

// Very bold versions
TextStyle primaryVeryBoldTextStyle({
  double fontSize = 16.0,
  Color color = Colors.black87,
}) {
  return helveticaBoldStyle(fontSize: fontSize, color: color);
}

TextStyle secondaryVeryBoldTextStyle({
  double fontSize = 16.0,
  Color color = Colors.black87,
}) {
  return helveticaBoldStyle(fontSize: fontSize, color: color);
}