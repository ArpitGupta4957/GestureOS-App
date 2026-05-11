<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

echo "--- GESTURES DUMP ---\n";
try {
    $gestures = App\Models\Gesture::all();
    if ($gestures->isEmpty()) {
        echo "No gestures found.\n";
    } else {
        foreach ($gestures as $g) {
            echo "ID: {$g->id} | Name: {$g->name} | Fav: " . ($g->is_favorite ? 'TRUE' : 'FALSE') . " (" . var_export($g->is_favorite, true) . ")\n";
        }
    }
} catch (\Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
echo "--- END DUMP ---\n";
