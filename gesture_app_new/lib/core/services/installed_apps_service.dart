import 'package:flutter/services.dart';

class AppInfo {
  final String name;
  final String packageName;
  final Uint8List? icon;

  AppInfo({required this.name, required this.packageName, this.icon});
}

class InstalledAppsService {
  static const _channel = MethodChannel('apps_channel');

  /// Fetch list of launchable apps from device
  static Future<List<AppInfo>> getApps() async {
    try {
      final List<dynamic> apps = await _channel.invokeMethod(
        'getInstalledApps',
      );

      return apps
          .map(
            (a) => AppInfo(
              name: a['name'] as String,
              packageName: a['package'] as String,
              icon: a['icon'],
            ),
          )
          .toList();
    } catch (e) {
      print("❌ Error fetching apps: $e");
      return [];
    }
  }
}
