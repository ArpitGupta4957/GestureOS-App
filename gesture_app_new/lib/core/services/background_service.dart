import 'dart:async';

// DUMMY IMPLEMENTATION TO PREVENT BUILD ERRORS
// since flutter_background_service is commented out in pubspec.yaml

@pragma("vm:entry-point")
void onStart(dynamic service) async {}

class BackgroundServiceInstance {
  static Future<void> initializeService() async {
    print("⚠️ [BackgroundService] Service DISABLED for Overlay Isolation Test");
  }

  static Future<void> start() async {}
  static Future<void> stop() async {}
  static Future<bool> isRunning() async { return false; }
}
