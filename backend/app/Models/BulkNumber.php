<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BulkNumber extends Model
{
    use HasFactory;

    protected $fillable = [
        'session_id', 
        'phone_number', 
        'name', 
        'notes', 
        'status', 
        'last_called_at'
    ];

    protected $casts = [
        'last_called_at' => 'datetime',
        'phone_number' => 'encrypted',
        'name' => 'encrypted',
        'notes' => 'encrypted',
    ];

    public function session()
    {
        return $this->belongsTo(BulkSession::class, 'session_id');
    }
}
