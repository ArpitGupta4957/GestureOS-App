<?php

declare(strict_types=1);

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable, HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'mobile_number',
        'mobile_verified_at',
        'otp_code',
        'otp_expires_at',
        'password',
        'pin',
        'role',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'pin',
        'remember_token',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'mobile_verified_at' => 'datetime',
            'otp_expires_at' => 'datetime',
            'password' => 'hashed',
            'pin' => 'hashed',
            // 'name' => 'encrypted',
        ];
    }

    // Relationships
    public function subscription()
    {
        return $this->hasOne(Subscription::class)->latestOfMany();
    }

    public function trialUsages()
    {
        return $this->hasMany(TrialUsage::class);
    }

    /**
     * Get the gestures for the user.
     */
    public function gestures(): HasMany
    {
        return $this->hasMany(Gesture::class);
    }

    /**
     * Get the device logs for the user.
     */
    public function deviceLogs(): HasMany
    {
        return $this->hasMany(DeviceLog::class);
    }
}
