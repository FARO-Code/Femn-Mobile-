import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- The Data Model ---
class WidgetLayout {
  final String id;
  final String name;
  final IconData icon;
  final String description;
  final int crossAxisCellCount;
  final int mainAxisCellCount;
  final int position;
  final bool isVisible;
  final Map<String, dynamic>? metadata;

  WidgetLayout({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.crossAxisCellCount = 2,
    this.mainAxisCellCount = 2,
    this.position = 0,
    this.isVisible = true,
    this.metadata,
  });

  // Create a copy of the object with updated values
  WidgetLayout copyWith({
    String? id,
    String? name,
    IconData? icon,
    String? description,
    int? crossAxisCellCount,
    int? mainAxisCellCount,
    int? position,
    bool? isVisible,
    Map<String, dynamic>? metadata,
  }) {
    return WidgetLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      crossAxisCellCount: crossAxisCellCount ?? this.crossAxisCellCount,
      mainAxisCellCount: mainAxisCellCount ?? this.mainAxisCellCount,
      position: position ?? this.position,
      isVisible: isVisible ?? this.isVisible,
      metadata: metadata ?? this.metadata,
    );
  }

  // Convert to Map for JSON saving
  // Note: We don't save the IconData directly to JSON, we rely on the ID to restore it
  // or we save the layout properties and merge with default definitions.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'crossAxisCellCount': crossAxisCellCount,
      'mainAxisCellCount': mainAxisCellCount,
      'position': position,
      'isVisible': isVisible,
    };
  }

  // Helper to reconstruct from JSON, merging with a default "Definition" to get back the Icon
  factory WidgetLayout.fromJson(Map<String, dynamic> json, WidgetLayout defaultDef) {
    return defaultDef.copyWith(
      crossAxisCellCount: json['crossAxisCellCount'],
      mainAxisCellCount: json['mainAxisCellCount'],
      position: json['position'],
      isVisible: json['isVisible'],
    );
  }
}

// --- The Service ---
class WidgetCustomizationService {
  static const String _storageKey = 'wellness_dashboard_layout';

  // 1. Define the Master List of all available widgets
  final List<WidgetLayout> _allWidgetsDefaults = [
    WidgetLayout(
      id: 'wellness_journal',
      name: 'Journal',
      icon: Feather.book,
      description: 'Track your thoughts & mood',
      crossAxisCellCount: 2,
      mainAxisCellCount: 2,
      metadata: {'hasStreak': true},
    ),
    WidgetLayout(
      id: 'cycle',
      name: 'Cycle',
      icon: Feather.droplet,
      description: 'Period & ovulation tracker',
      crossAxisCellCount: 3,
      mainAxisCellCount: 2,
      metadata: {'isCycle': true},
    ),
    WidgetLayout(
      id: 'activity',
      name: 'Activity',
      icon: Feather.activity,
      description: 'Physical movement log',
      crossAxisCellCount: 2,
      mainAxisCellCount: 2,
    ),
    WidgetLayout(
      id: 'twin_finder',
      name: 'Twin Finder',
      icon: Feather.users,
      description: 'Find your personality twin',
      crossAxisCellCount: 2,
      mainAxisCellCount: 2,
    ),
    WidgetLayout(
      id: 'leak_guard',
      name: 'LeakGuard',
      icon: Feather.shield,
      description: 'Protection reminders',
      crossAxisCellCount: 3,
      mainAxisCellCount: 2,
    ),
  ];

  // Get all widgets that exist in the app
  List<WidgetLayout> getAvailableWidgets() {
    return _allWidgetsDefaults;
  }

  // Get the default starting layout
  List<WidgetLayout> getDefaultLayout() {
    // Return copies so we don't mutate the master list
    return _allWidgetsDefaults.map((w) => w.copyWith()).toList();
  }

  // Save the current list to SharedPreferences
  Future<void> saveLayout(List<WidgetLayout> widgets) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Sort by position before saving to ensure consistency
    widgets.sort((a, b) => a.position.compareTo(b.position));

    final String encoded = jsonEncode(widgets.map((w) => w.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  // Load from SharedPreferences
  Future<List<WidgetLayout>> getSavedLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null) {
      return getDefaultLayout();
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      final List<WidgetLayout> loadedWidgets = [];

      // We define a map of the default definitions for easy lookup
      final Map<String, WidgetLayout> definitionsMap = {
        for (var w in _allWidgetsDefaults) w.id: w
      };

      for (var item in decoded) {
        final String id = item['id'];
        final WidgetLayout? definition = definitionsMap[id];

        // Only add if the widget ID still exists in our app definitions
        if (definition != null) {
          loadedWidgets.add(WidgetLayout.fromJson(item, definition));
        }
      }

      // Handle New Widgets:
      // If we added a new widget to the app update since the user last saved,
      // it won't be in the saved JSON. We should add it to the end or keep it available.
      // For now, we only return what was saved. The "Add Widget" screen handles the rest.
      
      return loadedWidgets..sort((a, b) => a.position.compareTo(b.position));

    } catch (e) {
      // If data is corrupt, return default
      debugPrint("Error loading layout: $e");
      return getDefaultLayout();
    }
  }
}
