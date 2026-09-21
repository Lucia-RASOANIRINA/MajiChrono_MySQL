<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Conversation extends Model
{
    protected $table = 'conversations';

    public $timestamps = false;

    protected $casts = [
        'archived_at' => 'datetime',
        'blocked_at' => 'datetime',
        'deleted_at' => 'datetime',
    ];

    protected $fillable = [
        'delivery_id', 'client_id', 'admin_id', 'kind', 'status',
        'archived_at', 'blocked_at', 'blocked_by', 'deleted_at',
    ];

    public function messages(): HasMany
    {
        return $this->hasMany(ChatMessage::class, 'conversation_id');
    }
}
