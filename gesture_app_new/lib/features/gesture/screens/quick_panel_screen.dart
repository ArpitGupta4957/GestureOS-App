import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gesture_app/features/gesture/models/quick_action_models.dart';
import 'package:gesture_app/core/services/quick_action_service.dart';
import 'package:gesture_app/core/services/action_service.dart';

class QuickPanelScreen extends StatefulWidget {
  const QuickPanelScreen({super.key});

  @override
  State<QuickPanelScreen> createState() => _QuickPanelScreenState();
}

class _QuickPanelScreenState extends State<QuickPanelScreen> {
  // ignore: unused_field
  final PageController _callsController = PageController();
  // ignore: unused_field
  final PageController _appsController = PageController();

  List<QuickShortcut> _shortcuts = [];
  List<FrequentContact> _contacts = [];
  List<AppUsage> _apps = [];

  // ignore: unused_field
  final int _callsPage = 0;
  // ignore: unused_field
  final int _appsPage = 0;

  static const _channel = MethodChannel('overlay_channel');

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenForUpdates();
  }

  void _listenForUpdates() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'refreshData') {
        debugPrint("🔄 [QuickPanel] Refreshing Data...");
        await _loadData(force: true);
      }
    });
  }

  Future<void> _loadData({bool force = false}) async {
    // 1. Shortcuts
    final shortcuts = await QuickActionService.loadShortcuts(force: force);

    // 2. Frequent Contacts
    final contacts = await QuickActionService.getFrequentContacts();

    // 3. Apps (Mock for now)
    final apps = await QuickActionService.getTopApps();

    setState(() {
      _shortcuts = shortcuts;
      _contacts = contacts;
      _apps = apps;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Dismissible Background
          GestureDetector(
            onTap: () {
              // Close Overlay via Channel
              const MethodChannel('overlay_channel')
                  .invokeMethod('closeQuickPanel');
            },
            child: Container(
              color: Colors.black.withValues(alpha: 0.3), // Dim
            ),
          ),

          // 2. The Panel
          Center(
            child: Container(
              width: 340, // Compact width
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF1E1E1E,
                ).withValues(alpha: 0.95), // Dark Theme
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- SECTION 1: SHORTCUTS ---
                    _buildShortcutsSection(),
                    Divider(height: 1, color: Colors.white.withOpacity(0.1)),

                    // --- SECTION 2: QUICK CONTACTS ---
                    _buildCallsSection(),
                    Divider(height: 1, color: Colors.white.withOpacity(0.1)),

                    // --- SECTION 3: APPS ---
                    _buildAppsSection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "QUICK ACTIONS",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _shortcuts.length,
            itemBuilder: (context, index) {
              final item = _shortcuts[index];
              final isCall = item.actionType.toUpperCase() == 'CALL';
              final initial = item.label.isNotEmpty
                  ? item.label
                      .replaceAll(
                        RegExp(r'^Call\s*', caseSensitive: false),
                        '',
                      )
                      .trim()
                  : '?';
              final displayName = initial.isNotEmpty ? initial : item.label;

              return Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      ActionService.executeAction(
                        item.actionType,
                        item.actionValue,
                      );
                      _channel.invokeMethod('closeQuickPanel');
                    },
                    child: Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: isCall
                            ? Colors.green.withOpacity(0.15)
                            : Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCall
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Icon(
                                _getIcon(item.actionType),
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String type) {
    if (type == 'FLASHLIGHT') return Icons.flashlight_on;
    if (type == 'WIFI') return Icons.wifi;
    if (type == 'LAUNCH_APP') return Icons.apps;
    return Icons.star;
  }

  Widget _buildCallsSection() {
    if (_contacts.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            "QUICK CONTACTS",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _contacts.length,
            separatorBuilder: (c, i) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              return _buildContactItem(_contacts[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem(FrequentContact contact) {
    return GestureDetector(
      onTap: () {
        ActionService.executeAction('call', contact.number);
        _channel.invokeMethod('closeQuickPanel');
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withOpacity(0.2),
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.green),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 50,
            child: Text(
              contact.name,
              style: const TextStyle(color: Colors.white, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsSection() {
    if (_apps.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            "SUGGESTED APPS",
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _apps.length,
            separatorBuilder: (c, i) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final app = _apps[index];
              if (app.packageName == "PERMISSION_ERROR") {
                return _buildPermissionItem();
              }
              return _buildAppItem(app);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionItem() {
    return GestureDetector(
      onTap: () {
        ActionService.executeAction('settings', 'usage');
        _channel.invokeMethod('closeQuickPanel');
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.lock_open, size: 20, color: Colors.red),
          ),
          const SizedBox(height: 6),
          const Text(
            "Grant",
            style: TextStyle(color: Colors.red, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAppItem(AppUsage app) {
    return GestureDetector(
      onTap: () {
        ActionService.executeAction('app', app.packageName);
        _channel.invokeMethod('closeQuickPanel');
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: (app.iconData != null && app.iconData!.isNotEmpty)
                  ? Image.memory(
                      app.iconData!,
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    )
                  : Text(
                      app.appName.isNotEmpty
                          ? app.appName[0].toUpperCase()
                          : "A",
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 50,
            child: Text(
              app.appName,
              style: const TextStyle(color: Colors.white, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
