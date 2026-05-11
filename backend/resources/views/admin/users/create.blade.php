@extends('layouts.admin')

@section('title', 'Create User')

@section('content')
<div class="container-fluid">
    <div class="flex justify-between items-center mb-6">
        <h1 class="text-3xl font-bold text-white tracking-tight">CREATE NEW USER</h1>
        <a href="{{ route('admin.users.index') }}" class="btn" style="border: 1px solid #555; color: #aaa;">&larr; Back to List</a>
    </div>

    <div class="card shadow mb-4">
        <div class="card-body">
            <form action="{{ route('admin.users.store') }}" method="POST">
                @csrf
                
                <h5 class="mb-3 text-xl font-bold text-white">User Details</h5>
                
                <div class="row" style="display: flex; flex-wrap: wrap; gap: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Full Name</label>
                        <input type="text" name="name" required placeholder="John Doe" style="background: #000; border: 1px solid #333; padding: 10px; color: #fff; width: 100%; border-radius: 4px;">
                    </div>
                    
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Email Address</label>
                        <input type="email" name="email" required placeholder="john@example.com" style="background: #000; border: 1px solid #333; padding: 10px; color: #fff; width: 100%; border-radius: 4px;">
                    </div>
                </div>

                <div class="row mt-4" style="display: flex; flex-wrap: wrap; gap: 20px; margin-top: 20px;">
                    <div style="flex: 1; min-width: 300px;">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Password</label>
                        <input type="password" name="password" required minlength="8" placeholder="********" style="background: #000; border: 1px solid #333; padding: 10px; color: #fff; width: 100%; border-radius: 4px;">
                    </div>

                    <div style="flex: 1; min-width: 300px;">
                        <!-- Hidden Role Input (Default: User) -->
                        <input type="hidden" name="role" value="user">
                        <label class="block mb-2 text-sm font-bold text-gray-500">Account Type</label>
                        <input type="text" value="Standard App User" disabled style="background: #111; border: 1px solid #333; padding: 10px; color: #777; width: 100%; border-radius: 4px; cursor: not-allowed;">
                        <small style="color: #666; display: block; margin-top: 5px;">
                            * Only standard user accounts can be created here.
                        </small>
                    </div>
                </div>

                <div class="mt-6" style="margin-top: 30px;">
                    <button type="submit" class="btn btn-primary" style="padding: 10px 30px;">Create User</button>
                </div>

            </form>
        </div>
    </div>
</div>
@endsection
