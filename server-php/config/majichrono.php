<?php

// Equivalent de server/app/config.py (Settings) : memes noms de variables
// d'environnement, memes valeurs par defaut, pour ne rien changer au
// comportement observable du mobile en passant d'un backend a l'autre.

return [
    'jwt_secret' => env('JWT_SECRET', 'developpement-uniquement-jamais-en-production'),
    'access_ttl_minutes' => (int) env('ACCESS_TTL_MINUTES', 15),
    'refresh_ttl_days' => (int) env('REFRESH_TTL_DAYS', 30),

    'otp_ttl_minutes' => (int) env('OTP_TTL_MINUTES', 5),
    'otp_max_attempts' => (int) env('OTP_MAX_ATTEMPTS', 3),
    'otp_debug_codes' => (bool) env('OTP_DEBUG_CODES', false),

    'mail_from_address' => env('MAIL_FROM_ADDRESS', 'no-reply@majichrono.mg'),
    'mail_from_name' => env('MAIL_FROM_NAME', 'MajiChrono'),
];
