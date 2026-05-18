import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/providers/gesture_provider.dart';
import 'package:gesture_app/features/bulk_dialer/screens/bulk_dialer_screen.dart';
import 'package:gesture_app/core/models/gesture_model.dart';

import 'package:gesture_app/core/services/ios_trigger_service.dart';
import 'package:gesture_app/core/services/overlay_service.dart';
import 'package:gesture_app/core/services/action_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gesture_app/features/common/widgets/sync_status_icon.dart';
import 'package:gesture_app/features/gesture/screens/action_picker_screen.dart';
import 'package:gesture_app/core/widgets/contact_avatar.dart';

import 'package:gesture_app/features/dashboard/screens/aliased_contacts_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  bool _isOverlayActive = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB visibility
    });
    _checkServiceStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAllPermissions();
      // Initialize iOS Triggers safely
      IosTriggerService.initialize(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkServiceStatus() async {
    if (!Platform.isAndroid) return; // Overlay is Android-only
    await OverlayService.initialize(); // Ensure shortcuts loaded
    // Check actual native overlay status
    final isRunningVal = await OverlayService.isRunning();
    setState(() {
      _isOverlayActive = isRunningVal;
    });
  }

  Future<void> _checkAllPermissions() async {
    // 1. Standard Permissions (cross-platform)
    await [
      Permission.phone,
      Permission.contacts,
      Permission.camera, // For Flashlight
    ].request();

    // Android-only permissions
    if (Platform.isAndroid) {
      // 2. Overlay Permission
      if (!await Permission.systemAlertWindow.isGranted) {
        await Permission.systemAlertWindow.request();
      }

      // 3. Usage Stats (Native Check via Android MethodChannel)
      try {
        final bool hasUsage = await const MethodChannel(
              'overlay_channel',
            ).invokeMethod('checkUsagePermission') ??
            false;
        if (!hasUsage) {
          if (mounted) {
            _showUsagePermissionDialog();
          }
        }
      } catch (e) {
        debugPrint("Usage Check Failed: $e");
      }
    }
  }

  void _showUsagePermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Additional Permission Required"),
        content: const Text(
          "To show 'Suggested Apps', the app needs Usage Access.\n\nPlease find 'Gesture App' in the list and enable it.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Open Settings
              ActionService.executeAction('settings', 'usage');
            },
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
        ],
      ),
    );
  }

  void _toggleOverlay() async {
    // 1. Permission Check
    final sysAlert = await Permission.systemAlertWindow.status;
    final phone = await Permission.phone.status;
    final contacts = await Permission.contacts.status;

    if (!sysAlert.isGranted || !phone.isGranted || !contacts.isGranted) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Requesting necessary permissions...")),
        );
      }

      Map<Permission, PermissionStatus> statuses = await [
        Permission.systemAlertWindow,
        Permission.phone,
        Permission.contacts,
      ].request();

      if (statuses[Permission.systemAlertWindow] != PermissionStatus.granted) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Overlay Permission is required.")),
          );
        }
        return;
      }
    }

    // 2. Toggle via Native Channel (The Fix)
    const channel = MethodChannel('overlay_channel');

    try {
      if (_isOverlayActive) {
        // Stop
        await channel.invokeMethod('stopOverlay');
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Overlay Stopped 🛑")));
        }
      } else {
        // Start
        print("🟢 Dashboard: Starting Native Overlay...");
        // Sync first (optional, but good)
        final gestures = ref.read(gestureProvider).gestures;
        final gesturesJson = gestures.map((g) => g.toJson()).toList();
        await OverlayService.syncGesturesToOverlaySync(gesturesJson);

        await channel.invokeMethod('startOverlay');
        // Removed redundant snackbar per user request
      }

      if (mounted) {
        setState(() {
          _isOverlayActive = !_isOverlayActive;
        });
      }
    } catch (e) {
      print("❌ Error toggling overlay: $e");
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
      // Revert state if failed
      _checkServiceStatus();
    }
  }

  void _showDeleteConfirmDialog(BuildContext context, GestureModel gesture) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Action?"),
        content: Text("Are you sure you want to delete '${gesture.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("CANCEL"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(gestureProvider.notifier)
                  .deleteGesture(gesture.uuid);
              if (success && mounted && context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Action deleted")));
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }

  IconData _getIconForActionType(String actionType) {
    switch (actionType) {
      case 'LAUNCH_APP':
        return Icons.apps_rounded;
      case 'WIFI':
        return Icons.wifi_rounded;
      case 'VOLUME':
        return Icons.volume_up_rounded;
      case 'FLASHLIGHT':
        return Icons.flashlight_on_rounded;
      default:
        return Icons.touch_app_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gestureState = ref.watch(gestureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MyDial'),
        bottom: TabBar(
          controller: _tabController,
          labelPadding: const EdgeInsets.symmetric(
            horizontal: 4.0,
          ), // Give more space
          tabs: const [
            Tab(text: "MY ACTIONS"),
            Tab(text: "BULK DIALER"),
            Tab(text: "ALIASED"),
          ],
          indicatorColor: const Color(0xFF00FF41), // Neo Green
          labelColor: const Color(0xFF00FF41),
          unselectedLabelColor: Colors.grey,
        ),
        actions: [
          // Overlay Toggle (Android Only)
          if (Platform.isAndroid)
            IconButton(
              icon: Icon(
                _isOverlayActive ? Icons.layers_rounded : Icons.layers_outlined,
                color: _isOverlayActive ? theme.colorScheme.primary : null,
              ),
              onPressed: _toggleOverlay,
              tooltip: 'Toggle Global Overlay',
            ),
          // Premium Button (New)
          IconButton(
            icon: const Icon(Icons.workspace_premium, color: Color(0xFF00FF41)),
            onPressed: () => context.push('/subscription'),
            tooltip: 'Premium Plans',
          ),
          // Sync Status (New)
          const SyncStatusIcon(),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(gestureProvider.notifier).refreshGestures();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Gestures Grid (Existing)
          _buildGestureTab(theme, gestureState),

          // Tab 2: Bulk Dialer
          _buildBulkDialerTab(theme),

          // Tab 3: Aliased Contacts (New)
          const AliasedContactsTab(),
        ],
      ),
      // Animate FAB scale based on tab position (Index 0 -> 1 hides it)
      floatingActionButton: AnimatedBuilder(
        animation: _tabController.animation!,
        builder: (context, child) {
          final value = _tabController.animation!.value;
          // Calculate scale: 1.0 at index 0, 0.0 at index 1.
          // We make it disappear faster (by 0.5 progress) for better responsiveness.
          final scale = (1.0 - (value * 2)).clamp(0.0, 1.0);

          if (scale == 0.0) return const SizedBox();

          return Transform.scale(scale: scale, child: child);
        },
        child: FloatingActionButton(
          onPressed: () {
            _showCreateOptions(context);
          },
          child: const Icon(Icons.add, size: 32),
        ),
      ),
    );
  }

  Widget _buildBulkDialerTab(ThemeData theme) {
    return const BulkDialerScreen();
  }

  Widget _buildGestureTab(ThemeData theme, GestureState gestureState) {
    return RefreshIndicator(
      onRefresh: () => ref.read(gestureProvider.notifier).refreshGestures(),
      child: gestureState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : gestureState.gestures.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 64,
                        color: theme.colorScheme.primary.withOpacity(0.5),
                      ),
                      const SizedBox(height: 16),
                      Text('No actions yet',
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap + to create your first action',
                        style: TextStyle(color: Colors.white54),
                      ),
                      if (Platform.isIOS) ...[
                        const SizedBox(height: 16),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: theme.colorScheme.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'On iOS, trigger actions by tapping cards, using the home screen widget, or long-pressing the app icon.',
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.primary.withOpacity(
                                      0.8,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (gestureState.error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          child: Card(
                            color: theme.colorScheme.errorContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.colorScheme.error,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      gestureState.error!,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color:
                                            theme.colorScheme.onErrorContainer,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: theme.colorScheme.onErrorContainer,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(gestureProvider.notifier)
                                          .clearError();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: gestureState.gestures.length,
                  itemBuilder: (context, index) {
                    final gesture = gestureState.gestures[index];
                    return _GestureCard(
                      name: gesture.name,
                      actionType: gesture.actionType,
                      actionValue: gesture.actionValue,
                      triggerText: gesture.triggerText,
                      isSynced: gesture.isSynced,
                      icon: _getIconForActionType(gesture.actionType),
                      localPhotoPath: gesture.localPhotoPath,
                      contactId: gesture.contactId,
                      onTap: () {
                        ActionService.executeAction(
                          gesture.actionType,
                          gesture.actionValue,
                        );
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("🚀 Executing: ${gesture.name}"),
                            duration: const Duration(seconds: 1),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      },
                      onEdit: () {
                        context.push('/draw-gesture', extra: gesture);
                        // Need to update router to accept extra!
                      },
                      onDelete: () {
                        _showDeleteConfirmDialog(context, gesture);
                      },
                      // New Properties
                      isShortcut: gesture.isFavorite, // Use DB source
                      onToggleShortcut: () async {
                        final updatedGesture = gesture.copyWith(
                          isFavorite: !gesture.isFavorite,
                        );

                        // Optimistic UI Update / API Call
                        final success = await ref
                            .read(gestureProvider.notifier)
                            .updateGesture(gesture.uuid, updatedGesture);

                        if (success) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                updatedGesture.isFavorite
                                    ? "Added to Quick Panel ⭐"
                                    : "Removed from Quick Panel",
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );
                        } else {
                          final errorMsg = ref.read(gestureProvider).error ??
                              "Failed to update favorite status";

                          if (errorMsg.contains("Maximum 4")) {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Quick Panel Full"),
                                content: const Text(
                                  "You can only have 4 items in the Quick Panel.\n\nPlease remove an existing one to add this.",
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
    );
  }

  void _showCreateOptions(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(
              color: Theme.of(
                sheetContext,
              ).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CREATE NEW",
              style: TextStyle(
                color: Theme.of(sheetContext).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    sheetContext,
                  ).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.touch_app_rounded,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
              ),
              title: const Text(
                "Custom Gesture",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text("Pick an action, then draw a gesture"),
              onTap: () async {
                Navigator.pop(sheetContext); // Close the bottom sheet
                // Action picker FIRST — use parentContext for navigation
                final result = await Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (context) => const ActionPickerScreen(),
                  ),
                );
                if (result != null && mounted) {
                  // Then draw page with pre-selected action
                  parentContext.push(
                    '/draw-gesture',
                    extra: {
                      'actionType': result['actionType'],
                      'actionValue': result['actionValue'],
                      'actionName':
                          result['displayValue'] ?? result['actionValue'],
                      'contactId': result['contactId'],
                      'localPhotoPath': result['localPhotoPath'],
                    },
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF41).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Color(0xFF00FF41),
                ),
              ),
              title: const Text(
                "Quick Dial Setup",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text("Assign call shortcuts to contacts"),
              onTap: () {
                Navigator.pop(sheetContext); // Close the bottom sheet
                parentContext.push('/auto-assign'); // Use parent context
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _GestureCard extends StatelessWidget {
  final String name;
  final String actionType;
  final String actionValue;
  final String? triggerText;
  final bool isSynced;
  final bool isShortcut;
  final IconData icon;
  final String? localPhotoPath;
  final String? contactId;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleShortcut;

  const _GestureCard({
    required this.name,
    required this.actionType,
    required this.actionValue,
    this.triggerText,
    required this.isSynced,
    required this.isShortcut,
    required this.icon,
    this.localPhotoPath,
    this.contactId,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleShortcut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String displayName = name;
    if (actionType.toLowerCase() == 'call' &&
        name.toLowerCase().startsWith('call ')) {
      displayName = name.substring(5).trim();
    }

    final alias = triggerText?.trim() ?? '';

    return Card(
        child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header: Sync Status & Menu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // SHORTCUT STAR
                  IconButton(
                    icon: Icon(
                      isShortcut
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 24,
                      color: isShortcut
                          ? Colors.amber
                          : theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onPressed: onToggleShortcut,
                    tooltip: isShortcut
                        ? "Remove from Quick Panel"
                        : "Add to Quick Panel",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),

                  Expanded(
                    child: Center(
                      child: alias.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(
                                  0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.3,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                alias,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.8,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // Menu
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text("Edit"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Delete",
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              Expanded(
                child: Center(
                  child: actionType.toLowerCase() == 'call' &&
                          actionValue.isNotEmpty
                      ? ContactAvatar(
                          fallbackName:
                              displayName.isNotEmpty ? displayName : '?',
                          localPhotoPath: localPhotoPath,
                          contactId: contactId,
                          phoneNumber: actionValue,
                          radius: 20,
                        )
                      : Icon(icon, size: 36, color: theme.colorScheme.primary),
                ),
              ),

              // Display name only. Alias is shown in header between star and menu.
              Flexible(
                child: Text(
                  displayName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Action Type
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  actionType.replaceAll('_', ' ').toUpperCase(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
