import 'package:flutter/material.dart';
import 'package:gesture_app/core/services/app_launcher_service.dart';

class _GestureDetailsDialog extends StatefulWidget {
  @override
  State<_GestureDetailsDialog> createState() => _GestureDetailsDialogState();
}

class _GestureDetailsDialogState extends State<_GestureDetailsDialog> {
  final _nameController = TextEditingController();
  String _selectedAction = 'launch_app';
  String _selectedApp = 'com.android.chrome';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        'Gesture Details',
        style: TextStyle(color: theme.colorScheme.primary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Gesture Name'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedAction,
            decoration: const InputDecoration(labelText: 'Action'),
            items: const [
              DropdownMenuItem(value: 'launch_app', child: Text('Launch App')),
              DropdownMenuItem(value: 'open_url', child: Text('Open URL')),
            ],
            onChanged: (value) => setState(() => _selectedAction = value!),
          ),
          if (_selectedAction == 'launch_app') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedApp,
              decoration: const InputDecoration(labelText: 'Select App'),
              items: AppLauncherService.popularApps.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.value, child: Text(e.key)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedApp = value!),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) return;
            Navigator.pop(context, {
              'name': _nameController.text,
              'actionType': _selectedAction,
              'actionValue':
                  _selectedAction == 'launch_app' ? _selectedApp : '',
            });
          },
          child: const Text('SAVE'),
        ),
      ],
    );
  }
}
