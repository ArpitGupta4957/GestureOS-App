@extends('layouts.admin')

@section('title', 'Global Settings')

@section('content')
<div class="space-y-6">
    <div class="flex justify-between items-center">
        <h1 class="text-3xl font-bold text-white tracking-tight">GLOBAL CONFIGURATION</h1>
    </div>

    <!-- Settings Form -->
    <div class="bg-gray-900 border border-gray-800 rounded-lg p-6">
        <form action="{{ route('admin.settings.update') }}" method="POST">
            @csrf
            
            <div class="space-y-6">
                @foreach($settings as $setting)
                    <div class="border-b border-gray-800 pb-6 last:border-0 last:pb-0">
                        <div class="flex flex-col md:flex-row md:items-start md:justify-between gap-4">
                            <div class="md:w-1/3">
                                <label for="{{ $setting->key }}" class="block text-white font-bold mb-1 font-mono uppercase text-sm">
                                    {{ str_replace('_', ' ', $setting->key) }}
                                </label>
                                <p class="text-gray-500 text-xs">
                                    {{ $setting->description }}
                                </p>
                            </div>
                            <div class="md:w-2/3">
                                <input type="text" name="{{ $setting->key }}" id="{{ $setting->key }}" 
                                    value="{{ $setting->value }}"
                                    class="w-full bg-black border border-gray-700 rounded py-2 px-4 text-gray-200 focus:outline-none focus:border-[#00ff9d] focus:shadow-[0_0_5px_#00ff9d] transition-all duration-300 font-mono">
                                <p class="text-gray-600 text-xs mt-1">Key: <span class="font-mono text-gray-500">{{ $setting->key }}</span></p>
                            </div>
                        </div>
                    </div>
                @endforeach
            </div>

            <div class="mt-8 pt-6 border-t border-gray-800 flex justify-end">
                <button type="submit" class="btn btn-primary font-bold py-2 px-6 rounded shadow-[0_0_5px_#00ff9d] hover:shadow-[0_0_15px_#00ff9d]">
                    SAVE_CHANGES
                </button>
            </div>
        </form>
    </div>
</div>
@endsection
