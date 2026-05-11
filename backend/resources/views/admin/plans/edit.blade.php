@extends('layouts.admin')

@section('content')
<div class="container-fluid">
    <h1 class="h3 mb-4 text-gray-800">Edit Plan: {{ $plan->name }}</h1>

    <div class="card shadow mb-4">
        <div class="card-body">
            <form action="{{ route('admin.plans.update', $plan->id) }}" method="POST">
                @csrf
                @method('PUT')
                
                <h5 class="mb-3">Basic Details</h5>
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label>Plan Name</label>
                        <input type="text" name="name" class="form-control" value="{{ $plan->name }}" required>
                    </div>
                    <div class="col-md-6 mb-3">
                        <label>Plan Type</label>
                        <select name="plan_type" class="form-control">
                            <option value="PAID" {{ $plan->plan_type == 'PAID' ? 'selected' : '' }}>Paid Subscription</option>
                            <option value="TRIAL" {{ $plan->plan_type == 'TRIAL' ? 'selected' : '' }}>Free Trial</option>
                        </select>
                    </div>
                </div>

                <div class="row">
                    <div class="col-md-4 mb-3">
                        <label>Price (INR)</label>
                        <input type="number" name="price" class="form-control" value="{{ $plan->price }}" step="0.01">
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Duration (Days)</label>
                        <input type="number" name="duration_days" class="form-control" value="{{ $plan->duration_days }}">
                    </div>
                </div>

                <hr>

                <h5 class="mb-3">Feature Access</h5>
                <div class="row">
                    @php 
                        $features = $plan->features ?? []; 
                    @endphp
                    <div class="col-md-3">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="features[]" value="ocr_import" id="f_ocr" {{ in_array('ocr_import', $features) ? 'checked' : '' }}>
                            <label class="form-check-label" for="f_ocr">OCR Scanner</label>
                        </div>
                    </div>
                    <div class="col-md-3">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" name="features[]" value="excel_import" id="f_excel" {{ in_array('excel_import', $features) ? 'checked' : '' }}>
                            <label class="form-check-label" for="f_excel">Excel Import</label>
                        </div>
                    </div>
                    <!-- Removed Auto Dialer & WhatsApp Sender as per request -->
                </div>

                <hr>

                <h5 class="mb-3">Usage Limits</h5>
                @php 
                    $limits = $plan->limits ?? []; 
                @endphp
                <div class="row">
                    <div class="col-md-4 mb-3">
                        <label>Max Daily Calls</label>
                        <input type="number" name="limit_daily_calls" class="form-control" value="{{ $limits['max_daily_calls'] ?? 0 }}">
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Max Contacts Storage</label>
                        <input type="number" name="limit_contacts" class="form-control" value="{{ $limits['max_contacts'] ?? 0 }}">
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Max OCR Scans/Day</label>
                        <input type="number" name="limit_ocr_scans" class="form-control" value="{{ $limits['max_ocr_scans'] ?? 0 }}">
                    </div>
                </div>

                <div class="row">
                    <div class="col-md-4 mb-3">
                        <label>Max Excel Imports/Day</label>
                         <input type="number" name="limit_excel_imports" class="form-control" value="{{ $limits['max_excel_imports'] ?? 2 }}">
                    </div>
                    <div class="col-md-4 mb-3">
                        <label>Session History (Hours)</label>
                        <input type="number" name="history_retention_hours" class="form-control" value="{{ $limits['history_retention_hours'] ?? 24 }}">
                        <small class="text-muted">Auto-delete after X hours</small>
                    </div>
                     <div class="col-md-4 mb-3">
                        <label class="d-block">Export Capabilities</label>
                        <div class="form-check mt-2">
                             <input type="hidden" name="allow_export" value="0">
                             <input class="form-check-input" type="checkbox" name="allow_export" id="allowExport" value="1" {{ ($limits['allow_export'] ?? 1) ? 'checked' : '' }}>
                             <label class="form-check-label" for="allowExport">Allow Exporting Reports</label>
                        </div>
                    </div>
                </div>

                <button type="submit" class="btn btn-primary mt-3">Update Plan</button>
            </form>
        </div>
    </div>
</div>
@endsection
