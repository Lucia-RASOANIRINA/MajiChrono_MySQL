<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Delivery;
use App\Models\DeliveryEvent;
use App\Models\DeliveryIncident;
use App\Models\DriverState;
use App\Models\DriverVehicle;
use App\Models\PositionSample;
use App\Models\Setting;
use App\Support\CurrentAccount;
use App\Support\DeliveryFare;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class DeliveryController extends Controller
{
    private const CANCELABLE = ['pending', 'accepted', 'assigned', 'picking_up'];

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

    /**
     * Qui fait avancer une course. Le livreur assigne la mene du depart a la
     * remise ; le client ne fait que confirmer la reception ; l'exploitation
     * peut tout. `assigned` ne s'obtient que par accept() ou une
     * reaffectation, `cancelled` que par cancel() : chacun a ses regles.
     */
    private const DRIVER_TARGETS = ['picking_up', 'picked_up', 'in_transit', 'awaiting_confirmation', 'delivered', 'failed'];

    private const CLIENT_TARGETS = ['delivered'];

    /** Delai de reflexion apres acceptation, pendant lequel le client annule sans frais. */
    private const FREE_CANCEL_SECONDS = 180;

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

    public function relayPoints(Request $request)
    {
        CurrentAccount::resolve($request);
        $district = $request->query('district');
        $lat = is_numeric($request->query('lat')) ? (float) $request->query('lat') : null;
        $lng = is_numeric($request->query('lng')) ? (float) $request->query('lng') : null;
        // Les relais sont de vraies boutiques partenaires : l'exploitation les
        // declare (reglage `relay_points`, tableau JSON). Aucun relais fictif
        // n'est annonce aux clients.
        $configured = json_decode((string) Setting::find('relay_points')?->value, true);
        $points = array_values(array_filter(
            is_array($configured) ? $configured : [],
            fn ($point): bool => is_array($point) && isset($point['id'], $point['point']['lat'], $point['point']['lng']),
        ));
        $items = array_values(array_filter(
            $points,
            fn (array $point): bool => $district === null || $point['district'] === $district,
        ));

        if ($lat !== null && $lng !== null) {
            foreach ($items as &$item) {
                $item['distanceKm'] = round($this->distanceKm(
                    $lat,
                    $lng,
                    $item['point']['lat'],
                    $item['point']['lng'],
                ), 2);
            }
            unset($item);
            usort($items, fn (array $a, array $b): int => $a['distanceKm'] <=> $b['distanceKm']);
        }

        return response()->json(['items' => $items]);
    }

    public function vehicle(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);
        $vehicle = DriverVehicle::find($account->id);

        return response()->json($vehicle?->jsonPayload() ?? [
            'type' => null,
            'validation' => 'pending',
        ]);
    }

    public function updateVehicle(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);
        $type = trim((string) $request->input('type', 'moto'));
        // Vocabulaire du mobile (moto, bicycle, car, tricycle, van) et ancien
        // vocabulaire du site (scooter, voiture, velo) : les deux sont acceptes.
        if (! in_array($type, ['moto', 'bicycle', 'car', 'tricycle', 'van', 'scooter', 'voiture', 'velo'], true)) {
            throw ApiException::unprocessable('invalid_type', 'Type de vehicule inconnu');
        }

        $vehicle = DriverVehicle::updateOrCreate(
            ['account_id' => $account->id],
            [
                'vehicle_type' => $type,
                'brand' => trim((string) $request->input('brand')) ?: null,
                'model' => trim((string) $request->input('model')) ?: null,
                'plate' => trim((string) $request->input('plate')) ?: null,
                'insurance_expiry' => trim((string) $request->input('insuranceExpiry')) ?: null,
                'validation' => 'pending',
                'updated_at' => Carbon::now(),
            ],
        );

        return response()->json($vehicle->jsonPayload());
    }

    public function trackingBatch(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);

        $points = $request->input('points');
        if (! is_array($points)) {
            throw ApiException::unprocessable('invalid_points', 'Les positions sont obligatoires');
        }
        if (count($points) > 50) {
            throw ApiException::unprocessable('batch_too_large', 'Lot de plus de 50 points');
        }

        $accepted = 0;
        $latest = null;
        foreach ($points as $point) {
            if (! is_array($point)) {
                continue;
            }
            $coords = is_array($point['point'] ?? null) ? $point['point'] : [];
            $lat = $coords['lat'] ?? $coords['latitude'] ?? null;
            $lng = $coords['lng'] ?? $coords['longitude'] ?? null;
            $fixedAt = $point['at'] ?? null;
            if (! is_numeric($lat) || ! is_numeric($lng) || ! is_string($fixedAt)) {
                continue;
            }

            $sample = PositionSample::firstOrCreate(
                ['driver_id' => $account->id, 'fixed_at' => $fixedAt],
                [
                    'delivery_id' => $point['deliveryId'] ?? null,
                    'lat' => (float) $lat,
                    'lng' => (float) $lng,
                    'accuracy_m' => is_numeric($point['accuracy'] ?? null) ? (float) $point['accuracy'] : null,
                ],
            );
            if ($sample->wasRecentlyCreated) {
                $accepted++;
            }
            if ($latest === null || strtotime($fixedAt) > strtotime((string) $latest['at'])) {
                $latest = ['lat' => (float) $lat, 'lng' => (float) $lng, 'at' => $fixedAt];
            }
        }

        if ($latest !== null) {
            $state = DriverState::firstOrCreate(['user_id' => $account->id]);
            if ($state->fixed_at === null || strtotime($latest['at']) > $state->fixed_at->timestamp) {
                $state->lat = $latest['lat'];
                $state->lng = $latest['lng'];
                $state->fixed_at = $latest['at'];
                $state->updated_at = Carbon::now();
                $state->save();
            }
        }

        return response()->json(['accepted' => $accepted, 'received' => count($points)]);
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

        // Attribution rapide : la course n'est proposee qu'aux livreurs equipes
        // du vehicule demande, et les plus proches du point de retrait la
        // voient en premier. Le premier qui accepte la prend (accept()).
        $driverVehicle = DriverVehicle::find($account->id)?->vehicle_type;
        $lat = $request->query('lat', $state->lat);
        $lng = $request->query('lng', $state->lng);

        $items = Delivery::where('status', 'pending')
            ->whereNull('driver_id')
            ->orderBy('created_at')
            ->get()
            ->filter(fn (Delivery $delivery) => DeliveryFare::servedBy($delivery->vehicle, $driverVehicle))
            ->map(fn (Delivery $delivery) => [
                // Avant acceptation, le livreur voit ou et quoi, pas les
                // numeros : ils ne sont transmis qu'a celui qui prend la course.
                'delivery' => $this->withoutContacts($delivery->jsonPayload()),
                'pickupDistanceKm' => ($lat !== null && $lng !== null)
                    ? round(DeliveryFare::distanceKm((float) $lat, (float) $lng, (float) $delivery->pickup_lat, (float) $delivery->pickup_lng), 2)
                    : 0,
                'estimatedEarning' => (int) round(((int) ($delivery->price_ariary ?: 0)) * 0.8),
            ])
            ->sortBy('pickupDistanceKm');

        return response()->json(['items' => $items->values()]);
    }

    public function accept(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $this->requireDriver($account);
        if ($account->kyc_status !== 'approved') {
            throw ApiException::forbidden('kyc_not_approved', 'Votre dossier n\'est pas encore valide : dossier en cours de validation');
        }

        if (! (bool) DriverState::find($account->id)?->online) {
            throw ApiException::conflict('driver_offline', 'Passez en ligne pour accepter une course');
        }

        $delivery = Delivery::find($id);
        if ($delivery === null) {
            throw ApiException::notFound('Course inconnue');
        }
        if ((string) $delivery->driver_id === (string) $account->id) {
            return response()->json($delivery->jsonPayload());
        }
        if (! DeliveryFare::servedBy($delivery->vehicle, DriverVehicle::find($account->id)?->vehicle_type)) {
            throw ApiException::conflict('vehicle_mismatch', 'Cette course demande un autre vehicule');
        }

        // Premier arrive, premier servi — et un seul : la mise a jour n'aboutit
        // que si la course est encore libre au moment precis de l'ecriture.
        // Deux livreurs qui appuient a la meme seconde ne peuvent pas tous les
        // deux recevoir « course acceptee ».
        $now = Carbon::now();
        $taken = DB::transaction(function () use ($id, $account, $now): bool {
            $updated = Delivery::where('id', $id)
                ->where('status', 'pending')
                ->whereNull('driver_id')
                ->update(['driver_id' => $account->id, 'status' => 'assigned', 'updated_at' => $now]);
            if ($updated !== 1) {
                return false;
            }
            $this->record(Delivery::find($id), $account->id, 'acceptation');

            return true;
        });

        $delivery = Delivery::find($id);
        if (! $taken) {
            if ($delivery->driver_id !== null) {
                throw ApiException::conflict('already_taken', 'Course deja prise');
            }
            throw ApiException::conflict('illegal_transition', 'La course n\'est plus a prendre');
        }

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
        $this->authorizeTransition($delivery, $account, $target);
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
        } elseif (! $account->isAdmin()) {
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

        // Vehicule demande : prix fixe recalcule par le serveur, qui fait foi.
        // Sans vehicule (ancienne version de l'application), la moto : le prix
        // et la zone sont toujours calcules ici, jamais repris du telephone.
        $vehicle = $request->input('vehicle') ?? 'moto';
        $package = (array) $request->input('package', []);
        $price = $request->input('price');
        if ($vehicle !== null) {
            if (! DeliveryFare::isVehicle($vehicle)) {
                throw ApiException::unprocessable('invalid_vehicle', 'Vehicule inconnu');
            }
            if (! DeliveryFare::canCarry($vehicle, $package['weight'] ?? null)) {
                throw ApiException::unprocessable('vehicle_too_small', 'Colis trop lourd pour ce vehicule');
            }
            if (! DeliveryFare::inZone($lat1, $lng1) || ! DeliveryFare::inZone($lat2, $lng2)) {
                throw ApiException::unprocessable('outside_service_area', 'MajiChrono livre a Majunga et ses environs');
            }
            $price = DeliveryFare::price($vehicle, $distance, $package, $request->input('kind'), $request->input('slot'));
        }

        $delivery = DB::transaction(function () use ($account, $request, $pickup, $dropoff, $lat1, $lng1, $lat2, $lng2, $distance, $vehicle, $price): Delivery {
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
                'price_ariary' => $price,
                'vehicle' => $vehicle,
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

        // Le livreur qui renonce avant d'avoir le colis ne l'annule pas pour
        // le client : il la rend. Elle repart aussitot aux autres livreurs.
        if (! $account->isAdmin() && (string) $delivery->driver_id === (string) $account->id) {
            $delivery->driver_id = null;
            $delivery->status = 'pending';
            $delivery->updated_at = Carbon::now();
            DB::transaction(function () use ($delivery, $account, $request): void {
                $delivery->save();
                $this->record($delivery, $account->id, 'liberee par le livreur'
                    .(($reason = trim((string) $request->input('reason'))) !== '' ? ' : '.mb_substr($reason, 0, 200) : ''));
            });

            return response()->json($delivery->jsonPayload());
        }

        // Frais d'annulation : seulement si un livreur s'est deja mis en route
        // et que le delai de reflexion est passe. L'exploitation n'en impose pas.
        $fee = 0;
        if (! $account->isAdmin() && in_array($delivery->status, ['assigned', 'accepted', 'picking_up'], true)) {
            $acceptedAt = DeliveryEvent::where('delivery_id', $delivery->id)
                ->where('status', 'assigned')->max('occurred_at');
            $elapsed = $acceptedAt === null ? PHP_INT_MAX : Carbon::parse($acceptedAt)->diffInSeconds(Carbon::now(), true);
            if ($elapsed > self::FREE_CANCEL_SECONDS) {
                $fee = max(1000, (int) round(((int) ($delivery->price_ariary ?: 5000)) * 0.20));
            }
        }
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
        $delivery = strlen($token) >= 32
            ? Delivery::where('tracking_token', $token)->first()
            : Delivery::findByTrackingCode($token);

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
            // Suivi sans session : le quartier suffit a savoir ou en est le
            // colis. L'adresse exacte et le repere restent aux deux parties.
            'dropoffSummary' => (string) ($delivery->place('dropoff_json', '')['district'] ?? ''),
            'updatedAt' => optional($delivery->updated_at)->toIso8601String(),
            'events' => $events->values(),
        ]);
    }

    private function record(Delivery $delivery, int $actorId, ?string $note): void
    {
        DeliveryEvent::create([
            'delivery_id' => $delivery->id,
            'status' => $delivery->status,
            'actor_id' => $actorId,
            'note' => $note,
            'occurred_at' => Carbon::now(),
        ]);
    }

    /**
     * Droit de mener la course vers `$target`, selon qui le demande. L'ordre
     * des etapes, lui, reste verifie par TRANSITIONS.
     */
    private function authorizeTransition(Delivery $delivery, $account, string $target): void
    {
        if ($target === 'assigned') {
            throw ApiException::conflict('illegal_transition', 'Une course s\'accepte, elle ne se force pas');
        }
        if ($target === 'cancelled') {
            throw ApiException::conflict('illegal_transition', 'Utilisez l\'annulation');
        }
        if ($account->isAdmin()) {
            return;
        }
        if ((string) $delivery->driver_id === (string) $account->id && in_array($target, self::DRIVER_TARGETS, true)) {
            return;
        }
        // Le client confirme la reception, une fois le livreur arrive.
        if ((string) $delivery->client_id === (string) $account->id
            && in_array($target, self::CLIENT_TARGETS, true)
            && $delivery->status === 'awaiting_confirmation') {
            return;
        }

        throw ApiException::forbidden('role_forbidden', 'Cette etape ne vous revient pas');
    }

    /** Fiche de course sans les numeros de contact. */
    private function withoutContacts(array $payload): array
    {
        foreach (['pickup', 'dropoff'] as $side) {
            if (isset($payload[$side]['contactPhone'])) {
                $payload[$side]['contactPhone'] = null;
            }
        }

        return $payload;
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
        return $account->isAdmin()
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
