@extends('layouts.admin')

@section('content')
<div class="container-fluid">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h1 class="h3 mb-0 text-gray-800">Subscription Plans</h1>
        <a href="{{ route('admin.plans.create') }}" class="btn btn-primary">
            <i class="fas fa-plus"></i> Create New Plan
        </a>
    </div>

    @if(session('success'))
        <div class="alert alert-success">{{ session('success') }}</div>
    @endif

    <div class="card shadow mb-4">
        <div class="card-body">
            <div class="table-responsive">
                <table class="table table-bordered" width="100%" cellspacing="0">
                    <thead>
                        <tr>
                            <th>Name</th>
                            <th>Type</th>
                            <th>Price</th>
                            <th>Duration</th>
                            <th>Features Enabled</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($plans as $plan)
                        <tr>
                            <td>{{ $plan->name }}</td>
                            <td>
                                <span class="badge badge-{{ $plan->plan_type == 'TRIAL' ? 'warning' : 'success' }}">
                                    {{ $plan->plan_type }}
                                </span>
                            </td>
                            <td>₹{{ $plan->price }}</td>
                            <td>{{ $plan->duration_days }} Days</td>
                            <td>
                                @if(is_array($plan->features))
                                    {{ count($plan->features) }} Features
                                @else
                                    0
                                @endif
                            </td>
                            <td>
                                <a href="{{ route('admin.plans.edit', $plan->id) }}" class="btn btn-sm btn-info">Edit</a>
                                <form action="{{ route('admin.plans.destroy', $plan->id) }}" method="POST" style="display:inline;">
                                    @csrf
                                    @method('DELETE')
                                    <button type="submit" class="btn btn-sm btn-danger" onclick="return confirm('Delete this plan?')">Delete</button>
                                </form>
                            </td>
                        </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
@endsection
