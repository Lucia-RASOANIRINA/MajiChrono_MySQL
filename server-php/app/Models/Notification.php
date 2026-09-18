<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    protected $table = 'notifications';

    public $timestamps = false;

    protected $fillable = [
        'user_id', 'type', 'title', 'message', 'related_id', 'is_read', 'created_at',
    ];

    protected function casts(): array
    {
        return ['is_read' => 'boolean', 'created_at' => 'datetime'];
    }

    public function payload(): array
    {
        return [
            'id' => $this->id,
            'type' => $this->type,
            'title' => $this->title,
            'message' => $this->message,
            'relatedId' => $this->related_id,
            'isRead' => (bool) $this->is_read,
            'createdAt' => optional($this->created_at)->toIso8601String(),
        ];
    }
}
