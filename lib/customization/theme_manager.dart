import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'colors.dart';
import '../customization/fonts.dart';

enum FemnThemeMode {
  midnightActivist, // Dark (Default)
  clarifiedDay,     // Light
  sageWellness,     // Nature
  highImpact,       // Contrast
}

class ThemeManager extends ChangeNotifier {
  static const String _themePrefKey = 'selected_theme';
  static const String _matchSystemKey = 'match_system';

  FemnThemeMode _currentMode = FemnThemeMode.midnightActivist;
  bool _matchSystem = false; // Default to manual control initially as per request logic, can be changed.

  FemnThemeMode get currentMode => _currentMode;
  bool get matchSystem => _matchSystem;

  ThemeManager() {
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _matchSystem = prefs.getBool(_matchSystemKey) ?? true; // Default true as per user request
    if (!_matchSystem) {
      final int? themeIndex = prefs.getInt(_themePrefKey);
      if (themeIndex != null && themeIndex >= 0 && themeIndex < FemnThemeMode.values.length) {
        _currentMode = FemnThemeMode.values[themeIndex];
      }
    }
    notifyListeners();
  }

  Future<void> setMatchSystem(bool value) async {
    _matchSystem = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_matchSystemKey, value);
    notifyListeners();
  }

  Future<void> setTheme(FemnThemeMode mode) async {
    if (_matchSystem) {
      // If we pick a theme manually, we likely want to turn off system sync?
      // Or we just update the preference for when efficient.
      // User request: "Option A (Best): No "Save" button. Tapping the theme applies it immediately"
      // Let's disable Match System if they manually pick a theme.
      await setMatchSystem(false);
    }
    _currentMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, mode.index);
    notifyListeners();
  }

  // --- Theme Generators ---

  ThemeData getThemeData(FemnThemeMode mode, {bool systemDarkMode = true}) {
    // If matching system, override mode based on system brightness
    FemnThemeMode effectiveMode = mode;
    if (_matchSystem) {
       effectiveMode = systemDarkMode ? FemnThemeMode.midnightActivist : FemnThemeMode.clarifiedDay;
    }

    switch (effectiveMode) {
      case FemnThemeMode.clarifiedDay:
        return _buildClarifiedDay();
      case FemnThemeMode.sageWellness:
        return _buildSageWellness();
      case FemnThemeMode.highImpact:
        return _buildHighImpact();
      case FemnThemeMode.midnightActivist:
      default:
        return _buildMidnightActivist();
    }
  }
  
  // 1. Midnight Activist (Original Dark)
  ThemeData _buildMidnightActivist() {
    const colors = FemnColors(
      backgroundDeep: Color(0xFF120E13),
      surface: Color(0xFF1E1B24),
      elevation: Color(0xFF2D2636),
      primaryLavender: Color(0xFFAD80BF),
      secondaryTeal: Color.fromARGB(255, 15, 103, 117),
      accentMustard: Color(0xFFBA8736),
      textHigh: Color(0xFFE6E1E5),
      textMedium: Color(0xFFCAC4D0),
      textDisabled: Color(0xFF49454F),
      error: Color(0xFFFFB4AB),
      success: Color(0xFFA5D6A7),
      iconDefault: Color(0xFFAD80BF),
      textOnSecondary: Colors.white,
    );

    return _buildThemeFromColors(colors, Brightness.dark);
  }

  // 2. Clarified Day (Light Mode)
  ThemeData _buildClarifiedDay() {
    const colors = FemnColors(
      backgroundDeep: Color(0xFFF9F9F9), // Soft Off-White
      surface: Color(0xFFFFFFFF),        // Pure White Cards
      elevation: Color(0xFFECECEC),      // Slight grey for bounds
      primaryLavender: Color(0xFF8D5E9F), // Darker Lavender for contrast on white
      secondaryTeal: Color(0xFF0F6775),
      accentMustard: Color(0xFFBA8736),
      textHigh: Color(0xFF1C1B1F),       // Dark Gunmetal (Main Text)
      textMedium: Color(0xFF48464C),     // Dark Grey
      textDisabled: Color(0xFF939094),
      error: Color(0xFFB3261E),          // Standard Red for Light
      success: Color(0xFF2E7D32),        // Darker Green
      iconDefault: Color(0xFF8D5E9F),
      textOnSecondary: Colors.white,
    );
     return _buildThemeFromColors(colors, Brightness.light);
  }

  // 3. Sage & Wellness (Forest Green / Nature)
  ThemeData _buildSageWellness() {
    const colors = FemnColors(
      backgroundDeep: Color(0xFF0F1510), // Very dark forest green
      surface: Color(0xFF1A241C),        // Lighter green surface
      elevation: Color(0xFF253328),
      primaryLavender: Color.fromARGB(255, 15, 103, 117), // Using Teal as primary for nature
      secondaryTeal: Color(0xFFAD80BF),  // Lavender becomes secondary
      accentMustard: Color(0xFFE8D3B9),  // Beige accent
      textHigh: Color(0xFFEFEFEF),
      textMedium: Color(0xFFC8CEC9),
      textDisabled: Color(0xFF5C635D),
      error: Color(0xFFFFB4AB),
      success: Color(0xFFA5D6A7),
      iconDefault: Color.fromARGB(255, 15, 103, 117),
      textOnSecondary: Colors.white,
    );
    return _buildThemeFromColors(colors, Brightness.dark);
  }

  // 4. High Impact (OLED Black)
  ThemeData _buildHighImpact() {
    const colors = FemnColors(
      backgroundDeep: Color(0xFF000000), // True Black
      surface: Color(0xFF121212),
      elevation: Color(0xFF2C2C2C),
      primaryLavender: Color(0xFFBA8736), // Mustard Primary (High Vis)
      secondaryTeal: Colors.tealAccent,
      accentMustard: Colors.yellowAccent,
      textHigh: Color(0xFFFFFFFF),       // Pure White
      textMedium: Color(0xFFE0E0E0),
      textDisabled: Color(0xFF808080),
      error: Color(0xFFFF5252),
      success: Color(0xFF69F0AE),
      iconDefault: Color(0xFFBA8736),
      textOnSecondary: Colors.black,
    );
    return _buildThemeFromColors(colors, Brightness.dark);
  }

  ThemeData _buildThemeFromColors(FemnColors colors, Brightness brightness) {
    return ThemeData(
      brightness: brightness,
      primaryColor: colors.primaryLavender,
      scaffoldBackgroundColor: colors.backgroundDeep,
      
      // Extensions!
      extensions: [colors],
      
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.primaryLavender,
        onPrimary: brightness == Brightness.dark ? colors.backgroundDeep : Colors.white,
        secondary: colors.secondaryTeal,
        onSecondary: colors.textOnSecondary,
        surface: colors.surface,
        onSurface: colors.textHigh,
        error: colors.error,
        onError: Colors.white,
      ),

      // Component Themes using our colors
      appBarTheme: AppBarTheme(
        backgroundColor: colors.backgroundDeep,
        elevation: 0,
        iconTheme: IconThemeData(color: colors.primaryLavender),
        titleTextStyle: TextStyle(
          color: colors.textHigh,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primaryLavender,
          foregroundColor: brightness == Brightness.dark ? colors.backgroundDeep : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),

      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.elevation,
        hintStyle: TextStyle(color: colors.textDisabled),
        labelStyle: TextStyle(color: colors.textMedium),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
           borderRadius: BorderRadius.circular(14),
           borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.primaryLavender, width: 1.5),
        ),
      ),
      
      iconTheme: IconThemeData(color: colors.iconDefault),
      
      textTheme: TextTheme(
        bodyLarge: primaryTextStyle(fontSize: 18.0, color: colors.textHigh),
        bodyMedium: primaryTextStyle(fontSize: 16.0, color: colors.textMedium),
        displayLarge: primaryVeryBoldTextStyle(fontSize: 32.0, color: colors.textHigh),
        displayMedium: primaryVeryBoldTextStyle(fontSize: 28.0, color: colors.textHigh),
        displaySmall: primaryVeryBoldTextStyle(fontSize: 24.0, color: colors.textHigh),
        headlineMedium: primaryVeryBoldTextStyle(fontSize: 20.0, color: colors.textHigh),
        headlineSmall: primaryVeryBoldTextStyle(fontSize: 18.0, color: colors.textHigh),
        titleLarge: primaryVeryBoldTextStyle(fontSize: 16.0, color: colors.textHigh),
        titleMedium: secondaryTextStyle(fontSize: 16.0, fontWeight: FontWeight.bold, color: colors.textHigh),
        titleSmall: secondaryTextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: colors.textHigh),
        bodySmall: secondaryTextStyle(fontSize: 12.0, color: colors.textMedium),
        labelLarge: secondaryVeryBoldTextStyle(fontSize: 16.0, color: colors.textHigh),
        labelSmall: secondaryTextStyle(fontSize: 10.0, color: colors.textMedium),
      ),
    );
  }
}
