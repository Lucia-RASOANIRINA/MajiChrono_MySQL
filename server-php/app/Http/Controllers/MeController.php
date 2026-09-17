<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Avatar;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Port de server/app/routers/me.py : le compte de la session courante.
 */
class MeController extends Controller
{
    private const MAX_AVATAR_BYTES = 700 * 1024;

    private const ALLOWED_AVATAR_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

    public function show(Request $request)
    {
        return response()->json(CurrentAccount::resolve($request)->toMobileJson());
    }

    public function update(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        $role = $request->input('role');
        if ($role !== null) {
            // Le role d'exploitation est attribue cote serveur uniquement
            // (EXI-T02) : une application qui le reclame doit etre refusee,
            // pas ignoree.
            if ($role === 'admin') {
                throw ApiException::forbidden('role_not_assignable', 'Le role administrateur est attribue cote serveur');
            }
            if (! in_array($role, ['client', 'driver'], true)) {
                throw ApiException::unprocessable('invalid_role', 'Role inconnu');
            }

            // Le profil ne se choisit qu'une fois : en changer changerait la
            // nature du compte et l'historique qui s'y rattache.
            if ($account->role !== null && $account->role !== $role) {
                throw ApiException::conflict('role_already_set', 'Profil deja defini');
            }

            $account->role = $role;
            if ($role === 'driver' && $account->kyc_status === null) {
                $account->kyc_status = 'draft';
            }
        }

        $firstName = $request->input('firstName');
        $lastName = $request->input('lastName');
        $displayName = $request->input('displayName');

        if ($firstName !== null || $lastName !== null) {
            if ($firstName !== null) {
                $account->first_name = trim($firstName) ?: null;
            }
            if ($lastName !== null) {
                $account->last_name = trim($lastName) ?: null;
            }
            $account->display_name = trim(implode(' ', array_filter([$account->first_name, $account->last_name])));
        } elseif ($displayName !== null) {
            $account->display_name = $displayName;
        }

        $account->save();

        return response()->json($account->toMobileJson());
    }

    public function uploadAvatar(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        $contentType = mb_strtolower(trim((string) $request->input('contentType')));
        if (! in_array($contentType, self::ALLOWED_AVATAR_TYPES, true)) {
            throw ApiException::unprocessable('unsupported_type', "Format d'image non accepte");
        }

        $raw = (string) $request->input('imageBase64');
        // Tolere un prefixe "data:image/...;base64," colle par certains encodeurs.
        if (str_starts_with(trim($raw), 'data:') && str_contains($raw, ',')) {
            $raw = explode(',', $raw, 2)[1];
        }

        $data = base64_decode($raw, true);
        if ($data === false) {
            throw ApiException::unprocessable('invalid_image', 'Image illisible');
        }
        if ($data === '') {
            throw ApiException::unprocessable('invalid_image', 'Image vide');
        }
        if (strlen($data) > self::MAX_AVATAR_BYTES) {
            throw ApiException::unprocessable('image_too_large', 'Image trop lourde', [
                'maxBytes' => self::MAX_AVATAR_BYTES,
            ]);
        }

        $now = Carbon::now();
        Avatar::updateOrCreate(
            ['account_id' => $account->id],
            ['data' => $data, 'content_type' => $contentType, 'updated_at' => $now],
        );

        $account->avatar_url = $this->avatarUrl($request, (string) $account->id, $now);
        $account->save();

        return response()->json($account->toMobileJson());
    }

    public function deleteAvatar(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        Avatar::where('account_id', $account->id)->delete();
        $account->avatar_url = null;
        $account->save();

        return response()->json($account->toMobileJson());
    }

    /**
     * Sert l'image, volontairement sans jeton : la balise <img> du mobile ne
     * peut pas porter d'en-tete d'authentification, et un avatar n'est pas
     * un secret. Le chemin est un identifiant opaque, non enumerable en
     * pratique.
     */
    public function readAvatar(string $accountId)
    {
        $avatar = Avatar::find($accountId);
        if ($avatar === null) {
            throw ApiException::notFound('Aucune photo pour ce compte');
        }

        return response($avatar->data, 200, [
            'Content-Type' => $avatar->content_type,
            'Cache-Control' => 'public, max-age=86400',
        ]);
    }

    private function avatarUrl(Request $request, string $accountId, Carbon $version): string
    {
        return "{$request->root()}/accounts/{$accountId}/avatar?v={$version->timestamp}";
    }
}
