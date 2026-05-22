<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Gesture;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;
use Twilio\Rest\Client;
use Twilio\Http\CurlClient;
use Illuminate\Support\Facades\Mail;
use App\Mail\OtpMail;

class ApiController extends Controller
{
    /**
     * Register a new user and return API token.
     *
     * @param Request $request
     * @return JsonResponse
     * @throws ValidationException
     */
    public function register(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'nullable|string|email|max:255|unique:users',
            'mobile_number' => 'nullable|string|unique:users',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $validator->after(function ($validator) use ($request) {
            if (empty($request->email) && empty($request->mobile_number)) {
                $validator->errors()->add('identifier', 'Either Email or Mobile Number is required.');
            }
        });

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email, // Can be null
            'mobile_number' => $request->mobile_number, // Can be null
            'password' => Hash::make($request->password),
            'role' => 'user',
        ]);

        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'User registered successfully',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'mobile_number' => $user->mobile_number,
                    'role' => $user->role,
                ],
                'token' => $token,
            ],
        ], 201);
    }

    /**
     * Authenticate user and return API token.
     *
     * @param Request $request
     * @return JsonResponse
     * @throws ValidationException
     */
    public function login(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'identifier' => 'required',
            'password' => 'required_without:pin',
            'pin' => 'required_without:password',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $identifier = $request->identifier;
        $field = filter_var($identifier, FILTER_VALIDATE_EMAIL) ? 'email' : 'mobile_number';

        if ($field === 'mobile_number') {
            // Normalize mobile if needed (simple check)
            // Ideally should match registration normalization logic
            if (!str_starts_with($identifier, '+') && strlen($identifier) === 10) {
                // Check both raw and normalized
                 $user = User::where('mobile_number', $identifier)
                             ->orWhere('mobile_number', '+91' . $identifier)
                             ->first();
            } else {
                 $user = User::where('mobile_number', $identifier)->first();
            }
        } else {
            $user = User::where('email', $identifier)->first();
        }
        
        $isValid = false;
        if ($request->has('pin')) {
            $isValid = $user && $user->pin && Hash::check($request->pin, $user->pin);
        } else {
            $isValid = $user && Hash::check($request->password, $user->password);
        }

        if (!$isValid) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials',
            ], 401);
        }

        // Revoke all previous tokens
        $user->tokens()->delete();

        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'mobile_number' => $user->mobile_number,
                    'role' => $user->role,
                ],
                'token' => $token,
            ],
        ], 200);
    }

    /**
     * Sync gestures from mobile app.
     * Update existing ones or create new ones.
     *
     * @param Request $request
     * @return JsonResponse
     * @throws ValidationException
     */
    public function syncGestures(Request $request): JsonResponse
    {


        $validator = Validator::make($request->all(), [
            'gestures' => 'required|array',
            'gestures.*.id' => 'nullable|integer|exists:gestures,id',
            'gestures.*.uuid' => 'nullable|string|max:255',
            'gestures.*.name' => 'required|string|max:255',
            'gestures.*.trigger_text' => 'nullable|string|max:255',
            'gestures.*.points_json' => 'nullable|array',
            'gestures.*.action_type' => 'required|string|max:255',
            'gestures.*.action_value' => 'required|string|max:255',
            'gestures.*.is_synced' => 'required|boolean',
            'gestures.*.is_favorite' => 'nullable|boolean',
            'gestures.*.is_text_enabled' => 'nullable|boolean',
            'gestures.*.is_shape_enabled' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $user = $request->user();
        
        $lock = \Illuminate\Support\Facades\Cache::lock("sync_gestures_{$user->id}", 10);
        if (!$lock->get()) {
            return response()->json([
                'success' => false,
                'message' => 'Sync already in progress. Please try again.',
            ], 429);
        }

        try {
            $syncedGestures = [];
            $created = 0;
            $updated = 0;

        foreach ($request->gestures as $gestureData) {
            // Check for duplicate trigger_text within this user's scope
            if (!empty($gestureData['trigger_text'])) {
                $query = Gesture::where('user_id', $user->id)
                    ->where('trigger_text', $gestureData['trigger_text']);
                
                if (isset($gestureData['id'])) {
                    $query->where('id', '!=', $gestureData['id']);
                }

                $exists = $query->exists();

                if ($exists) {
                    return response()->json([
                        'success' => false,
                        'message' => "Use a unique shortcut. '" . $gestureData['trigger_text'] . "' is already taken.",
                    ], 409); // Conflict
                }
            }

            // Start UUID-aware Logic
            $gesture = null;

            // 1. Try finding by ID
            if (isset($gestureData['id'])) {
                $gesture = Gesture::where('id', $gestureData['id'])
                    ->where('user_id', $user->id)
                    ->first();
            }

            // 2. If not found, try finding by UUID (Prevent Duplicates from unsynced local creations)
            if (!$gesture && !empty($gestureData['uuid'])) {
                $gesture = Gesture::where('uuid', $gestureData['uuid'])
                    ->where('user_id', $user->id)
                    ->first();
            }

            if ($gesture) {
                // Update existing gesture
                $gesture->update([
                    'uuid' => $gestureData['uuid'] ?? $gesture->uuid, // Ensure UUID is set
                    'name' => $gestureData['name'],
                    'trigger_text' => $gestureData['trigger_text'] ?? null,
                    'points_json' => $gestureData['points_json'],
                    'action_type' => $gestureData['action_type'],
                    'action_value' => $gestureData['action_value'],
                    'is_synced' => (bool)$gestureData['is_synced'],
                    'is_favorite' => isset($gestureData['is_favorite']) ? filter_var($gestureData['is_favorite'], FILTER_VALIDATE_BOOLEAN) : false,
                    'is_text_enabled' => isset($gestureData['is_text_enabled']) ? filter_var($gestureData['is_text_enabled'], FILTER_VALIDATE_BOOLEAN) : true,
                    'is_shape_enabled' => isset($gestureData['is_shape_enabled']) ? filter_var($gestureData['is_shape_enabled'], FILTER_VALIDATE_BOOLEAN) : true,
                ]);
                $updated++;
                $syncedGestures[] = $gesture;
            } else {
                // Create new gesture
                $gesture = Gesture::create([
                    'user_id' => $user->id,
                    'uuid' => $gestureData['uuid'] ?? null, // Save the client UUID
                    'name' => $gestureData['name'],
                    'trigger_text' => $gestureData['trigger_text'] ?? null,
                    'points_json' => $gestureData['points_json'],
                    'action_type' => $gestureData['action_type'],
                    'action_value' => $gestureData['action_value'],
                    'is_synced' => (bool)$gestureData['is_synced'],
                    'is_favorite' => isset($gestureData['is_favorite']) ? filter_var($gestureData['is_favorite'], FILTER_VALIDATE_BOOLEAN) : false,
                    'is_text_enabled' => isset($gestureData['is_text_enabled']) ? filter_var($gestureData['is_text_enabled'], FILTER_VALIDATE_BOOLEAN) : true,
                    'is_shape_enabled' => isset($gestureData['is_shape_enabled']) ? filter_var($gestureData['is_shape_enabled'], FILTER_VALIDATE_BOOLEAN) : true,
                ]);
                $created++;
                $syncedGestures[] = $gesture;
            }
        }

            return response()->json([
                'success' => true,
                'message' => 'Gestures synced successfully',
                'data' => [
                    'synced_gestures' => $syncedGestures,
                    'stats' => [
                        'created' => $created,
                        'updated' => $updated,
                        'total' => count($syncedGestures),
                    ],
                ],
            ], 200);
        } finally {
            $lock->release();
        }
    }

    /**
     * Update a specific gesture.
     *
     * @param Request $request
     * @param int $id
     * @return JsonResponse
     */
    public function updateGesture(Request $request, int $id): JsonResponse
    {

        $user = $request->user();
        
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'trigger_text' => [
                'nullable',
                'string',
                'max:255',
                // Unique per user, ignore current ID
                \Illuminate\Validation\Rule::unique('gestures')->where(function ($query) use ($user) {
                    return $query->where('user_id', $user->id);
                })->ignore($id),
            ],
            'points_json' => 'nullable|array',
            'action_type' => 'required|string|max:255',
            'action_value' => 'required|string|max:255',
            'is_favorite' => 'nullable|boolean',
            'is_text_enabled' => 'nullable|boolean',
            'is_shape_enabled' => 'nullable|boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $gesture = Gesture::where('id', $id)
            ->where('user_id', $user->id)
            ->first();

        if (!$gesture) {
            return response()->json([
                'success' => false,
                'message' => 'Gesture not found or access denied',
            ], 404);
        }

        $gesture->update([
            'name' => $request->name,
            'trigger_text' => $request->trigger_text,
            'points_json' => $request->points_json,
            'action_type' => $request->action_type,
            'action_value' => $request->action_value,
            'is_synced' => true, 
            'is_favorite' => $request->has('is_favorite') ? $request->boolean('is_favorite') : $gesture->is_favorite,
            'is_text_enabled' => $request->has('is_text_enabled') ? $request->boolean('is_text_enabled') : $gesture->is_text_enabled,
            'is_shape_enabled' => $request->has('is_shape_enabled') ? $request->boolean('is_shape_enabled') : $gesture->is_shape_enabled,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Gesture updated successfully',
            'data' => [
                'gesture' => $gesture,
            ],
        ], 200);
    }

    /**
     * Get all gestures for authenticated user.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function getGestures(Request $request): JsonResponse
    {
        $user = $request->user();
        $gestures = Gesture::where('user_id', $user->id)
            ->orderBy('created_at', 'desc')
            ->limit(1000)
            ->get();

        return response()->json([
            'success' => true,
            'message' => 'Gestures retrieved successfully',
            'data' => [
                'gestures' => $gestures,
                'count' => $gestures->count(),
            ],
        ], 200);
    }

    /**
     * Request account deletion.
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function requestAccountDeletion(Request $request): JsonResponse
    {
        $user = $request->user();
        
        // Delete all user's gestures first
        Gesture::where('user_id', $user->id)->delete();
        
        // Delete all user's tokens
        $user->tokens()->delete();
        
        // Permanently delete the user account
        $user->delete();

        return response()->json([
            'success' => true,
            'message' => 'Account and all associated data have been permanently deleted.',
        ], 200);
    }

    /**
     * Delete a gesture (soft delete).
     *
     * @param Request $request
     * @param int $id
     * @return JsonResponse
     */
    public function deleteGesture(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        
        $gesture = Gesture::where('id', $id)
            ->where('user_id', $user->id)
            ->first();
        
        if (!$gesture) {
            return response()->json([
                'success' => false,
                'message' => 'Gesture not found',
            ], 404);
        }
        
        $gesture->delete(); // Soft deletes using SoftDeletes trait
        
        return response()->json([
            'success' => true,
            'message' => 'Gesture deleted successfully',
            'data' => ['id' => $id],
        ], 200);
    }

    /**
     * Send OTP to Email or Mobile.
     */
    public function sendOtp(Request $request): JsonResponse
    {
        $request->validate([
            'identifier' => 'required|string', // Email or Mobile
        ]);

        $identifier = $request->identifier;
        $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL);

        if ($isEmail) {
            // EMAIL FLOW
            $user = User::where('email', $identifier)->first();
            if (!$user) {
                return response()->json(['success' => false, 'message' => 'User not found.'], 404);
            }

            $otp = rand(100000, 999999);
            $user->otp_code = $otp;
            $user->otp_expires_at = now()->addMinutes(10);
            $user->save();

            try {
                // Ensure user has email configured (should be true if found by email)
                Mail::to($user->email)->send(new OtpMail($otp));
            } catch (\Exception $e) {
                return response()->json(['success' => false, 'message' => 'Failed to send email: ' . $e->getMessage()], 500);
            }

            return response()->json(['success' => true, 'message' => 'OTP sent to email.']);

        } else {
            // MOBILE FLOW (Twilio)
            $mobile = $identifier;
            $normalized = $mobile;
            if (!str_starts_with($mobile, '+') && strlen($mobile) === 10) {
                $normalized = '+91' . $mobile;
            }

            // Check if mobile exists in DB (Try both formats)
            $user = User::where('mobile_number', $mobile)->orWhere('mobile_number', $normalized)->first();

            if (!$user) {
                 return response()->json(['success' => false, 'message' => 'User not found.'], 404);
            }

            try {
                $sid = env('TWILIO_SID');
                $token = env('TWILIO_TOKEN');
                $verifySid = env('TWILIO_VERIFY_SID');

                if (!$sid || !$token || !$verifySid) {
                    return response()->json(['success' => false, 'message' => 'Twilio not configured.'], 500);
                }

                $httpClient = new CurlClient();
                $twilio = new Client($sid, $token, null, null, $httpClient);
                
                $twilio->verify->v2->services($verifySid)
                    ->verifications
                    ->create($normalized, "sms");

                return response()->json(['success' => true, 'message' => 'OTP sent to mobile.']);
            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error('Twilio Send Error: ' . $e->getMessage());
                return response()->json(['success' => false, 'message' => 'Twilio Error: ' . $e->getMessage()], 500);
            }
        }
    }

    /**
     * Verify OTP and Login.
     */
    public function verifyOtp(Request $request): JsonResponse
    {
        $request->validate([
            'identifier' => 'required|string',
            'otp' => 'required|string',
        ]);

        $identifier = $request->identifier;
        $otp = $request->otp;
        $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL);

        $user = null;

        if ($isEmail) {
            // EMAIL VERIFICATION
            $user = User::where('email', $identifier)->first();
            if (!$user) return response()->json(['success' => false, 'message' => 'User not found.'], 404);

            if (hash_equals((string)$user->otp_code, (string)$otp) && $user->otp_expires_at && now()->lt($user->otp_expires_at)) {
                // Valid
                if (!$user->email_verified_at) {
                    $user->email_verified_at = now();
                }
                $user->otp_code = null;
                $user->otp_expires_at = null;
                $user->save();
            } else {
                return response()->json(['success' => false, 'message' => 'Invalid or expired OTP.'], 400);
            }

        } else {
            // MOBILE VERIFICATION (Twilio)
            $mobile = $identifier;
            $normalized = $mobile;
            if (!str_starts_with($mobile, '+') && strlen($mobile) === 10) {
                $normalized = '+91' . $mobile;
            }

            $user = User::where('mobile_number', $mobile)->orWhere('mobile_number', $normalized)->first();
            if (!$user) return response()->json(['success' => false, 'message' => 'User not found.'], 404);

            try {
                $sid = env('TWILIO_SID');
                $token = env('TWILIO_TOKEN');
                $verifySid = env('TWILIO_VERIFY_SID');

                if (!$sid || !$token || !$verifySid) {
                    return response()->json(['success' => false, 'message' => 'Twilio not configured.'], 500);
                }

                $httpClient = new CurlClient();
                $twilio = new Client($sid, $token, null, null, $httpClient);

                $verification = $twilio->verify->v2->services($verifySid)
                    ->verificationChecks
                    ->create([
                        'to' => $normalized,
                        'code' => $otp
                    ]);

                if ($verification->status !== 'approved') {
                     return response()->json(['success' => false, 'message' => 'Invalid OTP.'], 400);
                }

                // Mark mobile as verified
                if (!$user->mobile_verified_at) {
                    $user->mobile_verified_at = now();
                    $user->save();
                }

            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error('Twilio Error: ' . $e->getMessage());
                return response()->json(['success' => false, 'message' => 'Twilio Error: ' . $e->getMessage()], 500);
            }
        }

        // LOGIN SUCCESS
        $user->tokens()->delete(); // Optional: Revoke old tokens
        $token = $user->createToken('mobile-app')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'mobile_number' => $user->mobile_number,
                    'role' => $user->role,
                ],
                'token' => $token,
            ],
        ], 200);
    }

    /**
     * Change Password.
     */
    public function changePassword(Request $request): JsonResponse
    {
        $request->validate([
            'current_password' => 'required',
            'new_password' => 'required|string|min:8|confirmed',
        ]);

        $user = $request->user();

        if (!Hash::check($request->current_password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect.',
            ], 400);
        }

        $user->password = Hash::make($request->new_password);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully.',
        ], 200);
    }

    /**
     * Reset Password (Forgot Password flow).
     */
    public function resetPassword(Request $request): JsonResponse
    {
        $request->validate([
            'identifier' => 'required|string',
            'otp' => 'required|string',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $identifier = $request->identifier;
        $otp = $request->otp;
        $isEmail = filter_var($identifier, FILTER_VALIDATE_EMAIL);

        $user = null;

        if ($isEmail) {
            // EMAIL VERIFICATION
            $user = User::where('email', $identifier)->first();
            if (!$user) return response()->json(['success' => false, 'message' => 'User not found.'], 404);

            if (hash_equals((string)$user->otp_code, (string)$otp) && $user->otp_expires_at && now()->lt($user->otp_expires_at)) {
                // Valid OTP
                $user->otp_code = null;
                $user->otp_expires_at = null;
            } else {
                return response()->json(['success' => false, 'message' => 'Invalid or expired OTP.'], 400);
            }

        } else {
            // MOBILE VERIFICATION (Twilio)
            $mobile = $identifier;
            $normalized = $mobile;
            if (!str_starts_with($mobile, '+') && strlen($mobile) === 10) {
                $normalized = '+91' . $mobile;
            }

            $user = User::where('mobile_number', $mobile)->orWhere('mobile_number', $normalized)->first();
            if (!$user) return response()->json(['success' => false, 'message' => 'User not found.'], 404);

            try {
                $sid = env('TWILIO_SID');
                $token = env('TWILIO_TOKEN');
                $verifySid = env('TWILIO_VERIFY_SID');

                if (!$sid || !$token || !$verifySid) {
                    return response()->json(['success' => false, 'message' => 'Twilio not configured.'], 500);
                }

                $httpClient = new CurlClient([
                    CURLOPT_SSL_VERIFYHOST => 0,
                    CURLOPT_SSL_VERIFYPEER => 0,
                ]);
                $twilio = new Client($sid, $token, null, null, $httpClient);

                $verification = $twilio->verify->v2->services($verifySid)
                    ->verificationChecks
                    ->create([
                        'to' => $normalized,
                        'code' => $otp
                    ]);

                if ($verification->status !== 'approved') {
                     return response()->json(['success' => false, 'message' => 'Invalid OTP.'], 400);
                }

            } catch (\Exception $e) {
                \Illuminate\Support\Facades\Log::error('Twilio Error: ' . $e->getMessage());
                return response()->json(['success' => false, 'message' => 'Twilio Error: ' . $e->getMessage()], 500);
            }
        }

        // OTP IS VALID - RESET PASSWORD
        $user->password = Hash::make($request->password);
        $user->save();

        // Optional: Revoke all existing login tokens to force re-login everywhere upon password reset
        $user->tokens()->delete();

        return response()->json([
            'success' => true,
            'message' => 'Password reset successfully. Please login with your new password.',
        ], 200);
    }

    /**
     * Set or update PIN for the user.
     */
    public function setPin(Request $request): JsonResponse
    {
        $request->validate([
            'pin' => 'required|string|size:4', // Assuming 4-digit PIN
            'password' => 'required', // For security, require password to set PIN
        ]);

        $user = $request->user();

        if (!Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect.',
            ], 400);
        }

        $user->pin = Hash::make($request->pin);
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'PIN updated successfully.',
        ], 200);
    }

    /**
     * Public account deletion request (no auth required, for Play Store Data Safety).
     */
    public function publicRequestDeletion(Request $request): JsonResponse
    {
        $request->validate([
            'email' => 'required|email',
            'reason' => 'nullable|string|max:500',
        ]);

        $user = User::where('email', $request->email)->first();

        if (!$user) {
            // Don't reveal if the email exists or not for security
            return response()->json([
                'success' => true,
                'message' => 'If an account exists with this email, a deletion request has been submitted.',
            ], 200);
        }

        $user->deletion_requested_at = now();
        $user->save();

        return response()->json([
            'success' => true,
            'message' => 'Account deletion request submitted. Your data will be deleted within 30 days.',
        ], 200);
    }
}
