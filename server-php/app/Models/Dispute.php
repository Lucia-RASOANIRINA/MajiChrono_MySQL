<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

class Dispute extends Model
{
    protected $table = 'disputes';

    public $timestamps = false;

    protected $fillable = [
        'delivery_id', 'status', 'reason', 'opened_by', 'opened_at',
        'decision_action', 'decision_reason', 'decided_at', 'decided_by',
    ];

    protected function casts(): array
    {
        return [
            'opened_at' => 'datetime',
            'decided_at' => 'datetime',
        ];
    }

    public function messages()
    {
        return $this->hasMany(DisputeMessage::class, 'dispute_id')->orderBy('sent_at');
    }

    public function isClosed(): bool
    {
        return in_array($this->status, ['resolved', 'rejected'], true);
    }

    public function payload(): array
    {
        $decision = $this->decision_action === null ? null : [
            'action' => $this->decision_action,
            'reason' => $this->decision_reason ?? '',
            'decidedAt' => optional($this->decided_at)->toIso8601String(),
            'decidedBy' => $this->decided_by,
        ];

        return [
            'id' => (string) $this->id,
            'deliveryId' => (string) $this->delivery_id,
            'status' => $this->status,
            'reason' => $this->reason,
            'openedBy' => $this->opened_by,
            'openedAt' => optional($this->opened_at)->toIso8601String(),
            'messages' => $this->messages->map(fn (DisputeMessage $message): array => $message->payload())->values()->all(),
            'decision' => $decision,
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Dispute $dispute): void {
            $dispute->status ??= 'open';
            $dispute->opened_at ??= Carbon::now();
        });
    }
}
