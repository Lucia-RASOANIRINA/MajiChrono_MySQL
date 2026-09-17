<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Str;

class DeliveryIncident extends Model
{
    protected $table = 'delivery_incidents';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $fillable = [
        'delivery_id', 'reporter_id', 'kind', 'description', 'photo_media_id',
        'lat', 'lng', 'resolution', 'created_at',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'float',
            'lng' => 'float',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (DeliveryIncident $incident): void {
            $incident->id ??= 'inc_'.Str::lower(Str::random(32));
        });
    }
}
