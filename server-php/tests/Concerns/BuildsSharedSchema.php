<?php

namespace Tests\Concerns;

use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Forme minimale des tables partagees avec le site (`users`, `deliveries`,
 * `drivers`...), que les migrations Laravel ne creent pas ; puis les
 * migrations propres a l'API par-dessus, comme en production.
 */
trait BuildsSharedSchema
{
    protected function buildSharedSchema(): void
    {
        Schema::create('users', function (Blueprint $t): void {
            $t->id();
            $t->string('full_name')->default('');
            $t->string('email')->nullable();
            $t->string('phone')->nullable();
            $t->string('password_hash')->default('');
            $t->string('role')->default('client');
            $t->string('status')->nullable();
            $t->string('first_name')->nullable();
            $t->string('last_name')->nullable();
            $t->string('display_name')->nullable();
            $t->string('avatar_path')->nullable();
            $t->string('avatar_url')->nullable();
            $t->float('rating')->nullable();
            $t->string('kyc_status')->nullable();
            $t->timestamp('email_verified_at')->nullable();
            $t->timestamp('phone_verified_at')->nullable();
            $t->timestamp('suspended_at')->nullable();
            $t->timestamps();
        });
        Schema::create('deliveries', function (Blueprint $t): void {
            $t->id();
            $t->unsignedBigInteger('client_id');
            $t->unsignedBigInteger('driver_id')->nullable();
            $t->string('status')->default('pending');
            $t->string('kind')->default('standard');
            $t->string('pickup_address')->nullable();
            $t->string('dropoff_address')->nullable();
            foreach (['pickup_lat', 'pickup_lng', 'dropoff_lat', 'dropoff_lng', 'distance_km'] as $c) {
                $t->float($c)->nullable();
            }
            foreach (['pickup_json', 'dropoff_json', 'package_json', 'shopping_json'] as $c) {
                $t->text($c)->nullable();
            }
            $t->integer('price_ariary')->nullable();
            $t->string('cancel_reason')->nullable();
            $t->integer('cancel_fee_ariary')->nullable();
            $t->string('relay_point_id')->nullable();
            $t->string('relay_pickup_code')->nullable();
            $t->string('payer')->nullable();
            $t->string('tracking_token')->nullable();
            $t->timestamp('created_at')->nullable();
            $t->timestamp('updated_at')->nullable();
        });
        Schema::create('drivers', function (Blueprint $t): void {
            $t->unsignedBigInteger('user_id')->primary();
            $t->boolean('online')->default(false);
            $t->string('kyc_status')->nullable();
            $t->float('lat')->nullable();
            $t->float('lng')->nullable();
            $t->timestamp('fixed_at')->nullable();
            $t->timestamp('updated_at')->nullable();
        });
        Schema::create('driver_vehicles', function (Blueprint $t): void {
            $t->unsignedBigInteger('account_id')->primary();
            $t->string('vehicle_type')->nullable();
            $t->string('brand')->nullable();
            $t->string('model')->nullable();
            $t->string('plate')->nullable();
            $t->string('insurance_expiry')->nullable();
            $t->string('validation')->nullable();
            $t->timestamp('updated_at')->nullable();
        });
        Schema::create('delivery_events', function (Blueprint $t): void {
            $t->id();
            $t->unsignedBigInteger('delivery_id');
            $t->string('status');
            $t->unsignedBigInteger('actor_id')->nullable();
            $t->string('note')->nullable();
            $t->timestamp('occurred_at')->nullable();
        });
        Schema::create('refresh_tokens', function (Blueprint $t): void {
            $t->string('id')->primary();
            $t->string('account_id');
            $t->string('token_hash');
            $t->string('family');
            $t->string('device_label')->nullable();
            $t->timestamp('expires_at')->nullable();
            $t->timestamp('revoked_at')->nullable();
            $t->timestamp('created_at')->nullable();
        });
        Schema::create('location_pings', function (Blueprint $t): void {
            $t->id();
            $t->unsignedBigInteger('driver_id');
            $t->unsignedBigInteger('delivery_id')->nullable();
            $t->float('lat');
            $t->float('lng');
            $t->float('accuracy_m')->nullable();
            $t->timestamp('fixed_at')->nullable();
        });
        Schema::create('payments', function (Blueprint $t): void {
            $t->id();
            $t->unsignedBigInteger('delivery_id');
            $t->unsignedBigInteger('payer_id');
            $t->unsignedBigInteger('payee_id');
            $t->integer('amount_ariary');
            $t->string('direction');
            $t->string('status');
            $t->string('token_hash')->nullable();
            $t->string('failure')->nullable();
            $t->string('receipt_ref')->nullable();
            $t->timestamp('created_at')->nullable();
            $t->timestamp('expires_at')->nullable();
            $t->timestamp('captured_at')->nullable();
        });
        Schema::create('majipay_sandbox_accounts', function (Blueprint $t): void {
            $t->unsignedBigInteger('account_id')->primary();
            $t->integer('balance_ariary')->default(0);
            $t->string('account_ref')->nullable();
        });
        Schema::create('majipay_sandbox_txns', function (Blueprint $t): void {
            $t->string('idem_key')->primary();
            $t->string('receipt_ref')->nullable();
            $t->timestamp('created_at')->nullable();
        });
        Schema::create('notifications', function (Blueprint $t): void {
            $t->id();
            $t->unsignedBigInteger('user_id');
            $t->string('type')->nullable();
            $t->string('title')->nullable();
            $t->text('message')->nullable();
            $t->unsignedBigInteger('related_id')->nullable();
            $t->boolean('is_read')->default(false);
            $t->timestamp('created_at')->nullable();
        });
        Schema::create('moderation_logs', function (Blueprint $t): void {
            $t->string('id')->primary();
            $t->unsignedBigInteger('actor_id');
            $t->unsignedBigInteger('subject_id');
            $t->string('action');
            $t->text('reason')->nullable();
            $t->timestamp('decided_at')->nullable();
        });
        Schema::create('settings', function (Blueprint $t): void {
            $t->string('key_name')->primary();
            $t->text('value')->nullable();
            $t->timestamp('updated_at')->nullable();
        });

        foreach ([
            '2026_10_02_000001_add_delivery_vehicle.php',
            '2026_10_03_000001_create_device_credentials.php',
            '2026_10_04_000001_create_operations_tables.php',
        ] as $migration) {
            (require database_path('migrations/'.$migration))->up();
        }
    }
}
