import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/features/bulk_dialer/providers/bulk_dialer_provider.dart';
import 'package:gesture_app/features/bulk_dialer/screens/widgets/dialer_list_view.dart';
import 'package:gesture_app/features/bulk_dialer/screens/widgets/input_sources_widget.dart';
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart';
import 'package:gesture_app/features/gesture/screens/draw_gesture_screen.dart';
import 'package:gesture_app/core/services/paywall_service.dart';
import 'package:gesture_app/core/services/trial_usage_service.dart';
import 'package:gesture_app/core/services/subscription_service.dart';
import 'package:gesture_app/core/enums/premium_capability.dart';

class BulkDialerScreen extends ConsumerStatefulWidget {
  const BulkDialerScreen({super.key});

  @override
  ConsumerState<BulkDialerScreen> createState() => _BulkDialerScreenState();
}

class _BulkDialerScreenState extends ConsumerState<BulkDialerScreen> {
  @override
  void initState() {
    super.initState();
    // Load session when tab opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bulkDialerProvider.notifier).loadSession();
    });
  }

  void _showNewSessionDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Start New Session?"),
        content: const Text(
          "Current list will be cleared. Unsaved notes might be lost if not exported.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(bulkDialerProvider.notifier).createNewSession();
            },
            child: const Text("NEW SESSION"),
          ),
        ],
      ),
    );
  }

  void _showFinishDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Finish Session?"),
        content: const Text(
          "This will export the report and DELETE all session data permanently. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(bulkDialerProvider.notifier).finishAndClearSession();
            },
            child: const Text(
              "FINISH & DELETE",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkDialerProvider);
    final theme = Theme.of(context);

    // Error Handling
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
        );
        // Clear error? Or handle via state notifier method
      });
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'mydial_draw',
        onPressed: () async {
          // Navigate to mini draw pad and await strokes
          final strokes = await Navigator.push<List<Offset>>(
            context,
            MaterialPageRoute(builder: (_) => const _MiniDrawPad()),
          );

          if (strokes != null && strokes.isNotEmpty) {
            // Forward strokes to the full DrawGestureScreen for naming/action selection
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (ctx) => DrawGestureScreen(
                  preFilledPoints: strokes,
                ),
              ),
            );
          }
        },
        backgroundColor: theme.colorScheme.primary,
        tooltip: 'Quick Draw',
        child: Icon(Icons.gesture_rounded, color: theme.colorScheme.onPrimary),
      ),
      body: Column(
        children: [
          // 1. Session Header
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.currentSession?.name ??
                                  "Loading Session...",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          // Syncing Indicator
                          if (state.isSyncing)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          // Offline Badge
                          if (state.isOfflineMode && !state.isSyncing)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "OFFLINE",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        "${state.numbers.where((n) => n.status == CallStatus.called).length} / ${state.numbers.length} Called",
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Export Button
                IconButton(
                  onPressed: () {
                    // 1. Check Plan Limitations
                    final subState = ref.read(subscriptionProvider);
                    final allowExport =
                        subState.activePlanLimits['allow_export'] ?? true;

                    if (!allowExport) {
                      ref
                          .read(paywallProvider)
                          .showUpgradeSheet(context, "Export Reports");
                      return;
                    }

                    // 2. Check Trial Limits
                    final trialService = ref.read(trialUsageProvider.notifier);
                    const capability = PremiumCapability.exportReport;

                    if (!subState.isPremium &&
                        !trialService.canUse(capability)) {
                      ref.read(paywallProvider).showTrialLimitDialog(
                            context,
                            capability.displayName,
                          );
                      return;
                    }

                    ref.read(bulkDialerProvider.notifier).exportReport();
                    trialService.markUsed(capability);
                  },
                  icon: const Icon(Icons.download_rounded),
                  tooltip: "Export Report",
                ),

                // More Actions Menu
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'new_session') {
                      _showNewSessionDialog(context, ref);
                    } else if (value == 'finish_session') {
                      _showFinishDialog(context, ref);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'new_session',
                      child: Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text("New Session"),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'finish_session',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.green),
                          SizedBox(width: 8),
                          Text("Finish & Clear"),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Input Sources (Fixed Top)
          const InputSourcesWidget(),

          const Divider(height: 1),

          // 3. List (Expanded)
          const Expanded(child: DialerListView()),
        ],
      ),
    );
  }
}

/// Mini draw pad overlay for quick gesture creation from MyDial tab
class _MiniDrawPad extends StatefulWidget {
  const _MiniDrawPad();

  @override
  State<_MiniDrawPad> createState() => _MiniDrawPadState();
}

class _MiniDrawPadState extends State<_MiniDrawPad> {
  final List<Offset> _points = [];

  void _handleClear() {
    setState(() {
      _points.clear();
    });
  }

  void _handleUndo() {
    if (_points.isEmpty) return;
    setState(() {
      while (_points.isNotEmpty && _points.last == const Offset(-1.0, -1.0)) {
        _points.removeLast();
      }
      while (_points.isNotEmpty && _points.last != const Offset(-1.0, -1.0)) {
        _points.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('QUICK DRAW'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            onPressed: _handleUndo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _handleClear,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Draw a letter or shape, then tap DONE to create a gesture shortcut.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      onPanStart: (d) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        setState(() {
                          if (_points.isNotEmpty &&
                              _points.last != const Offset(-1.0, -1.0)) {
                            _points.add(const Offset(-1.0, -1.0));
                          }
                          _points.add(box.globalToLocal(d.globalPosition));
                        });
                      },
                      onPanUpdate: (d) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final localPos = box.globalToLocal(d.globalPosition);
                        // Prevent drawing outside the box bounds
                        if (localPos.dx >= 0 &&
                            localPos.dx <= constraints.maxWidth &&
                            localPos.dy >= 0 &&
                            localPos.dy <= constraints.maxHeight) {
                          setState(() {
                            _points.add(localPos);
                          });
                        }
                      },
                      onPanEnd: (_) {
                        setState(() {
                          _points.add(const Offset(-1.0, -1.0));
                        });
                      },
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _QuickDrawPainter(
                          points: _points,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _points.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context, List<Offset>.from(_points));
                      },
                icon: const Icon(Icons.check_rounded),
                label: const Text('DONE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuickDrawPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  _QuickDrawPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool isNewStroke = true;
    for (final p in points) {
      if (p == const Offset(-1.0, -1.0)) {
        isNewStroke = true;
        continue;
      }
      if (isNewStroke) {
        path.moveTo(p.dx, p.dy);
        isNewStroke = false;
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _QuickDrawPainter oldDelegate) =>
      points.length != oldDelegate.points.length;
}
