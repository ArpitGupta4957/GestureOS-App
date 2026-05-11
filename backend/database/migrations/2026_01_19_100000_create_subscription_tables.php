<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // 1. Subscription Plans (The Products)
        Schema::create('subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('name'); // e.g., "Pro", "Business"
            $table->decimal('price', 10, 2);
            $table->string('currency')->default('INR');
            $table->integer('duration_days')->default(30);
            $table->json('features')->nullable(); // List of unlocked features
            $table->string('gateway_plan_id')->nullable(); // Razorpay Plan ID
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        // 2. Subscriptions (The User's Purchase)
        Schema::create('subscriptions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->foreignId('plan_id')->constrained('subscription_plans');
            $table->string('status')->default('pending'); // active, expired, cancelled, pending
            $table->timestamp('starts_at')->nullable();
            $table->timestamp('expires_at')->nullable();
            $table->string('gateway_subscription_id')->nullable(); // Razorpay Subscription ID
            $table->string('gateway_payment_id')->nullable(); // Latest Payment ID
            $table->timestamps();
        });

        // 3. Trial Usages (The Free Tier Enforcement)
        Schema::create('trial_usages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->onDelete('cascade');
            $table->string('feature_key'); // e.g., "image_ocr", "excel_import"
            $table->integer('usage_count')->default(0);
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
            
            // Unique constraint: User can only have one counter per feature
            $table->unique(['user_id', 'feature_key']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('trial_usages');
        Schema::dropIfExists('subscriptions');
        Schema::dropIfExists('subscription_plans');
    }
};
