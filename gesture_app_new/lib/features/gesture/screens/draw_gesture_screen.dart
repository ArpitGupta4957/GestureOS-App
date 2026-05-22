import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/gesture_provider.dart';
import 'package:gesture_app/core/models/gesture_model.dart';
import 'package:gesture_app/features/gesture/screens/action_picker_screen.dart';
import 'package:gesture_app/core/utils/gesture_recognizer.dart';
import 'package:gesture_app/core/services/overlay_service.dart';
import 'package:gesture_app/core/services/action_service.dart';

class DrawGestureScreen extends ConsumerStatefulWidget {
  final GestureModel? gestureToEdit;
  final List<Offset>? preFilledPoints;
  final String? preSelectedActionType;
  final String? preSelectedActionValue;
  final String? preSelectedActionName;
  final String? preSelectedContactId;
  final String? preSelectedLocalPhotoPath;

  const DrawGestureScreen({
    super.key,
    this.gestureToEdit,
    this.preFilledPoints,
    this.preSelectedActionType,
    this.preSelectedActionValue,
    this.preSelectedActionName,
    this.preSelectedContactId,
    this.preSelectedLocalPhotoPath,
  });

  @override
  ConsumerState<DrawGestureScreen> createState() => _DrawGestureScreenState();
}

class _DrawGestureScreenState extends ConsumerState<DrawGestureScreen> {
  final List<Offset> _points = [];
  bool _isDrawing = false;
  // ignore: unused_field
  bool _isRecognizing = false;
  String? _selectedActionType;
  String? _selectedActionValue;
  String? _gestureName;
  String? _selectedContactId;
  String? _selectedLocalPhotoPath;
  late TextEditingController _triggerTextController;
  bool _isFavorite = false;

  // --- Action-delay countdown state ---
  Timer? _autoRunTimer;
  int _countdownSeconds = 0;
  bool _textEditedDuringCountdown = false;

  @override
  void initState() {
    super.initState();
    _triggerTextController = TextEditingController();

    if (widget.gestureToEdit != null) {
      _points.addAll(widget.gestureToEdit!.points);
      _selectedActionType = widget.gestureToEdit!.actionType;
      _selectedActionValue = widget.gestureToEdit!.actionValue;
      _gestureName = widget.gestureToEdit!.name;
      _selectedContactId = widget.gestureToEdit!.contactId;
      _selectedLocalPhotoPath = widget.gestureToEdit!.localPhotoPath;
      _triggerTextController.text = widget.gestureToEdit!.triggerText ?? '';
      _isFavorite = widget.gestureToEdit!.isFavorite;
    } else if (widget.preSelectedActionType != null) {
      _selectedActionType = widget.preSelectedActionType;
      _selectedActionValue = widget.preSelectedActionValue;
      _gestureName = widget.preSelectedActionName;
      _selectedContactId = widget.preSelectedContactId;
      _selectedLocalPhotoPath = widget.preSelectedLocalPhotoPath;
    } else if (widget.preFilledPoints != null &&
        widget.preFilledPoints!.isNotEmpty) {
      // Initialize canvas with prefilled strokes from a mini-draw pad
      _points.addAll(widget.preFilledPoints!);
      _isDrawing = true;
      // Trigger recognition and OCR on the prefilled strokes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkGestureMatch();
        _runOCR();
      });
    }
  }

  @override
  void dispose() {
    _autoRunTimer?.cancel();
    _triggerTextController.dispose();
    super.dispose();
  }

  // --- Countdown helpers ---

  void _startAutoRunCountdown(String detectedText, int delayMs) {
    _autoRunTimer?.cancel();
    _textEditedDuringCountdown = false;
    setState(() => _countdownSeconds = (delayMs / 1000).ceil());

    _autoRunTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_textEditedDuringCountdown || !mounted) {
        timer.cancel();
        if (mounted) setState(() => _countdownSeconds = 0);
        return;
      }
      setState(() => _countdownSeconds--);
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _autoRunTimer = null;
        final textToRun = _triggerTextController.text.trim();
        if (textToRun.isNotEmpty && mounted) {
          final executed = await OverlayService.triggerByText(textToRun);
          if (mounted) {
            if (executed) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("✅ Executed: '$textToRun'"),
                  backgroundColor: Colors.green,
                ),
              );
              Future.delayed(const Duration(milliseconds: 600), () {
                if (mounted) context.pop();
              });
            }
          }
        }
      }
    });
  }

  void _cancelAutoRun() {
    _autoRunTimer?.cancel();
    _autoRunTimer = null;
    if (mounted) setState(() => _countdownSeconds = 0);
  }

  void _handleClear() {
    setState(() {
      _points.clear();
      _isDrawing = false;
      _isRecognizing = false;
      _triggerTextController.clear();
    });
  }

  /// Undo the last drawn stroke (back to previous separator)
  void _handleUndo() {
    if (_points.isEmpty) return;
    setState(() {
      // Remove trailing separator if present
      while (_points.isNotEmpty && _points.last == const Offset(-1.0, -1.0)) {
        _points.removeLast();
      }
      // Remove points until previous separator or empty
      while (_points.isNotEmpty && _points.last != const Offset(-1.0, -1.0)) {
        _points.removeLast();
      }
      if (_points.isEmpty) _isDrawing = false;
    });
    // Re-run OCR with remaining strokes
    if (_points.isNotEmpty) _runOCR();
  }

  Future<void> _checkGestureMatch() async {
    if (_points.isEmpty) return;

    // Get saved gestures
    final savedGestures = ref.read(gestureProvider).gestures;
    if (savedGestures.isEmpty) return;

    // Convert models to templates
    final templates = savedGestures
        .map(
          (g) => GestureTemplate(
            name: g.name,
            points: g.points,
            metadata: {
              'actionType': g.actionType,
              'actionValue': g.actionValue,
            },
          ),
        )
        .toList();

    // Recognize
    final results = GestureRecognizer.recognize(List.from(_points), templates);

    if (results.isNotEmpty) {
      final result = results.first; // Best match

      if (result.score > 0.85) {
        final actionType = result.template?.metadata?['actionType'];
        final actionValue = result.template?.metadata?['actionValue'];

        if (actionType != null && actionValue != null) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✨ Matched "${result.name}" (${(result.score * 100).toInt()}%) - Executing...',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );

          // Execute Action: run the assigned action for this gesture
          try {
            await ActionService.executeAction(
                actionType as String, actionValue as String);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🚀 Executed: ${result.name}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(milliseconds: 900),
                ),
              );
            }
          } catch (e) {
            debugPrint('Execute action failed: $e');
          }
        }
      }
    }
  }

  Future<void> _handleSave() async {
    final isEditing = widget.gestureToEdit != null;
    final triggerText = _triggerTextController.text.trim();
    final normalizedTriggerText = triggerText.toLowerCase();

    // Validate: Must have either points OR text trigger
    if (_points.isEmpty && triggerText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw a gesture OR enter a text trigger!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 🔴 1. CHECK FOR DUPLICATE GESTURE SHAPE
    if (_points.isNotEmpty) {
      final savedGestures = ref.read(gestureProvider).gestures;
      debugPrint(
        "🔍 Validating Shape. Loaded ${savedGestures.length} gestures.",
      );

      // Filter out the one we are editing
      final candidates =
          savedGestures.where((g) => g.id != widget.gestureToEdit?.id).toList();

      if (candidates.isNotEmpty) {
        final templates = candidates
            .map(
              (g) =>
                  GestureTemplate(name: g.name, points: g.points, metadata: {}),
            )
            .toList();

        final results = GestureRecognizer.recognize(
          List.from(_points),
          templates,
        );

        if (results.isNotEmpty) {
          final bestMatch = results.first;
          final scorePct = (bestMatch.score * 100).toInt();
          debugPrint(
            "🔍 Best Match: ${bestMatch.name} - Score: ${bestMatch.score}",
          );

          // VISIBLE DEBUGGING FOR USER
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Analysis: Closest match is '${bestMatch.name}' ($scorePct%)",
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          if (bestMatch.score > 0.75) {
            // Lowered to 75%
            if (!mounted) return;

            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Gesture Conflict ⚠️"),
                content: Text(
                  "This drawing is too similar to '${bestMatch.name}' ($scorePct% match).\n\nPlease draw something distinct.",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("OK, I'll redraw"),
                  ),
                ],
              ),
            );
            return; // STOP SAVE
          }
        } else {
          debugPrint("✅ No similarity found.");
        }
      }
    }

    // 🔴 2. CHECK FOR DUPLICATE TEXT TRIGGER
    if (triggerText.isNotEmpty) {
      final savedGestures = ref.read(gestureProvider).gestures;
      final candidates =
          savedGestures.where((g) => g.id != widget.gestureToEdit?.id).toList();

      final duplicate = candidates.any(
        (g) => g.triggerText?.toLowerCase() == normalizedTriggerText,
      );
      debugPrint(
        "🔍 Checking Text: '$normalizedTriggerText'. Duplicate found? $duplicate",
      );

      if (duplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Conflict: The shortcut '$triggerText' is already used!",
            ),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
        return; // STOP SAVE
      }
    }

    // 🔴 3. PREVENT EMPTY GESTURES
    if (_points.isEmpty && triggerText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Please draw a gesture or enter a text trigger!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 1. Pick Action (use pre-selected or pick now)
    String? actionType = _selectedActionType;
    String? actionValue = _selectedActionValue;
    String? contactId = _selectedContactId;
    String? localPhotoPath = _selectedLocalPhotoPath;

    if (actionType == null || actionType == "null") {
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (context) => const ActionPickerScreen()),
      );

      if (result == null && !isEditing) return;

      actionType = result?['actionType'] ?? _selectedActionType;
      actionValue = result?['actionValue'] ?? _selectedActionValue;
      contactId = result?['contactId'] ?? _selectedContactId;
      localPhotoPath = result?['localPhotoPath'] ?? localPhotoPath;

      _selectedContactId = contactId;
      _selectedLocalPhotoPath = localPhotoPath;
    }

    if (actionType == null || actionType == "null") {
      if (isEditing) {
        actionType = _selectedActionType!;
        actionValue = _selectedActionValue!;
        contactId = _selectedContactId;
        localPhotoPath = _selectedLocalPhotoPath;
      } else {
        return;
      }
    }

    if (!mounted) return;

    // 2. Name Gesture
    final nameController = TextEditingController(text: _gestureName);
    final theme = Theme.of(context);

    final nameResult = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          isEditing ? 'Update Action' : 'Name Action',
          style: theme.textTheme.titleLarge,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'e.g., Launch WhatsApp',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              StatefulBuilder(
                builder: (context, setState) {
                  return CheckboxListTile(
                    title: Text(
                      "Add to Quick Panel?",
                      style: theme.textTheme.bodyMedium,
                    ),
                    value: _isFavorite,
                    onChanged: (val) {
                      setState(() => _isFavorite = val ?? false);
                    },
                    activeColor: theme.colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: Text(isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
    );

    if (nameResult == null || nameResult.isEmpty || !mounted) return;

    // 3. Save/Update
    debugPrint("🔵 [SAVE] Creating GestureModel with ${_points.length} points");
    // Ensure we save BOTH points and text if available
    final gestureModel = GestureModel(
      id: widget.gestureToEdit?.id,
      uuid: widget.gestureToEdit?.uuid ?? GestureModel.generateUuid(),
      name: nameResult,
      triggerText: triggerText.isNotEmpty ? triggerText : null,
      points: List.from(_points), // Create copy to prevent reference mutation
      actionType: actionType,
      actionValue: actionValue!,
      contactId: contactId,
      localPhotoPath: localPhotoPath,
      isFavorite: _isFavorite,
      createdAt: widget.gestureToEdit?.createdAt ?? DateTime.now(),
    );
    debugPrint(
      "🔵 [SAVE] Model created: ${gestureModel.name}, points=${gestureModel.points.length}, text=${gestureModel.triggerText}",
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEditing ? 'Updating action...' : 'Saving action...'),
        backgroundColor: theme.colorScheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );

    bool success;
    if (isEditing) {
      success = await ref
          .read(gestureProvider.notifier)
          .updateGesture(gestureModel.uuid, gestureModel);
    } else {
      success =
          await ref.read(gestureProvider.notifier).saveGesture(gestureModel);
    }

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✓ Action "$nameResult" ${isEditing ? 'updated' : 'saved'}!',
          ),
          backgroundColor: theme.colorScheme.primary,
        ),
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) context.pop();
      });
    } else {
      final errorMsg = ref.read(gestureProvider).error ??
          'Failed to ${isEditing ? 'update' : 'save'} action';

      if (errorMsg.contains("Maximum 4")) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Too Many Shortcuts"),
            content: const Text(
              "You can only have 4 shortcuts in the Quick Panel.\n\nPlease remove an existing one to add this.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error saving action. Please try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        debugPrint("🛑 SAVE ERROR: $errorMsg");
      }
    }
  }

  // --- OCR HELPER ---
  /// Returns true if OCR detected text (regardless of trigger match).
  /// When true, shape matching should be skipped for this stroke.
  Future<bool> _runOCR() async {
    if (_points.isEmpty) return false;

    setState(() => _isRecognizing = true);
    bool textDetected = false;

    try {
      // Convert points to strokes (SPLIT by -1,-1 separator)
      final List<List<Offset>> strokes = [];
      List<Offset> currentStroke = [];

      for (var p in _points) {
        if (p == const Offset(-1.0, -1.0)) {
          if (currentStroke.isNotEmpty) {
            strokes.add(List.from(currentStroke));
            currentStroke = [];
          }
        } else {
          currentStroke.add(p);
        }
      }
      if (currentStroke.isNotEmpty) strokes.add(currentStroke);

      final detectedText = await OverlayService.recognizeText(strokes);

      if (detectedText != null && detectedText.isNotEmpty) {
        debugPrint("✨ [OCR] Auto-detected: $detectedText");
        textDetected = true;

        if (mounted) {
          // Show detected text immediately in the text field
          setState(() => _triggerTextController.text = detectedText);
        }

        final delayMs = OverlayService.actionDelayMs;

        if (delayMs >= 1000) {
          // Start visible countdown — user can edit text during this window
          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("✨ Detected: '$detectedText' — editing allowed"),
                duration: const Duration(milliseconds: 1200),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          _startAutoRunCountdown(detectedText, delayMs);
        } else {
          // No significant delay — execute immediately
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("✨ Auto-detected: '$detectedText'"),
                duration: const Duration(milliseconds: 1200),
                backgroundColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }
          try {
            final executed = await OverlayService.triggerByText(detectedText);
            if (executed) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("✅ Executed shortcut: '$detectedText'"),
                    backgroundColor: Colors.green,
                    duration: const Duration(milliseconds: 1000),
                  ),
                );
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted) context.pop();
                });
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "📝 Detected '$detectedText' — no shortcut found.\nDraw a shape or save this as a text trigger.",
                    ),
                    backgroundColor: Colors.orange.shade700,
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('Error attempting to trigger overlay action: $e');
          }
        }
      }
    } catch (e) {
      debugPrint("OCR Error: $e");
    } finally {
      if (mounted) setState(() => _isRecognizing = false);
    }
    return textDetected;
  }

  /// Handles onPanEnd: runs OCR first, only runs shape match if OCR found nothing.
  /// This prevents letter strokes from being mismatched as shape gestures (e.g. VS→SM).
  Future<void> _handlePanEnd() async {
    setState(() {
      _isDrawing = true;
      _points.add(const Offset(-1.0, -1.0));
    });
    // OCR first — if it detects text, skip shape matching entirely
    final bool textDetected = await _runOCR();
    if (!textDetected) {
      // No text found → safe to run shape/gesture recognition
      await _checkGestureMatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.gestureToEdit != null ? 'EDIT ACTION' : 'DRAW GESTURE',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded),
            onPressed: _handleSave,
            tooltip: 'Save Action',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // 1. INSTRUCTIONS / FEEDBACK
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      color: theme.colorScheme.surface,
                      child: Row(
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Draw a shape OR write a word below.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. UNIFIED CANVAS
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        constraints: const BoxConstraints(
                          minHeight: 300,
                        ), // Ensure Canvas has space
                        decoration: BoxDecoration(
                          color: theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              GestureCanvas(
                                points: _points,
                                isDrawing: _isDrawing,
                                onPanStart: (offset) {
                                  setState(() {
                                    _isDrawing = true;
                                    // Safety: ensure strokes are separated
                                    // On iOS, onPanEnd may not always fire before the next onPanStart
                                    if (_points.isNotEmpty &&
                                        _points.last !=
                                            const Offset(-1.0, -1.0)) {
                                      _points.add(const Offset(-1.0, -1.0));
                                    }
                                    _points.add(offset);
                                  });
                                },
                                onPanUpdate: (offset) {
                                  setState(() {
                                    _points.add(offset);
                                  });
                                },
                                onPanEnd: () {
                                  // Fire-and-forget async handler:
                                  // OCR runs first, shape only if OCR finds nothing
                                  _handlePanEnd();
                                },
                                gridColor:
                                    theme.colorScheme.primary.withOpacity(0.1),
                                lineColor: theme.colorScheme.primary,
                              ),
                              // Undo Button (Floating inside)
                              Positioned(
                                left: 8,
                                top: 8,
                                child: IconButton(
                                  onPressed: _handleUndo,
                                  icon: Icon(
                                    Icons.undo_rounded,
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.7),
                                  ),
                                  tooltip: "Undo Last Stroke",
                                ),
                              ),
                              // Clear Button (Floating inside)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: IconButton(
                                  onPressed: _handleClear,
                                  icon: Icon(
                                    Icons.refresh,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.5),
                                  ),
                                  tooltip: "Clear Canvas",
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 3. TEXT TRIGGER INPUT (Auto-fill target)
                    // Footer Section (No Expanded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Wait! Also want a text trigger?",
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _triggerTextController,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    labelText: 'Text Shortcut (Optional)',
                                    hintText: 'e.g., call mom',
                                    prefixIcon: const Icon(
                                      Icons.keyboard_alt_rounded,
                                    ),
                                    filled: true,
                                    fillColor: theme
                                        .colorScheme.surfaceContainerHighest
                                        .withOpacity(0.3),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary
                                            .withOpacity(
                                          0.5,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    suffixIcon:
                                        _triggerTextController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear,
                                                    size: 18),
                                                onPressed: () => setState(
                                                  () => _triggerTextController
                                                      .clear(),
                                                ),
                                              )
                                            : null,
                                  ),
                                  onChanged: (text) {
                                    setState(() {});
                                    // If user edits text during countdown, cancel auto-run
                                    // and require them to click RUN manually
                                    if (_countdownSeconds > 0) {
                                      _textEditedDuringCountdown = true;
                                      _cancelAutoRun();
                                    }
                                  },
                                  onSubmitted: (_) async {
                                    // Submit via keyboard: attempt trigger regardless of drawn points
                                    if (_triggerTextController.text
                                        .trim()
                                        .isNotEmpty) {
                                      try {
                                        final executed =
                                            await OverlayService.triggerByText(
                                                _triggerTextController.text
                                                    .trim());
                                        if (executed) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    "✅ Executed: '${_triggerTextController.text.trim()}'"),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            Future.delayed(
                                                const Duration(
                                                    milliseconds: 600), () {
                                              if (mounted) context.pop();
                                            });
                                          }
                                        } else {
                                          if (mounted)
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      "No shortcut found for '${_triggerTextController.text.trim()}'")),
                                            );
                                        }
                                      } catch (e) {
                                        debugPrint('Error triggering text: $e');
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: (_triggerTextController.text
                                        .trim()
                                        .isEmpty)
                                    ? null
                                    : () async {
                                        final text =
                                            _triggerTextController.text.trim();
                                        try {
                                          final executed = await OverlayService
                                              .triggerByText(text);
                                          if (executed) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      "✅ Executed shortcut: '$text'"),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              Future.delayed(
                                                  const Duration(
                                                      milliseconds: 600), () {
                                                if (mounted) context.pop();
                                              });
                                            }
                                          } else {
                                            if (mounted)
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        "No shortcut found for '$text'")),
                                              );
                                          }
                                        } catch (e) {
                                          debugPrint('Run button error: $e');
                                        }
                                      },
                                icon: const Icon(Icons.play_arrow_rounded),
                                label: const Text('RUN'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // --- AUTO-RUN COUNTDOWN STRIP ---
                          if (_countdownSeconds > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  // Animated countdown icon
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      value: _countdownSeconds /
                                          (OverlayService.actionDelayMs / 1000)
                                              .ceil(),
                                      strokeWidth: 3,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Auto-running in $_countdownSeconds s\u2026  Edit text above to cancel.',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color:
                                                  theme.colorScheme.primary),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _cancelAutoRun,
                                    style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(60, 32)),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 8),
                          // ACTION BUTTONS ROW (Clear & Save)
                          Row(
                            children: [
                              // Clear Button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _handleClear,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('CLEAR'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(
                                      color: Colors.redAccent,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Save Button
                              Expanded(
                                flex: 2,
                                child: ElevatedButton.icon(
                                  onPressed: _handleSave,
                                  icon: const Icon(Icons.check_circle_rounded),
                                  label: const Text('SAVE ACTION'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: Colors.black,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16), // Bottom Padding
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom widget for drawing gestures with touch tracking
class GestureCanvas extends StatelessWidget {
  final List<Offset> points;
  final bool isDrawing;
  final Function(Offset) onPanStart;
  final Function(Offset) onPanUpdate;
  final VoidCallback onPanEnd;
  final Color gridColor;
  final Color lineColor;

  const GestureCanvas({
    super.key,
    required this.points,
    required this.isDrawing,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.gridColor,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Grid Pattern Background
        CustomPaint(
          size: Size.infinite,
          painter: _GridPainter(gridColor: gridColor),
        ),

        // Gesture Drawing Layer
        CustomPaint(
          size: Size.infinite,
          painter: _GesturePainter(points: points, lineColor: lineColor),
        ),

        // Placeholder Text (when no drawing)
        if (!isDrawing && points.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gesture_rounded,
                  size: 64,
                  color: lineColor.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'TAP TO BEGIN',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: lineColor.withOpacity(0.5),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

        // Touch Detection Layer
        GestureDetector(
          onPanStart: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(details.globalPosition);
            onPanStart(offset);
          },
          onPanUpdate: (details) {
            final RenderBox box = context.findRenderObject() as RenderBox;
            final offset = box.globalToLocal(details.globalPosition);
            onPanUpdate(offset);
          },
          onPanEnd: (details) {
            onPanEnd();
          },
          child: Container(color: Colors.transparent),
        ),
      ],
    );
  }
}

/// Custom painter for drawing the gesture path
class _GesturePainter extends CustomPainter {
  final List<Offset> points;
  final Color lineColor;

  _GesturePainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // Draw glow effect
    final glowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Draw path
    final path = Path();
    bool isNewStroke = true;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      if (p == const Offset(-1.0, -1.0)) {
        isNewStroke = true; // Next point will be start of new stroke
        continue;
      }

      if (isNewStroke) {
        path.moveTo(p.dx, p.dy);
        isNewStroke = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }

    // Draw glow first, then main line
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, paint);

    // Draw points as circles for visual feedback (skip separators)
    for (final point in points) {
      if (point != const Offset(-1.0, -1.0)) {
        canvas.drawCircle(point, 2, Paint()..color = lineColor);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GesturePainter oldDelegate) {
    return points.length != oldDelegate.points.length;
  }
}

/// Grid painter for background pattern
class _GridPainter extends CustomPainter {
  final Color gridColor;

  _GridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    const gridSize = 30.0;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
