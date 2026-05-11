import 'package:flutter/material.dart';

class ActionGridSelector extends StatelessWidget {
  final Function(String actionType, String? actionValue) onActionSelected;

  const ActionGridSelector({super.key, required this.onActionSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.85,
      children: [
        _buildActionCard(
          context,
          icon: Icons.apps,
          label: 'Launch App',
          onTap: () => onActionSelected('launch_app', null),
        ),
        _buildActionCard(
          context,
          icon: Icons.call,
          label: 'Make a Call',
          onTap: () => onActionSelected('call', null),
        ),
        _buildActionCard(
          context,
          icon: Icons.web,
          label: 'Open Website',
          onTap: () => onActionSelected('open_url', null),
        ),
        _buildActionCard(
          context,
          icon: Icons.wifi,
          label: 'WiFi Setting',
          onTap: () => onActionSelected('settings', 'android.settings.WIFI_SETTINGS'),
        ),
        _buildActionCard(
          context,
          icon: Icons.bluetooth,
          label: 'Bluetooth',
          onTap: () => onActionSelected('settings', 'android.settings.BLUETOOTH_SETTINGS'),
        ),
        _buildActionCard(
          context,
          icon: Icons.flashlight_on,
          label: 'Flashlight',
          onTap: () => onActionSelected('flashlight', null), // Placeholder
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
