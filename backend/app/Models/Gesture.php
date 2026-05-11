<?php

declare(strict_types=1);

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\SoftDeletes;

class Gesture extends Model
{
    use SoftDeletes;
    /**
     * The attributes that are mass assignable.
     *
     * @var array<int, string>
     */
    protected $fillable = [
        'user_id',
        'uuid',
        'name',
        'trigger_text',
        'points_json',
        'action_type',
        'action_value',
        'is_synced',
        'is_favorite',
        'is_text_enabled',
        'is_shape_enabled',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'points_json' => 'array', // Unencrypted for Flutter compatibility
            'is_synced' => 'boolean',
            'is_favorite' => 'boolean',
            'is_text_enabled' => 'boolean',
            'is_shape_enabled' => 'boolean',
            'action_value' => 'encrypted', // Keep sensitive data encrypted
        ];
    }

    /**
     * Get the user that owns the gesture.
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
