<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Delivery;
use App\Models\DeliveryEvent;
use App\Models\DriverState;
use App\Models\DriverVehicle;
use App\Models\ModerationLog;
use App\Models\Notification;
use App\Models\PositionSample;
use App\Support\CurrentAccount;
use App\Support\DeliveryFare;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Throwable;

/**
 * Terrain et exploitation : alerte d'urgence, constats de prise en charge et
 * de remise, trace en direct, reaffectation d'une course.
 *
 * Le mobile appelait deja ces routes ; elles n'existaient pas cote Laravel.
 * Le SOS d'un livreur, en particulier, partait dans le vide.
 */
class OperationsController extends Controller
{
    /** Etapes pendant lesquelles la position du livreur est montree au client. */
    private const LIVE_STATUSES = ['assigned', 'accepted', 'picking_up', 'picked_up', 'in_transit', 'awaiting_confirmation'];

    /** Une course se reaffecte tant que le colis n'est pas dans les mains du livreur. */
    private const REASSIGNABLE = ['pending', 'assigned', 'accepted', 'picking_up'];

    private const MIN_REASON_LENGTH = 10;

    // --- Alerte d'urgence ------------------------------------------------

    /**
     * Une alerte est **toujours** acceptee, meme incomplete : refuser un appel
     * a l'aide pour un champ manquant serait le pire comportement possible.
     * Rejouee depuis la file hors ligne, elle n'en cree pas une seconde.
     */
    public function raiseEmergency(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $id = substr(trim((string) $request->input('id')), 0, 64) ?: 'sos_'.Str::random(20);

        $existing = DB::table('emergency_alerts')->where('id', $id)->first();
        if ($existing !== null) {
            if ((string) $existing->account_id !== (string) $account->id) {
                throw ApiException::conflict('idempotency_key_reused', 'Identifiant d\'alerte deja utilise');
            }

            return response()->json($this->alertPayload($existing));
        }

        $point = $request->input('point');
        $lat = is_array($point) && is_numeric($point['lat'] ?? null) ? (float) $point['lat'] : null;
        $lng = is_array($point) && is_numeric($point['lng'] ?? null) ? (float) $point['lng'] : null;
        $deliveryId = $request->input('deliveryId');
        $battery = $request->input('battery');
        $now = Carbon::now();
        try {
            $raisedAt = Carbon::parse((string) $request->input('raisedAt', $now->toIso8601String()));
        } catch (Throwable) {
            $raisedAt = $now;
        }

        DB::table('emergency_alerts')->insert([
            'id' => $id,
            'account_id' => $account->id,
            'kind' => substr((string) $request->input('kind', 'other'), 0, 40),
            'lat' => $lat,
            'lng' => $lng,
            'delivery_id' => is_numeric($deliveryId) ? (int) $deliveryId : null,
            'battery' => is_numeric($battery) ? max(0, min(100, (int) $battery)) : null,
            'raised_at' => $raisedAt,
            'received_at' => $now,
        ]);

        // Toute l'exploitation est prevenue, tout de suite.
        $where = $lat !== null && $lng !== null ? sprintf(' — position %.5f, %.5f', $lat, $lng) : ' — position inconnue';
        foreach (Account::whereIn('role', Account::ADMIN_ROLES)->pluck('id') as $adminId) {
            Notification::create([
                'user_id' => $adminId,
                'type' => 'emergency',
                'title' => 'ALERTE SOS — '.$account->resolvedDisplayName(),
                'message' => 'Alerte '.$request->input('kind', 'other').' de '.($account->phone ?: 'livreur #'.$account->id).$where,
                'is_read' => false,
                'created_at' => $now,
            ]);
        }

        return response()->json(
            $this->alertPayload(DB::table('emergency_alerts')->where('id', $id)->first()),
            201,
        );
    }

    /** L'exploitation voit toutes les alertes ; un livreur, les siennes. */
    public function emergencies(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $query = DB::table('emergency_alerts')->orderByDesc('received_at')->limit(200);
        if (! $account->isAdmin()) {
            $query->where('account_id', $account->id);
        }
        if ($request->query('unacknowledged') === 'true') {
            $query->whereNull('acknowledged_at');
        }

        return response()->json(['items' => $query->get()->map(fn ($row) => $this->alertPayload($row))->values()]);
    }

    public function acknowledgeEmergency(Request $request, string $alertId)
    {
        $admin = $this->admin($request);
        $updated = DB::table('emergency_alerts')->where('id', $alertId)->whereNull('acknowledged_at')
            ->update(['acknowledged_at' => Carbon::now(), 'acknowledged_by' => $admin->id]);
        $row = DB::table('emergency_alerts')->where('id', $alertId)->first();
        if ($row === null) {
            throw ApiException::notFound('Alerte inconnue');
        }
        if ($updated === 1) {
            Notification::create([
                'user_id' => $row->account_id,
                'type' => 'emergency',
                'title' => 'Alerte prise en compte',
                'message' => 'L\'exploitation a vu votre alerte et s\'en occupe.',
                'is_read' => false,
                'created_at' => Carbon::now(),
            ]);
        }

        return response()->json($this->alertPayload($row));
    }

    private function alertPayload(object $row): array
    {
        $account = Account::find($row->account_id);

        return [
            'id' => $row->id,
            'driverId' => (string) $row->account_id,
            'driverName' => $account?->resolvedDisplayName(),
            'kind' => $row->kind,
            'point' => $row->lat === null ? null : ['lat' => (float) $row->lat, 'lng' => (float) $row->lng],
            'deliveryId' => $row->delivery_id === null ? null : (string) $row->delivery_id,
            'battery' => $row->battery === null ? null : (int) $row->battery,
            'raisedAt' => $this->iso($row->raised_at),
            'receivedAt' => $this->iso($row->received_at),
            'acknowledgedAt' => $this->iso($row->acknowledged_at),
        ];
    }

    // --- Constats de prise en charge et de remise ------------------------

    public function custodyPickup(Request $request, string $id)
    {
        return $this->acceptCustody($request, $id, 'pickup');
    }

    public function custodyHandover(Request $request, string $id)
    {
        return $this->acceptCustody($request, $id, 'handover');
    }

    /**
     * Enregistre un constat scelle par le livreur.
     *
     * Le serveur **recalcule l'empreinte** sur le corps canonique (le constat
     * sans son enveloppe : id, hash, sealedAt, serverTimestamp) et refuse
     * toute incoherence. Sans ce controle, la preuve deviendrait declarative.
     * La remise doit chainer sur la prise en charge enregistree, et un constat
     * scelle ne se remplace pas.
     */
    private function acceptCustody(Request $request, string $id, string $stage)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! $this->isParty($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }
        if ((string) $delivery->driver_id !== (string) $account->id) {
            throw ApiException::forbidden('role_forbidden', 'Seul le livreur de la course etablit un constat');
        }

        $body = json_decode($request->getContent(), false);
        if (! $body instanceof \stdClass) {
            throw ApiException::unprocessable('invalid_report', 'Constat illisible');
        }
        $claimed = is_string($body->hash ?? null) ? strtolower($body->hash) : null;
        if ($claimed === null || preg_match('/^[0-9a-f]{64}$/', $claimed) !== 1) {
            throw ApiException::unprocessable('missing_hash', 'Empreinte absente');
        }
        if (($body->stage ?? null) !== $stage || (string) ($body->deliveryId ?? '') !== (string) $delivery->id) {
            throw ApiException::unprocessable('invalid_report', 'Constat d\'une autre etape ou d\'une autre course');
        }

        $recomputed = hash('sha256', self::canonicalJson($body));
        if (! hash_equals($recomputed, $claimed)) {
            throw ApiException::unprocessable('hash_mismatch', 'Empreinte incoherente avec le contenu');
        }

        $previous = is_string($body->previousHash ?? null) ? strtolower($body->previousHash) : null;
        if ($stage === 'handover') {
            $pickup = DB::table('custody_reports')->where('delivery_id', $delivery->id)->where('stage', 'pickup')->first();
            if ($pickup === null) {
                throw ApiException::conflict('missing_pickup', 'Aucun constat de prise en charge');
            }
            if ($previous !== $pickup->hash) {
                throw ApiException::unprocessable('chain_broken', 'Le constat de remise ne chaine pas sur la prise en charge');
            }
        }

        $existing = DB::table('custody_reports')->where('delivery_id', $delivery->id)->where('stage', $stage)->first();
        if ($existing !== null) {
            if ($existing->hash !== $claimed) {
                throw ApiException::conflict('already_sealed', 'Un constat scelle existe deja pour cette etape');
            }

            return response()->json($this->custodyPayload($existing));
        }

        $now = Carbon::now();
        DB::table('custody_reports')->insert([
            'delivery_id' => $delivery->id,
            'stage' => $stage,
            'report_id' => substr((string) ($body->id ?? ''), 0, 64),
            'hash' => $claimed,
            'previous_hash' => $previous,
            'submitted_by' => $account->id,
            'body_json' => $request->getContent(),
            'server_timestamp' => $now,
        ]);

        return response()->json(
            $this->custodyPayload(DB::table('custody_reports')->where('delivery_id', $delivery->id)->where('stage', $stage)->first()),
            201,
        );
    }

    public function custody(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! ($this->isParty($delivery, $account) || $account->isAdmin())) {
            throw ApiException::notFound('Course inconnue');
        }
        $rows = DB::table('custody_reports')->where('delivery_id', $delivery->id)->get()->keyBy('stage');

        return response()->json([
            'pickup' => isset($rows['pickup']) ? $this->custodyPayload($rows['pickup']) : null,
            'handover' => isset($rows['handover']) ? $this->custodyPayload($rows['handover']) : null,
        ]);
    }

    /**
     * Meme serialisation que `jsonEncode` cote Dart : ordre des cles conserve,
     * ni `/` ni caracteres non ASCII echappes, `1.0` garde sa decimale.
     */
    public static function canonicalJson(\stdClass $body): string
    {
        $canonical = clone $body;
        unset($canonical->id, $canonical->hash, $canonical->sealedAt, $canonical->serverTimestamp);

        $json = json_encode(
            $canonical,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_LINE_TERMINATORS | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR,
        );

        // PHP ecrit `1.0e-7` la ou Dart ecrit `1e-7` : on aligne les nombres
        // en notation scientifique, sans toucher au contenu des chaines.
        return preg_replace_callback(
            '/"(?:[^"\\\\]|\\\\.)*"|(-?\d+)\.0(e[+-]?\d+)/',
            fn (array $m): string => isset($m[1]) && $m[1] !== '' ? $m[1].$m[2] : $m[0],
            $json,
        );
    }

    private function custodyPayload(object $row): array
    {
        $body = json_decode((string) $row->body_json, true) ?: [];

        return [...$body, 'serverTimestamp' => $this->iso($row->server_timestamp)];
    }

    // --- Trace en direct --------------------------------------------------

    public function trace(Request $request, string $id)
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($id);
        if ($delivery === null || ! ($this->isParty($delivery, $account) || $account->isAdmin())) {
            throw ApiException::notFound('Course inconnue');
        }

        $payload = $delivery->jsonPayload();
        $live = $delivery->driver_id !== null && in_array($delivery->status, self::LIVE_STATUSES, true);

        // Position du livreur : seulement pendant la course. Une fois le colis
        // remis, le client n'a plus a savoir ou se trouve le livreur.
        $position = null;
        $trace = [];
        $eta = null;
        if ($live) {
            $state = DriverState::find($delivery->driver_id);
            if ($state !== null && $state->lat !== null && $state->lng !== null) {
                $position = ['lat' => (float) $state->lat, 'lng' => (float) $state->lng];
                $before = in_array($delivery->status, ['assigned', 'accepted', 'picking_up'], true);
                $target = $before
                    ? [(float) $delivery->pickup_lat, (float) $delivery->pickup_lng]
                    : [(float) $delivery->dropoff_lat, (float) $delivery->dropoff_lng];
                $km = DeliveryFare::distanceKm($position['lat'], $position['lng'], $target[0], $target[1]);
                if ($before) {
                    $km += (float) $delivery->distance_km;
                }
                // Vitesse moyenne en ville a Majunga : ~18 km/h, arrets compris.
                $eta = (int) max(1, ceil($km / 18 * 60));
            }

            $samples = PositionSample::where('delivery_id', $delivery->id)->orderBy('fixed_at')->get(['lat', 'lng']);
            $step = max(1, (int) ceil($samples->count() / 200));
            foreach ($samples->values() as $index => $sample) {
                if ($index % $step === 0) {
                    $trace[] = ['lat' => $sample->lat, 'lng' => $sample->lng];
                }
            }
        }

        $driver = $delivery->driver_id === null ? null : Account::find($delivery->driver_id);
        $vehicle = $driver === null ? null : DriverVehicle::find($driver->id);

        return response()->json([
            'deliveryId' => (string) $delivery->id,
            'status' => $payload['status'],
            'driverPosition' => $position,
            'trace' => $trace,
            'etaMinutes' => $eta,
            'trackingToken' => $delivery->tracking_token,
            'driver' => $driver === null ? null : [
                'id' => (string) $driver->id,
                'displayName' => $driver->resolvedDisplayName(),
                // Le numero complet n'est jamais transmis a l'autre partie.
                'maskedPhone' => $this->maskPhone($driver->phone),
                'rating' => $driver->rating,
                'plate' => $vehicle?->plate,
                'vehicleModel' => trim(($vehicle?->brand ?? '').' '.($vehicle?->model ?? '')) ?: null,
            ],
            'timeline' => DeliveryEvent::where('delivery_id', $delivery->id)->orderBy('occurred_at')->get()
                ->map(fn (DeliveryEvent $event) => [
                    'status' => (new Delivery(['status' => $event->status]))->jsonPayload()['status'],
                    'at' => optional($event->occurred_at)->toIso8601String(),
                ])->values(),
        ]);
    }

    // --- Reaffectation ----------------------------------------------------

    /**
     * L'exploitation confie la course a un autre livreur : motif obligatoire,
     * livreur valide, en ligne, non suspendu et equipe du bon vehicule.
     * Jamais apres la prise en charge : le colis est deja dans des mains.
     */
    public function reassign(Request $request, string $id)
    {
        $admin = $this->admin($request);
        $delivery = Delivery::find($id);
        if ($delivery === null) {
            throw ApiException::notFound('Course inconnue');
        }
        $reason = trim((string) $request->input('reason'));
        if (mb_strlen($reason) < self::MIN_REASON_LENGTH) {
            throw ApiException::unprocessable('reason_required', 'Motif obligatoire', ['minLength' => self::MIN_REASON_LENGTH]);
        }
        if (! in_array($delivery->status, self::REASSIGNABLE, true)) {
            throw ApiException::conflict('illegal_transition', 'Le colis est deja pris en charge', [
                'currentState' => $delivery->jsonPayload()['status'],
            ]);
        }

        $target = Account::where('id', $request->input('driverId'))->where('role', 'driver')->first();
        if ($target === null) {
            throw ApiException::notFound('Livreur inconnu');
        }
        $online = (bool) DriverState::find($target->id)?->online;
        if ($target->suspended_at !== null || $target->kyc_status !== 'approved' || ! $online) {
            throw ApiException::conflict('driver_unavailable', 'Livreur indisponible');
        }
        if (! DeliveryFare::servedBy($delivery->vehicle, DriverVehicle::find($target->id)?->vehicle_type)) {
            throw ApiException::conflict('vehicle_mismatch', 'Ce livreur n\'a pas le vehicule demande');
        }

        $previous = $delivery->driver_id;
        $now = Carbon::now();
        DB::transaction(function () use ($delivery, $target, $admin, $reason, $previous, $now): void {
            $delivery->driver_id = $target->id;
            $delivery->status = 'assigned';
            $delivery->updated_at = $now;
            $delivery->save();
            DeliveryEvent::create([
                'delivery_id' => $delivery->id,
                'status' => 'assigned',
                'actor_id' => $admin->id,
                'note' => mb_substr('reaffectation : '.$reason, 0, 255),
                'occurred_at' => $now,
            ]);
            ModerationLog::create([
                'id' => (string) Str::uuid(),
                'actor_id' => $admin->id,
                'subject_id' => $target->id,
                'action' => 'delivery_reassigned',
                'reason' => $reason,
                'decided_at' => $now,
            ]);
            foreach (array_filter([$target->id, $previous, $delivery->client_id]) as $userId) {
                Notification::create([
                    'user_id' => $userId,
                    'type' => 'delivery',
                    'title' => 'Course reaffectee',
                    'message' => (string) $userId === (string) $target->id
                        ? 'Une course vous a ete confiee par l\'exploitation.'
                        : 'La course #'.$delivery->id.' a ete confiee a un autre livreur.',
                    'is_read' => false,
                    'created_at' => $now,
                ]);
            }
        });

        return response()->json($delivery->fresh()->jsonPayload());
    }

    // --- Aides --------------------------------------------------------------

    private function admin(Request $request): Account
    {
        $account = CurrentAccount::resolve($request);
        if (! $account->isAdmin()) {
            throw ApiException::forbidden('admin_required', "Accès réservé à l'administration");
        }

        return $account;
    }

    private function isParty(Delivery $delivery, Account $account): bool
    {
        return (string) $delivery->client_id === (string) $account->id
            || (string) $delivery->driver_id === (string) $account->id;
    }

    private function maskPhone(?string $phone): ?string
    {
        if (! filled($phone) || strlen($phone) < 6) {
            return null;
        }

        return '+261 ** ** *** '.substr($phone, -2);
    }

    private function iso($value): ?string
    {
        return $value === null ? null : Carbon::parse($value)->toIso8601String();
    }
}
