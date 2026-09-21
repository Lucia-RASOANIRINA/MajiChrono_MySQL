<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ChatMessage extends Model
{
    protected $table = 'conversation_messages';

    public $timestamps = false;

    protected $fillable = [
        'conversation_id', 'sender_id', 'body', 'created_at', 'read_at',
        'attachment_media_id', 'attachment_name', 'attachment_content_type',
    ];

    protected function casts(): array
    {
        return ['created_at' => 'datetime', 'read_at' => 'datetime'];
    }

    public function conversation(): BelongsTo
    {
        return $this->belongsTo(Conversation::class, 'conversation_id');
    }
}
