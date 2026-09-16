<?php

use App\Exceptions\ApiException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        // Sans prefixe "api/" : le mobile appelle /auth/..., /me, etc.
        // directement, comme sur le backend FastAPI qu'on remplace -- aucun
        // changement cote application n'est necessaire.
        api: __DIR__.'/../routes/api.php',
        apiPrefix: '',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        //
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Meme format d'erreur pour tout le monde : {"error": {...}}.
        // ApiException porte deja ce format ; les autres exceptions
        // (validation, 404 de route...) sont converties dans le meme moule
        // pour que l'intercepteur d'erreurs mobile n'ait qu'un seul contrat
        // a lire, quel que soit le backend.
        $exceptions->render(function (ApiException $e, Request $request) {
            if ($request->expectsJson() || $request->is('*')) {
                return response()->json($e->toResponse(), $e->statusCode);
            }
        });

        $exceptions->render(function (ValidationException $e, Request $request) {
            return response()->json([
                'error' => [
                    'code' => 'invalid_request',
                    'message' => 'Requete invalide',
                    'details' => ['fields' => $e->errors()],
                ],
            ], 422);
        });
    })->create();
