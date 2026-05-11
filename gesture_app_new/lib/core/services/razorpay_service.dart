import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gesture_app/core/providers/auth_provider.dart';
import 'package:gesture_app/core/services/subscription_service.dart';
import 'package:gesture_app/core/models/subscription_plan.dart';
import 'package:gesture_app/core/services/native_razorpay.dart';

final razorpayServiceProvider = Provider((ref) => RazorpayService(ref));

class RazorpayService {
  final Ref _ref;

  RazorpayService(this._ref);

  Future<void> purchasePlan(BuildContext context, SubscriptionPlan plan) async {
    print("🚀 purchasePlan called for ${plan.name}");
    try {
      // Show Loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing Request...'),
          duration: Duration(seconds: 1),
        ),
      );

      // Step 1: Create Order on Backend
      final apiService = _ref.read(apiServiceProvider);
      final response = await apiService.dio.post(
        '/api/subscription/create',
        data: {'plan_id': plan.id},
      );

      final orderId = response.data['order_id'];
      final keyId = response.data['key_id'];
      final amount = response.data['amount'];
      final currency = response.data['currency'];
      final prefill = response.data['prefill'];

      // Step 2: Prepare Options
      var options = {
        'key': keyId,
        'amount': amount,
        'currency': currency,
        'order_id': orderId,
        'name': 'Gesture App',
        'description': 'Upgrade to ${plan.name}',
        'prefill': {'contact': prefill['contact'], 'email': prefill['email']},
        'external': {
          'wallets': ['paytm'],
        },
      };

      // Step 3: Open Native Razorpay SDK
      // print("Opening Razorpay Native SDK...");
      final result = await NativeRazorpay.open(options);

      // Step 4: Handle Result
      if (result['status'] == 'success') {
        // print("Payment Success! Verifying...");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment Successful! Verifying...')),
        );
        await _verifyPayment(context, result, plan.id);
      } else {
        // print("Payment Failed: ${result['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Failed: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print("Error in Payment Flow: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _verifyPayment(
    BuildContext context,
    Map<String, dynamic> result,
    int planId,
  ) async {
    try {
      final apiService = _ref.read(apiServiceProvider);
      await apiService.dio.post(
        '/api/razorpay/verify',
        data: {
          'plan_id': planId,
          'razorpay_payment_id': result['paymentId'],
          'razorpay_order_id': result['orderId'],
          'razorpay_signature': result['signature'],
        },
      );

      // Sync Subscription Status
      await _ref.read(subscriptionProvider.notifier).checkStatus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subscription Activated!'),
          backgroundColor: Colors.green,
        ),
      );
      // print("Subscription Activated & Synced!");
    } catch (e) {
      // print("Verification Failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
