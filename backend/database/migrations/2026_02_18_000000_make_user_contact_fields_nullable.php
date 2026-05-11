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
        Schema::table('users', function (Blueprint $table) {
            $table->string('email')->nullable()->change();
            $table->string('mobile_number')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Reverting is tricky because we might have nulls now.
            // But structurally, we attempt to make them required again (if data allows).
            // In practice, down migrations for this might fail if null data exists.
            $table->string('email')->nullable(false)->change();
            $table->string('mobile_number')->nullable(false)->change();
        });
    }
};
