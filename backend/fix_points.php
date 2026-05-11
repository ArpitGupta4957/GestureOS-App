<?php
// Fix double-encoded JSON in points_json
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use Illuminate\Support\Facades\DB;

echo "=== Fixing points_json data ===\n\n";

$gestures = DB::table('gestures')->get();

foreach ($gestures as $gesture) {
    $raw = $gesture->points_json;
    
    if ($raw === null) {
        echo "ID {$gesture->id}: NULL - skipping\n";
        continue;
    }
    
    // Check if it's already a proper JSON array (starts with [)
    if (str_starts_with(trim($raw), '[')) {
        // Try to decode to verify it's valid JSON
        $decoded = json_decode($raw, true);
        if (is_array($decoded) && count($decoded) > 0) {
            echo "ID {$gesture->id} ({$gesture->name}): Already valid JSON with " . count($decoded) . " points\n";
            continue;
        }
    }
    
    // Try decoding as escaped string (e.g., "\"[{\\\"x\\\":...")
    $decoded = json_decode($raw, true);
    if (is_string($decoded)) {
        // It was a JSON-encoded string, decode again
        $decoded = json_decode($decoded, true);
    }
    
    if (is_array($decoded) && count($decoded) > 0) {
        // Re-save as proper JSON
        $fixed = json_encode($decoded);
        DB::table('gestures')
            ->where('id', $gesture->id)
            ->update(['points_json' => $fixed]);
        echo "ID {$gesture->id} ({$gesture->name}): FIXED - " . count($decoded) . " points\n";
    } else {
        echo "ID {$gesture->id} ({$gesture->name}): CANNOT FIX - data structure issue\n";
    }
}

echo "\n=== Done ===\n";
