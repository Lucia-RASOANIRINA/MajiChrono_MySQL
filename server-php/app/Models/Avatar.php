<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Photo de profil, rangee en base (table `avatars`) plutot que sur le
 * disque -- celui d'un hebergement mutualise est ephemere.
 */
class Avatar extends Model
{
    protected $table = 'avatars';

    protected $primaryKey = 'account_id';

    public $incrementing = false;

    protected $keyType = 'string';

    public $timestamps = false;

    protected $fillable = ['account_id', 'data', 'content_type', 'updated_at'];

    protected function casts(): array
    {
        return ['updated_at' => 'datetime'];
    }
}
