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
            'trackingToken' => $this->tracking_token,
            'createdAt' => optional($this->created_at)->toIso8601String(),
            'updatedAt' => optional($this->updated_at)->toIso8601String(),
        ];
    }
}
