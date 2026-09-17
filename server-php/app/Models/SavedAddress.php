<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Une entree du carnet d'adresses (table `addresses`, EXI-C05).
 *
 * Le compte proprietaire vit dans la colonne heritee `user_id` (entier, cle
 * vers `users.id`) -- pas dans la colonne `account_id` (varchar) ajoutee
 * plus tard et laissee inutilisee, exactement comme le fait le modele
 * SQLAlchemy actuel (`mapped_column("user_id", ...)`).
 */
class SavedAddress extends Model
{
    protected $table = 'addresses';

    const UPDATED_AT = null;

    protected $fillable = [
        'user_id', 'kind', 'label', 'full_address', 'city', 'lat', 'lng', 'is_default', 'payload', 'use_count',
    ];

    protected function casts(): array
    {
        return [
            'lat' => 'float',
            'lng' => 'float',
            'is_default' => 'boolean',
            'created_at' => 'datetime',
        ];
    }

    public function toMobileJson(): array
    {
        return [
            'id' => $this->id,
            'kind' => $this->kind,
            'label' => $this->label,
            'address' => $this->payload ? json_decode($this->payload, true) : ['summary' => $this->full_address],
            'useCount' => $this->use_count ?? 0,
            'createdAt' => optional($this->created_at)->toIso8601String(),
        ];
    }
}
