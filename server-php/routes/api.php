<?php

use App\Http\Controllers\AddressController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\MeController;
use App\Http\Controllers\MediaController;
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

Route::get('/me', [MeController::class, 'show']);
Route::patch('/me', [MeController::class, 'update']);
Route::post('/me/avatar', [MeController::class, 'uploadAvatar']);
Route::delete('/me/avatar', [MeController::class, 'deleteAvatar']);
Route::get('/accounts/{accountId}/avatar', [MeController::class, 'readAvatar']);

Route::prefix('addresses')->group(function () {
    Route::get('', [AddressController::class, 'index']);
    Route::post('', [AddressController::class, 'store']);
    Route::patch('/{addressId}', [AddressController::class, 'update']);
    Route::delete('/{addressId}', [AddressController::class, 'destroy']);
});

Route::post('/media', [MediaController::class, 'store']);
Route::get('/media/{mediaId}', [MediaController::class, 'show']);
