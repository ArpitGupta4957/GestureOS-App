import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Service to handle deep links from iOS (mydail:// scheme)
/// and Siri Shortcuts for Back Tap functionality
class DeepLinkService {
  static const _channel = MethodChannel('deep_link_channel');
  static GoRouter? _router;
  static bool _initialized = false;

  /// Initialize the deep link listener
  /// Call this from main.dart after MaterialApp is built
  static void initialize(GoRouter router) {
    if (_initialized) return;
    _router = router;
    _initialized = true;

    if (Platform.isIOS) {
      _channel.setMethodCallHandler(_handleDeepLink);
      debugPrint('📱 [DeepLinkService] iOS deep link listener initialized');
    }
  }

  /// Update router reference if needed
  static void updateRouter(GoRouter router) {
    _router = router;
  }

  /// Handle incoming deep links from iOS
  static Future<dynamic> _handleDeepLink(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final args = call.arguments as Map<dynamic, dynamic>;
      final host = args['host'] as String? ?? '';
      final path = args['path'] as String? ?? '';

      debugPrint('📱 [DeepLinkService] Received: host=$host, path=$path');

      _routeDeepLink(host, path);
    }
    return null;
  }

  /// Route deep link to appropriate screen using go_router
  static void _routeDeepLink(String host, String path) {
    if (_router == null) {
      debugPrint('⚠️ [DeepLinkService] No router available for navigation');
      return;
    }

    switch (host.toLowerCase()) {
      case 'draw':
      case 'drawpad':
      case 'gesture':
        // Navigate to draw gesture screen
        _router!.go('/draw-gesture');
        debugPrint('✅ [DeepLinkService] Navigating to draw screen');
        break;

      case 'home':
        _router!.go('/home');
        break;

      case 'settings':
        _router!.go('/settings');
        break;

      default:
        debugPrint('⚠️ [DeepLinkService] Unknown deep link host: $host');
        // Default to home
        _router!.go('/home');
    }
  }

  /// Check if we launched from a deep link (for cold start)
  static Future<void> checkInitialLink() async {
    if (!Platform.isIOS) return;

    try {
      debugPrint('📱 [DeepLinkService] Checking initial link...');
    } catch (e) {
      debugPrint('⚠️ [DeepLinkService] Initial link check failed: $e');
    }
  }
}
