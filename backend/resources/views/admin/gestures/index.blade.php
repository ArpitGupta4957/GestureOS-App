@extends('layouts.admin')

@section('title', 'Gesture Repository')

@section('content')
<div class="space-y-6">
    <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-white tracking-tight">GESTURE DATABASE</h1>
    </div>

    <!-- Gesture Table -->
    <div class="bg-gray-900 border border-gray-800 rounded-lg overflow-hidden">
        <div class="overflow-x-auto">
            <table class="w-full text-left">
                <thead>
                    <tr class="bg-black border-b border-gray-800 text-gray-400 font-mono text-xs uppercase">
                        <th class="px-6 py-4">ID</th>
                        <th class="px-6 py-4">User</th>
                        <th class="px-6 py-4">Gesture Name</th>
                        <th class="px-6 py-4">Action</th>
                        <th class="px-6 py-4">Created At</th>
                        <th class="px-6 py-4">Details</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-800">
                    @forelse($gestures as $gesture)
                        <tr class="hover:bg-gray-800/50 transition-colors">
                            <td class="px-6 py-4 text-gray-500 font-mono">#{{ $gesture->id }}</td>
                            <td class="px-6 py-4">
                                @if($gesture->user)
                                    <div class="font-bold text-white">{{ $gesture->user->name }}</div>
                                    <div class="text-xs text-gray-500">{{ Str::mask($gesture->user->email, '*', 3) }}</div>
                                @else
                                    <span class="text-red-500">UNKNOWN USER</span>
                                @endif
                            </td>
                            <td class="px-6 py-4 text-purple-400 font-mono text-sm">
                                {{ $gesture->name }}
                            </td>
                            <td class="px-6 py-4">
                                <div class="text-sm text-gray-300">
                                    <span class="text-green-500 font-bold">[{{ $gesture->action_type }}]</span>
                                    <div class="text-xs text-gray-500 mt-1 truncate w-40" title="{{ $gesture->action_value }}">
                                        @if(in_array($gesture->action_type, ['CALL', 'SMS', 'WHATSAPP']))
                                            {{ Str::mask($gesture->action_value, '*', 2, strlen($gesture->action_value) - 4) }}
                                        @else
                                            {{ $gesture->action_value }}
                                        @endif
                                    </div>
                                </div>
                            </td>
                            <td class="px-6 py-4 text-gray-400 text-sm">
                                {{ $gesture->created_at->format('M d, H:i') }}
                            </td>
                            <td class="px-6 py-4">
                                <span class="text-gray-600 text-xs font-mono border border-gray-700 px-2 py-1 rounded">
                                    RAW_DATA
                                </span>
                            </td>
                        </tr>
                    @empty
                        <tr>
                            <td colspan="6" class="px-6 py-8 text-center text-gray-500">
                                NO_GESTURES_RECORDED
                            </td>
                        </tr>
                    @endforelse
                </tbody>
            </table>
        </div>
        
        <div class="p-4 border-t border-gray-800">
            {{ $gestures->links() }}
        </div>
    </div>
</div>
@endsection
