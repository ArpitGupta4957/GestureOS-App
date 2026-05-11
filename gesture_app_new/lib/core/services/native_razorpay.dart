import 'package:flutter/services.dart';

class NativeRazorpay {
  static const MethodChannel _channel = MethodChannel('razorpay_channel');

  static Future<Map<String, dynamic>> open(Map<String, dynamic> options) async {
    try {
      final result = await _channel.invokeMethod('open', options);
      return Map<String, dynamic>.from(result);
    } on PlatformException {
      rethrow;
    }
  }
}
