<?php

declare(strict_types=1);

use App\Http\Controllers\ApiController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider and all of them will
| be assigned to the "api" middleware group. Make something great!
|
*/

// Public routes (no authentication required)
Route::post('/register', [ApiController::class, 'register']);
Route::post('/login', [ApiController::class, 'login']);
Route::post('/auth/send-otp', [ApiController::class, 'sendOtp']);
Route::post('/auth/verify-otp', [ApiController::class, 'verifyOtp']);
Route::post('/auth/reset-password', [ApiController::class, 'resetPassword']);

// Public subscription plans (viewable before signup)
Route::get('/subscription/plans', [\App\Http\Controllers\Api\SubscriptionController::class, 'plans']);

// Public account deletion request (for Play Store Data Safety)
Route::post('/account/request-deletion', [ApiController::class, 'publicRequestDeletion']);

// Protected routes (authentication required)
Route::middleware('auth:sanctum')->group(function () {
    // Bulk Dialer Routes
    Route::get('/bulk/sessions', [\App\Http\Controllers\Api\BulkDialerController::class, 'getSessions']);
    Route::post('/bulk/sessions', [\App\Http\Controllers\Api\BulkDialerController::class, 'createSession']);
    Route::get('/bulk/sessions/{id}/numbers', [\App\Http\Controllers\Api\BulkDialerController::class, 'getNumbers']);
    Route::post('/bulk/numbers', [\App\Http\Controllers\Api\BulkDialerController::class, 'addNumbers']);
    Route::put('/bulk/numbers/{id}', [\App\Http\Controllers\Api\BulkDialerController::class, 'updateNumber']);
    Route::delete('/bulk/sessions/{id}', [\App\Http\Controllers\Api\BulkDialerController::class, 'deleteSession']);

    Route::post('/gestures/sync', [ApiController::class, 'syncGestures']);
    Route::get('/gestures', [ApiController::class, 'getGestures']);
    Route::put('/gestures/{id}', [ApiController::class, 'updateGesture']);
    Route::delete('/gestures/{id}', [ApiController::class, 'deleteGesture']);

    // Subscription & Trials
    Route::get('/subscription/status', [\App\Http\Controllers\Api\SubscriptionController::class, 'status']);
    Route::post('/subscription/check-feature', [\App\Http\Controllers\Api\SubscriptionController::class, 'checkFeature']);
    Route::post('/trials/record', [\App\Http\Controllers\Api\SubscriptionController::class, 'recordTrial']);
    
    // Payment
    Route::post('/subscription/create', [\App\Http\Controllers\Api\RazorpayController::class, 'createOrder']);
    Route::post('/razorpay/verify', [\App\Http\Controllers\Api\RazorpayController::class, 'verify']);
    Route::post('/subscription/activate-free', [\App\Http\Controllers\Api\SubscriptionController::class, 'activateFree']);
    Route::post('/apple-iap/verify', [\App\Http\Controllers\Api\SubscriptionController::class, 'verifyAppleReceipt']);

    // Account Management
    Route::post('/user/change-password', [ApiController::class, 'changePassword']);
    Route::post('/user/set-pin', [ApiController::class, 'setPin']);
    Route::post('/user/delete-request', [ApiController::class, 'requestAccountDeletion']);
});
