<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Review extends Model
{
    protected $table = 'reviews';

    public $timestamps = false;

    protected $fillable = [
        'delivery_id', 'rater_id', 'ratee_id', 'stars', 'punctuality', 'service', 'comment', 'created_at',
    ];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }

    public function payload(): array
    {
        return [
            'id' => $this->id,
            'deliveryId' => (string) $this->delivery_id,
            'raterId' => (string) $this->rater_id,
            'rateeId' => (string) $this->ratee_id,
            'stars' => $this->stars,
            'punctuality' => $this->punctuality,
            'service' => $this->service,
            'comment' => $this->comment,
            'createdAt' => optional($this->created_at)->toIso8601String(),
        ];
    }
}
