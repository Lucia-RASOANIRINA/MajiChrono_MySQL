<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Jeton de rafraichissement — table `refresh_tokens`. Une ligne par appareil
 * connecte ("famille" de session) ; pas de colonne `updated_at`.
 */
class RefreshToken extends Model
{
    protected $table = 'refresh_tokens';
    public $incrementing = false;
    protected $keyType = 'string';
    public $timestamps = false;

    protected $fillable = [
        'id', 'account_id', 'token_hash', 'family', 'device_label', 'expires_at', 'revoked_at', 'created_at',
    ];

    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'revoked_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (RefreshToken $token): void {
            $token->id ??= (string) Str::uuid();
            $token->created_at ??= Carbon::now();
        });
    }
}
