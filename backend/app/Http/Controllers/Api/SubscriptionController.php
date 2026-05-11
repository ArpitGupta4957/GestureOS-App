<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Models\SubscriptionPlan;
use App\Models\Subscription;
use App\Models\TrialUsage;
use Illuminate\Support\Facades\DB;

class SubscriptionController extends Controller
{
    /**
     * Get current status: Plan + Trial Usages
     */
    public function status(Request $request)
    {
        $user = $request->user();
        $subscription = $user->subscription;
        
        // Is Premium?
        $isPremium = $subscription && $subscription->isValid();
        
        $activePlan = null;
        if ($isPremium) {
            $activePlan = $subscription->plan;
        } else {
            // Fetch Free Plan for limits display
            $activePlan = SubscriptionPlan::where('plan_type', 'FREE')->first();
        }
        
        // Trials (Still needed? If using limits, we compare usage vs limit)
        $trials = $user->trialUsages()->pluck('usage_count', 'feature_key');

        return response()->json([
            'is_premium' => $isPremium,
            'plan' => $activePlan, // Contains limits
            'subscription' => $isPremium ? [
                'status' => $subscription->status,
                'expires_at' => $subscription->expires_at,
            ] : null,
            'trials' => [
                'image_ocr' => $trials['image_ocr'] ?? 0,
                'excel_import' => $trials['excel_import'] ?? 0,
                'export_report' => $trials['export_report'] ?? 0,
            ]
        ]);
    }

    /**
     * Check if a specific feature is allowed
     */
    /**
     * Check if a specific feature is allowed
     */
    public function checkFeature(Request $request)
    {
        $request->validate(['feature' => 'required|string']);
        $feature = $request->feature;
        $user = $request->user();

        // 1. Check Subscription (Premium)
        if ($user->subscription && $user->subscription->isValid()) {
            $plan = $user->subscription->plan;
            $limits = $plan->limits ?? [];
            
            // Map feature keys to limit keys
            $limitKeyMap = [
                'image_ocr' => 'max_ocr_scans',
                'excel_import' => 'max_excel_imports',
                // 'export_report' -> handled boolean elsewhere usually, but count could work too
            ];

            $limitKey = $limitKeyMap[$feature] ?? null;
            
            // If no limit defined, assume Unlimited
            if (!$limitKey || !isset($limits[$limitKey]) || $limits[$limitKey] == 0) {
                 return response()->json(['allowed' => true, 'source' => 'subscription_unlimited']);
            }

            $maxDaily = (int) $limits[$limitKey];
            
            // Check Daily Usage
            $usage = $user->trialUsages()->where('feature_key', $feature)->first();
            
            // Calculate current usage (Reset if new day)
            $currentCount = 0;
            if ($usage) {
                $lastUsed = \Carbon\Carbon::parse($usage->last_used_at);
                if ($lastUsed->isToday()) {
                    $currentCount = $usage->usage_count;
                }
            }

            if ($currentCount < $maxDaily) {
                return response()->json(['allowed' => true, 'source' => 'subscription_quota', 'remaining' => $maxDaily - $currentCount]);
            } else {
                return response()->json(['allowed' => false, 'error' => 'Daily limit reached', 'limit' => $maxDaily]);
            }
        }

        // 2. Check Trial (Free)
        // Fetch Dynamic Config from "Free Trial" plan (plan_type = FREE)
        $freePlan = SubscriptionPlan::where('plan_type', 'FREE')->first();
        
        $freeLimits = [];
        if ($freePlan && $freePlan->limits) {
             // Map DB limit keys to internal feature keys if necessary, 
             // but we should store them consistently.
             // DB: max_ocr_scans, max_excel_imports
             // Code: image_ocr, excel_import
             
             // Mapping:
             $limitMap = [
                 'max_ocr_scans' => 'image_ocr',
                 'max_excel_imports' => 'excel_import',
                 // 'allow_export' handled via boolean check usually, but trial logic focuses on Counts.
             ];
             
             // Invert Mapping to find Limit Value for requested feature
             // Feature: image_ocr -> Need max_ocr_scans
             $keyMap = [
                 'image_ocr' => 'max_ocr_scans',
                 'excel_import' => 'max_excel_imports',
             ];
             
             $dbKey = $keyMap[$feature] ?? null;
             if ($dbKey && isset($freePlan->limits[$dbKey])) {
                 $freeLimits[$feature] = (int) $freePlan->limits[$dbKey];
             }
        }
        
        // Fallback defaults if DB plan missing or empty
        if (empty($freeLimits[$feature])) {
            $defaults = [
                'image_ocr' => 1,
                'excel_import' => 1,
            ];
            $freeLimits[$feature] = $defaults[$feature] ?? 0;
        }

        // if (!array_key_exists($feature, $freeLimits)) ... Logic above handles extraction or default.


        $usage = $user->trialUsages()->where('feature_key', $feature)->first();
        $count = $usage ? $usage->usage_count : 0;

        if ($count < $freeLimits[$feature]) {
            return response()->json(['allowed' => true, 'source' => 'trial', 'remaining' => $freeLimits[$feature] - $count]);
        }

        return response()->json(['allowed' => false, 'source' => 'none', 'error' => 'Trial limit reached']);
    }

    /**
     * Record usage
     */
    public function recordTrial(Request $request)
    {
        $request->validate(['feature' => 'required|string']);
        $feature = $request->feature;
        $user = $request->user();

        // Find or Create Record
        $usage = $user->trialUsages()->firstOrCreate(
            ['feature_key' => $feature],
            ['usage_count' => 0]
        );

        // Logic:
        // If Premium -> Check if Day Changed -> Reset Count -> Increment
        // If Free -> Just Increment (Lifetime)
        
        $isPremium = $user->subscription && $user->subscription->isValid();

        if ($isPremium) {
            $lastUsed = $usage->last_used_at ? \Carbon\Carbon::parse($usage->last_used_at) : null;
            if (!$lastUsed || !$lastUsed->isToday()) {
                $usage->usage_count = 0; // Reset for new day
            }
        }
        
        $usage->increment('usage_count');
        $usage->update(['last_used_at' => now()]);

        return response()->json(['status' => 'success', 'new_count' => $usage->usage_count]);
    }

    /**
     * List Plans
     */
    public function plans()
    {
        return response()->json(SubscriptionPlan::where('is_active', true)->get());
    }

    /**
     * Activate a free/trial plan without payment
     */
    public function activateFree(Request $request)
    {
        $request->validate([
            'plan_id' => 'required|exists:subscription_plans,id',
        ]);

        try {
            $user = $request->user();
            $plan = SubscriptionPlan::findOrFail($request->plan_id);

            // Only allow free plans (price = 0)
            if ($plan->price > 0) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'This plan requires payment. Please subscribe on our website.',
                ], 400);
            }

            // Check if user already has an active subscription
            if ($user->subscription && $user->subscription->isValid()) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'You already have an active subscription.',
                ], 400);
            }

            // Default to 7 days if duration_days is null; cap to avoid MySQL TIMESTAMP overflow (max 2038)
            $durationDays = min($plan->duration_days ?? 7, 3650);

            // Activate the free plan
            Subscription::create([
                'user_id' => $user->id,
                'plan_id' => $plan->id,
                'status' => 'active',
                'starts_at' => now(),
                'expires_at' => now()->addDays($durationDays),
                'gateway_payment_id' => 'free_activation',
            ]);

            return response()->json([
                'status' => 'success',
                'message' => 'Free plan activated successfully!',
            ]);

        } catch (\Exception $e) {
            \Illuminate\Support\Facades\Log::error('activateFree error: ' . $e->getMessage());
            return response()->json([
                'status' => 'error',
                'message' => 'Failed to activate plan: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Verify Apple In-App Purchase Receipt
     */
    public function verifyAppleReceipt(Request $request)
    {
        $request->validate([
            'receipt' => 'required|string',
            'product_id' => 'required|string',
        ]);

        $user = $request->user();
        $receipt = $request->input('receipt');
        $productId = $request->input('product_id');

        // Apple endpoint URLs
        $sandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
        $productionUrl = 'https://buy.itunes.apple.com/verifyReceipt';

        $appleSecret = env('APPLE_IAP_SHARED_SECRET', ''); // Anurag must add this to .env

        $payload = json_encode([
            'receipt-data' => $receipt,
            'password' => $appleSecret,
        ]);

        // Trying Production first is recommended by Apple
        $ch = curl_init($productionUrl);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
        $response = curl_exec($ch);
        curl_close($ch);

        $decoded = json_decode($response, true);

        // Status 21007 means this receipt is from the sandbox environment
        if (isset($decoded['status']) && $decoded['status'] == 21007) {
            $ch = curl_init($sandboxUrl);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_POST, true);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
            $response = curl_exec($ch);
            curl_close($ch);
            $decoded = json_decode($response, true);
        }

        if (isset($decoded['status']) && $decoded['status'] === 0) {
            // Receipt Validated successfully!
            // Issue #8 Fix: Dynamic plan matching from product ID
            // Extract plan type from product ID (com.gesture.basic130 -> basic)
            $planType = str_replace('com.gesture.', '', $productId);
            $planType = preg_replace('/\d+$/', '', $planType); // Remove trailing numbers (130, 299, etc.)
            
            if (empty($planType)) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Invalid product ID format: ' . $productId,
                ], 400);
            }

            // Find plan by flexible name matching (case-insensitive, supports various naming)
            // Searches for plans containing the plan type (e.g., finds "Basic_iOS" from "basic")
            $plan = SubscriptionPlan::where('plan_type', '!=', 'FREE')
                ->get()
                ->first(function($p) use ($planType) {
                    $planNameLower = strtolower($p->name);
                    $planTypeLower = strtolower($planType);
                    // Match if plan name contains the plan type
                    // e.g., "Basic_iOS" contains "basic", "Basic", "BASIC", etc.
                    return stripos($planNameLower, $planTypeLower) !== false;
                });

            if ($plan) {
                $durationDays = $plan->duration_days ?? 30;

                Subscription::updateOrCreate(
                    ['user_id' => $user->id],
                    [
                        'plan_id' => $plan->id,
                        'gateway_subscription_id' => 'Apple_IAP_' . time(),
                        'status' => 'active',
                        'starts_at' => now(),
                        'expires_at' => now()->addDays($durationDays)
                    ]
                );

                return response()->json([
                    'status' => 'success',
                    'message' => 'Apple subscription verified and activated successfully'
                ]);
            }

            return response()->json([
                'status' => 'error',
                'message' => 'Plan not found for product type: ' . $planType . ' (product_id: ' . $productId . ')',
                'debug_info' => [
                    'extracted_plan_type' => $planType,
                    'available_plans' => SubscriptionPlan::where('plan_type', '!=', 'FREE')->pluck('name')->toArray(),
                ]
            ], 400);
        }

        return response()->json([
            'status' => 'error',
            'message' => 'Invalid Apple Receipt',
            'apple_status' => $decoded['status'] ?? 'unknown',
        ], 400);
    }
}
