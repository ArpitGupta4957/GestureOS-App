import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/providers/gesture_provider.dart';

class SyncStatusIcon extends ConsumerWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gestureState = ref.watch(gestureProvider);
    final hasUnsynced = gestureState.gestures.any((g) => !g.isSynced);
    final isSyncing = gestureState.isSyncing;

    if (isSyncing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 20,
        height: 20,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    }

    if (!hasUnsynced) {
      // All good, maybe show a green check briefly? Or nothing.
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.cloud_off, color: Colors.amber),
      tooltip: "Offline Changes Pending",
      onPressed: () {
        // Trigger manual sync
        ref.read(gestureProvider.notifier).refreshGestures();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Syncing data..."),
            duration: Duration(seconds: 1),
          ),
        );
      },
    );
  }
}
