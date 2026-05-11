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
        if (!Schema::hasColumn('gestures', 'uuid')) {
            Schema::table('gestures', function (Blueprint $table) {
                $table->string('uuid')->nullable()->after('user_id');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('gestures', function (Blueprint $table) {
            $table->dropColumn('uuid');
        });
    }
};
