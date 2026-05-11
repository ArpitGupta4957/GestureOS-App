import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class OverlaySettings {
  final double bubbleSize;
  final double opacity;
  final String doubleTapAction; // 'QUICK_PANEL', 'CANVAS', 'NONE'
  final String longPressAction; // 'OPEN_APP', 'MOVE', 'NONE'
  final bool autoHide;
  final bool shakeEnabled;

  const OverlaySettings({
    this.bubbleSize = 35.0,
    this.opacity = 1.0,
    this.doubleTapAction = 'QUICK_PANEL',
    this.longPressAction = 'OPEN_APP',
    this.autoHide = false,
    this.shakeEnabled = true, // Default ON
  });

  OverlaySettings copyWith({
    double? bubbleSize,
    double? opacity,
    String? doubleTapAction,
    String? longPressAction,
    bool? autoHide,
    bool? shakeEnabled,
  }) {
    return OverlaySettings(
      bubbleSize: bubbleSize ?? this.bubbleSize,
      opacity: opacity ?? this.opacity,
      doubleTapAction: doubleTapAction ?? this.doubleTapAction,
      longPressAction: longPressAction ?? this.longPressAction,
      autoHide: autoHide ?? this.autoHide,
      shakeEnabled: shakeEnabled ?? this.shakeEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bubbleSize': bubbleSize,
      'opacity': opacity,
      'doubleTapAction': doubleTapAction,
      'longPressAction': longPressAction,
      'autoHide': autoHide,
      'shakeEnabled': shakeEnabled,
    };
  }
}

class OverlaySettingsNotifier extends StateNotifier<OverlaySettings> {
  OverlaySettingsNotifier() : super(const OverlaySettings()) {
    _loadSettings();
  }

  static const _kBubbleSize = 'overlay_bubble_size';
  static const _kOpacity = 'overlay_opacity';
  static const _kDoubleTap = 'overlay_double_tap';
  static const _kLongPress = 'overlay_long_press';
  static const _kAutoHide = 'overlay_auto_hide';
  static const _kShakeEnabled = 'overlay_shake_enabled';

  // Optimization Timers
  Timer? _syncTimer;
  Timer? _saveTimer;
  bool _needsSync = false;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = OverlaySettings(
      bubbleSize: prefs.getDouble(_kBubbleSize) ?? 35.0,
      opacity: prefs.getDouble(_kOpacity) ?? 1.0,
      doubleTapAction: prefs.getString(_kDoubleTap) ?? 'QUICK_PANEL',
      longPressAction: prefs.getString(_kLongPress) ?? 'OPEN_APP',
      autoHide: prefs.getBool(_kAutoHide) ?? false,
      shakeEnabled: prefs.getBool(_kShakeEnabled) ?? true,
    );
    // Initial sync
    _syncToNative();
  }

  void updateSettings({
    double? bubbleSize,
    double? opacity,
    String? doubleTapAction,
    String? longPressAction,
    bool? autoHide,
    bool? shakeEnabled,
  }) {
    // 1. Update Local State Immediately (UI is fast)
    state = state.copyWith(
      bubbleSize: bubbleSize,
      opacity: opacity,
      doubleTapAction: doubleTapAction,
      longPressAction: longPressAction,
      autoHide: autoHide,
      shakeEnabled: shakeEnabled,
    );

    // 2. Throttle Native Sync (Visual Updates)
    if (_syncTimer == null || !_syncTimer!.isActive) {
      _syncToNative();
      _syncTimer = Timer(const Duration(milliseconds: 50), () {
        if (_needsSync) {
          _syncToNative();
          _needsSync = false;
        }
      });
    } else {
      _needsSync = true;
    }

    // 3. Debounce Storage Save (Disk I/O)
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1000), _saveToPrefs);
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kBubbleSize, state.bubbleSize);
    await prefs.setDouble(_kOpacity, state.opacity);
    await prefs.setString(_kDoubleTap, state.doubleTapAction);
    await prefs.setString(_kLongPress, state.longPressAction);
    await prefs.setBool(_kAutoHide, state.autoHide);
    await prefs.setBool(_kShakeEnabled, state.shakeEnabled);
  }

  Future<void> _syncToNative() async {
    try {
      const channel = MethodChannel('overlay_channel');
      await channel.invokeMethod('updateOverlaySettings', state.toJson());
    } catch (e) {
      // Ignore
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }
}

final overlaySettingsProvider =
    StateNotifierProvider<OverlaySettingsNotifier, OverlaySettings>((ref) {
      return OverlaySettingsNotifier();
    });
