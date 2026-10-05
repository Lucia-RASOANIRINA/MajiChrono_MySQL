<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // Les plafonds sont comptes par IP **et** par identifiant vise : a
        // Majunga, des centaines d'abonnes Telma/Orange/Airtel sortent par la
        // meme IP (CGNAT). Un plafond par IP seul serait soit trop large pour
        // arreter une attaque, soit assez bas pour bloquer tout un quartier.

        // Connexion (mot de passe, cle d'appareil) : essais par numero/adresse.
        RateLimiter::for('auth-login', fn (Request $request) => [
            Limit::perMinute(10)->by('login:'.$this->identifier($request)),
            Limit::perMinute(60)->by('login-ip:'.$request->ip()),
        ]);

        // Envoi d'un code (SMS, e-mail) : chaque envoi coute et derange le
        // destinataire. Trois par quart d'heure et par destination.
        RateLimiter::for('auth-code', fn (Request $request) => [
            Limit::perMinutes(15, 3)->by('code:'.$this->identifier($request)),
            Limit::perHour(30)->by('code-ip:'.$request->ip()),
        ]);

        // Creation de compte et autres entrees publiques.
        RateLimiter::for('auth-public', fn (Request $request) => [
            Limit::perMinute(30)->by('auth-ip:'.$request->ip()),
        ]);

        // Suivi public sans session : de quoi suivre un colis, pas de quoi
        // essayer des codes au hasard.
        RateLimiter::for('public-track', fn (Request $request) => [
            Limit::perMinute(30)->by('track:'.$request->ip()),
        ]);

        // Tout le reste de l'API, par session quand il y en a une. Le suivi en
        // direct sonde toutes les quelques secondes : le plafond le permet.
        RateLimiter::for('api', function (Request $request) {
            $bearer = (string) $request->bearerToken();

            return Limit::perMinute(300)->by($bearer !== '' ? 'tok:'.sha1($bearer) : 'ip:'.$request->ip());
        });
    }

    private function identifier(Request $request): string
    {
        $raw = $request->input('phone') ?? $request->input('email') ?? $request->input('newEmail')
            ?? $request->input('newPhone') ?? '';

        return mb_strtolower(trim(is_string($raw) ? $raw : ''));
    }
}
