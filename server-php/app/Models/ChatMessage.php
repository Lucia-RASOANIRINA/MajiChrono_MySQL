<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ChatMessage extends Model
{
    protected $table = 'conversation_messages';

    public $timestamps = false;

    protected $fillable = ['conversation_id', 'sender_id', 'body', 'created_at', 'read_at'];

    protected function casts(): array
    {
        return ['created_at' => 'datetime', 'read_at' => 'datetime'];
    }
}
