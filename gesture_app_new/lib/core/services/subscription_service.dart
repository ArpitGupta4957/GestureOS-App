import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/models/subscription_plan.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:dio/dio.dart';

final subscriptionProvider =
    StateNotifierProvider<SubscriptionService, SubscriptionState>((ref) {
  return SubscriptionService(ref);
});

class SubscriptionState {
  final bool isPremium;
  final String? planName; // 'Pro', 'Business'
  final DateTime? expiryDate;
  final bool isLoading;
  final List<SubscriptionPlan> availablePlans;
  final String? errorMessage;
  final Map<String, dynamic> activePlanLimits;

  SubscriptionState({
    this.isPremium = false,
    this.planName,
    this.expiryDate,
    this.isLoading = true,
    this.availablePlans = const [],
    this.errorMessage,
    this.activePlanLimits = const {},
  });

  SubscriptionState copyWith({
    bool? isPremium,
    String? planName,
    DateTime? expiryDate,
    bool? isLoading,
    List<SubscriptionPlan>? availablePlans,
    String? errorMessage,
    Map<String, dynamic>? activePlanLimits,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      planName: planName ?? this.planName,
      expiryDate: expiryDate ?? this.expiryDate,
      isLoading: isLoading ?? this.isLoading,
      availablePlans: availablePlans ?? this.availablePlans,
      errorMessage: errorMessage ?? this.errorMessage,
      activePlanLimits: activePlanLimits ?? this.activePlanLimits,
    );
  }
}

class SubscriptionService extends StateNotifier<SubscriptionState> {
  final Ref ref;

  SubscriptionService(this.ref) : super(SubscriptionState()) {
    checkStatus();
    fetchPlans(); // Call on init
  }

  Future<void> fetchPlans() async {
    print("🔵 fetchPlans() called");
    try {
      final apiService = ref.read(apiServiceProvider);
      print("🔵 Making request to ${ApiConfig.subscriptionPlans}");
      final response = await apiService.dio.get(ApiConfig.subscriptionPlans);
      print("🔵 Response received: ${response.data}");
      print("🔵 Response type: ${response.data.runtimeType}");

      // Handle different response formats
      List data;
      if (response.data is List) {
        data = response.data as List;
      } else if (response.data is Map && response.data['data'] is List) {
        data = response.data['data'] as List;
      } else if (response.data is Map && response.data['plans'] is List) {
        data = response.data['plans'] as List;
      } else {
        print("❌ Unexpected response format: ${response.data.runtimeType}");
        state = state.copyWith(
          errorMessage: "Unexpected response format from server",
        );
        return;
      }

      print("🔵 Parsed as list with ${data.length} items");

      final plans = data
          .map((x) => SubscriptionPlan.fromJson(x as Map<String, dynamic>))
          .toList();
      print("🔵 Converted to ${plans.length} SubscriptionPlan objects");

      state = state.copyWith(availablePlans: plans, errorMessage: null);
      print(
        "🔵 State updated with plans: ${plans.map((p) => p.name).toList()}",
      );
    } on DioException catch (e) {
      print("❌ DioException fetching plans: $e");
      String errorMsg = "Failed to load plans";
      if (e.response?.statusCode != null) {
        errorMsg += " (${e.response!.statusCode})";
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMsg = "Connection timeout - please check your internet";
      } else if (e.type == DioExceptionType.connectionError) {
        errorMsg = "Unable to connect to server";
      }
      state = state.copyWith(errorMessage: errorMsg);
    } catch (e, stackTrace) {
      print("❌ Failed to fetch plans: $e");
      print("❌ Stack trace: $stackTrace");
      state = state.copyWith(
        errorMessage: "Failed to load plans: ${e.toString().split('\n').first}",
      );
    }
  }

  Future<void> checkStatus() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.dio.get(ApiConfig.subscriptionStatus);
      final data = response.data;

      final isPremium = data['is_premium'] ?? false;
      final plan = data['plan'];
      final subscription = data['subscription'];

      Map<String, dynamic> limits = {};
      if (plan != null && plan['limits'] != null) {
        limits = Map<String, dynamic>.from(plan['limits']);
      }

      state = state.copyWith(
        isPremium: isPremium,
        planName: plan?['name'],
        expiryDate: subscription?['expires_at'] != null
            ? DateTime.tryParse(subscription['expires_at'])
            : null,
        isLoading: false,
        activePlanLimits: limits,
      );

      // Update Trial Counts (Future Step: Link to TrialUsageService)
    } catch (e) {
      print(" Subscription Check Failed: $e");
      state = state.copyWith(isLoading: false); // Fallback to free?
    }
  }

  // Placeholder for Purchase Flow
  Future<void> purchasePlan(String planId) async {
    // Integrate Razorpay Here later
  }
}
