import 'dart:io';
import 'package:flutter/material.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:home_widget/home_widget.dart';
import 'package:go_router/go_router.dart';

/// Service to handle iOS specific triggers (App Icon Shortcuts, Widgets, etc.)
class IosTriggerService {
  static const QuickActions _quickActions = QuickActions();
  static const String _groupId =
      'group.com.yourcompany.gestureapp'; // App Group ID

  /// Initialize all iOS triggers
  static Future<void> initialize(BuildContext context) async {
    // 🛡️ STRICT PLATFORM GUARD 🛡️
    // This entire logic block executes ONLY on iOS.
    // Android is completely unaffected.
    if (!Platform.isIOS) return;

    debugPrint("🍎 [IosTriggerService] Initializing iOS Triggers...");

    try {
      await HomeWidget.setAppGroupId(_groupId);
    } catch (e) {
      debugPrint("❌ [HomeWidget] Set Group Error: $e");
    }

    await _setupAppIconShortcuts(context);
    await _setupHomeWidget(context);
  }

  /// 1. App Icon Shortcuts (3D Touch / Long Press)
  static Future<void> _setupAppIconShortcuts(BuildContext context) async {
    try {
      _quickActions.initialize((shortcutType) {
        debugPrint("🍎 [QuickActions] Triggered: $shortcutType");

        if (shortcutType == 'draw_gesture') {
          // Navigate to Draw Screen
          context.push('/draw-gesture');
        } else if (shortcutType == 'bulk_dialer') {
          // Navigate to Bulk Dialer
          // Assuming /bulk-dialer route exists, else Dashboard tab 1
          context.go('/dashboard');
          // You might need a specific provider update to switch tabs if using indexed stack
        }
      });

      await _quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
          type: 'draw_gesture',
          localizedTitle: 'Draw Gesture',
          icon: 'compose', // System icon name or asset
        ),
        const ShortcutItem(
          type: 'bulk_dialer',
          localizedTitle: 'Bulk Dialer',
          icon: 'contact',
        ),
      ]);

      debugPrint("🍎 [QuickActions] Shortcuts Registered");
    } catch (e) {
      debugPrint("❌ [QuickActions] Error: $e");
    }
  }

  /// 2. Home Screen Widget Data Sync
  static Future<void> _setupHomeWidget(BuildContext context) async {
    try {
      // Listen for Widget Taps (Deep Links essentially)
      HomeWidget.registerInteractivityCallback(_backgroundCallback);

      // Check if app was launched via Widget
      final launchedUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (launchedUri != null) {
        debugPrint("🍎 [HomeWidget] App launched from widget: $launchedUri");
        _handleWidgetLaunch(context, launchedUri);
      }
    } catch (e) {
      debugPrint("❌ [HomeWidget] Error: $e");
    }
  }

  static void _handleWidgetLaunch(BuildContext context, Uri uri) {
    if (uri.host == 'draw') {
      context.push('/draw-gesture');
    }
  }

  /// Update data available to the iOS Widget
  /// Call this whenever favorites change
  static Future<void> updateWidgetData(List<String> shortcutNames) async {
    if (!Platform.isIOS) return;

    try {
      await HomeWidget.saveWidgetData<String>(
        'shortcuts_list',
        shortcutNames.join(','),
      );
      await HomeWidget.updateWidget(
        name: 'QuickActionsWidget',
        iOSName: 'QuickActionsWidget',
      );
      debugPrint("🍎 [HomeWidget] Updated widget data: $shortcutNames");
    } catch (e) {
      debugPrint("❌ [HomeWidget] Update Error: $e");
    }
  }
}

/// Headless callback for widget interactivity (if needed)
@pragma('vm:entry-point')
Future<void> _backgroundCallback(Uri? uri) async {
  if (uri != null) {
    print("🍎 [HomeWidget] Background callback: $uri");
  }
}
