<?php
// Test what the API actually returns
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\Gesture;

$gesture = Gesture::first();
if ($gesture) {
    echo "Name: " . $gesture->name . "\n";
    echo "Points type: " . gettype($gesture->points_json) . "\n";
    echo "Points count: " . (is_array($gesture->points_json) ? count($gesture->points_json) : 'N/A') . "\n";
    
    if (is_array($gesture->points_json) && count($gesture->points_json) > 0) {
        echo "First point: " . json_encode($gesture->points_json[0]) . "\n";
    }
    
    echo "\n=== JSON Serialization ===\n";
    echo substr($gesture->toJson(), 0, 200) . "...\n";
} else {
    echo "No gestures found\n";
}
