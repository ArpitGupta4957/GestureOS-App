<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BulkSession extends Model
{
    use HasFactory;

    protected $fillable = ['user_id', 'name', 'is_archived'];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function numbers()
    {
        return $this->hasMany(BulkNumber::class, 'session_id');
    }
}
