<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ModerationLog extends Model
{
    protected $table = 'moderation_logs';

    public $timestamps = false;

    protected $fillable = ['id', 'actor_id', 'subject_id', 'action', 'reason', 'decided_at'];

    protected function casts(): array
    {
        return ['decided_at' => 'datetime'];
    }

    public function payload(): array
    {
        return [
            'id' => (string) $this->id,
            'actorId' => (string) $this->actor_id,
            'subjectId' => (string) $this->subject_id,
            'action' => $this->action,
            'reason' => $this->reason,
            'decidedAt' => optional($this->decided_at)->toIso8601String(),
        ];
    }
}
