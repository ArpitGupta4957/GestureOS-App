import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gesture_app/core/utils/permission_manager.dart';
import 'package:gesture_app/core/widgets/guided_permission_dialog.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/providers/theme_provider.dart';
import 'package:gesture_app/core/providers/overlay_settings_provider.dart';
import 'package:gesture_app/core/services/overlay_service.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh permissions when returning to app
    if (state == AppLifecycleState.resumed) {
      setState(() {
        // Triggers rebuild which re-runs FutureBuilders
      });
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('LOGOUT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'This will:\n'
          '• Permanently delete your account\n'
          '• Delete all your gestures and data from database\n'
          '• Log you out immediately\n\n'
          'This action is PERMANENT and cannot be undone!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext); // Close dialog

              try {
                final apiService = ref.read(apiServiceProvider);
                await apiService.dio.post('/api/user/delete-request');

                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Your account and all data have been permanently deleted.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );

                  // Wait a moment for user to see the message
                  await Future.delayed(const Duration(milliseconds: 500));

                  // Clear auth state and redirect to login
                  if (mounted) {
                    ref.read(authProvider.notifier).logout();
                    if (context.mounted) {
                      context.go('/login');
                    }
                  }
                }
              } catch (e) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to request deletion: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'REQUEST DELETION',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkStorageStatus() async {
    final storage = await Permission.storage.status;
    final photos = await Permission.photos.status;
    // On Android 13+, storage is usually denied, photos works.
    // On Older Android, storage works.
    return storage.isGranted || photos.isGranted;
  }

  Future<void> _requestStorage() async {
    // Show disclosure for storage and photos
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const GuidedPermissionDialog(permission: AppPermission.storage),
    );
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const GuidedPermissionDialog(permission: AppPermission.photos),
    );

    // Refresh UI
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'PROFILE & SETTINGS',
          style: TextStyle(letterSpacing: 1.5),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // PRODILE CARD
          if (user != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    const Color(0xFF2C2C2C),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors
                                .white, // In card, keep white as background is dark/gradient
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? user.mobileNumber ?? 'No Contact Info',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70, // Keep white in card
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.black45
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),

          // PERMISSIONS SECTION
          const _SectionHeader(title: 'PERMISSIONS MANAGER'),
          // Android-only: Display Over Apps (iOS doesn't support overlays)
          if (Platform.isAndroid)
            const _PermissionTile(
              title: 'Display Over Apps',
              subtitle: 'Required for floating trigger',
              permission: Permission.systemAlertWindow,
              icon: Icons.layers_outlined,
            ),
          // Android-only: Usage Access
          if (Platform.isAndroid)
            _CustomPermissionTile(
              title: 'Usage Access',
              subtitle: 'Recommended for "Recent Apps" panel',
              icon: Icons.data_usage,
              checkStatus: OverlayService.checkUsageStats,
              onTap: () {
                const AndroidIntent(
                  action: 'android.settings.USAGE_ACCESS_SETTINGS',
                ).launch();
              },
            ),
          const _PermissionTile(
            title: 'Phone Calls',
            subtitle: 'Direct call from gestures',
            permission: Permission.phone,
            icon: Icons.phone_outlined,
          ),
          const _PermissionTile(
            title: 'Contacts',
            subtitle: 'Pick numbers for actions',
            permission: Permission.contacts,
            icon: Icons.contacts_outlined,
          ),
          _CustomPermissionTile(
            title: 'Storage / Photos',
            subtitle: 'Required for Bulk Dialer Image/Excel',
            icon: Icons.folder_open,
            checkStatus: _checkStorageStatus,
            onTap: _requestStorage,
          ),
          const _PermissionTile(
            title: 'Notifications',
            subtitle: 'Required for background service',
            permission: Permission.notification,
            icon: Icons.notifications_active_outlined,
          ),
          if (Platform.isAndroid)
            const _PermissionTile(
              title: 'Battery Optimization',
              subtitle: 'Disable to keep overlay alive',
              permission: Permission.ignoreBatteryOptimizations,
              icon: Icons.battery_alert_outlined,
            ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: Colors.white12),
          ),

          // OVERLAY CUSTOMIZATION (Android Only)
          if (Platform.isAndroid) ...[
            const _SectionHeader(title: 'OVERLAY CUSTOMIZATION'),
            _OverlaySizeSlider(),
            _OverlayOpacitySlider(),
            _StrictnessSlider(),
            _RecognitionDelaySlider(),
            _ActionDelaySlider(),
            SwitchListTile(
              activeThumbColor: theme.colorScheme.primary,
              tileColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: const Text('Shake to Wake'),
              subtitle: const Text('Shake phone to open overlay'),
              value: ref.watch(overlaySettingsProvider).shakeEnabled,
              onChanged: (val) {
                ref
                    .read(overlaySettingsProvider.notifier)
                    .updateSettings(shakeEnabled: val);
              },
            ),
            SwitchListTile(
              activeThumbColor: theme.colorScheme.primary,
              tileColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: const Text('Auto-Hide Bubble'),
              subtitle: const Text('Hide when idle for 5s (Shake to wake)'),
              value: ref.watch(overlaySettingsProvider).autoHide,
              onChanged: (val) {
                ref
                    .read(overlaySettingsProvider.notifier)
                    .updateSettings(autoHide: val);
              },
            ),
            _DoubleTapActionSelector(),
            _LongPressActionSelector(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(color: Colors.white12),
            ),
          ],
          // APPEARANCE SECTION
          const _SectionHeader(title: 'APPEARANCE'),
          SwitchListTile(
            activeThumbColor: theme.colorScheme.primary,
            tileColor: Colors.transparent,
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(
              'Dark Mode',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Use dark theme for low light',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 12,
              ),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.dark_mode_outlined,
                color: theme.iconTheme.color,
              ),
            ),
            value: ref.watch(themeProvider) == ThemeMode.dark,
            onChanged: (value) {
              ref.read(themeProvider.notifier).toggleTheme(value);
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Divider(color: Colors.white12),
          ),

          // APP SETTINGS
          const _SectionHeader(title: 'APP SETTINGS'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About App',
            subtitle: 'Version 1.0.0 (Cyberpunk Edition)',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Gesture Control',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.fingerprint,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                children: [
                  const Text("Control your phone with magic gestures."),
                ],
              );
            },
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () => launchUrl(Uri.parse('https://servermine.com/privacy')),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: 'Terms of Use (EULA)',
            subtitle: 'Read our terms and conditions',
            onTap: () => launchUrl(Uri.parse('https://servermine.com/terms')),
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Logout',
            subtitle: 'Sign out of this device',
            iconColor: Colors.redAccent,
            onTap: () => _handleLogout(context),
          ),
          _SettingsTile(
            icon: Icons.delete_forever_rounded,
            title: 'Delete Account',
            subtitle: 'Request permanent deletion',
            iconColor: Colors.red,
            onTap: () => _handleDeleteAccount(context),
          ),

          const _SectionHeader(title: 'SECURITY'),
          const _AppPinSettingsTile(),
          _SettingsTile(
            icon: Icons.lock_reset_rounded,
            title: 'Change Password',
            subtitle: 'Update your login password',
            onTap: () => _showChangePasswordDialog(context),
          ),
          if (user?.email == null)
            _SettingsTile(
              icon: Icons.add_link_rounded,
              title: 'Link Email',
              subtitle: 'Add an email to your account',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email linking coming soon!')),
                );
              },
            ),
          if (user?.mobileNumber == null)
            _SettingsTile(
              icon: Icons.add_link_rounded,
              title: 'Link Mobile',
              subtitle: 'Add a mobile number to your account',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Mobile linking coming soon!')),
                );
              },
            ),

          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2C2C2C),
              title: const Text(
                'Change Password',
                style: TextStyle(color: Colors.white),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Enter current password' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: newPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                      validator: (v) =>
                          v!.length < 8 ? 'Min 8 characters' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                      ),
                      validator: (v) =>
                          v != newPasswordController.text ? 'Mismatch' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setState(() => isLoading = true);

                            final success = await ref
                                .read(authProvider.notifier)
                                .changePassword(
                                  currentPassword:
                                      currentPasswordController.text,
                                  newPassword: newPasswordController.text,
                                  newPasswordConfirmation:
                                      confirmPasswordController.text,
                                );

                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Password changed successfully',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else {
                                final error = ref.read(authProvider).error;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      error ?? 'Failed to change password',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('UPDATE'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Permission permission;
  final IconData icon;

  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.permission,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PermissionStatus>(
      future: permission.status,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final isGranted = status == PermissionStatus.granted ||
            status == PermissionStatus.limited;

        // Special handle for System Alert Window which returns different statuses on some versions
        // but 'isGranted' covers standard cases.

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Theme.of(context).iconTheme.color),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 12,
            ),
          ),
          trailing: status == null
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : isGranted
                  ? Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FF41), // Matrix Green
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check,
                          size: 16, color: Colors.black),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 0,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () async {
                        final appPermission = PermissionManager.fromPermission(
                          permission,
                        );
                        if (appPermission != null) {
                          // Show prominent disclosure dialog before system dialog
                          await showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => GuidedPermissionDialog(
                                permission: appPermission),
                          );
                        } else {
                          // Fallback for non-sensitive permissions
                          await permission.request();
                        }

                        if (status == PermissionStatus.permanentlyDenied) {
                          openAppSettings();
                        }
                      },
                      child: const Text("ALLOW"),
                    ),
        );
      },
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? theme.iconTheme.color),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: 12,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.iconTheme.color?.withOpacity(0.3),
      ),
      onTap: onTap,
    );
  }
}

class _AppPinSettingsTile extends ConsumerWidget {
  const _AppPinSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final pinFuture = ref.watch(pinServiceProvider).hasPin();

    return FutureBuilder<bool>(
      future: pinFuture,
      builder: (context, snapshot) {
        final hasPin = snapshot.data ?? false;

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.pin_outlined, color: theme.iconTheme.color),
          ),
          title: Text(
            hasPin ? 'Change Login PIN' : 'Set Login PIN',
            style: TextStyle(
              color: theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'Set a 4-digit PIN for quick login',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color,
              fontSize: 12,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: theme.iconTheme.color?.withOpacity(0.3),
          ),
          onTap: () => context.push('/pin-setup'),
        );
      },
    );
  }
}

class _BiometricsToggleTile extends ConsumerStatefulWidget {
  const _BiometricsToggleTile();

  @override
  ConsumerState<_BiometricsToggleTile> createState() =>
      _BiometricsToggleTileState();
}

class _BiometricsToggleTileState extends ConsumerState<_BiometricsToggleTile> {
  bool _isEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final pinService = ref.read(pinServiceProvider);
    final isEn = await pinService.isBiometricsEnabled();
    setState(() {
      _isEnabled = isEn;
      _isLoading = false;
    });
  }

  Future<void> _toggle(bool val) async {
    final pinService = ref.read(pinServiceProvider);
    await pinService.setBiometricsEnabled(val);
    setState(() {
      _isEnabled = val;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) return const SizedBox.shrink();

    return SwitchListTile(
      activeThumbColor: theme.colorScheme.primary,
      tileColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text(
        'Unlock with Biometrics',
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        'Use Fingerprint/Face ID',
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: 12,
        ),
      ),
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.fingerprint, color: theme.iconTheme.color),
      ),
      value: _isEnabled,
      onChanged: _toggle,
    );
  }
}

class _OverlaySizeSlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Bubble Size", style: theme.textTheme.bodyMedium),
              Text(
                "${settings.bubbleSize.toInt()}px",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: settings.bubbleSize.clamp(20.0, 80.0),
          min: 20.0,
          max: 80.0,
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade300,
          onChanged: (val) {
            ref
                .read(overlaySettingsProvider.notifier)
                .updateSettings(bubbleSize: val);
          },
        ),
      ],
    );
  }
}

class _OverlayOpacitySlider extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Opacity", style: theme.textTheme.bodyMedium),
              Text(
                "${(settings.opacity * 100).toInt()}%",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: settings.opacity.clamp(0.2, 1.0),
          min: 0.2,
          max: 1.0,
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade300,
          onChanged: (val) {
            ref
                .read(overlaySettingsProvider.notifier)
                .updateSettings(opacity: val);
          },
        ),
      ],
    );
  }
}

class _DoubleTapActionSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final theme = Theme.of(context);

    // Filter valid values to avoid assertion errors if settings file has bad data
    final validValues = ["QUICK_PANEL", "CANVAS", "NONE"];
    final currentValue = validValues.contains(settings.doubleTapAction)
        ? settings.doubleTapAction
        : "QUICK_PANEL";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text("Double Tap Action", style: theme.textTheme.bodyMedium),
      trailing: DropdownButton<String>(
        value: currentValue,
        dropdownColor: theme.cardColor,
        underline: Container(),
        icon: Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
        style: theme.textTheme.bodyMedium,
        items: const [
          DropdownMenuItem(value: "QUICK_PANEL", child: Text("Quick Panel")),
          DropdownMenuItem(value: "CANVAS", child: Text("Open Canvas")),
          DropdownMenuItem(value: "NONE", child: Text("None")),
        ],
        onChanged: (val) {
          if (val != null) {
            ref
                .read(overlaySettingsProvider.notifier)
                .updateSettings(doubleTapAction: val);
          }
        },
      ),
    );
  }
}

class _LongPressActionSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(overlaySettingsProvider);
    final theme = Theme.of(context);

    final validValues = ["OPEN_APP", "QUICK_PANEL", "NONE"];
    final currentValue = validValues.contains(settings.longPressAction)
        ? settings.longPressAction
        : "OPEN_APP";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Text("Long Press Action", style: theme.textTheme.bodyMedium),
      trailing: DropdownButton<String>(
        value: currentValue,
        dropdownColor: theme.cardColor,
        underline: Container(),
        icon: Icon(Icons.arrow_drop_down, color: theme.iconTheme.color),
        style: theme.textTheme.bodyMedium,
        items: const [
          DropdownMenuItem(value: "OPEN_APP", child: Text("Open App")),
          DropdownMenuItem(
            value: "QUICK_PANEL",
            child: Text("Open Quick Panel"),
          ),
          DropdownMenuItem(value: "NONE", child: Text("None")),
        ],
        onChanged: (val) {
          if (val != null) {
            ref
                .read(overlaySettingsProvider.notifier)
                .updateSettings(longPressAction: val);
          }
        },
      ),
    );
  }
}

class _StrictnessSlider extends StatefulWidget {
  @override
  State<_StrictnessSlider> createState() => _StrictnessSliderState();
}

class _StrictnessSliderState extends State<_StrictnessSlider> {
  int _currentValue = 1;

  @override
  void initState() {
    super.initState();
    _currentValue = OverlayService.strictness;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label = "Medium";
    String description = "Balanced (Default)";
    Color color = theme.colorScheme.primary;

    switch (_currentValue) {
      case 0:
        label = "Low";
        description = "Forgiving (Fuzzy Text)";
        color = Colors.green;
        break;
      case 2:
        label = "High";
        description = "Exact Match Only";
        color = Colors.redAccent;
        break;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Matching Strictness",
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Slider(
          value: _currentValue.toDouble(),
          min: 0,
          max: 2,
          divisions: 2,
          activeColor: color,
          inactiveColor: theme.brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade300,
          onChanged: (val) {
            setState(() {
              _currentValue = val.toInt();
            });
            OverlayService.setStrictness(_currentValue);
          },
        ),
      ],
    );
  }
}

class _CustomPermissionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Future<bool> Function() checkStatus;
  final VoidCallback onTap;

  const _CustomPermissionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.checkStatus,
    required this.onTap,
  });

  @override
  State<_CustomPermissionTile> createState() => _CustomPermissionTileState();
}

class _CustomPermissionTileState extends State<_CustomPermissionTile>
    with WidgetsBindingObserver {
  bool? isGranted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _check();
    }
  }

  Future<void> _check() async {
    final status = await widget.checkStatus();
    if (mounted) {
      setState(() {
        isGranted = status;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(widget.icon, color: theme.iconTheme.color),
      ),
      title: Text(
        widget.title,
        style: TextStyle(
          color: theme.textTheme.bodyLarge?.color,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        widget.subtitle,
        style: TextStyle(
          color: theme.textTheme.bodyMedium?.color,
          fontSize: 12,
        ),
      ),
      trailing: isGranted == null
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : isGranted!
              ? Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00FF41), // Matrix Green
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.black),
                )
              : OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: widget.onTap,
                  child: const Text("ALLOW"),
                ),
    );
  }
}
// ... (Existing code)

class _RecognitionDelaySlider extends StatefulWidget {
  @override
  State<_RecognitionDelaySlider> createState() =>
      _RecognitionDelaySliderState();
}

class _RecognitionDelaySliderState extends State<_RecognitionDelaySlider> {
  double _currentValue = 600;

  @override
  void initState() {
    super.initState();
    _loadDelay();
  }

  Future<void> _loadDelay() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentValue = (prefs.getInt('recognition_delay') ?? 600).toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Recognition Delay", style: theme.textTheme.bodyMedium),
              Text(
                "${_currentValue.toInt()} ms",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: _currentValue,
          min: 300,
          max: 2000,
          divisions: 17, // (2000-300)/100 = 17 steps (approx 100ms each)
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade300,
          onChanged: (val) {
            setState(() => _currentValue = val);
          },
          onChangeEnd: (val) {
            OverlayService.setRecognitionDelay(val.toInt());
          },
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            "Higher delay = Better text accuracy",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _ActionDelaySlider extends StatefulWidget {
  @override
  State<_ActionDelaySlider> createState() => _ActionDelaySliderState();
}

class _ActionDelaySliderState extends State<_ActionDelaySlider> {
  double _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _loadDelay();
  }

  Future<void> _loadDelay() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _currentValue = ((prefs.getInt('action_delay') ?? 0) / 1000).clamp(
          0.0,
          5.0,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Action Delay", style: theme.textTheme.bodyMedium),
              Text(
                _currentValue == 0 ? "Immediate" : "${_currentValue.toInt()}s",
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: _currentValue,
          min: 0,
          max: 5,
          divisions: 5, // 0, 1, 2, 3, 4, 5
          activeColor: theme.colorScheme.primary,
          inactiveColor: theme.brightness == Brightness.dark
              ? Colors.white10
              : Colors.grey.shade300,
          onChanged: (val) {
            setState(() => _currentValue = val);
          },
          onChangeEnd: (val) {
            // Convert seconds to ms for service
            OverlayService.setActionDelay((val * 1000).toInt());
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _currentValue > 3
                ? "Shows Preview Popup (>3s)"
                : _currentValue > 0
                    ? "Silent Delay (1-3s)"
                    : "Executes immediately",
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ),
      ],
    );
  }
}
