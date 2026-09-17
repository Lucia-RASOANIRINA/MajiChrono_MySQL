<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class DriverState extends Model
{
    protected $table = 'drivers';

    protected $primaryKey = 'user_id';

    public $incrementing = false;

    public $timestamps = false;

    protected $fillable = [
        'user_id', 'online', 'kyc_status', 'lat', 'lng', 'fixed_at', 'updated_at',
    ];

    protected function casts(): array
    {
        return [
            'online' => 'boolean',
            'lat' => 'float',
            'lng' => 'float',
            'fixed_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (DriverState $state): void {
            $state->updated_at ??= Carbon::now();
        });
    }
}
