<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\SubscriptionPlan;

class PlanSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Pro Plan
        SubscriptionPlan::updateOrCreate(
            ['name' => 'Pro'],
            [
                'price' => 199.00,
                'currency' => 'INR',
                'duration_days' => 30,
                'features' => ['ocr_import', 'excel_import', 'export_report', 'limit_300'],
                'gateway_plan_id' => 'plan_PsvX8g6X8g6X8', // Mock ID, to be replaced
                'is_active' => true,
            ]
        );

        // Business Plan
        SubscriptionPlan::updateOrCreate(
            ['name' => 'Business'],
            [
                'price' => 499.00,
                'currency' => 'INR',
                'duration_days' => 30,
                'features' => ['all_unlimited', 'priority_support'],
                'gateway_plan_id' => 'plan_BizX9h7X9h7X9', 
                'is_active' => true,
            ]
        );
    }
}
