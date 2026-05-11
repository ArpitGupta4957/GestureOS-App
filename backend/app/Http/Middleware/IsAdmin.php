<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Symfony\Component\HttpFoundation\Response;

class IsAdmin
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (!Auth::check() || Auth::user()->role !== 'admin') {
            // If logged in but not admin, or not logged in at all
            if (Auth::check()) {
                // Logged in but not admin
                 abort(403, 'Unauthorized access.');
            }
            return redirect()->route('admin.login');
        }

        return $next($request);
    }
}
