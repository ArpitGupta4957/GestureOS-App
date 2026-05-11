<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\SubscriptionPlan;
use Illuminate\Http\Request;

class PlanController extends Controller
{
    public function index()
    {
        $plans = SubscriptionPlan::all();
        return view('admin.plans.index', compact('plans'));
    }

    public function create()
    {
        return view('admin.plans.create');
    }

    public function store(Request $request)
    {
        $request->validate([
            'name' => 'required',
            'price' => 'required|numeric',
            'duration_days' => 'required|integer',
            'gateway_plan_id' => 'required',
            'plan_type' => 'required|in:TRIAL,PAID',
        ]);

        // Process Features Checkboxes
        $features = $request->input('features', []); // Array of selected keys
        
        // Process Limits
        $limits = [
            'max_daily_calls' => (int) $request->input('limit_daily_calls', 0),
            'max_contacts' => (int) $request->input('limit_contacts', 0),
            'max_ocr_scans' => (int) $request->input('limit_ocr_scans', 0),
            'max_excel_imports' => (int) $request->input('limit_excel_imports', 0),
            'history_retention_hours' => (int) $request->input('history_retention_hours', 24),
            'allow_export' => (bool) $request->input('allow_export', 0),
        ];

        SubscriptionPlan::create([
            'name' => $request->name,
            'plan_type' => $request->plan_type,
            'price' => $request->price,
            'currency' => 'INR',
            'duration_days' => $request->duration_days,
            'gateway_plan_id' => $request->gateway_plan_id,
            'features' => $features,
            'limits' => $limits,
            'is_active' => true,
        ]);

        return redirect()->route('admin.plans.index')->with('success', 'Plan Created Successfully');
    }

    public function edit($id)
    {
        $plan = SubscriptionPlan::findOrFail($id);
        return view('admin.plans.edit', compact('plan'));
    }

    public function update(Request $request, $id)
    {
        $plan = SubscriptionPlan::findOrFail($id);
        
        $features = $request->input('features', []);
        
        $limits = [
            'max_daily_calls' => (int) $request->input('limit_daily_calls', 0),
            'max_contacts' => (int) $request->input('limit_contacts', 0),
            'max_ocr_scans' => (int) $request->input('limit_ocr_scans', 0),
            'max_excel_imports' => (int) $request->input('limit_excel_imports', 0),
            'history_retention_hours' => (int) $request->input('history_retention_hours', 24),
            'allow_export' => (bool) $request->input('allow_export', 0),
        ];

        $plan->update([
            'name' => $request->name,
            'plan_type' => $request->plan_type,
            'price' => $request->price,
            'duration_days' => $request->duration_days,
            'features' => $features,
            'limits' => $limits,
        ]);

        return redirect()->route('admin.plans.index')->with('success', 'Plan Updated Successfully');
    }

    public function destroy($id)
    {
        SubscriptionPlan::destroy($id);
        return redirect()->route('admin.plans.index')->with('success', 'Plan Deleted');
    }
}
