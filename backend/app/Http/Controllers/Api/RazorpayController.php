<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\Subscription;
use App\Models\SubscriptionPlan;
use Illuminate\Support\Facades\Log;
use Razorpay\Api\Api;

class RazorpayController extends Controller
{
    private $api;

    public function __construct()
    {
        // Ideally from config
        $key = env('RAZORPAY_KEY');
        $secret = env('RAZORPAY_SECRET');
        if($key && $secret) {
            $this->api = new Api($key, $secret);
        }
    }

    /**
     * Create Order
     */
    public function createOrder(Request $request)
    {
        $request->validate([
            'plan_id' => 'required|exists:subscription_plans,id',
        ]);

        $plan = SubscriptionPlan::findOrFail($request->plan_id);
        
        // Amount in Paise (INR * 100)
        $amount = (int) ($plan->price * 100);

        try {
            if (!$this->api) {
                 throw new \Exception("Razorpay Keys Invalid or Missing in .env");
            }
            $orderData = [
                'amount'          => $amount,
                'currency'        => 'INR',
                // 'receipt'         => 'rcpt_' . uniqid(),
                // 'notes'           => [
                //     'plan_id' => (string) $plan->id,
                //     'user_id' => (string) $request->user()->id
                // ]
            ];
            
            Log::info("Razorpay Minimized Payload: " . json_encode($orderData));

            $order = $this->api->order->create($orderData);

            return response()->json([
                'order_id' => $order['id'],
                'amount' => $amount,
                'currency' => 'INR',
                'key_id' => env('RAZORPAY_KEY'), // Send public key to client
                'prefill' => [
                    'name' => $request->user()->name,
                    'email' => $request->user()->email,
                    'contact' => $request->user()->phone ?? '',
                ]
            ]);

        } catch (\Exception $e) {
            Log::error("Razorpay Order Creation Failed (" . get_class($e) . "): " . $e->getMessage());
            if (method_exists($e, 'getData')) {
                Log::error("Razorpay Error Data: " . json_encode($e->getData()));
            }
            return response()->json(['error' => 'Could not create order'], 500);
        }
    }

    /**
     * Verify Payment and Activate Subscription
     */
    public function verify(Request $request) 
    {
        $request->validate([
            'plan_id' => 'required|exists:subscription_plans,id',
            'razorpay_payment_id' => 'required',
            'razorpay_order_id' => 'nullable', // or subscription_id
            'razorpay_signature' => 'required'
        ]);

        $user = $request->user();

        try {
            // Verify Signature using Razorpay SDK
            $attributes = [
                'razorpay_payment_id' => $request->razorpay_payment_id,
                'razorpay_signature'  => $request->razorpay_signature
            ];
            
            // If subscription flow (recurring)
            if ($request->razorpay_subscription_id) {
                $attributes['razorpay_subscription_id'] = $request->razorpay_subscription_id;
            } else {
                $attributes['razorpay_order_id'] = $request->razorpay_order_id;
            }

            $this->api->utility->verifyPaymentSignature($attributes);

            // Activate Subscription in DB
            $plan = SubscriptionPlan::find($request->plan_id);
            
            // Cancel existing active subscriptions gracefully
            Subscription::where('user_id', $user->id)
                ->where('status', 'active')
                ->update(['status' => 'cancelled']);
            
            Subscription::create([
                'user_id' => $user->id,
                'plan_id' => $plan->id,
                'status' => 'active',
                'starts_at' => now(),
                'expires_at' => now()->addDays($plan->duration_days),
                'gateway_payment_id' => $request->razorpay_payment_id,
                'gateway_subscription_id' => $request->razorpay_subscription_id
            ]);

            return response()->json(['status' => 'success', 'message' => 'Subscription Activated']);

        } catch (\Exception $e) {
            Log::error("Razorpay Verification Failed: " . $e->getMessage());
            return response()->json(['status' => 'error', 'message' => 'Payment Verification Failed'], 400);
        }
    }
}
