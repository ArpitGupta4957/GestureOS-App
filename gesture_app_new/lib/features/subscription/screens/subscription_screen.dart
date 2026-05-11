import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/services/subscription_service.dart';
import 'package:gesture_app/core/models/subscription_plan.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:gesture_app/core/services/iap_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final theme = Theme.of(context);
    final isPremium = subscriptionState.isPremium;

    final filteredPlans = subscriptionState.availablePlans.where((plan) {
      final nameLower = plan.name.toLowerCase();
      if (nameLower.contains('free')) return true; // Show free trial on both
      if (Platform.isIOS) {
        return nameLower.contains('ios');
      } else {
        return nameLower.contains('android');
      }
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Premium Plans"), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () => ref.read(subscriptionProvider.notifier).checkStatus(),
        color: const Color(0xFF00FF41),
        backgroundColor: const Color(0xFF1E1E1E),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // 1. Current Plan Status
              _buildStatusCard(theme, isPremium, subscriptionState),
              const SizedBox(height: 24),

              // Info banner about website payment
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF41).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00FF41).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.open_in_browser,
                        color: Color(0xFF00FF41),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Subscriptions are managed on our website. You'll be redirected to complete your payment securely.",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Plans Header
              const Text(
                "Choose Your Plan",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              if (subscriptionState.errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subscriptionState.errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ref.read(subscriptionProvider.notifier).fetchPlans();
                        },
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              else if (filteredPlans.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                ...filteredPlans.map((plan) {
                  final isCurrentPlan = subscriptionState.planName == plan.name;
                  return Column(
                    children: [
                      _buildPlanCard(
                        context,
                        ref,
                        title: plan.name,
                        price: plan.price <= 0
                            ? "Free / ${plan.durationDays} Days"
                            : "₹${plan.price.toInt()} / ${plan.durationDays} Days",
                        features: plan.features,
                        isCurrent: isCurrentPlan,
                        plan: plan,
                        isRecommended: plan.name.contains("Pro"),
                        onTap: isPremium
                            ? null
                            : () {
                                _openSubscribePage(context, ref, plan);
                              },
                        theme: theme,
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                }),

              const SizedBox(height: 16),

              // Refresh status button
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(subscriptionProvider.notifier).checkStatus();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Checking subscription status...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Refresh Status"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00FF41),
                  side: const BorderSide(color: Color(0xFF00FF41)),
                ),
              ),

              if (Platform.isIOS) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    try {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Restoring purchases...')),
                      );
                      await ref.read(iapServiceProvider).restorePurchases();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to restore: $e')),
                      );
                    }
                  },
                  child: const Text(
                    "Restore Purchases",
                    style: TextStyle(
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    ThemeData theme,
    bool isPremium,
    SubscriptionState state,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPremium
              ? [
                  const Color(0xFF00FF41).withValues(alpha: 0.2),
                  const Color(0xFF00B02D).withOpacity(0.1),
                ]
              : [Colors.grey.shade900, Colors.grey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPremium ? const Color(0xFF00FF41) : Colors.white10,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPremium ? Icons.verified : Icons.lock_outline,
                color: isPremium ? const Color(0xFF00FF41) : Colors.grey,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                isPremium ? "PREMIUM ACTIVE" : "FREE PLAN",
                style: TextStyle(
                  color: isPremium ? const Color(0xFF00FF41) : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          if (isPremium && state.expiryDate != null) ...[
            const SizedBox(height: 8),
            Text(
              "Valid until ${state.expiryDate.toString().split(' ')[0]}",
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String price,
    required List<String> features,
    required bool isCurrent,
    SubscriptionPlan? plan,
    bool isRecommended = false,
    VoidCallback? onTap,
    required ThemeData theme,
  }) {
    final borderColor = isCurrent
        ? theme.colorScheme.primary
        : isRecommended
            ? const Color(0xFF00FF41)
            : Colors.white10;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: isCurrent || isRecommended ? 2 : 1,
            ),
            boxShadow: isRecommended
                ? [
                    BoxShadow(
                      color: const Color(0xFF00FF41).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          price,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (isCurrent)
                      const Chip(
                        label: Text("Current"),
                        backgroundColor: Colors.white10,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ...features.map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF00FF41),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                plan != null
                                    ? _formatFeature(f, plan)
                                    : _formatFeature(
                                        f,
                                        SubscriptionPlan(
                                            id: 0,
                                            name: '',
                                            price: 0,
                                            currency: '',
                                            durationDays: 0,
                                            features: [],
                                            gatewayPlanId: '',
                                            planType: '',
                                            limits: {})),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (title.contains('Trial') && plan != null) ...[
                      const SizedBox(height: 8),
                      _buildLimitInfo("${plan.durationDays} Days Validity"),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00FF41),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onPressed: onTap,
                    icon: const Icon(Icons.open_in_browser, size: 20),
                    label: Text(
                      title.toLowerCase().contains('free') ||
                              title.toLowerCase().contains('trial')
                          ? "START FREE TRIAL"
                          : (Platform.isIOS
                              ? "Subscribe"
                              : "Subscribe on Website"),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (isRecommended && !isCurrent)
          Positioned(
            top: -12,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF41),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                "RECOMMENDED",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLimitInfo(String text) {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: Colors.orange, size: 16),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.orange, fontSize: 12)),
      ],
    );
  }

  String _formatFeature(String key, SubscriptionPlan plan) {
    if (key.contains('validity')) {
      final days = key.split('_').last;
      return '$days Days Validity';
    }

    if (key == 'limit_300' ||
        key == 'calls_limit' ||
        key.startsWith('limit_') ||
        key.startsWith('daily_')) {
      final maxCalls = plan.limits['max_calls'] ??
          plan.limits['max_ocr_scans'] ??
          plan.limits['max_call'];
      if (maxCalls != null &&
          maxCalls.toString() != '0' &&
          maxCalls.toString() != '-1') {
        return 'Daily Limit: $maxCalls Calls';
      } else if (maxCalls != null &&
          (maxCalls.toString() == '0' || maxCalls.toString() == '-1')) {
        return 'Unlimited Calls';
      }
    }

    switch (key.toLowerCase()) {
      case 'ocr':
      case 'ocr_import':
        return 'Smart Scanning (OCR)';
      case 'bulk_import':
      case 'excel_import':
        return 'Excel Bulk Import';
      case 'auto_dialer':
        return 'Auto Dialer';
      case 'whatsapp_sender':
        return 'WhatsApp Integration';
      case 'all_unlimited':
        return 'Unlimited Calls & Imports';
      default:
        return key.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _openSubscribePage(
    BuildContext context,
    WidgetRef ref,
    SubscriptionPlan plan,
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

    // Free plans: activate directly via API
    if (plan.price <= 0) {
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Activating free plan...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        final apiService = ref.read(apiServiceProvider);
        final response = await apiService.dio.post(
          ApiConfig.subscriptionActivateFree,
          data: {'plan_id': plan.id},
          // Note: ApiService interceptor automatically adds the Bearer Token
        );

        if (response.statusCode == 200) {
          // Issue #15 fix: Refresh subscription status after free plan activation
          await ref.read(subscriptionProvider.notifier).checkStatus();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Free plan activated! 🎉'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          final msg = response.data?['message'] ?? 'Failed to activate';
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        String errorMsg = 'Failed to activate free plan';
        if (e is DioException) {
          if (e.response?.statusCode == 401) {
            errorMsg = 'Session expired. Please log out and log back in.';
            // Optionally, we could trigger ref.read(authProvider.notifier).logout() here
          } else if (e.response?.data != null) {
            errorMsg = e.response?.data['message'] ?? errorMsg;
          }
        } else {
          errorMsg = e.toString();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
          );
        }
      }
      return;
    }

    // Paid plans: handle platform routing
    if (Platform.isIOS) {
      // ------------------------------------------------------------- //
      // APPLE APP STORE COMPLIANCE: USE NATIVE IN-APP PURCHASES  //
      // ------------------------------------------------------------- //
      try {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connecting to App Store...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        // Map the plan names from your Admin Panel directly to Apple Product IDs
        // Normalize plan name: lowercase + remove separators for flexible matching (Issue #5 fix)
        String normalizedPlanName =
            plan.name.toLowerCase().replaceAll('_', '').replaceAll('-', '');

        String appleProductId = '';

        // Match against normalized names (handles Basic_iOS, basic_ios, basic-ios, basic, etc.)
        if (normalizedPlanName.contains('basic')) {
          appleProductId = 'com.gesture.basic130';
        } else if (normalizedPlanName.contains('standard')) {
          appleProductId = 'com.gesture.standard299';
        } else if (normalizedPlanName.contains('premium')) {
          appleProductId = 'com.gesture.premium649';
        } else if (normalizedPlanName.contains('ultimate')) {
          appleProductId = 'com.gesture.ultimate1299';
        } else {
          // Fallback to gatewayPlanId or throw
          if (plan.gatewayPlanId.isNotEmpty) {
            appleProductId = plan.gatewayPlanId;
          } else {
            throw Exception('Unknown iOS plan: ${plan.name}');
          }
        }

        // Important: import iap_service Provider at top of your file to use this:
        await ref.read(iapServiceProvider).buyPlan(appleProductId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App Store IAP requested for: $appleProductId'),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('App Store Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    // Android/Web: Fallback to existing Razorpay web implementation
    final url = '${ApiConfig.baseUrl}/subscribe/${plan.id}?token=$token';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open browser. Please try again.'),
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
}
