<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Gesture; // Assuming model exists in App\Models
use Illuminate\Http\Request;

class GestureController extends Controller
{
    public function index()
    {
        $gestures = Gesture::with('user')->latest()->paginate(15);
        return view('admin.gestures.index', compact('gestures'));
    }
}
