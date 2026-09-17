<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Delivery;
use App\Models\DeliveryEvent;
use App\Models\DeliveryIncident;
use App\Models\DriverState;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DeliveryController extends Controller
{
    private const CANCELABLE = ['pending', 'accepted', 'assigned'];

    private const INCIDENT_KINDS = [
        'sender_absent', 'recipient_absent', 'address_incorrect', 'package_damaged',
        'package_refused', 'accident', 'gps_problem', 'vehicle_problem',
        'payment_problem', 'other',
    ];

    private const TRANSITIONS = [
        'pending' => ['assigned', 'cancelled'],
        'assigned' => ['picking_up', 'picked_up', 'cancelled', 'failed'],
        'picking_up' => ['picked_up', 'cancelled', 'failed'],
        'picked_up' => ['in_transit', 'awaiting_confirmation', 'delivered', 'failed'],
        'in_transit' => ['awaiting_confirmation', 'delivered', 'failed'],
        'awaiting_confirmation' => ['delivered', 'failed'],
    ];

    public function driverStatus(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);
        $online = filter_var($request->input('online'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($online === null) {
            throw ApiException::unprocessable('invalid_online_status', 'Statut de disponibilite invalide');
        }
        if ($online && $account->kyc_status !== 'approved') {
            throw ApiException::forbidden('kyc_not_approved', 'Votre dossier n\'est pas encore valide');
        }

        $state = DriverState::updateOrCreate(
            ['user_id' => $account->id],
            ['online' => $online, 'updated_at' => Carbon::now()],
        );

        return response()->json([
            'driverId' => (string) $account->id,
            'online' => (bool) $state->online,
            'lat' => $state->lat,
            'lng' => $state->lng,
            'fixedAt' => optional($state->fixed_at)->toIso8601String(),
        ]);
    }

    public function available(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);
        if ($account->kyc_status !== 'approved') {
            return response()->json(['items' => []]);
        }

        $state = DriverState::find($account->id);
        if ($state === null || ! $state->online) {
            return response()->json(['items' => []]);
        }

        $items = Delivery::where('status', 'pending')
            ->whereNull('driver_id')
            ->orderBy('created_at')
            ->get()
            ->map(fn (Delivery $delivery) => [
                'delivery' => $delivery->jsonPayload(),
                'pickupDistanceKm' => 0,
                'estimatedEarning' => (int) round(((int) ($delivery->price_ariary ?: 0)) * 0.8),
            ]);

        return response()->json(['items' => $items->values()]);
    }

    public function accept(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);
        if ($account->kyc_status !== 'approved') {
            throw ApiException::forbidden('kyc_not_approved', 'Votre dossier n\'est pas encore valide : dossier en cours de validation');
        }

        $delivery = Delivery::find($id);
        if ($delivery === null) {
            throw ApiException::notFound('Course inconnue');
        }
        if ($delivery->driver_id !== null) {
            if ((string) $delivery->driver_id === (string) $account->id) {
                return response()->json($delivery->jsonPayload());
            }
            throw ApiException::conflict('already_taken', 'Course deja prise');
        }
        if ($delivery->status !== 'pending') {
            throw ApiException::conflict('illegal_transition', 'La course n\'est plus a prendre');
        }

        $delivery->driver_id = $account->id;
        $delivery->status = 'assigned';
        $delivery->updated_at = Carbon::now();
        DB::transaction(function () use ($delivery, $account): void {
            $delivery->save();
            $this->record($delivery, $account->id, 'acceptation');
        });

        return response()->json($delivery->jsonPayload());
    }

    public function status(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! $this->visible($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }

        $target = $request->input('incident') !== null
            ? 'failed'
            : $this->statusFromWire((string) $request->input('status'));
        if ($target === null) {
            throw ApiException::unprocessable('invalid_status', 'Statut ou incident requis');
        }
        if (! in_array($target, self::TRANSITIONS[$delivery->status] ?? [], true)) {
            throw ApiException::conflict('illegal_transition', 'Transition impossible depuis l\'etat courant', [
                'currentState' => $delivery->jsonPayload()['status'],
            ]);
        }

        $delivery->status = $target;
        $delivery->updated_at = Carbon::now();
        DB::transaction(function () use ($delivery, $account, $request): void {
            $delivery->save();
            $this->record($delivery, $account->id, $request->input('incident') ?: $request->input('note'));
        });

        return response()->json($delivery->jsonPayload());
    }

    public function reportIncident(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! $this->visible($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }
        $kind = (string) $request->input('kind');
        if (! in_array($kind, self::INCIDENT_KINDS, true)) {
            throw ApiException::unprocessable('invalid_kind', 'Type d incident inconnu');
        }

        $incident = DeliveryIncident::create([
            'delivery_id' => $delivery->id,
            'reporter_id' => $account->id,
            'kind' => $kind,
            'description' => trim((string) $request->input('description')) ?: null,
            'photo_media_id' => $request->input('photoId'),
            'lat' => $request->input('lat'),
            'lng' => $request->input('lng'),
            'resolution' => 'open',
            'created_at' => Carbon::now(),
        ]);

        return response()->json($this->incidentPayload($incident), 201);
    }

    public function incidents(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! $this->visible($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }

        $items = DeliveryIncident::where('delivery_id', $id)
            ->orderByDesc('created_at')->get()
            ->map(fn (DeliveryIncident $incident) => $this->incidentPayload($incident));

        return response()->json(['items' => $items->values()]);
    }

    public function index(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $query = Delivery::query()->orderByDesc('created_at');

        if ($account->role === 'client') {
            $query->where('client_id', $account->id);
        } elseif ($account->role === 'driver') {
            $query->where('driver_id', $account->id);
        } elseif (! in_array($account->role, ['admin', 'superadmin'], true)) {
            $query->whereRaw('1 = 0');
        }

        return response()->json(['items' => $query->get()->map->jsonPayload()->values()]);
    }

    public function store(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($account->role !== 'client') {
            throw ApiException::forbidden('role_forbidden', 'Seul un expediteur cree une course');
        }

        $pickup = $request->input('pickup');
        $dropoff = $request->input('dropoff');
        if (! is_array($pickup) || ! is_array($dropoff)
            || ! isset($pickup['point']['lat'], $pickup['point']['lng'])
            || ! isset($dropoff['point']['lat'], $dropoff['point']['lng'])) {
            throw ApiException::unprocessable('location_required', 'Les localisations de depart et d arrivee sont obligatoires');
        }

        $lat1 = (float) $pickup['point']['lat'];
        $lng1 = (float) $pickup['point']['lng'];
        $lat2 = (float) $dropoff['point']['lat'];
        $lng2 = (float) $dropoff['point']['lng'];
        if (! $this->inMadagascar($lat1, $lng1) || ! $this->inMadagascar($lat2, $lng2)) {
            throw ApiException::unprocessable('location_outside_madagascar', 'Les localisations doivent se trouver a Madagascar');
        }

        $distance = $this->distanceKm($lat1, $lng1, $lat2, $lng2);
        if ($distance < 0.05) {
            throw ApiException::unprocessable('invalid_distance', 'Le depart et l arrivee doivent etre differents');
        }

        $delivery = DB::transaction(function () use ($account, $request, $pickup, $dropoff, $lat1, $lng1, $lat2, $lng2, $distance): Delivery {
            $delivery = Delivery::create([
                'client_id' => $account->id,
                'kind' => $request->input('kind', 'standard'),
                'pickup_address' => substr((string) ($pickup['summary'] ?? ''), 0, 255),
                'dropoff_address' => substr((string) ($dropoff['summary'] ?? ''), 0, 255),
                'pickup_lat' => $lat1,
                'pickup_lng' => $lng1,
                'dropoff_lat' => $lat2,
                'dropoff_lng' => $lng2,
                'pickup_json' => json_encode($pickup, JSON_THROW_ON_ERROR),
                'dropoff_json' => json_encode($dropoff, JSON_THROW_ON_ERROR),
                'package_json' => json_encode($request->input('package', []), JSON_THROW_ON_ERROR),
                'distance_km' => round($distance, 3),
                'price_ariary' => $request->input('price'),
                'relay_point_id' => $request->input('relayPointId'),
                'payer' => $request->input('payer'),
                'shopping_json' => $request->has('shopping') ? json_encode($request->input('shopping'), JSON_THROW_ON_ERROR) : null,
                'tracking_token' => Str::random(40),
            ]);
            $this->record($delivery, $account->id, 'creation');

            return $delivery;
        });

        return response()->json($delivery->jsonPayload(), 201);
    }

    public function show(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! $this->visible($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }

        $events = DeliveryEvent::where('delivery_id', $delivery->id)
            ->orderBy('occurred_at')->get()
            ->map(fn (DeliveryEvent $event) => [
                'status' => $this->wireStatus($event->status),
                'actorId' => $event->actor_id,
                'note' => $event->note,
                'occurredAt' => optional($event->occurred_at)->toIso8601String(),
            ]);

        return response()->json([...$delivery->jsonPayload(), 'events' => $events->values()]);
    }

    public function cancel(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! $this->visible($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }
        if (! in_array($delivery->status, self::CANCELABLE, true)) {
            throw ApiException::conflict('illegal_transition', 'La course ne peut plus etre annulee', [
                'currentState' => $delivery->jsonPayload()['status'],
            ]);
        }

        $fee = $delivery->status === 'assigned'
            ? max(1000, (int) round(((int) ($delivery->price_ariary ?: 5000)) * 0.20))
            : 0;
        $delivery->status = 'cancelled';
        $delivery->cancel_reason = trim((string) $request->input('reason')) ?: null;
        $delivery->cancel_fee_ariary = $fee;
        $delivery->updated_at = Carbon::now();
        DB::transaction(function () use ($delivery, $account): void {
            $delivery->save();
            $this->record($delivery, $account->id, 'annulation');
        });

        return response()->json($delivery->jsonPayload());
    }

    public function track(string $token)
    {
        $delivery = Delivery::where('tracking_token', $token)->first();
        if ($delivery === null) {
            throw ApiException::notFound('Lien de suivi inconnu');
        }

        $events = DeliveryEvent::where('delivery_id', $delivery->id)->orderBy('occurred_at')->get()
            ->map(fn (DeliveryEvent $event) => [
                'status' => $this->wireStatus($event->status),
                'occurredAt' => optional($event->occurred_at)->toIso8601String(),
            ]);

        return response()->json([
            'status' => $delivery->jsonPayload()['status'],
            'dropoffSummary' => $delivery->place('dropoff_json', (string) $delivery->dropoff_address)['summary'] ?? '',
            'updatedAt' => optional($delivery->updated_at)->toIso8601String(),
            'events' => $events->values(),
        ]);
    }

    private function record(Delivery $delivery, int $actorId, string $note): void
    {
        DeliveryEvent::create([
            'delivery_id' => $delivery->id,
            'status' => $delivery->status,
            'actor_id' => $actorId,
            'note' => $note,
            'occurred_at' => Carbon::now(),
        ]);
    }

    private function requireDriver($account): void
    {
        if ($account->role !== 'driver') {
            throw ApiException::forbidden('role_forbidden', 'Seul un livreur peut effectuer cette action');
        }
    }

    private function statusFromWire(string $status): ?string
    {
        return [
            'en_attente' => 'pending',
            'acceptee' => 'assigned',
            'au_depart' => 'picking_up',
            'prise_en_charge' => 'picked_up',
            'en_transit' => 'in_transit',
            'a_destination' => 'awaiting_confirmation',
            'livree' => 'delivered',
            'annulee' => 'cancelled',
            'refusee' => 'failed',
        ][$status] ?? (array_key_exists($status, self::TRANSITIONS) ? $status : null);
    }

    private function incidentPayload(DeliveryIncident $incident): array
    {
        return [
            'id' => (string) $incident->id,
            'deliveryId' => (string) $incident->delivery_id,
            'kind' => $incident->kind,
            'description' => $incident->description,
            'photoId' => $incident->photo_media_id,
            'lat' => $incident->lat,
            'lng' => $incident->lng,
            'resolution' => $incident->resolution,
            'createdAt' => optional($incident->created_at)->toIso8601String(),
        ];
    }

    private function visible(Delivery $delivery, $account): bool
    {
        return in_array($account->role, ['admin', 'superadmin'], true)
            || (string) $delivery->client_id === (string) $account->id
            || (string) $delivery->driver_id === (string) $account->id;
    }

    private function wireStatus(string $status): string
    {
        return (new Delivery(['status' => $status]))->jsonPayload()['status'];
    }

    private function inMadagascar(float $lat, float $lng): bool
    {
        return $lat >= -26.0 && $lat <= -11.0 && $lng >= 42.0 && $lng <= 51.5;
    }

    private function distanceKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $radius = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return $radius * 2 * asin(sqrt($a));
    }
}
