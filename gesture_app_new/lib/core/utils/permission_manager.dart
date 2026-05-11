import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// Permission types needed for gesture control
enum AppPermission {
  notification,
  systemAlertWindow,
  ignoreBatteryOptimizations,
  contacts,
  storage,
  photos,
}

/// Permission manager for handling all app permissions
class PermissionManager {
  /// Check if all required permissions are granted
  static Future<bool> hasAllPermissions() async {
    final notification = await Permission.notification.isGranted;
    final overlay = Platform.isAndroid
        ? await Permission.systemAlertWindow.isGranted
        : true; // Overlay is Android-only
    final battery = Platform.isAndroid
        ? await Permission.ignoreBatteryOptimizations.isGranted
        : true; // Skip check on iOS
    final contacts = await Permission.contacts.isGranted;

    return notification && overlay && battery && contacts;
  }

  /// Check specific permission status
  static Future<bool> hasPermission(AppPermission permission) async {
    switch (permission) {
      case AppPermission.notification:
        return await Permission.notification.isGranted;
      case AppPermission.systemAlertWindow:
        return await Permission.systemAlertWindow.isGranted;
      case AppPermission.ignoreBatteryOptimizations:
        return await Permission.ignoreBatteryOptimizations.isGranted;
      case AppPermission.contacts:
        return await Permission.contacts.isGranted;
      case AppPermission.storage:
        return await Permission.storage.isGranted;
      case AppPermission.photos:
        return await Permission.photos.isGranted;
    }
  }

  /// Request specific permission
  static Future<bool> requestPermission(AppPermission permission) async {
    Permission perm;

    switch (permission) {
      case AppPermission.notification:
        perm = Permission.notification;
        break;
      case AppPermission.systemAlertWindow:
        perm = Permission.systemAlertWindow;
        break;
      case AppPermission.ignoreBatteryOptimizations:
        perm = Permission.ignoreBatteryOptimizations;
        break;
      case AppPermission.contacts:
        perm = Permission.contacts;
        break;
      case AppPermission.storage:
        perm = Permission.storage;
        break;
      case AppPermission.photos:
        perm = Permission.photos;
        break;
    }

    final status = await perm.request();
    return status.isGranted;
  }

  /// Request all permissions at once
  static Future<Map<AppPermission, bool>> requestAllPermissions() async {
    final results = <AppPermission, bool>{};

    for (final permission in AppPermission.values) {
      results[permission] = await requestPermission(permission);
    }

    return results;
  }

  /// Open app settings for manual permission grant
  static Future<void> openAppSettings() async {
    await openAppSettings();
  }

  /// Get permission name for display
  static String getPermissionName(AppPermission permission) {
    switch (permission) {
      case AppPermission.notification:
        return 'Notifications';
      case AppPermission.systemAlertWindow:
        return 'Display Over Other Apps';
      case AppPermission.ignoreBatteryOptimizations:
        return 'Background Service';
      case AppPermission.contacts:
        return 'Contacts';
      case AppPermission.storage:
        return 'Storage';
      case AppPermission.photos:
        return 'Gallery / Photos';
    }
  }

  /// Get permission description
  static String getPermissionDescription(AppPermission permission) {
    switch (permission) {
      case AppPermission.notification:
        return 'Allows MyDial to show gesture feedback and stay active in the background. Your data is processed locally and never shared.';
      case AppPermission.systemAlertWindow:
        return 'Allows the floating Quickball and gesture pad to appear over other apps. This is the core way to use MyDial. No screen data is recorded.';
      case AppPermission.ignoreBatteryOptimizations:
        return 'Ensures the gesture service is not killed by the system, allowing you to use gestures at any time. This uses minimal battery.';
      case AppPermission.contacts:
        return 'Allows you to assign gestures to your contacts for instant calling. Contact data is only used locally for display and is not uploaded.';
      case AppPermission.storage:
        return 'Required to import Excel files for bulk dialing and saving app data. Only requested files are accessed.';
      case AppPermission.photos:
        return 'Required to assign custom photos from your gallery to your contacts and aliases locally.';
    }
  }

  /// Get permission icon
  static IconData getPermissionIcon(AppPermission permission) {
    switch (permission) {
      case AppPermission.notification:
        return Icons.notifications_active_rounded;
      case AppPermission.systemAlertWindow:
        return Icons.layers_rounded;
      case AppPermission.ignoreBatteryOptimizations:
        return Icons.battery_charging_full_rounded;
      case AppPermission.contacts:
        return Icons.contacts_rounded;
      case AppPermission.storage:
        return Icons.folder_open_rounded;
      case AppPermission.photos:
        return Icons.image_rounded;
    }
  }

  /// Map permission_handler Permission to AppPermission
  static AppPermission? fromPermission(Permission permission) {
    if (permission == Permission.notification) return AppPermission.notification;
    if (permission == Permission.systemAlertWindow) {
      return AppPermission.systemAlertWindow;
    }
    if (permission == Permission.ignoreBatteryOptimizations) {
      return AppPermission.ignoreBatteryOptimizations;
    }
    if (permission == Permission.contacts) return AppPermission.contacts;
    if (permission == Permission.storage) return AppPermission.storage;
    if (permission == Permission.photos) return AppPermission.photos;
    return null;
  }
}
