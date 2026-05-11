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
        Schema::table('bulk_numbers', function (Blueprint $table) {
            // Change to TEXT to accommodate encrypted data
            $table->text('phone_number')->change();
            $table->text('name')->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('bulk_numbers', function (Blueprint $table) {
            $table->string('phone_number')->change();
            $table->string('name')->nullable()->change();
        });
    }
};
