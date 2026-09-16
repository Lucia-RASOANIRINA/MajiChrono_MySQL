<?php

use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

// Preuve de deploiement (Phase 0) : confirme que PHP execute bien le code
// Laravel sur DirectAdmin sans passer par l'Application Manager, et que la
// connexion a la base hebergee fonctionne dans ce contexte-la aussi.
Route::get('/', function () {
    return response()->json(['status' => 'ok', 'message' => 'Laravel fonctionne sur DirectAdmin']);
});

Route::get('/health', function () {
    return response()->json(['status' => 'ok']);
});

Route::get('/health/ready', function () {
    $count = DB::table('users')->count();
    return response()->json(['status' => 'ready', 'users' => $count]);
});
