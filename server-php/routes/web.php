<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;

// Preuve de deploiement (Phase 0) : confirme que PHP execute bien le code
// Laravel sur DirectAdmin sans passer par l'Application Manager, et que la
// connexion a la base hebergee fonctionne dans ce contexte-la aussi.
Route::get('/', function () {
    return response()->json(['status' => 'ok', 'message' => 'Laravel fonctionne sur DirectAdmin']);
});

Route::get('/health', function () {
    return response()->json(['status' => 'ok']);
});

// Pret = la base repond. En cas d'echec, la reponse dit **pourquoi** (acces
// refuse, base inconnue, serveur injoignable...) sans jamais exposer d'hote,
// d'utilisateur ni de mot de passe : sur un hebergement sans terminal, c'est
// le seul moyen de diagnostiquer sans ouvrir les journaux.
Route::get('/health/ready', function () {
    try {
        $count = DB::table('users')->count();
    } catch (Throwable $e) {
        $message = $e->getMessage();
        $reason = match (true) {
            str_contains($message, '[1045]') || str_contains($message, 'Access denied') => 'db_access_denied',
            str_contains($message, '[1044]') => 'db_no_privilege_on_database',
            str_contains($message, '[1049]') || str_contains($message, 'Unknown database') => 'db_unknown_database',
            str_contains($message, '[2002]') || str_contains($message, 'Connection refused')
                || str_contains($message, 'No such file') => 'db_unreachable',
            str_contains($message, '[2005]') || str_contains($message, 'getaddrinfo') => 'db_unknown_host',
            str_contains($message, '42S02') || str_contains($message, "doesn't exist") => 'db_missing_table',
            str_contains($message, 'could not find driver') => 'php_mysql_driver_missing',
            default => 'db_error',
        };
        Log::error('health_ready_failed', ['reason' => $reason, 'exception' => $message]);

        return response()->json([
            'status' => 'not_ready',
            'reason' => $reason,
            'config' => [
                'connection' => config('database.default'),
                'hostIsLocal' => in_array(config('database.connections.mysql.host'), ['localhost', '127.0.0.1'], true),
                'databaseSet' => filled(config('database.connections.mysql.database')),
                'usernameSet' => filled(config('database.connections.mysql.username')),
                'passwordSet' => filled(config('database.connections.mysql.password')),
            ],
        ], 503);
    }

    return response()->json(['status' => 'ready', 'users' => $count]);
});
