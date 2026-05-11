import 'package:flutter/services.dart';

class NativeDirectCaller {
  static const MethodChannel _channel = MethodChannel('action_channel');

  static Future<bool> callNumber(String number) async {
    try {
      // Reuse the existing 'executeAction' logic in MainActivity
      await _channel.invokeMethod('executeAction', {
        'type': 'call', 
        'value': number
      });
      return true;
    } catch (e) {
      print("NativeDirectCaller Error: $e");
      return false;
    }
  }
}
