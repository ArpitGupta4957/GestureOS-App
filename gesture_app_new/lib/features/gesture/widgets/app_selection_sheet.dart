import 'package:flutter/material.dart';
import 'package:gesture_app/core/services/installed_apps_service.dart';

class AppSelectionSheet extends StatefulWidget {
  const AppSelectionSheet({super.key});

  @override
  State<AppSelectionSheet> createState() => _AppSelectionSheetState();
}

class _AppSelectionSheetState extends State<AppSelectionSheet> {
  List<Map<String, dynamic>> _allApps = [];
  List<Map<String, dynamic>> _filteredApps = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  Future<void> _loadApps() async {
    // Fetch REAL installed apps from device
    final apps = await InstalledAppsService.getApps();
    
    // Map to simple structure used by UI
    final List<Map<String, dynamic>> realApps = apps.map((a) => {
      'name': a.name,
      'package': a.packageName,
      'icon': a.icon, // REAL ICON FETCHED
    }).toList();

    // Mock data removed as per strict requirements.
    // If realApps is empty, the list will be empty.

    
    if (mounted) {
      setState(() {
        _allApps = realApps;
        _filteredApps = realApps;
        _isLoading = false;
      });
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredApps = _allApps.where((app) {
        return (app['name'] as String).toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
             boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: 'Search apps...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        controller: controller,
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final hasIcon = app['icon'] != null;
                          final color = _getAppColor(app['name']);

                          return ListTile(
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: hasIcon ? Colors.transparent : color.withOpacity(0.2),
                                shape: BoxShape.circle,
                                border: hasIcon ? null : Border.all(color: color.withOpacity(0.5), width: 1),
                              ),
                              child: hasIcon 
                                ? ClipOval(child: Image.memory(app['icon'], fit: BoxFit.cover))
                                : Icon(_getAppIcon(app['name']), color: color, size: 24),
                            ),
                            title: Text(
                              app['name'],
                              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              app['package'],
                              style: theme.textTheme.bodySmall,
                            ),
                            onTap: () {
                              Navigator.pop(context, {
                                'package_name': app['package'],
                                'app_name': app['name'],
                              });
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getAppColor(String name) {
    switch (name.toLowerCase()) {
      case 'netflix': return Colors.red;
      case 'spotify': return Colors.green;
      case 'whatsapp': return Colors.greenAccent;
      case 'instagram': return Colors.purpleAccent;
      case 'discord': return const Color(0xFF5865F2);
      case 'snapchat': return Colors.yellow;
      case 'amazon': return Colors.orange;
      case 'youtube': return Colors.red;
      case 'chrome': return Colors.blue;
      case 'gmail': return Colors.redAccent;
      case 'facebook': return Colors.blueAccent;
      case 'twitter': return Colors.lightBlue;
      case 'maps': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getAppIcon(String name) {
    switch (name.toLowerCase()) {
      case 'netflix': return Icons.movie;
      case 'spotify': return Icons.music_note;
      case 'whatsapp': return Icons.chat;
      case 'instagram': return Icons.camera_alt;
      case 'discord': return Icons.headset;
      case 'snapchat': return Icons.perm_media;
      case 'amazon': return Icons.shopping_cart;
      case 'youtube': return Icons.play_arrow;
      case 'chrome': return Icons.web;
      case 'gmail': return Icons.email;
      case 'maps': return Icons.map;
      case 'settings': return Icons.settings;
      case 'camera': return Icons.camera;
      case 'gallery': return Icons.photo;
      default: return Icons.android;
    }
  }
}
