import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_settings/app_settings.dart';
import 'dart:io';

class ActionService {
  static const _nativeChannel = MethodChannel('action_channel');

  /// Executes the action based on type and value
  static Future<void> executeAction(
    String actionType,
    String actionValue,
  ) async {
    print("⚡ [ActionService] Processing: $actionType -> $actionValue");
    try {
      switch (actionType.toLowerCase()) {
        case 'launch_app':
        case 'app':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'app',
              'value': actionValue,
            });
          } else {
            // iOS: Try URL scheme (limited support)
            await _launchIOSApp(actionValue);
          }
          break;

        case 'open_url':
        case 'web':
          await _openUrl(actionValue);
          break;

        case 'call_contact':
        case 'call':
          if (Platform.isAndroid) {
            // Use Native Channel for Direct Call (ACTION_CALL)
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'call',
              'value': actionValue,
            });
          } else {
            // iOS: Use tel: URL scheme (shows call prompt)
            await _makeCall(actionValue);
          }
          break;

        case 'toggle_flashlight':
        case 'flashlight':
          // Both Android and iOS have native flashlight handlers
          await _nativeChannel.invokeMethod('executeAction', {
            'type': 'flashlight',
            'value': actionValue,
          });
          break;

        case 'set_volume':
        case 'volume':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'volume',
              'value': actionValue,
            });
          } else {
            print('⚠️ [iOS] Volume control not available');
          }
          break;

        case 'toggle_dnd':
        case 'dnd':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'dnd',
              'value': actionValue,
            });
          } else {
            print('⚠️ [iOS] DND toggle not available');
          }
          break;

        case 'toggle_wifi':
        case 'wifi':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'wifi',
              'value': actionValue,
            });
          } else {
            // iOS: Open WiFi settings
            await AppSettings.openAppSettings(type: AppSettingsType.wifi);
          }
          break;

        case 'toggle_bluetooth':
        case 'bluetooth':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'bluetooth',
              'value': actionValue,
            });
          } else {
            // iOS: Open Bluetooth settings
            await AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
          }
          break;

        case 'settings':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'settings',
              'value': actionValue,
            });
          } else {
            // iOS: Open app settings
            await AppSettings.openAppSettings();
          }
          break;

        case 'toggle_nfc':
        case 'nfc':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'nfc',
              'value': actionValue,
            });
          } else {
            print('⚠️ [iOS] NFC toggle not available');
          }
          break;

        case 'toggle_aeroplane':
        case 'aeroplane':
          if (Platform.isAndroid) {
            await _nativeChannel.invokeMethod('executeAction', {
              'type': 'aeroplane',
              'value': actionValue,
            });
          } else {
            print('⚠️ [iOS] Airplane mode toggle not available');
          }
          break;

        case 'toggle_mobile_data':
          await AppSettings.openAppSettings(type: AppSettingsType.settings);
          break;

        case 'toggle_airplane':
          await AppSettings.openAppSettings(type: AppSettingsType.settings);
          break;

        case 'toggle_battery_saver':
          await AppSettings.openAppSettings(type: AppSettingsType.settings);
          break;

        default:
          print('⚠️ Unknown action type: $actionType');
      }
    } catch (e) {
      print('❌ Error executing action: $e');
      // Don't re-throw — prevents app crash from overlay/background calls
    }
  }

  /// iOS app launching via URL schemes
  static Future<void> _launchIOSApp(String packageOrScheme) async {
    // Map common Android package names to iOS URL schemes
    final Map<String, String> androidToiOS = {
      'com.whatsapp': 'whatsapp://',
      'com.instagram.android': 'instagram://',
      'com.facebook.katana': 'fb://',
      'com.twitter.android': 'twitter://',
      'org.telegram.messenger': 'telegram://',
      'com.google.android.youtube': 'youtube://',
      'com.spotify.music': 'spotify://',
      'com.linkedin.android': 'linkedin://',
      'com.pinterest': 'pinterest://',
      'com.reddit.frontpage': 'reddit://',
    };

    String urlScheme = androidToiOS[packageOrScheme] ?? packageOrScheme;

    // If it looks like an Android package, try to make it a URL scheme
    if (!urlScheme.contains('://')) {
      urlScheme = '$urlScheme://';
    }

    final Uri uri = Uri.parse(urlScheme);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      print('⚠️ [iOS] Cannot launch app: $packageOrScheme');
    }
  }

  static Future<void> _makeCall(String number) async {
    if (number.isEmpty) {
      print('⚠️ [Call] Empty number, skipping');
      return;
    }
    // Normalize: strip spaces, dashes, parentheses
    String cleaned = number.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    // Add +91 prefix for 10-digit Indian numbers
    if (cleaned.length == 10 && !cleaned.startsWith('+')) {
      cleaned = '+91$cleaned';
    } else if (cleaned.length == 12 &&
        cleaned.startsWith('91') &&
        !cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: cleaned);
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        print('⚠️ [Call] Could not launch call to $cleaned');
      }
    } catch (e) {
      print('❌ [Call] Error calling $cleaned: $e');
    }
  }

  static Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    String urlString = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      urlString = 'https://$url';
    }

    final Uri launchUri = Uri.parse(urlString);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch URL $urlString';
    }
  }
}
