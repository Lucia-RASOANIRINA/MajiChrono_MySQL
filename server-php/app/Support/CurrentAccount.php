<?php

namespace App\Support;

use App\Exceptions\ApiException;
use App\Models\Account;
use Illuminate\Http\Request;

/**
 * Equivalent de server/app/core/deps.py:current_account. Utilise directement
 * dans chaque controleur (pas de guard Laravel) pour rester lisible comme
 * une phrase, meme esprit que les dependances FastAPI.
 */
class CurrentAccount
{
    public static function resolve(Request $request): Account
    {
        $authorization = $request->header('Authorization');
        if (! $authorization || ! str_starts_with(strtolower($authorization), 'bearer ')) {
            throw ApiException::unauthorized();
        }

        $claims = Security::readAccessToken(trim(substr($authorization, 7)));
        if ($claims === null) {
            throw ApiException::unauthorized();
        }

        $account = Account::find($claims['sub'] ?? null);
        if ($account === null) {
            throw ApiException::unauthorized();
        }

        // Un compte suspendu garde un jeton valide jusqu'a son expiration. On
        // le refuse ici plutot que d'attendre l'expiration naturelle.
        if ($account->suspended_at !== null) {
            throw ApiException::forbidden('account_suspended', 'Compte suspendu');
        }

        return $account;
    }
}
