<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Alertes d'urgence des livreurs et constats de prise en charge / remise.
 *
 * Deux tables que le mobile alimentait deja dans le vide : le bouton SOS et
 * les constats photo tombaient sur une route inexistante et restaient en file
 * sur le telephone.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('emergency_alerts')) {
            Schema::create('emergency_alerts', function (Blueprint $table): void {
                $table->string('id', 64)->primary();
                $table->unsignedBigInteger('account_id');
                $table->string('kind', 40)->nullable();
                $table->double('lat')->nullable();
                $table->double('lng')->nullable();
                $table->unsignedBigInteger('delivery_id')->nullable();
                $table->unsignedTinyInteger('battery')->nullable();
                $table->timestamp('raised_at')->nullable();
                $table->timestamp('received_at')->nullable();
                $table->timestamp('acknowledged_at')->nullable();
                $table->unsignedBigInteger('acknowledged_by')->nullable();
                $table->index(['acknowledged_at', 'received_at']);
            });
        }

        if (! Schema::hasTable('custody_reports')) {
            Schema::create('custody_reports', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('delivery_id');
                $table->string('stage', 16);
                $table->string('report_id', 64);
                $table->char('hash', 64);
                $table->char('previous_hash', 64)->nullable();
                $table->unsignedBigInteger('submitted_by');
                $table->longText('body_json');
                $table->timestamp('server_timestamp')->nullable();
                $table->unique(['delivery_id', 'stage']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('custody_reports');
        Schema::dropIfExists('emergency_alerts');
    }
};
