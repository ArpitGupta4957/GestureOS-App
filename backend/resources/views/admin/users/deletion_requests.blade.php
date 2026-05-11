@extends('layouts.admin')

@section('title', 'Deletion Requests')

@section('content')
<div class="space-y-6">
    <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-white tracking-tight">ACCOUNT DELETION REQUESTS</h1>
    </div>

    <!-- Alert Info -->
    <div class="bg-red-900/20 border border-red-500/50 p-4 rounded-lg">
        <p class="text-red-400 text-sm">
            <i class="fas fa-exclamation-triangle mr-2"></i>
            <strong>Warning:</strong> Deleting an account here is permanent and cannot be undone. All user data will be erased.
        </p>
    </div>

    <!-- User Table -->
    <div class="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left">
                <thead>
                    <tr class="bg-black border-b border-gray-800 text-gray-400 font-mono text-xs uppercase">
                        <th class="px-6 py-4">ID</th>
                        <th class="px-6 py-4">Name / Email</th>
                        <th class="px-6 py-4">Requested At</th>
                        <th class="px-6 py-4">Status</th>
                        <th class="px-6 py-4 text-right">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-800">
                    @forelse($users as $user)
                        <tr class="hover:bg-gray-800/50 transition-colors">
                            <td class="px-6 py-4 text-gray-500 font-mono">#{{ $user->id }}</td>
                            <td class="px-6 py-4">
                                <div class="font-bold text-white">{{ $user->name }}</div>
                                <div class="text-sm text-gray-500">{{ $user->email }}</div>
                            </td>
                            <td class="px-6 py-4" style="color: #ff6b6b; font-size: 0.875rem;">
                                {{ $user->deletion_requested_at ? \Carbon\Carbon::parse($user->deletion_requested_at)->diffForHumans() : 'N/A' }}
                            </td>
                            <td class="px-6 py-4">
                                @if($user->is_active)
                                    <span style="color: var(--success); font-family: monospace; font-size: 0.75rem;">● ACTIVE</span>
                                @else
                                    <span style="color: var(--danger); font-family: monospace; font-size: 0.75rem;">● INACTIVE</span>
                                @endif
                            </td>
                             <td class="px-6 py-4" style="text-align: right;">
                                <!-- Cancel Request -->
                                <form action="{{ route('admin.users.deletion_requests.cancel', $user->id) }}" method="POST" class="inline" style="display:inline;">
                                    @csrf
                                    <button type="submit" class="btn" style="border-color: #555; color: #888; font-size: 0.8rem;" onclick="return confirm('Are you sure you want to cancel this deletion request? The user account will remain active.')">
                                        CANCEL REQUEST
                                    </button>
                                </form>

                                <!-- Permanent Delete -->
                                <form action="{{ route('admin.users.destroy', $user->id) }}" method="POST" class="inline" style="display:inline;">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-danger" style="font-size: 0.8rem; margin-left: 10px;" onclick="return confirm('PERMANENTLY DELETE {{ $user->email }}? This action CANNOT be undone.')">
                                        DELETE PERMANENTLY
                                    </button>
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="5" class="px-6 py-8 text-center text-gray-500">
                                NO DELETION REQUESTS PENDING
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        <div class="p-4 border-t border-gray-800">
            {{ $users->links() }}
        </div>
    </div>
</div>
@endsection
