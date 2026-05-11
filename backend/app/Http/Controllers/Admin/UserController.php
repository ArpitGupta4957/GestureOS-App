<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserController extends Controller
{
    public function index()
    {
        $users = User::paginate(10);
        return view('admin.users.index', compact('users'));
    }

    public function create()
    {
        return view('admin.users.create');
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|email|unique:users,email',
            'password' => 'required|min:8',
            'role' => 'required|in:user,admin',
        ]);

        User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => \Illuminate\Support\Facades\Hash::make($request->password),
            'role' => $request->role,
        ]);

        return redirect()->route('admin.users.index')->with('success', 'User created successfully.');
    }

    public function toggleStatus($id)
    {
        $user = User::findOrFail($id);
        
        // Prevent deactivating self
        if ($user->id === auth()->id()) {
            return redirect()->back()->with('error', 'You cannot deactivate your own account.');
        }

        $user->is_active = !$user->is_active;
        $user->save();

        $status = $user->is_active ? 'activated' : 'deactivated';
        return redirect()->back()->with('success', "User has been {$status}.");
    }

    /**
     * Show list of users who requested account deletion.
     */
    public function deletionRequests()
    {
        $users = User::whereNotNull('deletion_requested_at')
                     ->orderBy('deletion_requested_at', 'asc')
                     ->paginate(10);
                     
        return view('admin.users.deletion_requests', compact('users'));
    }

    /**
     * Cancel the deletion request (Keep account).
     */
    public function cancelDeletionRequest($id)
    {
        $user = User::findOrFail($id);
        $user->deletion_requested_at = null;
        $user->save();

        return redirect()->back()->with('success', 'Deletion request cancelled. Account kept active.');
    }

    /**
     * Permanently delete the user.
     */
    public function destroy($id)
    {
        $user = User::findOrFail($id);

        if ($user->id === auth()->id()) {
             return redirect()->back()->with('error', 'You cannot delete yourself.');
        }

        // Delete related data if not using cascade?
        // Laravel's cascade on foreign keys usually handles it, but verify models.
        // Assuming database level cascade or Model 'deleting' events.
        
        $user->delete();

        return redirect()->back()->with('success', 'User account permanently deleted.');
    }
}
