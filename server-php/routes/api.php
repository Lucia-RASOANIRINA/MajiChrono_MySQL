<?php

use App\Http\Controllers\AuthController;
use Illuminate\Support\Facades\Route;

// Memes chemins que server/app/routers/auth.py (et ApiEndpoints.dart cote
// mobile) : aucun changement d'URL entre les deux backends.
Route::prefix('auth')->group(function () {
    Route::post('/otp/request', [AuthController::class, 'requestOtp']);
    Route::post('/otp/verify', [AuthController::class, 'verifyOtp']);
    Route::post('/phone/login', [AuthController::class, 'phoneLogin']);

    Route::post('/email/request', [AuthController::class, 'requestEmailCode']);
    Route::post('/email/verify', [AuthController::class, 'verifyEmailCode']);
    Route::post('/email/register', [AuthController::class, 'registerWithEmail']);

    Route::post('/refresh', [AuthController::class, 'refresh']);
    Route::post('/logout', [AuthController::class, 'logout']);
});
