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
        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->text('value')->nullable();
            $table->string('description')->nullable();
            $table->timestamps();
        });

        // Seed default settings
        DB::table('settings')->insert([
            [
                'key' => 'global_sensitivity_threshold',
                'value' => '0.85',
                'description' => 'Minimum similarity score required for gesture recognition (0.0 - 1.0)',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'key' => 'enable_new_registrations',
                'value' => '1',
                'description' => 'Allow new users to sign up via API',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'key' => 'system_maintenance_mode',
                'value' => '0',
                'description' => 'Put the API into maintenance mode (reject all non-admin requests)',
                'created_at' => now(),
                'updated_at' => now(),
            ]
        ]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('settings');
    }
};
