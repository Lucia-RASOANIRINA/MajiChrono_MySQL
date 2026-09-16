<?php

namespace App\Support;

use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Firebase\JWT\ExpiredException;
use Firebase\JWT\SignatureInvalidException;
use Illuminate\Support\Carbon;
use UnexpectedValueException;

/**
 * Empreintes et jetons — meme vocabulaire que server/app/core/security.py,
 * pour que le mobile n'ait rien a distinguer entre les deux backends.
 */
class Security
{
    /**
     * Empreinte bcrypt. PHP produit nativement le prefixe `$2y$` (celui du
     * site web existant) : contrairement a Python, aucune conversion n'est
     * necessaire ici.
     */
    public static function hashSecret(string $value): string
    {
        return password_hash($value, PASSWORD_BCRYPT, ['cost' => 10]);
    }

    /**
     * Verifie une empreinte sans jamais lever pour un simple echec.
     */
    public static function verifySecret(?string $hashed, string $value): bool
    {
        if (! $hashed) {
            return false;
        }

        return password_verify($value, $hashed);
    }

    /** Code a six chiffres, tire d'une source cryptographique. */
    public static function newNumericCode(int $digits = 6): string
    {
        $upper = 10 ** $digits;

        return str_pad((string) random_int(0, $upper - 1), $digits, '0', STR_PAD_LEFT);
    }

    /** Jeton opaque pour le refresh token — equivalent de secrets.token_urlsafe(48). */
    public static function newOpaqueToken(): string
    {
        return rtrim(strtr(base64_encode(random_bytes(48)), '+/', '-_'), '=');
    }

    /**
     * @return array{0: string, 1: Carbon} [jeton, date d'expiration]
     */
    public static function issueAccessToken(string $accountId, ?string $role, ?string $family = null): array
    {
        $now = Carbon::now();
        $expires = $now->copy()->addMinutes((int) config('majichrono.access_ttl_minutes'));

        $payload = [
            'sub' => $accountId,
            'role' => $role,
            'typ' => 'access',
            'fam' => $family,
            'exp' => $expires->timestamp,
            'iat' => $now->timestamp,
        ];

        $token = JWT::encode($payload, config('majichrono.jwt_secret'), 'HS256');

        return [$token, $expires];
    }

    /**
     * Revendications du jeton, ou null si invalide — signature, expiration,
     * type : une seule et meme reponse, pour ne renseigner aucun attaquant.
     */
    public static function readAccessToken(string $token): ?array
    {
        try {
            $claims = (array) JWT::decode($token, new Key(config('majichrono.jwt_secret'), 'HS256'));
        } catch (ExpiredException|SignatureInvalidException|UnexpectedValueException) {
            return null;
        }

        return ($claims['typ'] ?? null) === 'access' ? $claims : null;
    }
}
