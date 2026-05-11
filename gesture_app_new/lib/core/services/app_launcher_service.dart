import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import 'dart:io';

/// App launcher service for launching apps and URLs
class AppLauncherService {
  /// Launch an app by package name using Android Intent
  static Future<bool> launchApp(String packageName) async {
    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: packageName,
          flags: <int>[
            268435456, // FLAG_ACTIVITY_NEW_TASK
          ],
        );
        await intent.launch();
        return true;
      } else {
        // Fallback for iOS - open settings or custom URL scheme
        debugPrint("iOS: App Link Launch not implemented yet");
        // Try simple URL scheme if we knew it
        return false;
      }
    } catch (e) {
      print('Error launching app $packageName: $e');
      return false;
    }
  }

  /// Launch URL in browser
  static Future<bool> launchURL(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      print('Error launching URL $url: $e');
      return false;
    }
  }

  /// Common app shortcuts (you can get package names from user's device)
  static final Map<String, String> popularApps = {
    'Chrome': 'com.android.chrome',
    'Gmail': 'com.google.android.gm',
    'Maps': 'com.google.android.apps.maps',
    'YouTube': 'com.google.android.youtube',
    'Camera': 'com.android.camera',
    'Gallery': 'com.google.android.apps.photos',
    'Messages': 'com.google.android.apps.messaging',
    'Phone': 'com.google.android.dialer',
    'Contacts': 'com.google.android.contacts',
    'Settings': 'com.android.settings',
    'WhatsApp': 'com.whatsapp',
    'Instagram': 'com.instagram.android',
    'Facebook': 'com.facebook.katana',
    'Twitter': 'com.twitter.android',
    'Telegram': 'org.telegram.messenger',
  };

  /// Get list of installed apps (Mock Data for Demo)
  static Future<List<AppInfo>> getInstalledApps() async {
    // Return mock data to show UI functionality
    await Future.delayed(const Duration(milliseconds: 500)); // Simulate loading

    final List<AppInfo> mockApps = popularApps.entries.map((entry) {
      return AppInfo(
        packageName: entry.value,
        appName: entry.key,
        // No icon for mock data, UI handles this with default icon
      );
    }).toList();

    // Add some more mock apps to make the list look full like the screenshot
    mockApps.addAll([
      AppInfo(packageName: 'com.netflix.mediaclient', appName: 'Netflix'),
      AppInfo(packageName: 'com.spotify.music', appName: 'Spotify'),
      AppInfo(packageName: 'com.discord', appName: 'Discord'),
      AppInfo(packageName: 'com.snapchat.android', appName: 'Snapchat'),
      AppInfo(
        packageName: 'com.amazon.mShop.android.shopping',
        appName: 'Amazon',
      ),
      AppInfo(packageName: 'com.pinterest', appName: 'Pinterest'),
      AppInfo(packageName: 'com.linkedin.android', appName: 'LinkedIn'),
      AppInfo(packageName: 'com.zhiliaoapp.musically', appName: 'TikTok'),
      AppInfo(packageName: 'com.reddit.frontpage', appName: 'Reddit'),
    ]);

    mockApps.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );
    return mockApps;
  }

  /// Open system settings for specific action
  static Future<bool> openSettings(String settingsAction) async {
    try {
      if (Platform.isAndroid) {
        final intent = AndroidIntent(
          action: settingsAction,
          flags: <int>[268435456], // FLAG_ACTIVITY_NEW_TASK
        );
        await intent.launch();
        return true;
      } else {
        // iOS specific settings URLS
        // For now, open general settings
        // final Uri url = Uri.parse('app-settings:');
        // if (await canLaunchUrl(url)) await launchUrl(url);
        return false;
      }
    } catch (e) {
      print('Error opening settings $settingsAction: $e');
      return false;
    }
  }

  /// Toggle WiFi (requires system permissions)
  static Future<bool> toggleWiFi() async {
    return openSettings('android.settings.WIFI_SETTINGS');
  }

  /// Toggle Bluetooth settings
  static Future<bool> toggleBluetooth() async {
    return openSettings('android.settings.BLUETOOTH_SETTINGS');
  }

  /// Open location settings
  static Future<bool> openLocationSettings() async {
    return openSettings('android.settings.LOCATION_SOURCE_SETTINGS');
  }
}

/// App information model (simplified)
class AppInfo {
  final String packageName;
  final String appName;
  final Uint8List? icon;

  AppInfo({required this.packageName, required this.appName, this.icon});

  Map<String, dynamic> toJson() {
    return {'package_name': packageName, 'app_name': appName};
  }

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      packageName: json['package_name'],
      appName: json['app_name'],
    );
  }

  @override
  String toString() => 'AppInfo(name: $appName, package: $packageName)';
}
