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
        Schema::create('bulk_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->boolean('is_archived')->default(false);
            $table->timestamps();
        });

        Schema::create('bulk_numbers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('session_id')->constrained('bulk_sessions')->onDelete('cascade');
            $table->string('phone_number');
            $table->string('name')->nullable();
            $table->text('notes')->nullable();
            $table->string('status')->default('pending'); // pending, called, skipped
            $table->timestamp('last_called_at')->nullable();
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('bulk_numbers');
        Schema::dropIfExists('bulk_sessions');
    }
};
