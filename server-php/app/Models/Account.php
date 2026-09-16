<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Compte utilisateur (table `users`, partagee avec le site web PHP existant).
 *
 * Deux portes d'entree facultatives : `phone` et `email`. La colonne `role`
 * a un DEFAULT 'client' NOT NULL cote base (heritage du site web) : un
 * compte fraichement cree par OTP a donc deja `role = 'client'` des sa
 * premiere lecture, meme si l'ecran de choix de profil n'a pas encore ete
 * traverse cote mobile. On reproduit ce comportement a l'identique plutot
 * que de le "corriger" ici.
 */
class Account extends Model
{
    protected $table = 'users';

    // Pas de colonne `updated_at` geree par nous specifiquement au-dela du
    // comportement par defaut de Laravel (la table en a une, avec le meme
    // nom) ; `created_at`/`updated_at` restent les valeurs par defaut.
    public $timestamps = true;

    protected $fillable = [
        'full_name',
        'email',
        'phone',
        'password_hash',
        'role',
        'status',
        'avatar_path',
        'first_name',
        'last_name',
        'display_name',
        'avatar_url',
        'rating',
        'kyc_status',
        'email_verified_at',
        'phone_verified_at',
    ];

    protected $hidden = [
        'password_hash',
        'otp_code',
        'otp_expires_at',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'phone_verified_at' => 'datetime',
            'suspended_at' => 'datetime',
            'rating' => 'float',
        ];
    }

    /**
     * Nom d'usage, recompose a partir du prenom/nom quand ils existent —
     * memes regles que `Account.to_json()` cote FastAPI.
     */
    public function resolvedDisplayName(): string
    {
        if (filled($this->display_name)) {
            return $this->display_name;
        }

        $parts = array_filter([$this->first_name, $this->last_name]);
        if ($parts) {
            return implode(' ', $parts);
        }

        return $this->full_name ?? '';
    }

    /**
     * Forme JSON envoyee au mobile — memes noms de champs que
     * `Account.to_json()` cote FastAPI, pour ne rien changer au contrat.
     */
    public function toMobileJson(): array
    {
        return [
            'id' => (string) $this->id,
            // Colonnes NOT NULL sans defaut sur la table heritee : MySQL les
            // coerce en '' en mode non strict quand on ne les fournit pas a
            // la creation (voir AuthController). On les renvoie a null au
            // mobile, comme le ferait une vraie absence de valeur.
            'phone' => filled($this->phone) ? $this->phone : null,
            'email' => filled($this->email) ? $this->email : null,
            'role' => $this->role,
            'firstName' => $this->first_name,
            'lastName' => $this->last_name,
            'displayName' => $this->resolvedDisplayName(),
            'avatarUrl' => $this->avatar_url,
            'rating' => $this->rating,
            'kycStatus' => $this->kyc_status,
            'createdAt' => optional($this->created_at)->toIso8601String(),
        ];
    }
}
