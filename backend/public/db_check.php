<?php
// Load Laravel App
require __DIR__ . '/../vendor/autoload.php';
$app = require_once __DIR__ . '/../bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Http\Kernel::class);
$response = $kernel->handle(
    $request = Illuminate\Http\Request::capture()
);

// Dump Plans
use App\Models\SubscriptionPlan;
header('Content-Type: application/json');
try {
    $plans = SubscriptionPlan::all();
    echo json_encode([
        'count' => $plans->count(),
        'plans' => $plans->toArray()
    ], JSON_PRETTY_PRINT);
} catch (\Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
