import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:gesture_app/features/gesture/widgets/app_selection_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum ActionType {
  launchApp,
  openUrl,
  makeCall,
  toggleWifi,
  toggleBluetooth,
  toggleFlashlight,
  volumeControl,
  toggleNfc,
  toggleAeroplane,
}

class ActionPickerScreen extends StatelessWidget {
  const ActionPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'SELECT ACTION',
          style: TextStyle(letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildActionCard(
              context,
              icon: FeatherIcons.grid,
              label: 'Launch App',
              onTap: () => _handleLaunchApp(context),
            ),
            _buildActionCard(
              context,
              icon: FeatherIcons.globe,
              label: 'Open Website',
              onTap: () => _handleOpenWebsite(context),
            ),
            _buildActionCard(
              context,
              icon: FeatherIcons.phone,
              label: 'Make a Call',
              onTap: () => _handleMakeCall(context),
            ),
            _buildActionCard(
              context,
              icon: FeatherIcons.wifi,
              label: 'WiFi Settings',
              onTap: () => _handleSystemToggle(context, ActionType.toggleWifi),
            ),
            _buildActionCard(
              context,
              icon: FeatherIcons.bluetooth,
              label: 'Bluetooth',
              onTap: () =>
                  _handleSystemToggle(context, ActionType.toggleBluetooth),
            ),
            _buildActionCard(
              context,
              icon: FeatherIcons.zap,
              label: 'Flashlight',
              onTap: () =>
                  _handleSystemToggle(context, ActionType.toggleFlashlight),
            ),
            _buildActionCard(
              context,
              icon: FeatherIcons.volume2,
              label: 'Volume',
              onTap: () =>
                  _handleSystemToggle(context, ActionType.volumeControl),
            ),
            _buildActionCard(
              context,
              icon: Icons.nfc, // Using standard Material Icon for NFC
              label: 'NFC',
              onTap: () => _handleSystemToggle(context, ActionType.toggleNfc),
            ),
            _buildActionCard(
              context,
              icon: Icons.airplanemode_active,
              label: 'Aeroplane',
              onTap: () =>
                  _handleSystemToggle(context, ActionType.toggleAeroplane),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleLaunchApp(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AppSelectionSheet(),
    );

    if (result != null && context.mounted) {
      Navigator.pop(context, {
        'actionType': 'LAUNCH_APP',
        'actionValue': result['package_name'],
        'displayValue': result['app_name'], // For UI display
      });
    }
  }

  void _handleOpenWebsite(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'https://google.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      if (context.mounted) {
        Navigator.pop(context, {'actionType': 'WEB', 'actionValue': result});
      }
    } else if (result != null && result.isEmpty) {
      // Handle empty input but user pressed save - maybe imply a default or show error?
      // For now, let's not return a success map so the flow stops and user sees they need to enter something.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid URL')),
        );
      }
    }
  }

  void _handleMakeCall(BuildContext context) async {
    final controller = TextEditingController();
    String? selectedContactId;
    String? localPhotoPath;
    final theme = Theme.of(context);
    bool isPickingImage = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Number'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom Avatar Picker
                GestureDetector(
                  onTap: () async {
                    setState(() => isPickingImage = true);
                    try {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        final directory =
                            await getApplicationDocumentsDirectory();
                        final String newPath =
                            '${directory.path}/${const Uuid().v4()}_avatar.jpg';
                        final savedImage = await File(
                          pickedFile.path,
                        ).copy(newPath);
                        setState(() {
                          localPhotoPath = savedImage.path;
                        });
                      }
                    } catch (e) {
                      debugPrint('Error picking image: $e');
                    } finally {
                      setState(() => isPickingImage = false);
                    }
                  },
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: localPhotoPath != null
                        ? FileImage(File(localPhotoPath!))
                        : null,
                    child: isPickingImage
                        ? const CircularProgressIndicator()
                        : localPhotoPath == null
                            ? Icon(
                                Icons.add_a_photo,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '1234567890'),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                  onPressed: () async {
                    try {
                      final contact = await FlutterContacts.openExternalPick();
                      if (contact != null) {
                        setState(() {
                          selectedContactId = contact.id;
                        });
                        // Try to find a phone number
                        String? number = contact.phones.isNotEmpty
                            ? contact.phones.first.number
                            : null;
                        if (number != null) {
                          // Standardize format: +91XXXXXXXXXX
                          String digitsOnly = number.replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          String formatted = digitsOnly;

                          if (digitsOnly.length == 10) {
                            formatted = '+91$digitsOnly';
                          } else if (digitsOnly.length == 11 &&
                              digitsOnly.startsWith('0')) {
                            formatted = '+91${digitsOnly.substring(1)}';
                          } else if (digitsOnly.length == 12 &&
                              digitsOnly.startsWith('91')) {
                            formatted = '+$digitsOnly';
                          }

                          controller.text = formatted;
                        }
                      }
                    } catch (e) {
                      debugPrint('Contact pick failed: $e');
                    }
                  },
                  icon: const Icon(FeatherIcons.users, size: 16),
                  label: const Text('Pick Contact instead'),
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
              onPressed: () {
                Navigator.pop(context, {
                  'number': controller.text,
                  'contactId': selectedContactId,
                  'localPhotoPath': localPhotoPath,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result['number'].toString().isNotEmpty) {
      if (context.mounted) {
        Navigator.pop(context, {
          'actionType': 'CALL',
          'actionValue': result['number'],
          'contactId': result['contactId'],
          'localPhotoPath': result['localPhotoPath'],
        });
      }
    }
  }

  void _handleSystemToggle(BuildContext context, ActionType type) {
    String actionCode;
    String displayValue;

    switch (type) {
      case ActionType.toggleWifi:
        actionCode = 'WIFI';
        displayValue = 'WiFi Settings';
        break;
      case ActionType.toggleBluetooth:
        actionCode = 'BLUETOOTH';
        displayValue = 'Bluetooth Settings';
        break;
      case ActionType.toggleFlashlight:
        actionCode = 'FLASHLIGHT';
        displayValue = 'Flashlight';
        break;
      case ActionType.volumeControl:
        actionCode = 'VOLUME';
        displayValue = 'Volume Control';
        break;
      case ActionType.toggleNfc:
        actionCode = 'NFC';
        displayValue = 'NFC Settings';
        break;
      case ActionType.toggleAeroplane:
        actionCode = 'AEROPLANE';
        displayValue = 'Aeroplane Mode';
        break;
      default:
        return;
    }

    Navigator.pop(context, {
      'actionType': actionCode,
      'actionValue': 'ENABLE', // Non-empty value to pass backend validation
      'displayValue': displayValue,
    });
  }
}
