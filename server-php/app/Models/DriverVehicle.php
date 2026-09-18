<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DriverVehicle extends Model
{
    protected $table = 'driver_vehicles';

    protected $primaryKey = 'account_id';

    public $incrementing = false;

    public $timestamps = false;

    protected $fillable = [
        'account_id', 'vehicle_type', 'brand', 'model', 'plate',
        'insurance_expiry', 'validation', 'updated_at',
    ];

    protected function casts(): array
    {
        return ['updated_at' => 'datetime'];
    }

    public function jsonPayload(): array
    {
        return [
            'type' => $this->vehicle_type,
            'brand' => $this->brand,
            'model' => $this->model,
            'plate' => $this->plate,
            'insuranceExpiry' => $this->insurance_expiry,
            'validation' => $this->validation,
        ];
    }
}
