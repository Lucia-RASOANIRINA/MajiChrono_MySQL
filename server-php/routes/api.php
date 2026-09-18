<?php

use App\Http\Controllers\AddressController;
use App\Http\Controllers\AdminController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\ChatController;
use App\Http\Controllers\DeliveryController;
use App\Http\Controllers\DisputeController;
use App\Http\Controllers\KycController;
use App\Http\Controllers\MeController;
use App\Http\Controllers\MediaController;
use App\Http\Controllers\PaymentController;
use App\Http\Controllers\ReviewController;
use App\Http\Controllers\SupportController;
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
    Route::post('/password/signin', [AuthController::class, 'signInWithPassword']);
    Route::post('/password/signup', [AuthController::class, 'signUpWithPassword']);
    Route::post('/password/reset', [AuthController::class, 'resetPassword']);
    Route::post('/email/change/request', [AuthController::class, 'requestEmailChange']);
    Route::post('/email/change/verify', [AuthController::class, 'verifyEmailChange']);
    Route::post('/phone/change/request', [AuthController::class, 'requestPhoneChange']);
    Route::post('/phone/change/verify', [AuthController::class, 'verifyPhoneChange']);
    Route::post('/email/link', [AuthController::class, 'linkEmail']);
    Route::post('/password/change', [AuthController::class, 'changePassword']);
    Route::get('/sessions', [AuthController::class, 'sessions']);
    Route::delete('/sessions/{family}', [AuthController::class, 'revokeSession']);

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
Route::get('/drivers/kyc/status', [KycController::class, 'status']);
Route::get('/drivers/kyc/messages', [KycController::class, 'messages']);
Route::post('/drivers/kyc/messages', [KycController::class, 'sendMessage']);
Route::post('/drivers/kyc/documents/{kind}', [KycController::class, 'upload']);
Route::delete('/drivers/kyc/documents/{kind}', [KycController::class, 'delete']);
Route::post('/drivers/kyc', [KycController::class, 'submit']);
Route::get('/accounts/{accountId}/kyc/{kind}', [KycController::class, 'read']);
Route::post('/reviews', [ReviewController::class, 'store']);
Route::get('/reviews/delivery/{deliveryId}', [ReviewController::class, 'show']);
Route::get('/notifications', [SupportController::class, 'notifications']);
Route::post('/notifications/{notificationId}/read', [SupportController::class, 'markNotificationRead']);
Route::post('/contact', [SupportController::class, 'contact']);
Route::get('/admin/contact', [SupportController::class, 'adminContacts']);
Route::post('/admin/contact/{messageId}/reply', [SupportController::class, 'replyContact']);
Route::get('/admin/dashboard', [AdminController::class, 'dashboard']);
Route::get('/admin/fleet', [AdminController::class, 'fleet']);
Route::get('/admin/users', [AdminController::class, 'users']);
Route::post('/admin/drivers/{driverId}/suspension', [AdminController::class, 'suspendDriver']);
Route::post('/admin/users/{accountId}/suspension', [AdminController::class, 'suspendUser']);
Route::get('/admin/moderation', [AdminController::class, 'moderation']);
Route::get('/admin/system/audit', [SupportController::class, 'audit']);
Route::get('/admin/settings', [SupportController::class, 'settings']);
Route::put('/admin/settings/{key}', [SupportController::class, 'updateSetting']);
Route::get('/disputes/{disputeId}/files', [SupportController::class, 'files']);
Route::post('/disputes/{disputeId}/files', [SupportController::class, 'addFile']);
Route::prefix('payments')->group(function () {
    Route::get('/balance', [PaymentController::class, 'balance']);
    Route::get('/history', [PaymentController::class, 'history']);
    Route::post('/intent', [PaymentController::class, 'createIntent']);
    Route::get('/{paymentId}', [PaymentController::class, 'show']);
    Route::post('/{paymentId}/claim', [PaymentController::class, 'claim']);
    Route::post('/{paymentId}/confirm', [PaymentController::class, 'confirm']);
    Route::post('/{paymentId}/cash', [PaymentController::class, 'cash']);
    Route::post('/withdraw', [PaymentController::class, 'withdraw']);
});
Route::get('/disputes', [DisputeController::class, 'index']);
Route::post('/disputes', [DisputeController::class, 'store']);
Route::get('/disputes/{disputeId}', [DisputeController::class, 'show']);
Route::post('/disputes/{disputeId}/messages', [DisputeController::class, 'message']);
Route::post('/disputes/{disputeId}/decision', [DisputeController::class, 'decision']);
Route::get('/conversations', [ChatController::class, 'conversations']);
Route::get('/deliveries/{deliveryId}/messages', [ChatController::class, 'messages']);
Route::post('/deliveries/{deliveryId}/messages', [ChatController::class, 'send']);
Route::post('/deliveries/{deliveryId}/messages/read', [ChatController::class, 'markRead']);
Route::get('/kyc', [KycController::class, 'queue']);
Route::get('/kyc/{driverId}/documents', [KycController::class, 'adminDocuments']);
Route::get('/kyc/{driverId}/messages', [KycController::class, 'adminMessages']);
Route::post('/kyc/{driverId}/messages', [KycController::class, 'adminSendMessage']);
Route::post('/kyc/{driverId}/review', [KycController::class, 'review']);
Route::get('/relay-points', [DeliveryController::class, 'relayPoints']);
Route::get('/track/{token}', [DeliveryController::class, 'track']);
Route::get('/public/track/{token}', [DeliveryController::class, 'track']);
Route::get('/deliveries/available', [DeliveryController::class, 'available']);
Route::post('/driver/status', [DeliveryController::class, 'driverStatus']);
Route::get('/driver/vehicle', [DeliveryController::class, 'vehicle']);
Route::patch('/driver/vehicle', [DeliveryController::class, 'updateVehicle']);
Route::post('/tracking/batch', [DeliveryController::class, 'trackingBatch']);
Route::prefix('deliveries')->group(function () {
    Route::get('', [DeliveryController::class, 'index']);
    Route::post('', [DeliveryController::class, 'store']);
    Route::get('/{id}', [DeliveryController::class, 'show']);
    Route::post('/{id}/cancel', [DeliveryController::class, 'cancel']);
    Route::post('/{id}/accept', [DeliveryController::class, 'accept']);
    Route::post('/{id}/status', [DeliveryController::class, 'status']);
    Route::post('/{id}/incidents', [DeliveryController::class, 'reportIncident']);
    Route::get('/{id}/incidents', [DeliveryController::class, 'incidents']);
});
