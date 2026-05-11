import 'package:flutter/services.dart';
import 'package:gesture_app/features/gesture/models/quick_action_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class QuickActionService {
  static const MethodChannel _channel = MethodChannel('overlay_channel');
  static const String _prefsKey = 'user_shortcuts_v2';

  static List<QuickShortcut> _cachedShortcuts = [];

  static Future<List<QuickShortcut>> loadShortcuts({bool force = false}) async {
    if (!force && _cachedShortcuts.isNotEmpty) return _cachedShortcuts;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      if (force) {
         await prefs.reload();
      }
      final String? jsonString = prefs.getString(_prefsKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _cachedShortcuts = jsonList.map((e) => QuickShortcut.fromJson(e)).toList();
      } else {
        // No defaults - User must add them (Future UI)
        _cachedShortcuts = [];
      }
    } catch (e) {
      print("Error loading shortcuts: $e");
    }
    return _cachedShortcuts;
  }

  static Future<void> saveShortcuts(List<QuickShortcut> shortcuts) async {
    _cachedShortcuts = shortcuts;
    try {
      final prefs = await SharedPreferences.getInstance();
      final String jsonString = jsonEncode(shortcuts.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, jsonString);
    } catch (e) {
      print("Error saving shortcuts: $e");
    }
  }

  static Future<List<FrequentContact>> getFrequentContacts() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getRecentCalls');
      print("📞 Raw Contacts: ${result?.length ?? 0}");
      if (result == null) return [];
      
      final uniqueNumbers = <String>{};
      final contacts = <FrequentContact>[];

      for (var e in result) {
        try {
          final number = e['number']?.toString() ?? '';
          if (number.isNotEmpty && !uniqueNumbers.contains(number)) {
              uniqueNumbers.add(number);
              
              String name = e['name']?.toString() ?? 'Unknown';
              if (name.trim().isEmpty) name = 'Unknown';
              
              contacts.add(FrequentContact(
                name: name,
                number: number,
                timesContacted: e['timesContacted'] ?? 0,
              ));
          }
        } catch (e) {
          print("⚠️ Error parsing contact: $e");
        }
      }
      print("📞 Unique Contacts (Limit 8): ${contacts.length}");
      return contacts.take(8).toList();
    } catch (e) {
      print("❌ Error fetching contacts: $e");
      return [];
    }
  }

  static Future<List<AppUsage>> getTopApps() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod('getTopApps');
      print("📱 Raw Apps: ${result?.length ?? 0}");
      if (result == null) return [];
      
      final uniquePackages = <String>{};
      final apps = <AppUsage>[];

      for (var e in result) {
        try {
          final packageName = e['packageName']?.toString() ?? '';
          if (packageName.isNotEmpty && !uniquePackages.contains(packageName)) {
              uniquePackages.add(packageName);
              
              String appName = e['appName']?.toString() ?? 'App';
              if (appName.trim().isEmpty) appName = 'App';
              
              apps.add(AppUsage(
                packageName: packageName,
                appName: appName,
                usageTime: e['usageTime'] ?? 0,
                iconData: e['icon'], 
              ));
          }
        } catch (e) {
             print("⚠️ Error parsing app usage: $e");
        }
      }
      print("📱 Unique Apps: ${apps.length}");
      return apps;
    } catch (e) {
      print("❌ Error fetching app usage: $e");
      return [];
    }
  }
}
