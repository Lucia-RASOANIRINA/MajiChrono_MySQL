<?php

namespace App\Support;

use App\Mail\LoginCodeMail;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use RuntimeException;

/**
 * Equivalent de server/app/core/mail.py. Sans SMTP configure, le code part
 * dans le journal plutot que de donner l'illusion d'un envoi reussi.
 */
class MailSender
{
    public static function sendLoginCode(string $toAddress, string $code): void
    {
        if (! self::emailsAreReal()) {
            Log::warning('AUCUN SMTP CONFIGURE — code non envoye.', [
                'destinataire' => $toAddress,
                'code' => $code,
            ]);

            return;
        }

        try {
            Mail::to($toAddress)->send(new LoginCodeMail($code));
        } catch (\Throwable $error) {
            Log::error('envoi SMTP refuse : '.$error->getMessage());

            throw new RuntimeException('mail_provider_rejected', previous: $error);
        }

        Log::info('code envoye a '.self::mask($toAddress));
    }

    public static function emailsAreReal(): bool
    {
        return filled(config('mail.mailers.smtp.host'))
            && filled(config('mail.mailers.smtp.username'))
            && filled(config('mail.mailers.smtp.password'));
    }

    /** `hery.rakoto@gmail.com` devient `h***o@gmail.com` (EXI-T10). */
    private static function mask(string $address): string
    {
        [$local, $domain] = array_pad(explode('@', $address, 2), 2, '');
        if (mb_strlen($local) <= 2) {
            return mb_substr($local, 0, 1)."***@{$domain}";
        }

        return mb_substr($local, 0, 1).'***'.mb_substr($local, -1)."@{$domain}";
    }
}
