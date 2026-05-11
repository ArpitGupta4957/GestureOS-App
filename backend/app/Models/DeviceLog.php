<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class DeviceLog extends Model
{
    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'user_id',
        'device_name',
        'app_version',
        'log_message',
    ];

    /**
     * Get the user that owns the device log.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
