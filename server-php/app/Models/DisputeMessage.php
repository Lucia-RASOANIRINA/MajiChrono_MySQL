<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class DisputeMessage extends Model
{
    protected $table = 'dispute_messages';

    public $timestamps = false;

    protected $fillable = [
        'dispute_id', 'author_label', 'body', 'from_operations', 'sent_at',
    ];

    protected function casts(): array
    {
        return [
            'from_operations' => 'boolean',
            'sent_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (DisputeMessage $message): void {
            $message->sent_at ??= Carbon::now();
        });
    }

    public function payload(): array
    {
        return [
            'id' => (string) $this->id,
            'authorLabel' => $this->author_label,
            'body' => $this->body,
            'sentAt' => optional($this->sent_at)->toIso8601String(),
            'fromOperations' => (bool) $this->from_operations,
        ];
    }
}
