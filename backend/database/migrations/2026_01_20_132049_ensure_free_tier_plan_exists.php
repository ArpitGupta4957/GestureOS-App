<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;
use App\Models\SubscriptionPlan;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Check if a free plan already exists
        $exists = DB::table('subscription_plans')->where('plan_type', 'FREE')->exists();

        if (!$exists) {
            DB::table('subscription_plans')->insert([
                'name' => 'Free Trial',
                'plan_type' => 'FREE',
                'price' => 0,
                'currency' => 'INR',
                'duration_days' => 36500, // 100 years (effectively lifetime)
                'gateway_plan_id' => 'plan_free_default',
                'features' => json_encode(['Basic Access']),
                'limits' => json_encode([
                    'max_ocr_scans' => 1,
                    'max_excel_imports' => 1,
                    'allow_export' => false,
                    'history_retention_hours' => 24
                ]),
                'is_active' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // We don't necessarily want to delete it on rollback to preserve data integrity if modified
    }
};
