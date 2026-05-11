@extends('layouts.admin')

@section('title', 'Create Plan')

@section('content')
<style>
    /* Custom Styling for "Click Boxes" (Selectable Cards) */
    .feature-card {
        background: #000; 
        border: 1px solid #333; 
        padding: 15px; 
        border-radius: 4px; 
        display: flex; 
        align-items: center; 
        gap: 15px; 
        cursor: pointer; 
        transition: 0.2s;
    }
    .feature-card:hover { border-color: #555; }
    .f-check:checked + .feature-card { 
        border-color: var(--primary, #00ff9d); 
        background: var(--primary-dim, rgba(0, 255, 157, 0.1)); 
    }
    .f-check:checked + .feature-card span {
        color: var(--primary, #00ff9d) !important;
    }
    .f-check { display: none; }

    /* Custom Numeric Input */
    .numeric-wrapper {
        display: flex;
        align-items: center;
        background: #000;
        border: 1px solid #333;
        border-radius: 4px;
        overflow: hidden;
        width: 100%;
        transition: border-color 0.2s;
    }
    .numeric-wrapper:hover {
        border-color: #555;
    }
    .numeric-wrapper:focus-within {
        border-color: var(--primary, #00ff9d);
        box-shadow: 0 0 0 1px var(--primary-dim, rgba(0, 255, 157, 0.1));
    }

    .btn-spinner {
        padding: 10px 15px;
        color: #888;
        cursor: pointer;
        user-select: none;
        font-weight: bold;
        transition: all 0.2s;
        background: #0a0a0a;
        display: flex;
        align-items: center;
        justify-content: center;
    }
    .btn-spinner:hover {
        background: #1a1a1a;
        color: #fff;
    }
    .btn-spinner.increase:hover {
        color: var(--primary, #00ff9d);
        background: var(--primary-dim, rgba(0, 255, 157, 0.1));
    }
    .btn-spinner.decrease:hover {
        color: #ff5555;
        background: rgba(255, 85, 85, 0.1);
    }

    .numeric-input {
        flex: 1;
        background: transparent;
        border: none;
        color: #fff;
        text-align: center;
        padding: 10px;
        width: 50px; /* Min width, flex grows it */
        appearance: none;
        -moz-appearance: textfield;
    }
    .numeric-input:focus {
        outline: none;
    }
    /* Hide default spinners */
    .numeric-input::-webkit-outer-spin-button,
    .numeric-input::-webkit-inner-spin-button {
        -webkit-appearance: none;
        margin: 0;
    }

    /* Toggle Switch */
    .toggle-switch {
        position: relative;
        display: inline-block;
        width: 44px;
        height: 24px;
    }
    .toggle-switch input { opacity: 0; width: 0; height: 0; }
    .slider {
        position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0;
        background-color: #333; transition: .4s; border-radius: 34px;
    }
    .slider:before {
        position: absolute; content: ""; height: 18px; width: 18px; left: 3px; bottom: 3px;
        background-color: white; transition: .4s; border-radius: 50%;
    }
    input:checked + .slider { background-color: var(--primary, #00ff9d); }
    input:checked + .slider:before { transform: translateX(20px); }

</style>

<div class="container-fluid">
    <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold text-white tracking-tight">CREATE NEW PLAN</h1>
        <a href="{{ route('admin.plans.index') }}" class="btn" style="border: 1px solid #555; color: #aaa;">&larr; Back to List</a>
    </div>

    <div class="card shadow mb-4" style="background: #1a1a1a; border: none;">
        <div class="card-body">
            <form action="{{ route('admin.plans.store') }}" method="POST">
                @csrf
                
                <h5 class="mb-4 text-xl font-bold text-white">Basic Details</h5>
                
                <!-- Row 1: Name & Type -->
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Plan Name</label>
                        <input type="text" name="name" required value="{{ old('name') }}" placeholder="e.g. Premium Monthly" style="background: #000; border: 1px solid #333; padding: 10px; color: #fff; width: 100%; border-radius: 4px;">
                    </div>
                    
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Plan Type</label>
                        <select name="plan_type" style="background: #000; border: 1px solid #333; padding: 10px; color: #fff; width: 100%; border-radius: 4px;">
                            <option value="PAID">Paid Subscription</option>
                            <option value="TRIAL">Free Trial</option>
                        </select>
                    </div>
                </div>

                <!-- Row 2: Price & Duration -->
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Price (INR)</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -1)">-</div>
                            <input type="number" name="price" required value="{{ old('price') }}" step="0.01" placeholder="999.00" class="numeric-input">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 1)">+</div>
                        </div>
                    </div>
                    
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Duration (Days)</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -1)">-</div>
                            <input type="number" name="duration_days" required value="{{ old('duration_days') }}" placeholder="30" class="numeric-input">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 1)">+</div>
                        </div>
                    </div>
                </div>

                <!-- Row 3: Gateway ID & Daily Calls -->
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Gateway Plan ID (Razorpay)</label>
                        <input type="text" name="gateway_plan_id" required value="{{ old('gateway_plan_id') }}" placeholder="plan_LZ..." style="background: #000; border: 1px solid #333; padding: 10px; color: #fff; width: 100%; border-radius: 4px;">
                    </div>
                    
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Max Daily Calls</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -10)">-</div>
                            <input type="number" name="limit_daily_calls" value="{{ old('limit_daily_calls', 100) }}" class="numeric-input" step="10">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 10)">+</div>
                        </div>
                    </div>
                </div>

                <hr style="border-color: #333; margin: 30px 0;">

                <h5 class="mb-4 text-xl font-bold text-white">Feature Access</h5>
                
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label style="display: block; width: 100%;">
                            <input type="checkbox" name="features[]" value="ocr_import" class="f-check" checked>
                            <div class="feature-card">
                                <span style="font-weight: bold; color: #fff; transition: color 0.2s;">OCR Scanner</span>
                                <span style="color: #666; font-size: 12px; margin-left: auto;">Physical Cards</span>
                            </div>
                        </label>
                    </div>
                    <div style="flex: 1; min-width: 300px;">
                        <label style="display: block; width: 100%;">
                            <input type="checkbox" name="features[]" value="excel_import" class="f-check" checked>
                            <div class="feature-card">
                                <span style="font-weight: bold; color: #fff; transition: color 0.2s;">Excel Import</span>
                                <span style="color: #666; font-size: 12px; margin-left: auto;">Bulk Upload</span>
                            </div>
                        </label>
                    </div>
                </div>

                <hr style="border-color: #333; margin: 30px 0;">

                <h5 class="mb-4 text-xl font-bold text-white">Usage Limits</h5>
                
                <!-- Row 4: Contacts & OCR Limit -->
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Max Contacts Storage</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -100)">-</div>
                            <input type="number" name="limit_contacts" value="{{ old('limit_contacts', 5000) }}" class="numeric-input" step="100">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 100)">+</div>
                        </div>
                    </div>
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Max OCR Scans/Day</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -5)">-</div>
                            <input type="number" name="limit_ocr_scans" value="{{ old('limit_ocr_scans', 50) }}" class="numeric-input" step="5">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 5)">+</div>
                        </div>
                    </div>
                </div>

                <!-- Row 5: Excel Limit & History -->
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Max Excel Imports/Day</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -1)">-</div>
                            <input type="number" name="limit_excel_imports" value="{{ old('limit_excel_imports', 2) }}" class="numeric-input">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 1)">+</div>
                        </div>
                    </div>
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Session History (Hours)</label>
                        <div class="numeric-wrapper">
                            <div class="btn-spinner decrease" onclick="adjustValue(this, -1)">-</div>
                            <input type="number" name="history_retention_hours" value="{{ old('history_retention_hours', 24) }}" class="numeric-input">
                            <div class="btn-spinner increase" onclick="adjustValue(this, 1)">+</div>
                        </div>
                    </div>
                </div>

                <!-- Row 6: Export Toggle -->
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 20px;">
                     <div style="flex: 1; min-width: 300px; background: #000; border: 1px solid #333; padding: 15px; border-radius: 4px; display: flex; align-items: center; justify-content: space-between;">
                        <div>
                            <span class="text-white font-bold block">Allow Exporting Reports</span>
                            <span class="text-gray-500 text-xs">PDF/Excel Download Permission</span>
                        </div>
                        <label class="toggle-switch">
                            <input type="hidden" name="allow_export" value="0">
                            <input type="checkbox" name="allow_export" value="1" checked>
                            <span class="slider"></span>
                        </label>
                    </div>
                    <div style="flex: 1; min-width: 300px; opacity: 0;"></div> 
                </div>

                <div class="mt-6" style="margin-top: 30px;">
                    <button type="submit" class="btn btn-primary" style="padding: 10px 30px; width: 200px; text-transform: uppercase; letter-spacing: 1px;">CREATE PLAN</button>
                </div>

            </form>
        </div>
    </div>
</div>

<script>
    function adjustValue(btn, amount) {
        const wrapper = btn.closest('.numeric-wrapper');
        const input = wrapper.querySelector('input');
        const currentVal = parseFloat(input.value) || 0;
        
        // Respect step attribute if small increments
        let step = parseFloat(input.getAttribute('step')) || 1;
        
        // If amount is 1 or -1, use the larger of step or amount logic
        // But here I passed specific amounts (1, 10, 100).
        // If amount is passed, use it. But ensure we don't break decimals for price.
        
        let newVal = currentVal + amount;
        
        // Fix floating point errors
        if (Number.isInteger(step)) {
            newVal = Math.round(newVal);
        } else {
            newVal = parseFloat(newVal.toFixed(2));
        }

        // Prevent negative values
        if (newVal < 0) newVal = 0;
        
        input.value = newVal;
    }
</script>
@endsection
