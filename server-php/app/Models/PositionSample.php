<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class PositionSample extends Model
{
    protected $table = 'location_pings';

    public $timestamps = false;

    protected $fillable = [
        'driver_id', 'delivery_id', 'lat', 'lng', 'accuracy_m', 'fixed_at',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'float',
            'lng' => 'float',
            'accuracy_m' => 'float',
            'fixed_at' => 'datetime',
        ];
    }
}
