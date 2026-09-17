<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\SavedAddress;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;

/**
 * Port de server/app/routers/addresses.py.
 */
class AddressController extends Controller
{
    private const UNIQUE_KINDS = ['home', 'work'];

    private const KINDS = ['home', 'work', 'favorite', 'other'];

    public function index(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        $rows = SavedAddress::where('user_id', $account->id)
            ->orderByRaw('use_count IS NULL, use_count DESC')
            ->orderByDesc('created_at')
            ->get();

        return response()->json(['items' => $rows->map->toMobileJson()->all()]);
    }

    public function store(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $body = $this->validatedBody($request);

        [$lat, $lng] = $this->point($body['address']);
        $entry = SavedAddress::create([
            'user_id' => $account->id,
            'kind' => $body['kind'],
            'label' => trim($body['label']),
            'payload' => json_encode($body['address']),
            'full_address' => mb_substr(trim((string) ($body['address']['summary'] ?? '')), 0, 255),
            'city' => mb_substr(trim((string) ($body['address']['city'] ?? '')), 0, 80) ?: null,
            'lat' => $lat,
            'lng' => $lng,
            'use_count' => 0,
        ]);

        $this->demoteExisting($account->id, $body['kind'], $entry->id);

        return response()->json($entry->toMobileJson(), 201);
    }

    public function update(Request $request, int $addressId)
    {
        $account = CurrentAccount::resolve($request);
        $body = $this->validatedBody($request);

        $entry = SavedAddress::find($addressId);
        if ($entry === null || (int) $entry->user_id !== (int) $account->id) {
            throw ApiException::notFound('Adresse inconnue');
        }

        [$lat, $lng] = $this->point($body['address']);
        $entry->update([
            'label' => trim($body['label']),
            'kind' => $body['kind'],
            'payload' => json_encode($body['address']),
            'full_address' => mb_substr(trim((string) ($body['address']['summary'] ?? '')), 0, 255),
            'city' => mb_substr(trim((string) ($body['address']['city'] ?? '')), 0, 80) ?: null,
            'lat' => $lat,
            'lng' => $lng,
        ]);

        $this->demoteExisting($account->id, $body['kind'], $entry->id);

        return response()->json($entry->toMobileJson());
    }

    public function destroy(Request $request, int $addressId)
    {
        $account = CurrentAccount::resolve($request);

        $entry = SavedAddress::find($addressId);
        if ($entry !== null && (int) $entry->user_id === (int) $account->id) {
            $entry->delete();
        }

        return response()->noContent();
    }

    private function validatedBody(Request $request): array
    {
        $kind = $request->input('kind', 'other');
        if (! in_array($kind, self::KINDS, true)) {
            throw ApiException::unprocessable('invalid_kind', "Type d'adresse inconnu");
        }

        $address = $request->input('address');
        if (! is_array($address)) {
            throw ApiException::unprocessable('invalid_request', 'Adresse invalide');
        }

        return [
            'label' => mb_substr((string) $request->input('label', ''), 0, 120),
            'kind' => $kind,
            'address' => $address,
        ];
    }

    /** @return array{0: float, 1: float} */
    private function point(array $address): array
    {
        $point = $address['point'] ?? null;
        if (is_array($point)) {
            return [(float) ($point['lat'] ?? 0), (float) ($point['lng'] ?? 0)];
        }

        return [(float) ($address['lat'] ?? 0), (float) ($address['lng'] ?? 0)];
    }

    /**
     * Un compte n'a qu'un seul domicile et un seul lieu de travail : poser un
     * nouveau "home" deplace l'ancien vers "other".
     */
    private function demoteExisting(int $accountId, string $kind, int $keepId): void
    {
        if (! in_array($kind, self::UNIQUE_KINDS, true)) {
            return;
        }

        SavedAddress::where('user_id', $accountId)
            ->where('kind', $kind)
            ->where('id', '!=', $keepId)
            ->update(['kind' => 'other']);
    }
}
