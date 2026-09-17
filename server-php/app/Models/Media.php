<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

/**
 * Photo televersee (colis a la declaration, EXI-C09) -- table `media`.
 */
class Media extends Model
{
    protected $table = 'media';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $fillable = ['id', 'account_id', 'data', 'content_type', 'created_at'];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }

    protected static function booted(): void
    {
        static::creating(function (Media $media): void {
            $media->id ??= 'med_'.Str::random(24);
            $media->created_at ??= Carbon::now();
        });
    }
}
