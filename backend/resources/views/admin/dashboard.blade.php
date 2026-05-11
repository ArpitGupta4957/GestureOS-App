@extends('layouts.admin')

@section('title', 'Dashboard')

@section('content')
<div style="display: flex; flex-direction: column; gap: 1.5rem;">
    <div class="flex justify-between items-center">
        <h1 class="text-2xl font-bold text-white" style="letter-spacing: -0.025em;">SYSTEM STATUS</h1>
        <div class="font-mono text-sm" style="color: var(--success); border: 1px solid var(--success); padding: 0.25rem 0.5rem; border-radius: 4px;">
            ONLINE
        </div>
    </div>

    <!-- Stats Grid -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1.5rem;">
        <!-- Stat Card 1 -->
        <div class="card relative overflow-hidden">
            <h3 class="text-gray text-sm font-mono mb-4">TOTAL USERS</h3>
            <p class="text-2xl font-bold text-white">{{ number_format($totalUsers) }}</p>
            <div class="mt-4 text-sm" style="color: var(--success); display: flex; align-items: center;">
                <span>▲ 12%</span>
                <span class="text-gray" style="margin-left: 0.5rem;">vs last week</span>
            </div>
        </div>

        <!-- Stat Card 2 -->
        <div class="card relative overflow-hidden">
            <h3 class="text-gray text-sm font-mono mb-4">TOTAL GESTURES</h3>
            <p class="text-2xl font-bold text-white">{{ number_format($totalGestures) }}</p>
            <div class="mt-4 text-sm" style="color: var(--success); display: flex; align-items: center;">
                <span>▲ 5%</span>
                <span class="text-gray" style="margin-left: 0.5rem;">vs last week</span>
            </div>
        </div>

        <!-- Stat Card 3 -->
        <div class="card relative overflow-hidden">
            <h3 class="text-gray text-sm font-mono mb-4">ACTIVE SESSIONS</h3>
            <p class="text-2xl font-bold text-white">{{ $activeSessions }}</p>
             <div class="mt-4 text-sm text-gray" style="display: flex; align-items: center;">
                <span style="color: var(--text-muted);">Currently Online</span>
            </div>
        </div>
         <!-- Stat Card 4 -->
        <div class="card relative overflow-hidden">
            <h3 class="text-gray text-sm font-mono mb-4">AVG RESPONSE</h3>
            <p class="text-2xl font-bold text-white">124ms</p>
            <div class="mt-4 text-sm" style="color: var(--success); display: flex; align-items: center;">
                <span>▼ 2ms</span>
                <span class="text-gray" style="margin-left: 0.5rem;">Optimal</span>
            </div>
        </div>
    </div>

    <!-- Charts Section -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(400px, 1fr)); gap: 1.5rem;">
        
        <!-- User Growth Chart -->
        <div class="card">
            <div class="flex justify-between items-center mb-4">
                <h3 class="text-gray text-sm font-mono">USER GROWTH</h3>
                <div class="custom-select-wrapper">
                    <select onchange="initUserChart(this.value)" class="custom-select">
                        <option value="daily">Daily</option>
                        <option value="weekly">Weekly</option>
                        <option value="monthly">Monthly</option>
                        <option value="yearly">Yearly</option>
                    </select>
                    <div class="custom-select-arrow">
                        <svg class="fill-current w-full h-full" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/></svg>
                    </div>
                </div>
            </div>
            <div style="height: 300px; position: relative; width: 100%;">
                <canvas id="userChart"></canvas>
            </div>
        </div>

        <!-- Subscription Trends Chart -->
        <div class="card">
            <div class="flex justify-between items-center mb-4">
                <h3 class="text-gray text-sm font-mono">SUBSCRIPTION TRENDS</h3>
                <div class="custom-select-wrapper">
                    <select onchange="initSubsChart(this.value)" class="custom-select">
                        <option value="daily">Daily</option>
                        <option value="weekly">Weekly</option>
                        <option value="monthly" selected>Monthly</option>
                        <option value="yearly">Yearly</option>
                    </select>
                    <div class="custom-select-arrow">
                        <svg class="fill-current w-full h-full" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/></svg>
                    </div>
                </div>
            </div>
            <div style="height: 300px; position: relative; width: 100%;">
                <canvas id="subsChart"></canvas>
            </div>
        </div>
    </div>

    <!-- Recent Activity Placeholder -->
    <div class="card">
        <h2 class="text-xl font-bold text-white mb-4 neon-text">RECENT REGISTRATIONS</h2>
        <div style="display: flex; flex-direction: column; gap: 0.75rem;">
             @forelse($recentUsers as $user)
             <div class="flex items-center justify-between text-sm py-2" style="border-bottom: 1px solid var(--border-color);">
                <span class="text-gray font-mono">[INFO] New user registered: {{ $user->name }}</span>
                <span style="color: var(--text-muted);">{{ $user->created_at->diffForHumans() }}</span>
            </div>
            @empty
            <div class="text-gray">No recent activity.</div>
            @endforelse
        </div>
    </div>

<!-- Row 3: Action Stats & Plan Stats -->
<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; margin-bottom: 1.5rem;">
    <!-- Top Gestures Chart -->
    <div class="card">
        <h3 class="text-gray text-sm font-mono mb-4">TOP GESTURE ACTIONS</h3>
        <div style="height: 250px; position: relative; width: 100%;">
            <canvas id="actionChart"></canvas>
        </div>
    </div>

    <!-- Plan Distribution Chart -->
    <div class="card">
        <h3 class="text-gray text-sm font-mono mb-4">PLAN DISTRIBUTION</h3>
        <div style="height: 250px; position: relative; width: 100%;">
            <canvas id="planChart"></canvas>
        </div>
    </div>
</div>

<!-- Row 4: Recent Gestures Table -->
<div class="card mb-6">
    <h3 class="text-gray text-sm font-mono mb-4">LATEST GESTURES CREATED</h3>
    <div class="overflow-x-auto">
        <table>
            <thead>
                <tr>
                    <th>USER</th>
                    <th>GESTURE NAME</th>
                    <th>ACTION</th>
                    <th>CREATED</th>
                </tr>
            </thead>
            <tbody>
                @forelse($recentGestures as $gesture)
                <tr>
                    <td class="font-mono text-xs">{{ $gesture->user->name ?? 'Unknown' }}</td>
                    <td class="text-primary font-bold">{{ $gesture->name }}</td>
                    <td class="text-xs uppercase">{{ $gesture->action_type }}</td>
                    <td class="text-xs text-gray">{{ $gesture->created_at->diffForHumans() }}</td>
                </tr>
                @empty
                <tr><td colspan="4" class="text-center text-gray">No gestures found.</td></tr>
                @endforelse
            </tbody>
        </table>
    </div>
</div>
</div> <!-- End Main Flex Wrapper -->

<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
    // --- Theme Config ---
    function getThemeColors() {
        const theme = document.documentElement.getAttribute('data-theme') || 'dark';
        const isDark = theme === 'dark';
        
        return {
            primary: '#00ff9d',
            secondary: '#7000ff',
            grid: isDark ? '#ffffff0d' : '#0000000d',
            text: isDark ? '#aaaaaa' : '#4b5563',
            gradientStart: isDark ? 'rgba(0, 255, 157, 0.2)' : 'rgba(0, 255, 157, 0.4)',
            gradientEnd: isDark ? 'rgba(0, 255, 157, 0)' : 'rgba(0, 255, 157, 0.05)',
            tooltipBg: 'rgba(0, 0, 0, 0.9)', // Always dark tooltip looks premium
            tooltipBorder: 'rgba(0, 255, 157, 0.3)'
        };
    }

    Chart.defaults.font.family = "'Inter', monospace";
    
    // Global Tooltip Styling (Consistent Dark Theme)
    Chart.defaults.plugins.tooltip.backgroundColor = 'rgba(0, 0, 0, 0.9)';
    Chart.defaults.plugins.tooltip.titleColor = '#fff';
    Chart.defaults.plugins.tooltip.bodyColor = '#ccc';
    Chart.defaults.plugins.tooltip.borderColor = 'rgba(0, 255, 157, 0.3)';
    Chart.defaults.plugins.tooltip.borderWidth = 1;
    Chart.defaults.plugins.tooltip.padding = 10;
    Chart.defaults.plugins.tooltip.displayColors = false;
    Chart.defaults.plugins.tooltip.callbacks.title = (items) => items[0].label.toUpperCase();

    // --- Dynamic Data ---
    const chartData = @json($chartData);
    const subsChartData = @json($subsChartData);
    const actionStats = @json($actionStats);
    const planStats = @json($planStats);
    
    let userChartInstance = null;
    let subsChartInstance = null;
    let actionChartInstance = null;
    let planChartInstance = null;
    let currentFrameUser = 'daily';
    let currentFrameSubs = 'monthly';

    function initUserChart(timeframe) {
        currentFrameUser = timeframe;
        const ctx = document.getElementById('userChart').getContext('2d');
        const data = chartData[timeframe];
        const colors = getThemeColors();

        if (userChartInstance) userChartInstance.destroy();

        let gradient = ctx.createLinearGradient(0, 0, 0, 300);
        gradient.addColorStop(0, colors.gradientStart);
        gradient.addColorStop(1, colors.gradientEnd);

        Chart.defaults.color = colors.text;
        Chart.defaults.borderColor = colors.grid;

        userChartInstance = new Chart(ctx, {
            type: 'line',
            data: {
                labels: data.labels,
                datasets: [{
                    label: 'New Users',
                    data: data.data,
                    borderColor: colors.primary,
                    backgroundColor: gradient,
                    borderWidth: 2,
                    tension: 0.4,
                    fill: true,
                    pointRadius: 0,
                    pointHoverRadius: 6,
                    pointBackgroundColor: '#000',
                    pointBorderColor: colors.primary,
                    pointBorderWidth: 2,
                    pointHoverBackgroundColor: colors.primary 
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: { beginAtZero: true, grid: { color: colors.grid, borderDash: [5, 5] }, border: { display: false } },
                    x: { grid: { display: false }, border: { display: false } }
                },
                interaction: { mode: 'index', intersect: false }
            }
        });
    }

    function initSubsChart(timeframe) {
        currentFrameSubs = timeframe;
        const ctx = document.getElementById('subsChart').getContext('2d');
        const data = subsChartData[timeframe];
        const colors = getThemeColors();

        if (subsChartInstance) subsChartInstance.destroy();
        
        let gradMonthly = ctx.createLinearGradient(0, 0, 0, 300);
        gradMonthly.addColorStop(0, '#00ff9d');
        gradMonthly.addColorStop(1, colors.gradientEnd);

        let gradYearly = ctx.createLinearGradient(0, 0, 0, 300);
        gradYearly.addColorStop(0, '#7000ff');
        gradYearly.addColorStop(1, 'rgba(112, 0, 255, 0.05)');

        subsChartInstance = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: data.labels,
                datasets: [
                    { label: 'Monthly', data: data.monthly, backgroundColor: gradMonthly, borderRadius: 4, barPercentage: 0.6 },
                    { label: 'Yearly', data: data.yearly, backgroundColor: gradYearly, borderRadius: 4, barPercentage: 0.6 }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { 
                        display: true, position: 'top', align: 'end',
                        labels: { color: colors.text, font: { family: 'monospace', size: 10 }, usePointStyle: true, boxWidth: 8 }
                    }
                },
                scales: {
                    x: { stacked: true, grid: { display: false }, border: { display: false } },
                    y: { stacked: true, beginAtZero: true, grid: { color: colors.grid, borderDash: [5, 5] }, border: { display: false } }
                }
            }
        });
    }

    function initActionChart() {
        const ctx = document.getElementById('actionChart').getContext('2d');
        const colors = getThemeColors();
        
        if (actionChartInstance) actionChartInstance.destroy();

        const labels = actionStats.map(i => i.action_type.toUpperCase());
        const data = actionStats.map(i => i.count);

        actionChartInstance = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: ['#00ff9d', '#7000ff', '#ff2a6d', '#00f3ff'],
                    borderColor: 'transparent',
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'right', labels: { color: colors.text, font: { family: 'monospace' }, usePointStyle: true } }
                }
            }
        });
    }

    function initPlanChart() {
        const ctx = document.getElementById('planChart').getContext('2d');
        const colors = getThemeColors();
        
        if (planChartInstance) planChartInstance.destroy();

        const labels = planStats.map(i => i.name.toUpperCase());
        const data = planStats.map(i => i.count);

        planChartInstance = new Chart(ctx, {
            type: 'pie',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: ['#7000ff', '#00ff9d', '#ff2a6d'],
                    borderColor: 'transparent',
                    borderWidth: 0
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { position: 'right', labels: { color: colors.text, font: { family: 'monospace' }, usePointStyle: true } }
                }
            }
        });
    }

    // Initialize
    initUserChart('daily');
    initSubsChart('monthly');
    initActionChart();
    initPlanChart();

    // Theme Change Listener
    window.addEventListener('themeChanged', () => {
        initUserChart(currentFrameUser);
        initSubsChart(currentFrameSubs);
        initActionChart();
        initPlanChart();
    });
</script>
@endsection
