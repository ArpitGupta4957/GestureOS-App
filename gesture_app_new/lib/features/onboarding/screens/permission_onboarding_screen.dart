import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gesture_app/core/utils/permission_manager.dart';
import 'package:gesture_app/core/widgets/guided_permission_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final bool _isRequesting = false;

  // permission checklist state
  bool _showPermissionList = false;
  bool _loadingStatuses = false;
  final Map<AppPermission, bool> _statuses = {};

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      title: 'WELCOME TO\nGESTURE CONTROL',
      description:
          'Control your device with custom gestures.\nDraw once, execute anywhere.',
      icon: Icons.touch_app_rounded,
      color: const Color(0xFF00FF41),
    ),
    _OnboardingPage(
      title: 'SYSTEM PERMISSIONS\nREQUIRED',
      description:
          'We need a few permissions to make the magic happen.\nDon\'t worry, we explain everything.',
      icon: Icons.security_rounded,
      color: const Color(0xFF00FF41),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Show permission checklist first
      setState(() => _showPermissionList = true);
      _loadPermissionStatuses();
    }
  }

  Future<void> _loadPermissionStatuses() async {
    setState(() => _loadingStatuses = true);
    final statuses = <AppPermission, bool>{};
    for (final p in AppPermission.values) {
      statuses[p] = await PermissionManager.hasPermission(p);
    }
    if (mounted) {
      setState(() {
        _statuses.clear();
        _statuses.addAll(statuses);
        _loadingStatuses = false;
      });
    }
  }

  Future<void> _requestPermission(AppPermission permission) async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => GuidedPermissionDialog(permission: permission),
    );

    // After dialog, refresh status
    final granted = await PermissionManager.hasPermission(permission);
    if (mounted) setState(() => _statuses[permission] = granted);
  }

  Future<void> _requestAll() async {
    setState(() => _loadingStatuses = true);
    for (final p in AppPermission.values) {
      final already = _statuses[p] ?? false;
      if (!already) {
        await _requestPermission(p);
      }
    }
    if (mounted) setState(() => _loadingStatuses = false);
  }

  Future<void> _skipPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_permissions', true);
    await prefs.setBool('permissions_skipped', true);
    if (mounted) context.go('/dashboard');
  }

  Future<void> _finishPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_permissions', true);
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, theme.colorScheme.surface],
          ),
        ),
        child: SafeArea(
          child: _showPermissionList
              ? Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Permissions',
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _loadingStatuses
                          ? const Center(child: CircularProgressIndicator())
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: AppPermission.values.length,
                              itemBuilder: (context, index) {
                                final permission = AppPermission.values[index];
                                final granted = _statuses[permission] ?? false;
                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      PermissionManager.getPermissionIcon(
                                          permission),
                                      color: granted
                                          ? Colors.green
                                          : theme.colorScheme.primary,
                                    ),
                                    title: Text(
                                      PermissionManager.getPermissionName(
                                          permission),
                                    ),
                                    subtitle: Text(
                                      PermissionManager
                                          .getPermissionDescription(permission),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: granted
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : TextButton(
                                            onPressed: () =>
                                                _requestPermission(permission),
                                            child: const Text('Grant'),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loadingStatuses ? null : _requestAll,
                              child: const Text('Request All'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed:
                                  _loadingStatuses ? null : _skipPermissions,
                              child: const Text('Skip'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _loadingStatuses ? null : _finishPermissions,
                              child: const Text('Done'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    // Page Indicator
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // PageView
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          return _OnboardingPageWidget(page: page);
                        },
                      ),
                    ),

                    // Continue Button
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isRequesting ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            elevation: 8,
                            shadowColor:
                                theme.colorScheme.primary.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'GET STARTED'
                                : 'CONTINUE',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageWidget({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.color.withOpacity(0.1),
              boxShadow: [
                BoxShadow(
                  color: page.color.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(page.icon, size: 100, color: page.color),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: page.color,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Description
          Text(
            page.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white70,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
