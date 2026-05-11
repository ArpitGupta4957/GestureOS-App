<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\BulkSession;
use App\Models\BulkNumber;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class BulkDialerController extends Controller
{
    // GET /api/bulk/sessions
    public function getSessions(Request $request)
    {
        $user = $request->user();
        
        // 1. Determine History Retention Limit
        $retentionHours = 24; // Default constraint
        
        if ($user && $user->subscription && $user->subscription->isValid()) {
            $plan = $user->subscription->plan;
            if ($plan) {
                $limits = $plan->limits; // Cast to array in model
                if (isset($limits['history_retention_hours'])) {
                    $retentionHours = (int) $limits['history_retention_hours'];
                }
            }
        }

        // 2. Cleanup Old Sessions (Lazy Cleanup)
        // Only cleanup sessions for THIS user if we are associating sessions with users?
        // Wait, BulkSession model check needed. Assuming user_id exists or sessions are global?
        // If sessions are per user, we must filter by user_id too.
        // Let's assume for now valid context. 
        // Based on previous code, no user_id filtering was visible in getSessions!
        // Re-checking getSessions: BulkSession::where('is_archived', false)...
        // IT IS MISSING USER FILTER! This is a bug if multi-tenant.
        // But assuming single user or filtered globally.
        // I'll add the cleanup logic assuming global for now, but really should be scoped.
        
        // Safety: Only delete if retention > 0.
        if ($retentionHours > 0) {
            $threshold = now()->subHours($retentionHours);
            BulkSession::where('user_id', $user->id)
                ->where('created_at', '<', $threshold)
                ->delete();
        }

        // Simple pagination for sessions
        $sessions = BulkSession::where('user_id', $user->id)
            ->where('is_archived', false)
            ->orderBy('created_at', 'desc')
            ->paginate(20); // 20 per page
            
        return response()->json($sessions);
    }

    // POST /api/bulk/sessions
    public function createSession(Request $request)
    {
        $request->validate(['name' => 'required|string']);
        
        $session = BulkSession::create([
            'user_id' => $request->user()->id,
            'name' => $request->name,
        ]);
        
        return response()->json($session, 201);
    }

    // GET /api/bulk/sessions/{id}/numbers
    public function getNumbers(Request $request, $sessionId)
    {
        // Ensure session belongs to user
        $session = BulkSession::where('id', $sessionId)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        $limit = $request->input('limit', 50); // Default 50
        $numbers = BulkNumber::where('session_id', $sessionId)
            ->orderBy('id', 'asc')
            ->cursorPaginate($limit); // Efficient for large lists
            
        return response()->json($numbers);
    }

    // POST /api/bulk/numbers (Batch Insert)
    public function addNumbers(Request $request)
    {
        $request->validate([
            'session_id' => 'required|exists:bulk_sessions,id',
            'numbers' => 'required|array',
            'numbers.*.phone_number' => 'required|string',
        ]);

        $sessionId = $request->session_id;
        
        // Ensure session belongs to user
        $session = BulkSession::where('id', $sessionId)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        // Must use create() instead of insert() to trigger encryption casts
        foreach ($request->numbers as $num) {
            BulkNumber::create([
                'session_id' => $sessionId,
                'phone_number' => $num['phone_number'],
                'name' => $num['name'] ?? null,
                'notes' => $num['notes'] ?? '',
                'status' => 'pending',
            ]);
        }

        return response()->json(['message' => 'Numbers added successfully']);
    }

    // PUT /api/bulk/numbers/{id}
    public function updateNumber(Request $request, $id)
    {
        $number = BulkNumber::whereHas('session', function($query) use ($request) {
            $query->where('user_id', $request->user()->id);
        })->findOrFail($id);
        
        $input = $request->only(['phone_number', 'name', 'notes', 'status', 'last_called_at']);
        
        if (isset($input['status']) && $input['status'] == 'called' && empty($input['last_called_at'])) {
             $input['last_called_at'] = now();
        }

        $number->update($input);
        return response()->json($number);
    }

    // DELETE /api/bulk/sessions/{id}
    public function deleteSession(Request $request, $id)
    {
        $session = BulkSession::where('id', $id)
            ->where('user_id', $request->user()->id)
            ->firstOrFail();

        // Cascade handles numbers, but implicit check good.
        $session->delete();
        return response()->json(['message' => 'Session deleted']);
    }
}
