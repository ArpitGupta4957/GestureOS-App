<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/privacy', function () {
    return view('privacy');
});

Route::get('/delete-account', function () {
    return view('delete-account');
});

// Web Subscription Payment Page (redirected from the app)
Route::get('/subscribe/{plan_id}', function ($plan_id, \Illuminate\Http\Request $request) {
    $token = $request->query('token');
    if (!$token) {
        abort(403, 'Invalid access. Please open this page from the Gesture App.');
    }

    // Authenticate user via Sanctum token
    $accessToken = \Laravel\Sanctum\PersonalAccessToken::findToken($token);
    if (!$accessToken) {
        abort(403, 'Session expired. Please try again from the app.');
    }

    $user = $accessToken->tokenable;
    $plan = \App\Models\SubscriptionPlan::where('id', $plan_id)->where('is_active', true)->first();

    if (!$plan) {
        abort(404, 'Plan not found.');
    }

    return view('subscribe', [
        'plan' => $plan,
        'user' => $user,
        'token' => $token,
        'razorpayKey' => env('RAZORPAY_KEY'),
    ]);
});

// Admin Auth Routes
Route::get('/admin/login', [App\Http\Controllers\Admin\AuthController::class, 'showLoginForm'])->name('admin.login');
Route::post('/admin/login', [App\Http\Controllers\Admin\AuthController::class, 'login'])->name('admin.login.submit');
Route::post('/admin/logout', [App\Http\Controllers\Admin\AuthController::class, 'logout'])->name('admin.logout');

// Protected Admin Routes
Route::middleware([\App\Http\Middleware\IsAdmin::class])->group(function () {
    Route::get('/admin/dashboard', [App\Http\Controllers\Admin\DashboardController::class, 'index'])->name('admin.dashboard');
    
    // User Management
    Route::get('/admin/users', [App\Http\Controllers\Admin\UserController::class, 'index'])->name('admin.users.index');
    Route::get('/admin/users/create', [App\Http\Controllers\Admin\UserController::class, 'create'])->name('admin.users.create');
    Route::post('/admin/users', [App\Http\Controllers\Admin\UserController::class, 'store'])->name('admin.users.store');
    Route::post('/admin/users/{id}/toggle', [App\Http\Controllers\Admin\UserController::class, 'toggleStatus'])->name('admin.users.toggle');
    
    // Account Deletion Requests
    Route::get('/admin/users/deletion-requests', [App\Http\Controllers\Admin\UserController::class, 'deletionRequests'])->name('admin.users.deletion_requests');
    Route::post('/admin/users/{id}/cancel-deletion', [App\Http\Controllers\Admin\UserController::class, 'cancelDeletionRequest'])->name('admin.users.deletion_requests.cancel');
    Route::delete('/admin/users/{id}', [App\Http\Controllers\Admin\UserController::class, 'destroy'])->name('admin.users.destroy');
    
    // Gesture Management
    Route::get('/admin/gestures', [App\Http\Controllers\Admin\GestureController::class, 'index'])->name('admin.gestures.index');
    
    // Global Settings
    Route::get('/admin/settings', [App\Http\Controllers\Admin\SettingsController::class, 'index'])->name('admin.settings.index');
    Route::post('/admin/settings', [App\Http\Controllers\Admin\SettingsController::class, 'update'])->name('admin.settings.update');

    // Plan Management
    Route::resource('/admin/plans', App\Http\Controllers\Admin\PlanController::class)->names('admin.plans');
});
