<?php

use App\Exceptions\ApiException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

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
        // Plafond general par session (limiteur `api`, AppServiceProvider) ;
        // les routes d'authentification ont en plus leurs propres plafonds.
        $middleware->throttleApi('api');
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

        // Route inconnue, methode refusee, trop de requetes... : toujours le
        // meme moule JSON, jamais la page HTML de Laravel.
        $exceptions->render(function (HttpExceptionInterface $e, Request $request) {
            $status = $e->getStatusCode();
            [$code, $message] = match ($status) {
                404 => ['not_found', 'Ressource introuvable'],
                405 => ['method_not_allowed', 'Methode non autorisee'],
                429 => ['too_many_requests', 'Trop de tentatives, reessayez dans un moment'],
                503 => ['unavailable', 'Service momentanement indisponible'],
                default => ['http_'.$status, 'Requete refusee'],
            };
            $details = [];
            $retryAfter = $e->getHeaders()['Retry-After'] ?? null;
            if ($retryAfter !== null) {
                $details['retryAfterSeconds'] = (int) $retryAfter;
            }

            return response()->json(
                ['error' => ['code' => $code, 'message' => $message] + ($details ? ['details' => $details] : [])],
                $status,
                $e->getHeaders(),
            );
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

        // Erreur imprevue : un 500 JSON sans trace (la trace va au journal).
        $exceptions->render(function (Throwable $e, Request $request) {
            if (config('app.debug')) {
                return null;
            }

            return response()->json(['error' => ['code' => 'server_error', 'message' => 'Erreur interne']], 500);
        });
    })->create();
