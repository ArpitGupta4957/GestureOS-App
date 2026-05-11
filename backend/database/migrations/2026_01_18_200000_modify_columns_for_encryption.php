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
        // 1. Bulk Numbers: Widen columns for encryption
        Schema::table('bulk_numbers', function (Blueprint $table) {
            $table->text('phone_number')->change();
            $table->text('name')->nullable()->change();
        });

        // 2. Gestures: Widen action_value
        Schema::table('gestures', function (Blueprint $table) {
            $table->text('action_value')->change();
        });

        // 3. Users: Widen name
        Schema::table('users', function (Blueprint $table) {
            $table->text('name')->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Revert to original types (approximate)
        Schema::table('bulk_numbers', function (Blueprint $table) {
            $table->string('phone_number')->change();
            $table->string('name')->nullable()->change();
        });

        Schema::table('gestures', function (Blueprint $table) {
            $table->string('action_value')->change();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->string('name')->change();
        });
    }
};
