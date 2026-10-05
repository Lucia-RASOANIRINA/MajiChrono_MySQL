<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Cles d'appareil : l'entree par numero sans SMS.
 *
 * A l'inscription, le telephone cree un secret aleatoire, le garde dans son
 * stockage securise (Keystore) et n'y donne acces qu'apres le verrouillage du
 * telephone (code, schema, empreinte, visage). Le serveur n'en garde que
 * l'empreinte. Se connecter, c'est presenter ce secret : seul ce telephone,
 * deverrouille par son proprietaire, le peut.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('device_credentials')) {
            Schema::create('device_credentials', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('account_id');
                $table->string('secret_hash');
                $table->string('device_label', 120)->nullable();
                $table->timestamp('created_at')->nullable();
                $table->timestamp('last_used_at')->nullable();
                $table->timestamp('revoked_at')->nullable();
                $table->index(['account_id', 'revoked_at']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('device_credentials');
    }
};
