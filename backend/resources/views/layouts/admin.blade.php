<!DOCTYPE html>
<html lang="{{ str_replace('_', '-', app()->getLocale()) }}">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MyDial Admin - @yield('title')</title>
    {{-- @vite(['resources/css/app.css', 'resources/js/app.js']) --}}
    <link rel="stylesheet" href="{{ asset('css/admin.css') }}">
    <!-- Custom CSS Moved to public/css/admin.css -->
</head>
<body class="flex flex-col">
    <!-- Navbar -->
    <nav class="flex justify-between items-center px-6 h-16">
        <div class="flex items-center">
            <!-- App Logo -->
            <div class="app-logo">
                <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
                    <path d="M9 11.75c-.69 0-1.25.56-1.25 1.25s.56 1.25 1.25 1.25 1.25-.56 1.25-1.25-.56-1.25-1.25-1.25zm6 0c-.69 0-1.25.56-1.25 1.25s.56 1.25 1.25 1.25 1.25-.56 1.25-1.25-.56-1.25-1.25-1.25zM12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8 0-.29.02-.58.05-.86 2.36-1.05 4.23-2.98 5.21-5.37C11.07 8.33 14.05 10 17.42 10c.78 0 1.53-.09 2.25-.26.21.71.33 1.47.33 2.26 0 4.41-3.59 8-8 8z"/>
                </svg>
            </div>
            <span class="text-2xl neon-text font-bold tracking-wider">My<span class="text-white">Dial</span></span>
        </div>
        
        <div class="flex items-center gap-4">
            <!-- Premium Theme Toggle -->
            <div onclick="toggleTheme()" class="theme-switch" title="Toggle Light/Dark Mode">
                <span class="icon moon">🌙</span>
                <span class="icon sun">☀️</span>
                <div class="knob"></div>
            </div>
            @auth
                <span class="text-gray text-sm hidden sm:block">
                    {{ Auth::user()->name }}
                </span>
                <form action="{{ route('admin.logout') }}" method="POST">
                    @csrf
                    <button type="submit" class="btn btn-danger text-sm font-mono">
                        [LOGOUT]
                    </button>
                </form>
            @else
                <span class="text-gray text-sm">
                    // GUEST_ACCESS
                </span>
            @endauth
        </div>
    </nav>

    <div class="flex flex-1 overflow-hidden">
        <!-- Sidebar -->
        @auth
        <aside class="w-64 hidden md:block">
            <div class="py-6 px-4">
                <ul class="flex flex-col gap-2">
                    <li>
                         <a href="{{ route('admin.dashboard') }}" class="sidebar-link block py-2 px-4 rounded {{ request()->routeIs('admin.dashboard') ? 'active neon-text' : '' }}">
                            DASHBOARD
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.users.index') }}" class="sidebar-link block py-2 px-4 rounded {{ request()->routeIs('admin.users.index') ? 'active neon-text' : '' }}">
                            USERS
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.users.deletion_requests') }}" class="sidebar-link block py-2 px-4 rounded {{ request()->routeIs('admin.users.deletion_requests') ? 'active neon-text' : '' }}">
                            DELETION REQUESTS
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.gestures.index') }}" class="sidebar-link block py-2 px-4 rounded {{ request()->routeIs('admin.gestures.index') ? 'active neon-text' : '' }}">
                            GESTURES
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.plans.index') }}" class="sidebar-link block py-2 px-4 rounded {{ request()->routeIs('admin.plans.*') ? 'active neon-text' : '' }}">
                            SUBSCRIPTION PLANS
                        </a>
                    </li>
                    <li>
                        <a href="{{ route('admin.settings.index') }}" class="sidebar-link block py-2 px-4 rounded {{ request()->routeIs('admin.settings.*') ? 'active neon-text' : '' }}">
                            SETTINGS
                        </a>
                    </li>
                </ul>
            </div>
        </aside>
        @endauth

        <!-- Main Content -->
        <main class="flex-1 p-6 overflow-y-auto">
            @if(session('success'))
                <div class="alert alert-success mb-4">
                    {{ session('success') }}
                </div>
            @endif

            @if(session('error'))
                <div class="alert alert-error mb-4">
                    {{ session('error') }}
                </div>
            @endif

            @yield('content')
        </main>
    </div>
    <script>
        function toggleTheme() {
            const html = document.documentElement;
            const current = html.getAttribute('data-theme') || 'dark';
            const next = current === 'light' ? 'dark' : 'light';
            html.setAttribute('data-theme', next);
            localStorage.setItem('theme', next);
            // Trigger custom event for charts
            window.dispatchEvent(new CustomEvent('themeChanged', { detail: next }));
        }

        // Initialize
        (function() {
            const saved = localStorage.getItem('theme') || 'dark';
            document.documentElement.setAttribute('data-theme', saved);
        })();
    </script>
    @if(session('success'))
    <script>
        // Optional: Auto-hide alerts
        setTimeout(() => {
            const alerts = document.querySelectorAll('.alert');
            alerts.forEach(a => a.style.display = 'none');
        }, 5000);
    </script>
    @endif
</body>
</html>
