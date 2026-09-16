<?php

namespace App\Support;

use Illuminate\Support\Facades\Log;

/**
 * Equivalent de server/app/core/sms.py : la passerelle SMS reelle n'est pas
 * encore branchee. Journalise sans jamais envoyer ni lever — un appelant ne
 * doit pas pouvoir distinguer ce cas d'un vrai succes cote HTTP (le code
 * reste utilisable via `debugCode` en developpement).
 */
class SmsSender
{
    public static function sendLoginCode(string $phoneE164, string $code): void
    {
        Log::info('SMS reel a venir — code non envoye (fonctionnalite indisponible).', [
            'destinataire' => self::mask($phoneE164),
        ]);
    }

    private static function mask(string $phone): string
    {
        return mb_strlen($phone) <= 4 ? $phone : mb_substr($phone, 0, -4).'****';
    }
}
