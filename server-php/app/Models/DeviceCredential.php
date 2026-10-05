<?php

namespace App\Models;

use App\Support\Security;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * Cle d'un appareil autorise a ouvrir une session sur un compte, sans SMS ni
 * mot de passe : le secret ne quitte le telephone qu'apres son verrouillage
 * (code, schema, empreinte, visage). Seule son empreinte est gardee ici.
 */
class DeviceCredential extends Model
{
    protected $table = 'device_credentials';

    public $timestamps = false;

    /** Appareils actifs au plus par compte : les plus anciens sont revoques. */
    public const MAX_PER_ACCOUNT = 5;

    protected $fillable = [
        'account_id', 'secret_hash', 'device_label', 'created_at', 'last_used_at', 'revoked_at',
    ];

    protected function casts(): array
    {
        return [
            'created_at' => 'datetime',
            'last_used_at' => 'datetime',
            'revoked_at' => 'datetime',
        ];
    }

    /** Enregistre un appareil pour le compte et revoque les surnumeraires. */
    public static function enroll(Account $account, string $secret, ?string $label): self
    {
        $credential = self::create([
            'account_id' => $account->id,
            'secret_hash' => Security::hashSecret($secret),
            'device_label' => $label === null ? null : mb_substr($label, 0, 120),
            'created_at' => Carbon::now(),
        ]);

        $active = self::where('account_id', $account->id)
            ->whereNull('revoked_at')
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get();
        foreach ($active->slice(self::MAX_PER_ACCOUNT) as $old) {
            $old->revoked_at = Carbon::now();
            $old->save();
        }

        return $credential;
    }

    /** Appareil actif du compte dont le secret correspond, ou null. */
    public static function match(Account $account, string $secret): ?self
    {
        $active = self::where('account_id', $account->id)->whereNull('revoked_at')->get();
        foreach ($active as $credential) {
            if (Security::verifySecret($credential->secret_hash, $secret)) {
                return $credential;
            }
        }

        return null;
    }
}
