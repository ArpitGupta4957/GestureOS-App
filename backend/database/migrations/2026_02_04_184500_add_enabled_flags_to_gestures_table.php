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
        Schema::table('gestures', function (Blueprint $table) {
            if (!Schema::hasColumn('gestures', 'is_text_enabled')) {
                $table->boolean('is_text_enabled')->default(true)->after('is_favorite');
            }
            if (!Schema::hasColumn('gestures', 'is_shape_enabled')) {
                $table->boolean('is_shape_enabled')->default(true)->after('is_text_enabled');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('gestures', function (Blueprint $table) {
            $table->dropColumn(['is_text_enabled', 'is_shape_enabled']);
        });
    }
};
