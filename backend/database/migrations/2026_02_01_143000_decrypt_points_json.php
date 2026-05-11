<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Crypt;

return new class extends Migration
{
    /**
     * Decrypt all existing points_json data.
     * This is needed because we're removing encryption from this field.
     */
    public function up(): void
    {
        $gestures = DB::table('gestures')->get();
        
        foreach ($gestures as $gesture) {
            try {
                // Try to decrypt if it's encrypted
                $decrypted = Crypt::decryptString($gesture->points_json);
                
                // Update with decrypted value
                DB::table('gestures')
                    ->where('id', $gesture->id)
                    ->update(['points_json' => $decrypted]);
                    
                echo "Decrypted gesture {$gesture->id}: {$gesture->name}\n";
            } catch (\Exception $e) {
                // Already unencrypted or invalid, leave as-is
                echo "Skipped gesture {$gesture->id} (already plain or invalid)\n";
            }
        }
    }

    /**
     * Re-encrypt (not recommended, data loss possible)
     */
    public function down(): void
    {
        // Cannot reliably reverse this
    }
};
