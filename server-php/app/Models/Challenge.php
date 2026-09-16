<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Defi OTP (SMS ou e-mail) — table `challenges`. Cle primaire en chaine
 * (UUID), pas de colonne `updated_at` : la table ne la definit pas.
 */
class Challenge extends Model
{
    protected $table = 'challenges';
    public $incrementing = false;
    protected $keyType = 'string';
    public $timestamps = false;

    protected $fillable = [
        'id', 'channel', 'destination', 'code_hash', 'attempts_left', 'expires_at', 'consumed_at', 'created_at',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'consumed_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Challenge $challenge): void {
            $challenge->id ??= (string) Str::uuid();
            $challenge->created_at ??= Carbon::now();
        });
    }

    public function isUsable(): bool
    {
        return $this->consumed_at === null && $this->expires_at->isFuture();
    }
}
