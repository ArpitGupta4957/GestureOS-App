import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math'; // For max
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gesture_app/core/utils/gesture_recognizer.dart';
import 'package:gesture_app/core/services/action_service.dart';
import 'package:gesture_app/core/data/default_gestures.dart';
import 'dart:async';
import 'dart:ui' as ui; // For PictureRecorder
import 'dart:io'; // For Temp File
import 'package:path_provider/path_provider.dart'; // For Temp Dir
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:gesture_app/core/services/quick_action_service.dart';
import 'package:gesture_app/features/gesture/models/quick_action_models.dart';
import 'package:gesture_app/core/models/gesture_model.dart';

enum GestureIntent { text, shape }

class OverlayService {
  static const String overlayName = "gesture_bubble";
  static const MethodChannel _channel = MethodChannel('overlay_channel');

  // Local cache of templates for matching
  static List<GestureTemplate> _templates = [];
  static Map<String, GestureTemplate> _textTriggerIndex = {}; // O(1) Lookup
  static List<GestureModel> _cachedGestures = []; // Full Cache for Shortcuts

  // 0 = Low, 1 = Medium (Default), 2 = High
  static int _strictness = 1;
  static int get strictness => _strictness;

  // Expose action delay so UI can show countdown
  static int get actionDelayMs => _actionDelayMs;

  // --- HYBRID RECOGNITION STATE ---
  static final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Initialize the service and listener
  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_methodHandler);
    debugPrint("🔵 [OverlayService] Listener Initialized");

    // Load strictness
    final prefs = await SharedPreferences.getInstance();
    _strictness = prefs.getInt('gesture_strictness') ?? 1;
    _recognitionDelayMs = prefs.getInt('recognition_delay') ?? 600;
    _actionDelayMs = prefs.getInt('action_delay') ?? 0;

    debugPrint(
      "🎯 [OverlayService] Strictness: $_strictness, RecogDelay: ${_recognitionDelayMs}ms, ActionDelay: ${_actionDelayMs}ms",
    );
    // Init Handwriting (Removed for Offline Geometric Approach)
    // HandwritingService().initialize(); - DEPRECATED
  }

  static void setStrictness(int level) {
    _strictness = level.clamp(0, 2);
    debugPrint("🎯 [OverlayService] Strictness set to: $_strictness");
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('gesture_strictness', _strictness);
    });
  }

  /// Check if the native overlay service is running
  static Future<bool> isRunning() async {
    try {
      if (Platform.isAndroid) {
        final bool isOpen = await _channel.invokeMethod('isOverlayActive');
        return isOpen;
      }
      return false;
    } catch (e) {
      debugPrint("⚠️ Failed to check overlay status: $e");
      return false;
    }
  }

  /// Helper to check if a name is a favorite (Legacy helper, mostly unused now as UI uses model)
  // static bool isShortcut(String name) { ... }

  /// Update local templates from Provider
  static void updateGestures(List<GestureModel> gestures) {
    _cachedGestures = gestures; // Store full list
    _templates = [];
    _textTriggerIndex = {}; // Clear index
    debugPrint(
      "🔄 [OverlayService] Syncing ${gestures.length} gestures to Overlay...",
    );

    for (final gesture in gestures) {
      debugPrint("  → Processing: ${gesture.name} (UUID: ${gesture.uuid})");
      debugPrint("    Raw Points Count: ${gesture.points.length}");
      if (gesture.points.isNotEmpty) {
        debugPrint("    Sample Point [0]: ${gesture.points.first}");
      }

      // 1. Index Text Trigger (if present)
      if (gesture.triggerText != null && gesture.triggerText!.isNotEmpty) {
        // Normalize trigger key the same way OCR normalizes input so lookups match
        final normalizedTrigger =
            _normalizeForOCR(gesture.triggerText!.trim().toLowerCase());

        // Create a template logic wrapper
        final template = GestureTemplate(
          name: gesture.name,
          points: [], // Not needed for text trigger
          metadata: {
            'actionType': gesture.actionType,
            'actionValue': gesture.actionValue,
            'id': gesture.id,
            'triggerText': normalizedTrigger,
            'isFavorite': gesture.isFavorite,
          },
        );

        _textTriggerIndex[normalizedTrigger] = template;
        debugPrint("    ✓ Text trigger indexed: '$normalizedTrigger'");
      }

      // 2. Index Draw Trigger (if valid points)
      if (gesture.points.length >= 5) {
        try {
          final copiedPoints =
              gesture.points.map((p) => Offset(p.dx, p.dy)).toList();
          final normalized = GestureRecognizer.normalize(copiedPoints);

          _templates.add(
            GestureTemplate(
              name: gesture.name,
              points: normalized,
              metadata: {
                'actionType': gesture.actionType,
                'actionValue': gesture.actionValue,
                'id': gesture.id,
                'triggerText': gesture.triggerText,
                'isFavorite': gesture.isFavorite,
              },
            ),
          );
          debugPrint(
            "    ✓ Draw template created (${normalized.length} normalized points)",
          );
        } catch (e) {
          debugPrint("    ❌ Failed to create template: $e");
        }
      } else if (gesture.points.isNotEmpty) {
        debugPrint(
          "    ⚠️ Not enough points for draw gesture (min 5, got ${gesture.points.length})",
        );
      }
    }

    // --- LOAD DEFAULT GEOMETRIC TEMPLATES (Offline Handwriting) ---
    _templates.addAll(DefaultGestures.all);
    debugPrint(
      "    ✓ Added ${DefaultGestures.all.length} default geometric templates (A-Z)",
    );
    debugPrint(
      "🧠 [OverlayService] Total draw templates: ${_templates.length}",
    );
    debugPrint(
      "⌨️ [OverlayService] Total text triggers: ${_textTriggerIndex.length}",
    );

    // Sync Shortcuts based on Database Flag
    _syncShortcutsToNative();

    // Notify Background Service to Refresh Templates
    try {
      if (Platform.isAndroid) {
        _channel.invokeMethod('refreshBackgroundGestures');
      }
    } catch (e) {
      debugPrint("⚠️ Failed to trigger background refresh: $e");
    }
  }

  /// Execute a gesture by Text Trigger
  static Future<bool> triggerByText(String input) async {
    // 1. OCR Normalization (The "Glue")
    String normalized = _normalizeForOCR(input.trim().toLowerCase());

    debugPrint(
      "⌨️ Text Trigger: '$input' -> Normalized: '$normalized' (Strictness: $_strictness)",
    );

    GestureTemplate? template = _textTriggerIndex[normalized];

    // 2. Fuzzy Match (If no exact match)
    // Always allow fuzzy if strictness is LOW (0) or NORMAL (1)
    if (template == null && _strictness <= 1) {
      int bestDistance = 99;
      String? bestKey;

      // Determine Allowed Errors based on Token Length & Strictness.
      // Short aliases need slightly more forgiveness in low/medium modes,
      // otherwise handwriting OCR frequently misses 3-letter shortcuts.

      for (final key in _textTriggerIndex.keys) {
        // Calculate Levenshtein Distance
        int distance = _levenshteinDistance(normalized, key);

        // Dynamic Tolerance Threshold
        int tolerance = 1; // Default
        if (_strictness == 0) {
          tolerance = key.length <= 4 ? 2 : 2;
        } else if (_strictness == 1) {
          tolerance = key.length <= 3 ? 2 : 1;
        }

        if (distance <= tolerance && distance < bestDistance) {
          bestDistance = distance;
          bestKey = key;
        }
      }

      if (bestKey != null) {
        template = _textTriggerIndex[bestKey];
        debugPrint(
          "🧩 Fuzzy Match Found: '$normalized' ~ '$bestKey' (Dist: $bestDistance)",
        );
      }
    }

    if (template != null) {
      final metadata = template.metadata!;
      final actionType = metadata['actionType'] as String;
      final actionValue = metadata['actionValue'] as String;

      debugPrint(
        "🚀 [OverlayService] Executing Text Trigger '${template.name}': $actionType -> $actionValue",
      );

      // Show detection feedback
      // 2. PROFESSIONAL SEQUENCE (Text Mode): Match Found
      try {
        await _channel.invokeMethod('hideGestureView');
      } catch (e) {
        debugPrint("⚠️ Failed to hide gesture view: $e");
      }
      await _updateNativeInput("✅ Found: ${template.name}");
      await Future.delayed(const Duration(milliseconds: 1500));

      // 3. PROFESSIONAL SEQUENCE: Executing (delegated to delayed executor)
      await _updateNativeInput("🚀 ${template.name} → $actionValue");
      await _executeWithDelay(
        actionType,
        actionValue,
        template.name,
        detectionMethod: 'text',
        detectedValue: input,
      );
      HapticFeedback.mediumImpact();
      return true;
    } else {
      debugPrint("⚠️ No gesture found for trigger text: '$normalized'");
      return false;
    }
  }

  /// Normalizes confusing OCR characters
  static String _normalizeForOCR(String text) {
    return text
        .replaceAll('0', 'o')
        .replaceAll('1', 'l')
        .replaceAll('5', 's')
        .replaceAll('@', 'a')
        .replaceAll('|', 'i')
        .replaceAll(
          RegExp(r'[^a-z0-9]'),
          '',
        ); // Remove all non-alphanumeric noise logic
  }

  /// Calculates Levenshtein Distance (Edit Distance)
  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }

      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[t.length];
  }

  static void _syncShortcutsToNative() async {
    // 1. Filter Database Favorites using FULL Cache
    var currentShortcuts = _cachedGestures.where((g) => g.isFavorite).toList();

    // 2. Take Max 4
    final labels = currentShortcuts.take(4).map((g) => g.name).toList();

    debugPrint("⚡ Syncing Shortcuts (DB): $labels");

    // 3. Update Native Overlay
    // 3. Update Quick Panel Data (Deep Sync) - FIRST (Perist Data)
    try {
      final List<QuickShortcut> panelShortcuts = currentShortcuts.take(4).map((
        g,
      ) {
        return QuickShortcut(
          id: g.id?.toString() ?? '',
          label: g.name,
          actionType: g.actionType,
          actionValue: g.actionValue,
        );
      }).toList();

      await QuickActionService.saveShortcuts(panelShortcuts);
    } catch (e) {
      debugPrint("⚠️ Deep Sync Failed: $e");
    }

    if (Platform.isAndroid) {
      _channel.invokeMethod('syncShortcuts', labels);
    }
  }

  /// Update the native input field (Visual Feedback)
  static Future<void> _updateNativeInput(String text) async {
    debugPrint("📝 [_updateNativeInput] Called with: '$text'");
    try {
      if (Platform.isAndroid) {
        debugPrint("📝 [_updateNativeInput] Sending to native...");
        await _channel.invokeMethod('updateInputText', text);
        debugPrint("📝 [_updateNativeInput] SUCCESS - Native received it");
      }
    } catch (e) {
      debugPrint("⚠️ Failed to update native input: $e");
    }
  }

  /// Handle messages from Native Android
  static Future<dynamic> _methodHandler(MethodCall call) async {
    try {
      switch (call.method) {
        case 'onGestureDrawn':
          final pointsData = call.arguments as List;
          debugPrint(
            "✍️ [OverlayService] Received Fragment with ${pointsData.length} points",
          );
          _bufferGestureFragment(pointsData);
          break;
        case 'onShortcutClicked':
          final index = call.arguments as int;
          debugPrint("⚡ [OverlayService] Shortcut clicked: $index");
          _handleShortcutClick(index);
          break;
        case 'onTextTrigger':
          final text = call.arguments as String;
          debugPrint("⌨️ [OverlayService] Text Trigger Received: $text");
          // Await to catch errors
          await triggerByText(text);
          break;
        case 'onNoteSaved':
          final text = call.arguments as String;
          debugPrint("📝 [OverlayService] Note Saved: $text");
          onNoteSavedCallback?.call(text);
          break;
        default:
          debugPrint("❓ [OverlayService] Unknown method: ${call.method}");
      }
    } catch (e) {
      debugPrint("🔥 [OverlayService] Method Handler Error: $e");
    }
  }

  // Callback for Note Saved
  static Function(String)? onNoteSavedCallback;

  // --- MULTI-STROKE BUFFERING ---
  static final List<dynamic> _pendingFragments = [];
  static Timer? _fragmentTimer;
  static int _recognitionDelayMs = 600; // Default 600ms
  static int _actionDelayMs = 0; // Default 0 (Immediate)

  static void setRecognitionDelay(int ms) {
    _recognitionDelayMs = ms.clamp(300, 2000);
    debugPrint(
      "⏳ [OverlayService] Recognition Delay set to: ${_recognitionDelayMs}ms",
    );
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('recognition_delay', _recognitionDelayMs);
    });
    // Reuse existing native bridge hook to refresh running background templates/config.
    if (Platform.isAndroid) {
      _channel.invokeMethod('refreshBackgroundGestures').catchError((e) {
        debugPrint('⚠️ Failed to refresh background gestures: $e');
      });
    }
  }

  static void setActionDelay(int ms) {
    _actionDelayMs = ms.clamp(0, 5000);
    debugPrint("⏳ [OverlayService] Action Delay set to: ${_actionDelayMs}ms");
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('action_delay', _actionDelayMs);
    });
    if (Platform.isAndroid) {
      _channel.invokeMethod('refreshBackgroundGestures').catchError((e) {
        debugPrint('⚠️ Failed to refresh background gestures: $e');
      });
    }
  }

  static void _bufferGestureFragment(List<dynamic> newPoints) {
    // 🛑 Cancel pending action if user draws again
    _cancelPendingAction();

    if (newPoints.isEmpty) return;

    // 1. Add gap if we already have data (Logic: Pen Lift between fragments)
    if (_pendingFragments.isNotEmpty) {
      // Add a separator to indicate stroke break
      _pendingFragments.add({'x': -1.0, 'y': -1.0}); // Native map format
    }

    // 2. Add new points
    _pendingFragments.addAll(newPoints);

    debugPrint(
      "⏳ [OverlayService] Buffering... Total points: ${_pendingFragments.length}",
    );

    // 3. Process immediately since native already waited 1.5s
    //    Use short timer only to debounce rapid consecutive calls
    _fragmentTimer?.cancel();
    _fragmentTimer = Timer(const Duration(milliseconds: 100), () {
      debugPrint("✅ [OverlayService] Processing gesture immediately...");
      final fullGesture = List.from(_pendingFragments);
      // Clear immediately so a fast second gesture doesn't inherit old strokes
      _pendingFragments.clear();
      _fragmentTimer = null;
      _processGesture(fullGesture);
    });
  }

  /// Handle Shortcut Click
  static Future<void> _handleShortcutClick(int index) async {
    if (index >= 0 && index < _templates.length) {
      final template = _templates[index];
      final metadata = template.metadata;

      if (metadata != null) {
        final actionType = metadata['actionType'] as String;
        final actionValue = metadata['actionValue'] as String;
        final name = template.name;

        debugPrint(
          "🚀 Shortcut Clicked '$name'. Delegating to delayed executor.",
        );

        await _executeWithDelay(actionType, actionValue, name);
        HapticFeedback.mediumImpact();
      }
    }
  }

  // --- ACTION DELAY LOGIC ---
  static Timer? _actionTimer;

  /// Cancel any pending delayed action
  static void _cancelPendingAction() {
    if (_actionTimer != null && _actionTimer!.isActive) {
      _actionTimer?.cancel();
      _actionTimer = null;
      _updateNativeInput("🛑 Action Cancelled");
      debugPrint(
        "🛑 [OverlayService] Pending action cancelled by user interaction.",
      );
    }
  }

  /// Execute action with configured delay
  static Future<void> _executeWithDelay(
    String actionType,
    String actionValue,
    String actionName, {
    String detectionMethod = 'draw',
    String? detectedValue,
  }) async {
    // 1. Cancel any existing
    _cancelPendingAction();

    // Build descriptive feedback showing detection method
    final methodIcon = detectionMethod == 'text' ? '⌨️' : '✋';
    final methodLabel = detectionMethod == 'text' ? 'Text' : 'Draw';
    final detectedInfo =
        detectedValue != null ? "'$detectedValue'" : actionName;
    final feedbackLine =
        "$methodIcon $methodLabel: $detectedInfo \u2192 $actionName";

    // 2. Immediate Execution (0-1s)
    if (_actionDelayMs < 1000) {
      await _updateNativeInput("✅ $feedbackLine");
      await showNote("✅ $feedbackLine", status: "success");
      if (_actionDelayMs > 0) {
        await Future.delayed(Duration(milliseconds: _actionDelayMs));
      }

      await ActionService.executeAction(actionType, actionValue);
      return;
    }

    // 3. Delayed Execution (>1s)
    int remainingSeconds = (_actionDelayMs / 1000).ceil();

    // For long delays (>3s), use showNote so popup stays visible
    if (_actionDelayMs > 3000) {
      await showNote(
        "⏳ $feedbackLine in ${remainingSeconds}s",
        status: "pending",
      );
    }
    // Initial Feedback via input field
    String feedback = "⏳ $feedbackLine in ${remainingSeconds}s";
    await _updateNativeInput(feedback);

    _actionTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      remainingSeconds--;

      if (remainingSeconds <= 0) {
        timer.cancel();
        _actionTimer = null;
        await _updateNativeInput("🚀 Executing: $actionName");
        await showNote("✅ $feedbackLine", status: "success");
        await ActionService.executeAction(actionType, actionValue);
      } else {
        // Update Count
        String status = "⏳ $feedbackLine in ${remainingSeconds}s";
        await _updateNativeInput(status);
      }
    });
  }

  // --- HYBRID HELPERS ---

  /// 2. TEXT PIPELINE: Convert strokes -> Bitmap -> OCR
  static Future<String?> recognizeText(List<List<Offset>> strokes) async {
    try {
      // A. Create Canvas
      final recorder = ui.PictureRecorder();
      final canvas =
          ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 768, 768));
      final paint = ui.Paint()
        ..color = const ui.Color(0xFF000000) // Black Ink
        ..strokeWidth = 14.0  // Thicker strokes → better ML Kit OCR accuracy
        ..style = ui.PaintingStyle.stroke
        ..strokeCap = ui.StrokeCap.round
        ..strokeJoin = ui.StrokeJoin.round;

      // Fill White BG
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, 768, 768),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );

      // B. Draw Strokes (Scale to fit 500x500)
      final allPoints = strokes.expand((s) => s).toList();
      if (allPoints.isEmpty) return null;

      final boundingBox = GestureRecognizer.boundingBox(allPoints);
      final scale = 600.0 / max(boundingBox.width, boundingBox.height);
      final dx = 84.0 - (boundingBox.left * scale); // Padding 84
      final dy = 84.0 - (boundingBox.top * scale);

      for (var stroke in strokes) {
        final path = ui.Path();
        if (stroke.isEmpty) continue;
        path.moveTo(stroke.first.dx * scale + dx, stroke.first.dy * scale + dy);
        for (var i = 1; i < stroke.length; i++) {
          path.lineTo(stroke[i].dx * scale + dx, stroke[i].dy * scale + dy);
        }
        canvas.drawPath(path, paint);
      }

      // C. Save to Image
      final picture = recorder.endRecording();
      final img = await picture.toImage(768, 768);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      // D. Save to Temp File
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/gesture_ocr.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      // E. Run OCR
      final inputImage = InputImage.fromFilePath(file.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      String result = recognizedText.text.trim().replaceAll('\n', ' ');
      debugPrint("📖 [OCR] Raw: '${recognizedText.text}' -> Clean: '$result'");

      return result.isNotEmpty ? result : null;
    } catch (e) {
      debugPrint("❌ [OCR] Error: $e");
      return null;
    }
  }

  /// Process the drawn points
  static Future<void> _processGesture(List<dynamic> rawPoints) async {
    debugPrint("🎨 [OverlayService] Processing Hybrid Gesture...");

    // 1. PROFESSIONAL SEQUENCE START: Scanning - respect configured recognition delay
    await _updateNativeInput("Scanning...");
    await Future.delayed(Duration(milliseconds: _recognitionDelayMs));

    if (_templates.isEmpty && _textTriggerIndex.isEmpty) {
      debugPrint("❌ [OverlayService] CRITICAL: No templates or text triggers!");
      await _updateNativeInput("⚠️ System: No Gestures Loaded");
      // await showNote("⚠️ System: No Gestures Loaded", status: "error"); // Removed per user request
      await Future.delayed(const Duration(seconds: 3));
      await collapseOverlay();
      return;
    }

    try {
      // 1. PARSE STROKES (Split by explicit {x:-1,y:-1} sentinel OR distance jumps)
      List<List<Offset>> strokes = [];
      List<Offset> currentStroke = [];
      List<Offset> flatPoints = [];

      Offset? lastP;
      for (var p in rawPoints) {
        final map = Map<String, dynamic>.from(p as Map);
        final rawX = (map['x'] as num).toDouble();
        final rawY = (map['y'] as num).toDouble();

        // --- BUG FIX: Detect explicit stroke separator sentinel {x:-1, y:-1} ---
        // _bufferGestureFragment() inserts this map between strokes.
        // Without this check the sentinel is treated as a real point at (-1,-1)
        // which corrupts the bounding-box and produces garbage OCR/shape results.
        if (rawX == -1.0 && rawY == -1.0) {
          if (currentStroke.isNotEmpty) {
            strokes.add(List.from(currentStroke));
            currentStroke = [];
          }
          flatPoints.add(const Offset(-1, -1));
          lastP = null; // Reset gap detector across explicit separators
          continue;
        }

        final currentP = Offset(rawX, rawY);

        // Also split on large distance jumps (native sometimes skips separator)
        bool isGap = false;
        if (lastP != null && (currentP - lastP).distance > 100.0) {
          isGap = true;
        }

        if (isGap) {
          if (currentStroke.isNotEmpty) strokes.add(List.from(currentStroke));
          currentStroke = [];

          // Also add separator to flatPoints for $1 recognizer
          flatPoints.add(const Offset(-1, -1));
        }

        currentStroke.add(currentP);
        flatPoints.add(currentP);
        lastP = currentP;
      }
      if (currentStroke.isNotEmpty) strokes.add(currentStroke);

      // 2. ALWAYS TRY OCR FIRST (Show feedback regardless of result)
      debugPrint(
        "🔍 [OCR] Starting OCR... strokes=${strokes.length}, points=${strokes.expand((s) => s).length}",
      );

      String? ocrResult = await recognizeText(strokes);
      debugPrint("🔍 [OCR] Raw Result: '$ocrResult'");
      ocrResult = ocrResult?.trim();

      // 👁️ ALWAYS SHOW VISUAL FEEDBACK (Even if no trigger match)
      if (ocrResult != null && ocrResult.isNotEmpty) {
        debugPrint("📖 [OCR] Detected: '$ocrResult'");

        // #5: Immediately write detected text to the native text box
        await _updateNativeInput(ocrResult);

        // Small grace pause to flush UI, then attempt trigger. Action delay
        // (if configured) will be applied by triggerByText/_executeWithDelay.
        await Future.delayed(const Duration(milliseconds: 500));

        // Now try to match against text triggers
        if (await triggerByText(ocrResult)) {
          // Success - Action Executed, close overlay
          debugPrint("✅ [OCR] Trigger matched and executed!");
          await collapseOverlay(); // Close expanded view
          return; // Done - don't fallback to shape
        } else {
          debugPrint(
            "⚠️ [OCR] Text '$ocrResult' has no trigger. Trying shape...",
          );
          await _updateNativeInput(
            "✍️ '$ocrResult' — no trigger. Trying shape...",
          );
          // Continue to shape recognition as fallback
        }
      } else {
        debugPrint("⚠️ [OCR] No text detected. Trying shape recognition...");
      }

      // 3. FALLBACK: SHAPE RECOGNITION
      debugPrint("📐 [Shape] Running Geometric Recognizer...");

      // Filter templates based on Strictness
      double minScore = 0.65; // Default Medium
      if (_strictness == 0) minScore = 0.55; // Loose
      if (_strictness == 2) minScore = 0.80; // Strict

      List<RecognitionResult> results = [];
      if (_templates.isNotEmpty) {
        results = GestureRecognizer.recognize(flatPoints, _templates);
      }

      if (results.isNotEmpty) {
        // Find the best result that has a valid action (skip system templates without actions)
        RecognitionResult? best;
        for (final result in results) {
          if (result.score < minScore) {
            break; // No more candidates above threshold
          }
          final meta = result.template?.metadata;
          if (meta == null) continue;
          // Skip system templates that have no actionType (default A-Z letters)
          final isSystem = meta['isSystem'] == true;
          final hasAction = meta['actionType'] != null &&
              meta['actionType'].toString().isNotEmpty;
          if (isSystem && !hasAction) {
            debugPrint(
              "⏭️ [Shape] Skipping system template '${result.name}' (${(result.score * 100).toInt()}%) — no action",
            );
            continue;
          }
          best = result;
          break;
        }

        if (best != null && best.score >= minScore) {
          final meta = best.template?.metadata;
          final actionType = meta?['actionType']?.toString();
          final actionValue = meta?['actionValue']?.toString();
          debugPrint(
            "📐 [Shape] Best: ${best.name} (${(best.score * 100).toInt()}%) actionType=$actionType actionValue=$actionValue",
          );

          if (actionType != null &&
              actionType.isNotEmpty &&
              actionValue != null) {
            // 2. PROFESSIONAL SEQUENCE: Match Found
            debugPrint("✅ [Shape] Found: ${best.name}");
            try {
              await _channel.invokeMethod('hideGestureView');
            } catch (e) {
              debugPrint("⚠️ Failed to hide gesture view: $e");
            }
            await _updateNativeInput("✅ Found: ${best.name}");
            await Future.delayed(
              const Duration(milliseconds: 1500),
            ); // Pause to let user read

            // 3. PROFESSIONAL SEQUENCE: Executing
            debugPrint("🚀 [Shape] Executing: ${best.name}");
            await _updateNativeInput("🚀 ${best.name} → $actionValue");

            await ActionService.executeAction(actionType, actionValue);

            // Clean up
            await Future.delayed(const Duration(seconds: 1));
            HapticFeedback.mediumImpact();
            await collapseOverlay();
          } else {
            debugPrint(
              "⚠️ [Shape] Matched '${best.name}' but actionType/actionValue is null!",
            );
            await _updateNativeInput("⚠️ '${best.name}' has no action");
            // DO NOT close or show popup, let user try again
          }
        } else {
          // No valid match above threshold
          final closest = results.isNotEmpty ? results.first : null;
          final msg = closest != null
              ? "No match (${(closest.score * 100).toInt()}% closest)"
              : "No match found";
          debugPrint("⚠️ [Shape] $msg");
          await _updateNativeInput("⚠️ $msg");
          // DO NOT close or show popup, let user try again
        }
      } else {
        // No recognition results at all
        await _updateNativeInput("⚠️ No match found");
        // DO NOT close or show popup, let user try again
      }
    } catch (e) {
      debugPrint("🔥 [Hybrid] Error: $e");
    }
  }

  /// Check if we have overlay permissions
  static Future<bool> checkPermission() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  /// Request overlay permissions
  static Future<void> requestPermission() async {
    if (!(await checkPermission())) {
      await Permission.systemAlertWindow.request();
    }
  }

  /// Check Usage Stats Permission (Native)
  static Future<bool> checkUsageStats() async {
    try {
      if (Platform.isAndroid) {
        final bool granted = await _channel.invokeMethod('checkUsageStats');
        return granted;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Failed to check usage stats: $e");
      return false;
    }
  }

  /// Show the floating bubble (Native Kotlin Service)
  static Future<void> showBubble() async {
    try {
      debugPrint("🔵 [OverlayService] showBubble() called");

      if (Platform.isAndroid) {
        if (!(await checkPermission())) {
          await requestPermission();
          if (!(await checkPermission())) return;
        }

        // Ensure listener is ready
        initialize();

        await _channel.invokeMethod('startOverlay');
      } else {
        debugPrint(
          "🍎 [OverlayService] iOS: Floating Bubble is not supported. Use Widget.",
        );
        // Optional: Show iOS specific dialog or tutorial here
      }
    } catch (e) {
      debugPrint("❌ [OverlayService] Start Error: $e");
    }
  }

  static Future<void> showNote(String text, {String status = ""}) async {
    try {
      debugPrint("🔵 [OverlayService] Showing Note: $text (Status: $status)");
      // Check permission first
      if (!(await checkPermission())) {
        await requestPermission();
        if (!(await checkPermission())) return;
      }
      // Check Phone State Permission for Auto-Save
      if (!(await Permission.phone.isGranted)) {
        await Permission.phone.request();
      }

      if (Platform.isAndroid) {
        await _channel.invokeMethod('showNote', {
          'text': text,
          'status': status,
        });
      }
    } catch (e) {
      debugPrint("❌ [OverlayService] Show Note Error: $e");
    }
  }

  /// Collapse the expanded overlay back to bubble (used after successful gesture trigger)
  static Future<void> collapseOverlay() async {
    try {
      if (Platform.isAndroid) {
        debugPrint("🔵 [OverlayService] Collapsing overlay back to bubble...");
        await _channel.invokeMethod('collapseOverlay');
      }
    } catch (e) {
      debugPrint("⚠️ [OverlayService] Collapse Error: $e");
    }
  }

  /// Close the overlay
  static Future<void> closeOverlay() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('stopOverlay');
      }
    } catch (e) {
      debugPrint("❌ [OverlayService] Stop Error: $e");
    }
  }

  // Legacy compatibility
  static Future<void> syncGesturesToOverlaySync(
    List<dynamic> gesturesJson,
  ) async {
    // This was for the old java service, now we just keep the local list updated
    // No-op or we could parse json here if needed, but updateGestures is better
  }
}
