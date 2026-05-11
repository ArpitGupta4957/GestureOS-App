@extends('layouts.admin')

@section('title', 'Login')

@section('content')
<div class="flex items-center justify-center min-h-screen px-4"> <!-- Added px-4 for mobile padding, removed negative margin -->
    <div class="card w-full" style="max-width: 28rem; position: relative; overflow: hidden; margin: auto;"> <!-- Added margin auto -->
        <!-- Decorational elements -->
        <div style="position: absolute; top: 0; right: 0; width: 5rem; height: 5rem; background: linear-gradient(to bottom left, rgba(0,255,157,0.2), transparent);"></div>
        
        <div class="text-center mb-4">
            <h2 class="text-2xl font-bold neon-text" style="letter-spacing: 0.1em;">ADMIN ACCESS</h2>
            <p class="text-gray mt-4 font-mono text-sm">AUTHORIZED PERSONNEL ONLY</p>
        </div>

        <form method="POST" action="{{ route('admin.login.submit') }}">
            @csrf
            
            <div class="mb-4">
                <label for="email" class="font-bold font-mono text-sm">// EMAIL_ID</label>
                <input type="email" name="email" id="email" 
                    placeholder="admin@mydial.app" required autofocus>
                @error('email')
                    <p class="text-red text-sm mt-4">{{ $message }}</p>
                @enderror
            </div>

            <div class="mb-4" style="margin-bottom: 2rem;">
                <label for="password" class="font-bold font-mono text-sm">// ACCESS_KEY</label>
                <input type="password" name="password" id="password" 
                    placeholder="••••••••" required>
                @error('password')
                    <p class="text-red text-sm mt-4">{{ $message }}</p>
                @enderror
            </div>

            <button type="submit" class="btn btn-primary w-full">
                INITIATE_SESSION
            </button>
        </form>
    </div>
</div>
@endsection
