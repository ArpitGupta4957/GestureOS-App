import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/services/subscription_service.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:url_launcher/url_launcher.dart';

final paywallProvider = Provider((ref) => PaywallService(ref));

class PaywallService {
  final Ref ref;

  PaywallService(this.ref);

  void showUpgradeSheet(BuildContext context, String featureName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _PaywallContent(featureName: featureName),
    );
  }

  void showTrialLimitDialog(BuildContext context, String featureName) {
    final isPremium = ref.read(subscriptionProvider).isPremium;

    final title = isPremium ? "Daily Limit Reached" : "Trial Limit Reached";
    final message = isPremium
        ? "You have reached your daily limit for $featureName.\nPlease wait until tomorrow or upgrade your plan."
        : "You have used your free $featureName for today.\nUpgrade to Premium for unlimited access.";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Colors.grey)),
          ),
          if (!isPremium)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF41),
              ),
              onPressed: () {
                Navigator.pop(context);
                showUpgradeSheet(context, featureName);
              },
              child: const Text(
                "Upgrade",
                style: TextStyle(color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }
}

class _PaywallContent extends ConsumerWidget {
  final String featureName;
  const _PaywallContent({required this.featureName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.star, color: Color(0xFF00FF41), size: 48),
          const SizedBox(height: 16),
          Text(
            "Unlock $featureName",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            "Get unlimited access to OCR, Excel Import, and Reports.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00FF41).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00FF41).withOpacity(0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.open_in_browser, color: Color(0xFF00FF41), size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You'll be redirected to our website to complete payment securely.",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildPlanCard(context, ref, "Pro", "₹199 / month", 1, [
            "Unlimited Features",
            "Priority Support",
          ]),
          const SizedBox(height: 16),
          _buildPlanCard(context, ref, "Business", "₹499 / month", 2, [
            "All Features + Team",
            "API Access",
          ]),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _openSubscribePage(
    BuildContext context,
    WidgetRef ref,
    int planId,
  ) async {
    final authState = ref.read(authProvider);
    final token = authState.token;

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to subscribe.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final url = '${ApiConfig.baseUrl}/subscribe/$planId?token=$token';
    Navigator.pop(context); // Close the bottom sheet first

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open browser.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildPlanCard(
    BuildContext context,
    WidgetRef ref,
    String title,
    String price,
    int planId,
    List<String> features,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  price,
                  style: const TextStyle(
                    color: Color(0xFF00FF41),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            onPressed: () => _openSubscribePage(context, ref, planId),
            icon: const Icon(
              Icons.open_in_browser,
              size: 16,
              color: Colors.black,
            ),
            label: const Text(
              "Subscribe",
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
