<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Queue\SerializesModels;

/**
 * Meme contenu que server/app/core/mail.py:_send_blocking (sujet, texte,
 * gabarit HTML) — un utilisateur ne doit voir aucune difference selon le
 * backend qui a traite sa demande.
 */
class LoginCodeMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(public readonly string $code)
    {
    }

    public function build(): self
    {
        return $this
            ->subject("{$this->code} — votre code MajiChrono")
            ->text('emails.login-code-text')
            ->view('emails.login-code')
            ->with(['code' => $this->code]);
    }
}
