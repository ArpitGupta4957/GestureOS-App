import 'package:flutter/material.dart';
import 'package:gesture_app/features/gesture/widgets/action_grid_selector.dart';
import 'package:gesture_app/features/gesture/widgets/app_list_selector.dart';

/// Dialog for getting gesture details before saving
class GestureDetailsDialog extends StatefulWidget {
  const GestureDetailsDialog({super.key});

  @override
  State<GestureDetailsDialog> createState() => _GestureDetailsDialogState();
}

class _GestureDetailsDialogState extends State<GestureDetailsDialog> {
  final _nameController = TextEditingController();
  String? _selectedActionType;
  String? _selectedActionValue;
  String? _selectedAppName; // For display
  int _viewIndex = 0; // 0: Name & Grid, 1: App List

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleActionSelected(String type, String? value) {
    if (type == 'launch_app') {
      setState(() {
        _viewIndex = 1; // Show app list
      });
    } else {
      _finishSelection(type, value);
    }
  }

  void _finishSelection(String type, String? value, [String? displayValue]) {
    setState(() {
      _selectedActionType = type;
      _selectedActionValue = value;
      if (displayValue != null) _selectedAppName = displayValue;
      _viewIndex = 0; // Go back to main
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelectingApp = _viewIndex == 1;

    return Dialog(
      backgroundColor: theme.scaffoldBackgroundColor,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        height: 600,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
              ),
              child: Row(
                children: [
                  if (isSelectingApp)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _viewIndex = 0),
                    ),
                  Expanded(
                    child: Text(
                      isSelectingApp ? 'Select App' : 'GESTURE DETAILS',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: isSelectingApp
                          ? TextAlign.start
                          : TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: isSelectingApp
                  ? AppListSelector(
                      onAppSelected: (app) {
                        _finishSelection(
                          'launch_app',
                          app.packageName,
                          app.appName,
                        );
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Gesture Name',
                              hintText: 'e.g., Launch Chrome',
                              prefixIcon: Icon(Icons.edit),
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (_selectedActionType != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _selectedActionType == 'launch_app'
                                        ? Icons.apps
                                        : Icons.touch_app,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _selectedActionType == 'launch_app'
                                          ? 'Launch: ${_selectedAppName ?? "Unknown App"}'
                                          : 'Action: $_selectedActionType',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.red,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _selectedActionType = null;
                                        _selectedActionValue = null;
                                        _selectedAppName = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          const Text(
                            'Select Action',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 10),

                          Expanded(
                            child: ActionGridSelector(
                              onActionSelected: _handleActionSelected,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // Footer actions (only on main screen)
            if (!isSelectingApp)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        if (_nameController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a name'),
                            ),
                          );
                          return;
                        }
                        if (_selectedActionType == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please select an action'),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context, {
                          'name': _nameController.text,
                          'actionType': _selectedActionType!,
                          'actionValue': _selectedActionValue ?? '',
                        });
                      },
                      child: const Text('SAVE GESTURE'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
