<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ContactMessage extends Model
{
    protected $table = 'contact_messages';

    public $timestamps = false;

    protected $fillable = [
        'client_id', 'subject', 'message', 'status', 'admin_reply', 'replied_by',
        'replied_at', 'created_at', 'updated_at',
    ];

    protected function casts(): array
    {
        return ['replied_at' => 'datetime', 'created_at' => 'datetime', 'updated_at' => 'datetime'];
    }
}
