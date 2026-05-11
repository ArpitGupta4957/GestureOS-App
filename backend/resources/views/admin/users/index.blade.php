@extends('layouts.admin')

@section('title', 'User Management')

@section('content')
<div class="space-y-6">
    <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-white tracking-tight">USER DATABASE</h1>
        <a href="{{ route('admin.users.create') }}" class="btn btn-primary" style="font-size: 0.8rem;">+ CREATE USER</a>
    </div>

    <!-- User Table -->
    <div class="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left">
                <thead>
                    <tr class="bg-black border-b border-gray-800 text-gray-400 font-mono text-xs uppercase">
                        <th class="px-6 py-4">ID</th>
                        <th class="px-6 py-4">Name / Email</th>
                        <th class="px-6 py-4">Role</th>
                        <th class="px-6 py-4">Joined</th>
                        <th class="px-6 py-4">Status</th>
                        <th class="px-6 py-4">Actions</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-800">
                    @forelse($users as $user)
                        <tr class="hover:bg-gray-800/50 transition-colors">
                            <td class="px-6 py-4 text-gray-500 font-mono">#{{ $user->id }}</td>
                            <td class="px-6 py-4">
                                <div class="font-bold text-white">{{ $user->name }}</div>
                                <div class="text-sm text-gray-500">
                                    {{ Str::mask($user->email, '*', 3) }}
                                </div>
                            </td>
                            <td class="px-6 py-4">
                                @if($user->role === 'admin')
                                    <span style="border: 1px solid var(--secondary); color: var(--secondary); padding: 2px 6px; border-radius: 4px; font-size: 0.75rem;">ADMIN</span>
                                @else
                                    <span style="border: 1px solid #555; color: #aaa; padding: 2px 6px; border-radius: 4px; font-size: 0.75rem;">USER</span>
                                @endif
                            </td>
                            <td class="px-6 py-4 text-gray-400 text-sm">
                                {{ $user->created_at->format('M d, Y') }}
                            </td>
                            <td class="px-6 py-4">
                                @if($user->is_active)
                                    <span style="color: var(--success); font-family: monospace; font-size: 0.75rem;">● ACTIVE</span>
                                @else
                                    <span style="color: var(--danger); font-family: monospace; font-size: 0.75rem;">● INACTIVE</span>
                                @endif
                            </td>
                            <td class="px-6 py-4">
                                <form action="{{ route('admin.users.toggle', $user->id) }}" method="POST" class="inline" style="display:inline;">
                                    @csrf
                                    @if($user->is_active)
                                        <button type="submit" class="btn btn-danger" style="font-size: 0.75rem; padding: 0.2rem 0.5rem;" onclick="return confirm('Deactivate this user?')">
                                            DEACTIVATE
                                        </button>
                                    @else
                                        <button type="submit" class="btn btn-primary" style="font-size: 0.75rem; padding: 0.2rem 0.5rem;" onclick="return confirm('Activate this user?')">
                                            ACTIVATE
                                        </button>
                                    @endif
                                </form>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-6 py-8 text-center text-gray-500">
                                NO_RECORDS_FOUND
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
