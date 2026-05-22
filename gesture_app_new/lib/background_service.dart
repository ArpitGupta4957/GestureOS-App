/// Background Service for Gesture Recognition
/// This runs as a headless Flutter engine when the main app is killed.
///
/// Entry point annotation is REQUIRED for background execution.
library;

import 'dart:ui' as ui;
import 'dart:ui'; // For DartPluginRegistrant
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:gesture_app/core/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gesture_app/core/utils/gesture_recognizer.dart';
import 'package:gesture_app/core/services/action_service.dart';
import 'package:gesture_app/core/data/default_gestures.dart';
import 'dart:async';

// Global state for background service
List<GestureTemplate> _templates = [];
Map<String, GestureTemplate> _textTriggerIndex = {};
bool _isInitialized = false;

// --- HYBRID RECOGNITION STATE ---
final TextRecognizer _textRecognizer = TextRecognizer(
  script: TextRecognitionScript.latin,
);

// Configurable recognition delay (ms) - will be read from SharedPreferences
int _recognitionDelayMs = 600;
// Configurable action delay (ms) for background execution
int _actionDelayMs = 0;

/// Entry point for background Flutter engine
@pragma('vm:entry-point')
void entrypointMain() {
  // Ensure Flutter binding is initialized for headless mode
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Dart IO manually (sometimes needed for older versions, harmless here)
  DartPluginRegistrant.ensureInitialized();

  print(
    '🔵 [BackgroundService] 🚀 STARTING HEADLESS ENGINE (ENTRYPOINT MAIN) 🚀',
  );

  try {
    // Set up MethodChannel for communication with native
    const channel = MethodChannel('overlay_channel');
    channel.setMethodCallHandler(_handleMethodCall);

    // 🔥 Send Ready Signal to Native
    channel.invokeMethod("backgroundReady");
    print('🔵 [BackgroundService] Channel registered & Ready Signal Sent');

    // Initialize database and load templates
    // Use Future.delayed to allow native side to stabilize
    Future.delayed(const Duration(milliseconds: 500), () {
      _initializeTemplates().then((_) {
        print(
          '🔵 [BackgroundService] Initialization complete in background',
        );
      }).catchError((e) {
        print(
          '❌ [BackgroundService] Initialization FAILED in background: $e',
        );
      });
    });
  } catch (e, s) {
    print('❌ [BackgroundService] FATAL CRASH: $e\n$s');
  }
}

/// Initialize templates from local database
Future<void> _initializeTemplates() async {
  if (_isInitialized) return;

  try {
    // Load recognition delay from shared prefs (keeps parity with main app)
    try {
      final prefs = await SharedPreferences.getInstance();
      _recognitionDelayMs =
          prefs.getInt('recognition_delay') ?? _recognitionDelayMs;
      _actionDelayMs = prefs.getInt('action_delay') ?? _actionDelayMs;
      print(
          '📦 [BackgroundService] recognitionDelay=${_recognitionDelayMs}ms actionDelay=${_actionDelayMs}ms');
    } catch (e) {
      print('⚠️ [BackgroundService] Failed to read prefs: $e');
    }
    print('📦 [BackgroundService] Loading gestures from SQLite...');
    final db = DatabaseHelper();
    // Test DB Access
    print('📦 [BackgroundService] Opening Database...');
    final gestures = await db.getAllGestures();
    print(
      '📦 [BackgroundService] DB Opened! Found ${gestures.length} gestures',
    );

    _templates = [];
    _textTriggerIndex = {};

    for (final gesture in gestures) {
      // Index text triggers
      if (gesture.triggerText != null && gesture.triggerText!.isNotEmpty) {
        // Normalize stored trigger keys the same as OCR normalization
        final normalized =
            _normalizeForOCR(gesture.triggerText!.trim().toLowerCase());
        _textTriggerIndex[normalized] = GestureTemplate(
          name: gesture.name,
          points: [],
          metadata: {
            'actionType': gesture.actionType,
            'actionValue': gesture.actionValue,
            'id': gesture.id,
            'triggerText': normalized,
          },
        );
      }

      // Index draw gestures
      if (gesture.points.length >= 5) {
        try {
          final normalized = GestureRecognizer.normalize(
            gesture.points.map((p) => Offset(p.dx, p.dy)).toList(),
          );
          _templates.add(
            GestureTemplate(
              name: gesture.name,
              points: normalized,
              metadata: {
                'actionType': gesture.actionType,
                'actionValue': gesture.actionValue,
                'id': gesture.id,
              },
            ),
          );
        } catch (e) {
          print(
            '❌ [BackgroundService] Failed to normalize ${gesture.name}: $e',
          );
        }
      }
    }

    _templates.addAll(DefaultGestures.all);
    _isInitialized = true;
    print(
      '✅ [BackgroundService] Loaded ${_templates.length} draw templates, ${_textTriggerIndex.length} text triggers',
    );
  } catch (e, s) {
    print('❌ [BackgroundService] Failed to load gestures: $e\n$s');
  }
}

/// Handle method calls from native
Future<dynamic> _handleMethodCall(MethodCall call) async {
  print('📞 [BackgroundService] Received MethodCall: ${call.method}');
  try {
    switch (call.method) {
      case 'onGestureDrawn':
        final pointsData = call.arguments as List;
        print(
          '✍️ [BackgroundService] Received Fragment (${pointsData.length} pts)',
        );
        _bufferGestureFragment(pointsData);
        break;

      case 'onTextTrigger':
        final text = call.arguments as String;
        print('⌨️ [BackgroundService] Text trigger: $text');
        await _handleTextTrigger(text);
        break;

      case 'refreshTemplates':
        print('🔄 [BackgroundService] Refreshing templates...');
        _isInitialized = false;
        await _initializeTemplates();
        break;

      default:
        print('❓ [BackgroundService] Unknown method: ${call.method}');
    }
  } catch (e, s) {
    print('❌ [BackgroundService] Error in _handleMethodCall: $e\n$s');
  }
}

// --- HYBRID HELPERS ---

/// 2. TEXT PIPELINE
Future<String?> _recognizeText(List<List<Offset>> strokes) async {
  try {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, const ui.Rect.fromLTWH(0, 0, 768, 768));
    final paint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = 14.0  // Thicker strokes → better ML Kit OCR accuracy
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round;

    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 768, 768),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    final allPoints = strokes.expand((s) => s).toList();
    if (allPoints.isEmpty) return null;

    final boundingBox = GestureRecognizer.boundingBox(allPoints);
    final scale = 600.0 / max(boundingBox.width, boundingBox.height);
    final dx = 84.0 - (boundingBox.left * scale);
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

    final picture = recorder.endRecording();
    final img = await picture.toImage(768, 768);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/bg_gesture_ocr.png');
    await file.writeAsBytes(byteData.buffer.asUint8List());

    final inputImage = InputImage.fromFilePath(file.path);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    String result = recognizedText.text.trim().replaceAll('\n', ' ');
    print("📖 [BG OCR] Result: '$result'");

    return result.isNotEmpty ? result : null;
  } catch (e) {
    print("❌ [BG OCR] Error: $e");
    return null;
  }
}

enum GestureIntent { text, shape }

// --- MULTI-STROKE BUFFERING ---
List<dynamic> _pendingFragments = [];
Timer? _fragmentTimer;

void _bufferGestureFragment(List<dynamic> newPoints) {
  if (newPoints.isEmpty) return;

  if (_pendingFragments.isNotEmpty) {
    _pendingFragments.add({'x': -1.0, 'y': -1.0});
  }
  _pendingFragments.addAll(newPoints);

  print(
    "⏳ [BackgroundService] Buffering... Total: ${_pendingFragments.length}",
  );

  _fragmentTimer?.cancel();
  // Use the same recognition delay configured by the user (loaded from prefs)
  final debounceMs = _recognitionDelayMs.clamp(100, 2000);
  _fragmentTimer = Timer(Duration(milliseconds: debounceMs), () {
    print("✅ [BackgroundService] Trace finished. Processing...");
    final fullGesture = List.from(_pendingFragments);
    _pendingFragments.clear();
    _fragmentTimer = null;
    _processGesture(fullGesture);
  });
}

/// Process drawn gesture and recognize
Future<void> _processGesture(List<dynamic> rawPoints) async {
  // 1. PROFESSIONAL SEQUENCE START: Scanning
  const channel = MethodChannel('overlay_channel');
  try {
    await channel.invokeMethod('updateInputText', 'Scanning...');
  } catch (e) {
    print("⚠️ [BG] Failed to update input: $e");
  }
  await Future.delayed(Duration(milliseconds: _recognitionDelayMs));

  if (!_isInitialized) await _initializeTemplates();

  if (_templates.isEmpty && _textTriggerIndex.isEmpty) {
    print('❌ [BackgroundService] No templates or text triggers available');
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
      // which corrupts the bounding-box, producing garbage OCR / shape results.
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
      if (lastP != null && (currentP - lastP).distance > 100.0) isGap = true;

      if (isGap) {
        if (currentStroke.isNotEmpty) strokes.add(List.from(currentStroke));
        currentStroke = [];
        flatPoints.add(const Offset(-1, -1));
      }

      currentStroke.add(currentP);
      flatPoints.add(currentP);
      lastP = currentP;
    }
    if (currentStroke.isNotEmpty) strokes.add(currentStroke);

    // 2. ALWAYS TRY OCR FIRST (Fix: Don't rely on classification)
    print("🔍 [BG OCR] Starting OCR... strokes=${strokes.length}");
    String? ocrResult = await _recognizeText(strokes);
    print("🔍 [BG OCR] Result: '$ocrResult'");

    bool handled = false;

    // 👁️ ALWAYS SHOW VISUAL FEEDBACK if OCR detected something
    if (ocrResult != null && ocrResult.isNotEmpty) {
      // Update native input field to show detected text
      const channel = MethodChannel('overlay_channel');
      try {
        await channel.invokeMethod('updateInputText', 'Detected: $ocrResult');
      } catch (e) {
        print("⚠️ [BG] Failed to update native input: $e");
      }

      // Try fuzzy match with triggers
      final normalized = _normalizeForOCR(ocrResult.trim().toLowerCase());
      GestureTemplate? template = _textTriggerIndex[normalized];

      // Fuzzy match if no exact match
      if (template == null) {
        int bestDistance = 99;
        String? bestKey;
        for (final key in _textTriggerIndex.keys) {
          int distance = _levenshteinDistance(normalized, key);
          int tolerance = key.length > 4 ? 2 : (key.length >= 3 ? 2 : 0);
          if (distance <= tolerance && distance < bestDistance) {
            bestDistance = distance;
            bestKey = key;
          }
        }
        if (bestKey != null) {
          template = _textTriggerIndex[bestKey];
          print("🧩 [BG OCR] Fuzzy: '$normalized' ~ '$bestKey'");
        }
      }

      if (template != null) {
        print("✅ [BG OCR] Trigger matched! Executing...");
        final meta = template.metadata!;
        // Respect configured background action delay
        if (_actionDelayMs > 0) {
          print('⏳ [BG OCR] Waiting ${_actionDelayMs}ms before executing');
          await Future.delayed(Duration(milliseconds: _actionDelayMs));
        }
        await ActionService.executeAction(
          meta['actionType'] as String,
          meta['actionValue'] as String,
        );
        handled = true;
      } else {
        print("⚠️ [BG OCR] Text '$ocrResult' has no trigger. Trying shape...");
      }
    } else {
      print("⚠️ [BG OCR] No text detected. Trying shape recognition...");
    }

    // 3. FALLBACK: SHAPE RECOGNITION
    if (!handled) {
      print("📐 [BG Shape] Running Geometric...");
      List<RecognitionResult> results = [];
      if (_templates.isNotEmpty) {
        results = GestureRecognizer.recognize(flatPoints, _templates);
      }

      if (results.isNotEmpty) {
        // Find the best result that has a valid action (skip system templates without actions)
        RecognitionResult? best;
        for (final result in results) {
          if (result.score < 0.75) break; // No more candidates above threshold
          final meta = result.template?.metadata;
          if (meta == null) continue;
          // Skip system templates that have no actionType (default A-Z letters)
          final isSystem = meta['isSystem'] == true;
          final hasAction = meta['actionType'] != null &&
              meta['actionType'].toString().isNotEmpty;
          if (isSystem && !hasAction) {
            print(
              "⏭️ [BG Shape] Skipping system template '${result.name}' (${(result.score * 100).toStringAsFixed(1)}%) — no action",
            );
            continue;
          }
          best = result;
          break;
        }

        if (best != null) {
          final meta = best.template?.metadata;
          final actionType = meta?['actionType']?.toString();
          final actionValue = meta?['actionValue']?.toString();
          print(
            '🧠 [BG Shape] Best: ${best.name} (${(best.score * 100).toStringAsFixed(1)}%) actionType=$actionType actionValue=$actionValue',
          );

          if (actionType != null &&
              actionType.isNotEmpty &&
              actionValue != null) {
            // 2. PROFESSIONAL SEQUENCE: Match Found
            print('✅ [BG Shape] Found: ${best.name}');
            const channel = MethodChannel('overlay_channel');
            try {
              await channel.invokeMethod(
                'hideGestureView',
              ); // Hide Draw Pad Instantly
              await channel.invokeMethod(
                'updateInputText',
                "✅ Found: ${best.name}",
              );
            } catch (e) {
              /* ignore */
            }
            await Future.delayed(
              const Duration(milliseconds: 1500),
            ); // Pause to let user read

            // 3. PROFESSIONAL SEQUENCE: Executing
            print('🚀 [BG Shape] Executing: ${best.name}');
            try {
              await channel.invokeMethod(
                'updateInputText',
                "🚀 Executing: $actionValue",
              );
            } catch (e) {
              /* ignore */
            }

            if (_actionDelayMs > 0) {
              print(
                  '⏳ [BG Shape] Waiting ${_actionDelayMs}ms before executing');
              await Future.delayed(Duration(milliseconds: _actionDelayMs));
            }
            await ActionService.executeAction(actionType, actionValue);
          } else {
            print(
              '⚠️ [BG Shape] Matched ${best.name} but actionType/actionValue is null!',
            );
            try {
              const channel = MethodChannel('overlay_channel');
              await channel.invokeMethod(
                'updateInputText',
                "⚠️ Error: No Action",
              );
            } catch (e) {
              /* ignore */
            }
          }
        } else {
          // Best match but low score
          try {
            const channel = MethodChannel('overlay_channel');
            await channel.invokeMethod('updateInputText', "⚠️ No match found");
          } catch (e) {
            /* ignore */
          }
        }
      } else {
        // No results at all
        try {
          const channel = MethodChannel('overlay_channel');
          await channel.invokeMethod('updateInputText', "⚠️ No match found");
        } catch (e) {
          /* ignore */
        }
      }
    }
  } catch (e) {
    print('🔥 [BackgroundService] Error: $e');
  }
}

/// Handle text trigger
Future<void> _handleTextTrigger(String text) async {
  if (!_isInitialized) {
    await _initializeTemplates();
  }

  // 1. OCR Normalization
  final normalized = _normalizeForOCR(text.trim().toLowerCase());
  print('⌨️ [BackgroundService] Trigger: "$text" -> Normalized: "$normalized"');

  GestureTemplate? template = _textTriggerIndex[normalized];

  // 2. Fuzzy Match (Always active in background for robustness)
  if (template == null) {
    int bestDistance = 99;
    String? bestKey;

    for (final key in _textTriggerIndex.keys) {
      int distance = _levenshteinDistance(normalized, key);

      // Dynamic Tolerance
      int tolerance = key.length <= 3 ? 2 : 1;
      if (key.length > 4) tolerance = 2; // Allow 2 typos for long words

      if (distance <= tolerance && distance < bestDistance) {
        bestDistance = distance;
        bestKey = key;
      }
    }

    if (bestKey != null) {
      template = _textTriggerIndex[bestKey];
      print(
        "🧩 [BackgroundService] Fuzzy Match: '$normalized' ~ '$bestKey' (Dist: $bestDistance)",
      );
    }
  }

  if (template != null) {
    final metadata = template.metadata!;
    final actionType = metadata['actionType'] as String;
    final actionValue = metadata['actionValue'] as String;

    // 2. PROFESSIONAL SEQUENCE (Text Mode): Match Found
    const channel = MethodChannel('overlay_channel');
    try {
      await channel.invokeMethod('hideGestureView'); // Hide Draw Pad Instantly
      await channel.invokeMethod(
        'updateInputText',
        "✅ Found: ${template.name}",
      );
    } catch (e) {
      /* ignore */
    }
    await Future.delayed(const Duration(milliseconds: 1500));

    // 3. PROFESSIONAL SEQUENCE: Executing
    try {
      await channel.invokeMethod(
        'updateInputText',
        "🚀 Executing: $actionValue",
      );
    } catch (e) {
      /* ignore */
    }

    await ActionService.executeAction(actionType, actionValue);

    // Clean up wait
    await Future.delayed(const Duration(seconds: 1));
  } else {
    print('⚠️ [BackgroundService] No gesture found for: $normalized');
  }
}

// --- FUZZY HELPERS (Duplicate from OverlayService) ---

String _normalizeForOCR(String text) {
  return text
      .replaceAll('0', 'o')
      .replaceAll('1', 'l')
      .replaceAll('5', 's')
      .replaceAll('@', 'a')
      .replaceAll('|', 'i')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');
}

int _levenshteinDistance(String s, String t) {
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
