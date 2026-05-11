<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    public function index()
    {
        $totalUsers = \App\Models\User::count();
        $totalGestures = \App\Models\Gesture::count();
        // Assuming database session driver
        $activeSessions = \Illuminate\Support\Facades\DB::table('sessions')
            ->where('last_activity', '>=', now()->subMinutes(5)->timestamp)
            ->count();

        // Recent Activity
        $recentUsers = \App\Models\User::latest()->take(5)->get();

        // --- Chart Data: User Registrations (Multi-Frame) ---
        
        // 1. Daily (Last 30 Days)
        $dailyUsers = \App\Models\User::selectRaw('DATE(created_at) as date, count(*) as count')
            ->where('created_at', '>=', now()->subDays(30))
            ->groupBy('date')
            ->orderBy('date')
            ->get();

        // 2. Weekly (Last 12 Weeks)
        $weeklyUsers = \App\Models\User::selectRaw('YEARWEEK(created_at) as week, MIN(DATE(created_at)) as start_date, count(*) as count')
            ->where('created_at', '>=', now()->subWeeks(12))
            ->groupBy('week')
            ->orderBy('week')
            ->get();

        // 3. Monthly (Last 12 Months)
        $monthlyUsers = \App\Models\User::selectRaw('DATE_FORMAT(created_at, "%Y-%m") as month, count(*) as count')
            ->where('created_at', '>=', now()->subMonths(12))
            ->groupBy('month')
            ->orderBy('month')
            ->get();

        // 4. Yearly (Last 5 Years)
        $yearlyUsers = \App\Models\User::selectRaw('YEAR(created_at) as year, count(*) as count')
            ->where('created_at', '>=', now()->subYears(5))
            ->groupBy('year')
            ->orderBy('year')
            ->get();

        // Prepare Data for View (Convert to array for easier JS handling)
        $chartData = [
            'daily' => [
                'labels' => $dailyUsers->pluck('date')->map(fn($d) => \Carbon\Carbon::parse($d)->format('d M'))->toArray(),
                'data' => $dailyUsers->pluck('count')->toArray(),
            ],
            'weekly' => [
                'labels' => $weeklyUsers->pluck('start_date')->map(fn($d) => 'Week ' . \Carbon\Carbon::parse($d)->format('W'))->toArray(),
                'data' => $weeklyUsers->pluck('count')->toArray(),
            ],
            'monthly' => [
                'labels' => $monthlyUsers->pluck('month')->map(fn($d) => \Carbon\Carbon::createFromFormat('Y-m', $d)->format('M Y'))->toArray(),
                'data' => $monthlyUsers->pluck('count')->toArray(),
            ],
            'yearly' => [
                'labels' => $yearlyUsers->pluck('year')->toArray(),
                'data' => $yearlyUsers->pluck('count')->toArray(),
            ]
        ];

        // --- Chart Data: Subscriptions (Multi-Frame) ---
        
        $subsChartData = [];
        $frames = [
            'daily'   => ['select' => 'DATE(subscriptions.created_at) as date', 'groupby' => 'date', 'interval' => now()->subDays(60)], // Last 60 Days
            'weekly'  => ['select' => 'YEARWEEK(subscriptions.created_at) as week, MIN(DATE(subscriptions.created_at)) as start_date', 'groupby' => 'week', 'interval' => now()->subWeeks(24)],
            'monthly' => ['select' => 'DATE_FORMAT(subscriptions.created_at, "%Y-%m") as month', 'groupby' => 'month', 'interval' => now()->subMonths(12)],
            'yearly'  => ['select' => 'YEAR(subscriptions.created_at) as year', 'groupby' => 'year', 'interval' => now()->subYears(5)],
        ];

        foreach ($frames as $key => $config) {
            $raw = \App\Models\Subscription::join('subscription_plans', 'subscriptions.plan_id', '=', 'subscription_plans.id')
                ->selectRaw($config['select'] . ', subscription_plans.name as plan_name, count(*) as count')
                ->where('subscriptions.created_at', '>=', $config['interval'])
                ->groupBy(\Illuminate\Support\Facades\DB::raw($config['groupby']), 'plan_name')
                ->orderBy(\Illuminate\Support\Facades\DB::raw($config['groupby']))
                ->get();

            // Extract unique labels (Dates/Weeks/Months)
            if ($key === 'daily') {
                $labels = $raw->pluck('date')->unique()->sort()->values();
                $formattedLabels = $labels->map(fn($d) => \Carbon\Carbon::parse($d)->format('d M'))->toArray();
            } elseif ($key === 'weekly') {
                $labels = $raw->pluck('week')->unique()->sort()->values();
                 // Use start_date for label if available, mapping from week group
                $weekMap = $raw->pluck('start_date', 'week'); 
                $formattedLabels = $labels->map(fn($w) => 'Week ' . \Carbon\Carbon::parse($weekMap[$w])->format('W'))->toArray();
            } elseif ($key === 'monthly') {
                $labels = $raw->pluck('month')->unique()->sort()->values();
                $formattedLabels = $labels->map(fn($d) => \Carbon\Carbon::createFromFormat('Y-m', $d)->format('M Y'))->toArray();
            } else {
                $labels = $raw->pluck('year')->unique()->sort()->values();
                $formattedLabels = $labels->toArray();
            }

            // Map data to labels (fill gaps with 0 if needed - simple mapping here)
            $monthlySales = [];
            $yearlySales = [];
            
            foreach ($labels as $label) {
                // Filter raw collection by the group key ($config['groupby'] logic equivalent)
                // For daily: $label is '2025-01-20'. Raw item 'date' is '2025-01-20'.
                $groupKey = $key === 'weekly' ? 'week' : ($key === 'daily' ? 'date' : ($key === 'monthly' ? 'month' : 'year'));
                
                $monthlySales[] = $raw->where($groupKey, $label)->where('plan_name', 'Monthly')->sum('count');
                $yearlySales[] = $raw->where($groupKey, $label)->where('plan_name', 'Yearly')->sum('count');
            }

            $subsChartData[$key] = [
                'labels' => $formattedLabels,
                'monthly' => $monthlySales,
                'yearly' => $yearlySales
            ];
        }

        // 5. Action Distribution
        $actionStats = \App\Models\Gesture::select('action_type', \Illuminate\Support\Facades\DB::raw('count(*) as count'))
            ->groupBy('action_type')
            ->orderByDesc('count')
            ->get();

        // 6. Recent Gestures
        $recentGestures = \App\Models\Gesture::with('user')->latest()->take(5)->get();

        // 7. Plan Stats
        $planStats = \App\Models\Subscription::join('subscription_plans', 'subscriptions.plan_id', '=', 'subscription_plans.id')
            ->select('subscription_plans.name', \Illuminate\Support\Facades\DB::raw('count(*) as count'))
            ->groupBy('subscription_plans.name')
            ->orderByDesc('count')
            ->get();
            
        return view('admin.dashboard', compact(
            'totalUsers', 'totalGestures', 'activeSessions', 'recentUsers',
            'chartData', 'subsChartData',
            'actionStats', 'recentGestures', 'planStats'
        ));
    }
}
