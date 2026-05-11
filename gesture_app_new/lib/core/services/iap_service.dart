import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/api/api_config.dart';
import 'package:gesture_app/core/services/subscription_service.dart';

final iapServiceProvider = Provider<IAPService>((ref) {
  return IAPService(ref);
});

class IAPService {
  final Ref ref;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  IAPService(this.ref) {
    _initialize();
  }

  void _initialize() {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('IAP Error: $error');
      },
    );
  }

  void dispose() {
    _subscription.cancel();
  }

  /// Purchase a subscription plan
  /// Note: The 'productId' must match exactly with what is set up in App Store Connect.
  Future<void> buyPlan(String productId) async {
    final bool isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      debugPrint('IAP not available. Store might be unreachable.');
      throw Exception(
        'Store is currently unreachable. Please try again later.',
      );
    }

    // 1. Fetch Product Details
    final ProductDetailsResponse response = await _iap.queryProductDetails({
      productId,
    });

    if (response.notFoundIDs.isNotEmpty || response.productDetails.isEmpty) {
      debugPrint('Product $productId not found in App Store Connect.');
      throw Exception(
        'Subscription plan is currently unavailable on the App Store.',
      );
    }

    final productDetails = response.productDetails.first;

    // 2. Initiate Purchase
    final purchaseParam = PurchaseParam(productDetails: productDetails);

    // Using buyNonConsumable since standard subscriptions are handled this way or buyConsumable depending on exact type.
    // For auto-renewable subscriptions, buyNonConsumable is typically used in the API call.
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// Restores previous purchases
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  /// Handle updates from the purchase stream
  Future<void> _onPurchaseUpdate(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        debugPrint('⏳ Purchase is pending for: ${purchaseDetails.productID}');
        // Show pending UI to user
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        debugPrint('❌ Purchase failed: ${purchaseDetails.error}');
        // Issue #13 fix: Handle error state properly
        if (purchaseDetails.error != null) {
          debugPrint('Error details: ${purchaseDetails.error!.message}');
        }
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // Issue #13 fix: Handle user cancellation
        debugPrint(
            '⚠️ Purchase cancelled by user for: ${purchaseDetails.productID}');
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        debugPrint('✅ Purchase completed: ${purchaseDetails.productID}');
        // 1. Handle complete purchase (Verify receipt with backend)
        await _verifyPurchaseWithBackend(purchaseDetails);
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }
  }

  /// Send the receipt to Laravel backend for validation
  Future<void> _verifyPurchaseWithBackend(
    PurchaseDetails purchaseDetails,
  ) async {
    final token = ref.read(authProvider).token;
    if (token == null) return;

    try {
      final apiService = ref.read(apiServiceProvider);

      final receiptData =
          purchaseDetails.verificationData.serverVerificationData;

      // Call Laravel backend to verify the Apple receipt
      final response = await apiService.dio.post(
        ApiConfig.appleIapVerify,
        data: {'receipt': receiptData, 'product_id': purchaseDetails.productID},
      );

      if (response.statusCode == 200) {
        debugPrint('🎉 Apple IAP Verified successfully!');
        // Issue #15 fix: Refresh subscription status after purchase
        debugPrint('🔄 Refreshing subscription status...');
        await ref.read(subscriptionProvider.notifier).checkStatus();
        debugPrint('✅ Subscription status refreshed after IAP purchase');
      }
    } catch (e) {
      debugPrint('❌ Error verifying purchase on backend: $e');
    }
  }
}
