<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;

class Delivery extends Model
{
    protected $table = 'deliveries';

    public $timestamps = false;

    protected $fillable = [
        'client_id', 'driver_id', 'status', 'kind', 'pickup_address', 'dropoff_address',
        'pickup_lat', 'pickup_lng', 'dropoff_lat', 'dropoff_lng', 'pickup_json',
        'dropoff_json', 'package_json', 'price_ariary', 'distance_km', 'cancel_reason',
        'cancel_fee_ariary', 'relay_point_id', 'relay_pickup_code', 'payer',
        'shopping_json', 'tracking_token', 'created_at', 'updated_at',
        'vehicle',
    ];

    protected function casts(): array
    {
        return [
            'pickup_lat' => 'float',
            'pickup_lng' => 'float',
            'dropoff_lat' => 'float',
            'dropoff_lng' => 'float',
            'distance_km' => 'float',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::creating(function (Delivery $delivery): void {
            $delivery->status ??= 'pending';
            $delivery->kind ??= 'standard';
            $delivery->package_json ??= '{}';
            $delivery->tracking_token ??= Str::random(40);
            $delivery->created_at ??= Carbon::now();
            $delivery->updated_at ??= Carbon::now();
        });
    }

    public function place(string $field, string $fallback): array
    {
        $value = json_decode((string) $this->{$field}, true);

        return is_array($value) ? $value : ['summary' => $fallback];
    }

    /**
     * Code de suivi a communiquer au destinataire : `MC-<course>-<controle>`.
     *
     * Le numero de course seul se devinerait (MC-1, MC-2...) et livrerait le
     * statut et le quartier de toutes les livraisons. Les six caracteres de
     * controle sont une signature HMAC de la course par la cle de
     * l'application : sans elle, il faut essayer ~2 milliards de codes par
     * course, a 30 essais par minute.
     */
    public function publicTrackingCode(): ?string
    {
        if (! is_numeric($this->id)) {
            return null;
        }

        return 'MC-'.strtoupper(base_convert((string) $this->id, 10, 36)).'-'.self::trackingCheck((string) $this->id);
    }

    public static function trackingCheck(string $id): string
    {
        $mac = hash_hmac('sha256', 'track:'.$id, (string) config('app.key'));
        $value = strtoupper(base_convert(substr($mac, 0, 12), 16, 36));

        return substr(str_pad($value, 6, '0', STR_PAD_LEFT), -6);
    }

    /** Course designee par un code de suivi, ou null si le code est faux. */
    public static function findByTrackingCode(string $code): ?self
    {
        if (preg_match('/^MC-([A-Z0-9]{1,10})-([A-Z0-9]{6})$/', strtoupper(trim($code)), $m) !== 1) {
            return null;
        }
        $id = base_convert(strtolower($m[1]), 36, 10);
        if (! hash_equals(self::trackingCheck($id), $m[2])) {
            return null;
        }

        return self::find($id);
    }

    public function jsonPayload(): array
    {
        $status = [
            'pending' => 'en_attente',
            'accepted' => 'acceptee',
            'assigned' => 'acceptee',
            'picking_up' => 'au_depart',
            'picked_up' => 'prise_en_charge',
            'in_transit' => 'en_transit',
            'awaiting_confirmation' => 'a_destination',
            'delivered' => 'livree',
            'cancelled' => 'annulee',
            'failed' => 'refusee',
        ][$this->status] ?? $this->status;

        $driver = $this->driver_id === null ? null : Account::find($this->driver_id);

        return [
            'id' => (string) $this->id,
            'clientId' => (string) $this->client_id,
            'driverId' => $this->driver_id === null ? null : (string) $this->driver_id,
            'status' => $status,
            'kind' => $this->kind,
            'pickup' => $this->place('pickup_json', (string) $this->pickup_address),
            'dropoff' => $this->place('dropoff_json', (string) $this->dropoff_address),
            'package' => json_decode((string) $this->package_json, true) ?: [],
            'price' => $this->price_ariary,
            'distanceKm' => $this->distance_km,
            'cancelReason' => $this->cancel_reason,
            'cancelFee' => $this->cancel_fee_ariary,
            'relayPointId' => $this->relay_point_id,
            'relayPickupCode' => $this->relay_pickup_code,
            'payer' => $this->payer,
            'shopping' => $this->shopping_json ? json_decode($this->shopping_json, true) : null,
            'vehicle' => $this->vehicle,
            // Nom du livreur assigne : la fiche du suivi l'affiche (EXI-C22).
            'driverName' => $driver?->resolvedDisplayName(),
            'trackingToken' => $this->tracking_token,
            'trackingCode' => $this->publicTrackingCode(),
            'createdAt' => optional($this->created_at)->toIso8601String(),
            'updatedAt' => optional($this->updated_at)->toIso8601String(),
        ];
    }
}
