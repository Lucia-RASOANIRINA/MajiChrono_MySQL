<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Vehicule demande pour une livraison (moto, tricycle, voiture, camionnette),
 * choisi selon la taille du colis. La demande n'est proposee qu'aux livreurs
 * equipes de ce vehicule.
 *
 * La table `deliveries` est partagee avec le site existant : colonne nullable,
 * gardee par `hasColumn`, comme la migration des conversations.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('deliveries', 'vehicle')) {
            Schema::table('deliveries', function (Blueprint $table): void {
                $table->string('vehicle', 20)->nullable();
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('deliveries', 'vehicle')) {
            Schema::table('deliveries', function (Blueprint $table): void {
                $table->dropColumn('vehicle');
            });
        }
    }
};
