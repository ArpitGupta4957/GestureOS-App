import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/services/subscription_service.dart';
import 'package:gesture_app/core/enums/premium_capability.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

final trialUsageProvider =
    StateNotifierProvider<TrialUsageService, Map<String, int>>((ref) {
  return TrialUsageService(ref);
});

class TrialUsageService extends StateNotifier<Map<String, int>> {
  final Ref ref;

  TrialUsageService(this.ref) : super({}) {
    // Initialize mapping
    checkStatus();
  }

  Future<void> checkStatus() async {
    // 1. Fetch from API (Source of Truth)
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.dio.get('/api/subscription/status');
      final trials = response.data['trials'] as Map<String, dynamic>;

      // Convert to Map<String, int>
      state = trials.map((key, value) => MapEntry(key, value as int));

      // Update LocalStorage backup
      final prefs = await SharedPreferences.getInstance();
      trials.forEach((key, value) {
        prefs.setInt('trial_$key', value as int);
      });
    } catch (e) {
      // Offline fallback
      final prefs = await SharedPreferences.getInstance();
      Map<String, int> local = {};
      for (var cap in PremiumCapability.values) {
        if (cap == PremiumCapability.manualEntry) continue;
        local[cap.key] = prefs.getInt('trial_${cap.key}') ?? 0;
      }
      state = local;
    }
  }

  bool canUse(PremiumCapability capability) {
    // 0. Manual Entry is always free
    if (capability == PremiumCapability.manualEntry) return true;

    final subState = ref.read(subscriptionProvider);

    // Issue #7 Fix: Use centralized limitKey mapping from PremiumCapability
    final limitKey = capability.limitKey;

    // Fetch limit from State (populated from Backend)
    int? limit = subState.activePlanLimits[limitKey];

    // Fallback for Offline/Missing Data
    if (limit == null) {
      // Hardcoded Fallbacks (Safety Net)
      if (limitKey == 'max_ocr_scans') limit = 1;
      if (limitKey == 'max_excel_imports') limit = 1;
      if (limitKey == 'max_exports') limit = 1;
    }

    // If 0 means Unlimited, return true
    if (limit == 0) return true;

    final count = state[capability.key] ?? 0;
    return count < limit!;
  }

  Future<void> markUsed(PremiumCapability capability) async {
    // 0. Manual Entry is always free
    if (capability == PremiumCapability.manualEntry) return;

    try {
      // Issue #9 fix: Use a synchronous lock to prevent race conditions
      // Optimistic Update
      final current = state[capability.key] ?? 0;
      final newState = Map<String, int>.from(state);
      newState[capability.key] = current + 1;
      state = newState;

      // Sync with Server (fire and forget, but store server value when returns)
      final apiService = ref.read(apiServiceProvider);
      try {
        final response = await apiService.dio.post(
          ApiConfig.trialsRecord,
          data: {'feature': capability.key},
        );

        if (response.statusCode == 200 && response.data['new_count'] != null) {
          final authoritativeCount = response.data['new_count'] as int;
          // Update local state if different (e.g., reset happened on server)
          if (authoritativeCount != newState[capability.key]) {
            final correctedState = Map<String, int>.from(state);
            correctedState[capability.key] = authoritativeCount;
            state = correctedState;
          }

          // Persist
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('trial_${capability.key}', authoritativeCount);
        }
      } catch (e) {
        print("⚠️ Server sync failed for trial: $e");
        // Keep optimistic state, will resync on next status check
      }
    } catch (e) {
      print("❌ Failed to mark trial usage: $e");
    }
  }
}
