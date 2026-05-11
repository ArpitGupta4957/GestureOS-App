import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/features/bulk_dialer/models/bulk_dialer_models.dart';
import 'package:gesture_app/features/bulk_dialer/providers/bulk_dialer_provider.dart';
import 'package:gesture_app/features/bulk_dialer/screens/widgets/notes_modal.dart';
import 'package:gesture_app/core/widgets/contact_avatar.dart';

class DialerListView extends ConsumerWidget {
  const DialerListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkDialerProvider);
    final numbers = state.numbers;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (numbers.isEmpty) {
      return const Center(
        child: Text(
          "No numbers added.\nUse manual entry, Excel, or Camera.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Fab space
      itemCount: numbers.length,
      itemBuilder: (context, index) {
        final number = numbers[index];
        return _buildNumberCard(context, ref, number);
      },
    );
  }

  Widget _buildNumberCard(
    BuildContext context,
    WidgetRef ref,
    BulkNumberModel number,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (number.status) {
      case CallStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.access_time_rounded;
        break;
      case CallStatus.called:
        statusColor = const Color(0xFF00FF41); // Neo Green
        statusIcon = Icons.check_circle_rounded;
        break;
      case CallStatus.skipped:
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.skip_next_rounded;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              ContactAvatar(
                fallbackName:
                    number.name?.isNotEmpty == true ? number.name : '?',
                contactId: number.contactId,
                localPhotoPath: number.localPhotoPath,
                radius: 20,
              ),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 14),
                ),
              ),
            ],
          ),
          title: Text(
            number.phoneNumber,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: number.notes.isNotEmpty
              ? Text(
                  "📝 ${number.notes}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit Button
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.grey),
                onPressed: () => _showEditDialog(context, ref, number),
              ),
              // Notes Button
              IconButton(
                icon: Icon(
                  number.notes.isNotEmpty
                      ? Icons.rate_review_rounded
                      : Icons.chat_bubble_outline_rounded,
                  color:
                      number.notes.isNotEmpty ? Colors.blueAccent : Colors.grey,
                ),
                onPressed: () => _showNotesModal(context, ref, number),
              ),

              // Call Button
              IconButton(
                icon: const Icon(
                  Icons.phone_enabled_rounded,
                  color: Color(0xFF00FF41),
                ),
                onPressed: () =>
                    ref.read(bulkDialerProvider.notifier).callNumber(number),
              ),
            ],
          ),
          onLongPress: () {
            // Cycle Status Manually
            ref.read(bulkDialerProvider.notifier).toggleStatus(number);
          },
        ),
      ),
    );
  }

  void _showNotesModal(
    BuildContext context,
    WidgetRef ref,
    BulkNumberModel number,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => NotesModal(
        initialNotes: number.notes,
        onSave: (newNote) {
          ref.read(bulkDialerProvider.notifier).saveNote(number, newNote);
        },
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    BulkNumberModel number,
  ) {
    final phoneController = TextEditingController(text: number.phoneNumber);
    final nameController = TextEditingController(text: number.name ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Number"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name (Optional)"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(bulkDialerProvider.notifier).editNumber(
                    number,
                    phoneController.text,
                    nameController.text.isEmpty ? null : nameController.text,
                  );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
