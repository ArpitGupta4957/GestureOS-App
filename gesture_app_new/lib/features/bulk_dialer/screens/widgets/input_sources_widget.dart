import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/features/bulk_dialer/providers/bulk_dialer_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:gesture_app/core/services/paywall_service.dart';
import 'package:gesture_app/core/services/trial_usage_service.dart';
import 'package:gesture_app/core/enums/premium_capability.dart';

class InputSourcesWidget extends ConsumerWidget {
  const InputSourcesWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: theme.scaffoldBackgroundColor, // Or surface color
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSourceButton(
            context,
            icon: Icons.keyboard,
            label: "Manual",
            onTap: () => _showManualInputDialog(context, ref),
            color: Colors.blueAccent,
          ),
          _buildSourceButton(
            context,
            icon: Icons.camera_alt,
            label: "Scan Image",
            onTap: () => _pickImage(context, ref),
            color: Colors.purpleAccent,
          ),
          _buildSourceButton(
            context,
            icon: Icons.table_chart,
            label: "Import Excel",
            onTap: () => _pickExcel(context, ref),
            color: Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Manual Entry"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter numbers (one per line):"),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "9876543210\n+91 12345 67890",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                ref
                    .read(bulkDialerProvider.notifier)
                    .importFromText(controller.text);
              }
            },
            child: const Text("ADD"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(
    BuildContext context,
    WidgetRef ref, [
    ImageSource? source,
  ]) async {
    final trialService = ref.read(trialUsageProvider.notifier);
    const capability = PremiumCapability.imageOcr;

    if (!trialService.canUse(capability)) {
      ref
          .read(paywallProvider)
          .showTrialLimitDialog(context, capability.displayName);
      return;
    }

    // If source is not provided, show selection sheet
    ImageSource? selectedSource = source;
    if (selectedSource == null) {
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('Take Photo'),
                onTap: () {
                  selectedSource = ImageSource.camera;
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.purple),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  selectedSource = ImageSource.gallery;
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      );
    }

    if (selectedSource == null) return; // User cancelled

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: selectedSource!);
      if (picked != null) {
        ref
            .read(bulkDialerProvider.notifier)
            .importFromImage(File(picked.path));
        trialService.markUsed(capability);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
      }
    }
  }

  Future<void> _pickExcel(BuildContext context, WidgetRef ref) async {
    final trialService = ref.read(trialUsageProvider.notifier);
    const capability = PremiumCapability.excelImport;

    if (!trialService.canUse(capability)) {
      ref
          .read(paywallProvider)
          .showTrialLimitDialog(context, capability.displayName);
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );

    if (result != null && result.files.single.path != null) {
      ref
          .read(bulkDialerProvider.notifier)
          .importFromExcel(File(result.files.single.path!));
      trialService.markUsed(capability);
    }
  }
}
