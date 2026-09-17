<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeliveryEvent extends Model
{
    protected $table = 'delivery_events';

    public $timestamps = false;

    protected $fillable = ['delivery_id', 'status', 'actor_id', 'note', 'occurred_at'];

    protected function casts(): array
    {
        return ['occurred_at' => 'datetime'];
    }
}
