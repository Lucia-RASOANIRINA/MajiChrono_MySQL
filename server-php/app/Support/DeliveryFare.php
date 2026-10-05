<?php

namespace App\Support;

/**
 * Prix fixe d'une livraison, miroir exact de `DeliveryVehicle.tariff` et de
 * `TariffGrid.estimate` cote mobile : le prix annonce avant la commande est
 * celui que le serveur enregistre. Le serveur le recalcule et fait foi — un
 * prix envoye par le telephone n'est jamais repris tel quel.
 */
class DeliveryFare
{
    /** @var array<string, array{0:int,1:int,2:int}> prise en charge, prix au km, minimum */
    public const TARIFFS = [
        'moto' => [2000, 800, 2000],
        'tricycle' => [3000, 1000, 3000],
        'car' => [5000, 1200, 5000],
        'van' => [15000, 2500, 15000],
    ];

    /** Fiches vehicule (vocabulaires mobile et site) capables d'assurer chaque vehicule demande. */
    public const SERVED_BY = [
        'moto' => ['moto', 'scooter'],
        'tricycle' => ['tricycle'],
        'car' => ['car', 'voiture'],
        'van' => ['van'],
    ];

    /** Supplement de manutention selon le poids declare (WeightCategory). */
    public const WEIGHT_SURCHARGE = ['lt_2' => 0, '2_5' => 1000, '5_15' => 3000, 'gt_15' => 8000];

    /** Majoration selon la nature du colis (DeliveryKind.priceMultiplier). */
    public const KIND_MULTIPLIER = ['fragile' => 1.20, 'food' => 1.10];

    public const SCHEDULED_SURCHARGE = 1000;

    public const INSURANCE_RATE = 0.02;

    /** Centre de Majunga et rayon desservi. */
    public const CENTER = [-15.7167, 46.3167];

    public const RADIUS_KM = 25.0;

    public static function isVehicle(?string $vehicle): bool
    {
        return $vehicle !== null && array_key_exists($vehicle, self::TARIFFS);
    }

    /** Une moto ne porte pas plus de 15 kg. */
    public static function canCarry(string $vehicle, ?string $weight): bool
    {
        return $vehicle !== 'moto' || $weight !== 'gt_15';
    }

    /**
     * @param array<string,mixed> $package declaration du colis (weight, declaredValue)
     * @param array<string,mixed>|null $slot creneau (immediate)
     */
    public static function price(string $vehicle, float $km, array $package, ?string $kind, ?array $slot): int
    {
        [$base, $perKm, $minimum] = self::TARIFFS[$vehicle];

        $subtotal = $base + (int) round($km * $perKm);
        $subtotal += self::WEIGHT_SURCHARGE[$package['weight'] ?? 'lt_2'] ?? 0;

        $multiplier = self::KIND_MULTIPLIER[$kind ?? ''] ?? 1.0;
        if ($multiplier !== 1.0) {
            $subtotal += (int) round($subtotal * ($multiplier - 1));
        }

        if ($slot !== null && ($slot['immediate'] ?? true) === false) {
            $subtotal += self::SCHEDULED_SURCHARGE;
        }

        $insured = (int) ($package['declaredValue'] ?? 0);
        if ($insured > 0) {
            $subtotal += (int) round($insured * self::INSURANCE_RATE);
        }

        return max($minimum, $subtotal);
    }

    /**
     * Un livreur sans fiche vehicule n'est pas prive des courses : le client
     * jugera a la remise. Une course sans vehicule demande (creee avant ce
     * choix) reste visible de tous.
     */
    public static function servedBy(?string $requested, ?string $driverVehicle): bool
    {
        // Course ancienne sans vehicule : n'importe quel livreur. Livreur sans
        // vehicule declare : aucune course — on ne confie pas un colis de
        // 80 kg a quelqu'un dont on ignore s'il est a pied.
        if ($requested === null) {
            return true;
        }
        if ($driverVehicle === null || $driverVehicle === '') {
            return false;
        }

        return in_array($driverVehicle, self::SERVED_BY[$requested] ?? [], true);
    }

    public static function inZone(float $lat, float $lng): bool
    {
        return self::distanceKm($lat, $lng, self::CENTER[0], self::CENTER[1]) <= self::RADIUS_KM;
    }

    public static function distanceKm(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $r = 6371.0;
        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);
        $a = sin($dLat / 2) ** 2 + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return $r * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
