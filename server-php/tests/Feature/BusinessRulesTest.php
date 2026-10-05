<?php

namespace Tests\Feature;

use App\Http\Controllers\OperationsController;
use App\Models\Account;
use App\Models\Delivery;
use App\Models\DeliveryEvent;
use App\Models\DriverState;
use App\Models\DriverVehicle;
use App\Models\MajiPaySandboxAccount;
use App\Models\Notification;
use App\Support\Security;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\RateLimiter;
use Tests\Concerns\BuildsSharedSchema;
use Tests\TestCase;

/**
 * Regles metier corrigees apres l'audit : qui fait avancer une course, qui
 * l'annule et a quel prix, comment elle se paie, et ce que voit un inconnu.
 */
class BusinessRulesTest extends TestCase
{
    use BuildsSharedSchema;

    private const MAHABIBO = ['lat' => -15.7100, 'lng' => 46.3285];

    private const BORD_DE_MER = ['lat' => -15.7224, 'lng' => 46.3108];

    protected function setUp(): void
    {
        parent::setUp();
        $this->buildSharedSchema();
        RateLimiter::clear('pwd-fail:phone:+261341234500');
    }

    // --- Aides ---------------------------------------------------------------

    private function bearer(Account $account, string $family = 'fam'): array
    {
        [$token] = Security::issueAccessToken((string) $account->id, $account->role, $family);

        return ['Authorization' => 'Bearer '.$token];
    }

    private function account(string $role, array $extra = []): Account
    {
        return Account::create(['full_name' => ucfirst($role), 'role' => $role, 'password_hash' => ''] + $extra);
    }

    private function driver(string $vehicle = 'moto', bool $online = true): Account
    {
        $driver = $this->account('driver', ['kyc_status' => 'approved', 'phone' => '+26134'.random_int(1000000, 9999999)]);
        DriverState::create(['user_id' => $driver->id, 'online' => $online, 'lat' => self::MAHABIBO['lat'], 'lng' => self::MAHABIBO['lng']]);
        DriverVehicle::create(['account_id' => $driver->id, 'vehicle_type' => $vehicle]);

        return $driver;
    }

    private function order(Account $client, array $overrides = []): array
    {
        return $this->postJson('/deliveries', array_replace([
            'pickup' => ['point' => self::MAHABIBO, 'district' => 'Mahabibo', 'landmark' => 'Pharmacie', 'contactPhone' => '+261340000001', 'summary' => 'Mahabibo, pharmacie'],
            'dropoff' => ['point' => self::BORD_DE_MER, 'district' => 'Bord de mer', 'landmark' => 'Lot 12', 'contactPhone' => '+261340000002', 'summary' => 'Chez Rakoto, lot 12'],
            'package' => ['weight' => 'lt_2'],
            'vehicle' => 'moto',
        ], $overrides), $this->bearer($client))->assertCreated()->json();
    }

    private function advance(Account $who, array $delivery, string $status)
    {
        return $this->postJson("/deliveries/{$delivery['id']}/status", ['status' => $status], $this->bearer($who));
    }

    // --- Avancement d'une course -------------------------------------------

    public function test_the_driver_moves_the_delivery_forward_without_a_note(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();
        $delivery = $this->order($client);
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($driver))->assertOk();

        // Le mobile n'envoie que le statut : c'etait une erreur 500.
        foreach (['au_depart', 'prise_en_charge', 'en_transit', 'a_destination'] as $step) {
            $this->advance($driver, $delivery, $step)->assertOk()->assertJsonPath('status', $step);
        }
        // Le livreur arrive : c'est le client qui confirme la reception.
        $this->advance($client, $delivery, 'livree')->assertOk()->assertJsonPath('status', 'livree');
    }

    public function test_the_client_cannot_drive_the_delivery_himself(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();
        $delivery = $this->order($client);

        // Personne ne force « acceptee » : seule accept() attribue un livreur.
        $this->advance($client, $delivery, 'acceptee')->assertStatus(409);
        $this->assertNull(Delivery::find($delivery['id'])->driver_id);

        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($driver))->assertOk();
        $this->advance($client, $delivery, 'prise_en_charge')->assertForbidden();
        $this->advance($client, $delivery, 'livree')->assertForbidden();
        $this->assertSame('assigned', Delivery::find($delivery['id'])->status);
    }

    public function test_acceptance_requires_being_online_with_the_right_vehicle(): void
    {
        $client = $this->account('client');
        $delivery = $this->order($client, ['vehicle' => 'van', 'package' => ['weight' => 'gt_15']]);

        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($this->driver('van', online: false)))
            ->assertStatus(409)->assertJsonPath('error.code', 'driver_offline');
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($this->driver('moto')))
            ->assertStatus(409)->assertJsonPath('error.code', 'vehicle_mismatch');

        $first = $this->driver('van');
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($first))->assertOk();
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($this->driver('van')))
            ->assertStatus(409)->assertJsonPath('error.code', 'already_taken');
        $this->assertSame((string) $first->id, (string) Delivery::find($delivery['id'])->driver_id);
    }

    public function test_a_courier_without_a_declared_vehicle_gets_no_job(): void
    {
        $this->order($this->account('client'));
        $driver = $this->driver();
        DriverVehicle::where('account_id', $driver->id)->delete();

        $this->getJson('/deliveries/available', $this->bearer($driver))->assertOk()->assertJsonCount(0, 'items');
    }

    public function test_couriers_do_not_see_phone_numbers_before_accepting(): void
    {
        $this->order($this->account('client'));
        $items = $this->getJson('/deliveries/available', $this->bearer($this->driver()))->json('items');

        $this->assertNull($items[0]['delivery']['pickup']['contactPhone']);
        $this->assertNull($items[0]['delivery']['dropoff']['contactPhone']);
    }

    public function test_an_order_without_vehicle_is_priced_and_zoned_by_the_server(): void
    {
        $client = $this->account('client');
        $delivery = $this->postJson('/deliveries', [
            'pickup' => ['point' => self::MAHABIBO, 'summary' => 'A'],
            'dropoff' => ['point' => self::BORD_DE_MER, 'summary' => 'B'],
            'package' => ['weight' => 'lt_2'],
            'price' => 10,
        ], $this->bearer($client))->assertCreated()->json();

        $this->assertSame('moto', $delivery['vehicle']);
        $this->assertGreaterThan(2000, $delivery['price']);

        $this->postJson('/deliveries', [
            'pickup' => ['point' => ['lat' => -18.8792, 'lng' => 47.5079], 'summary' => 'Tana'],
            'dropoff' => ['point' => ['lat' => -18.9010, 'lng' => 47.5490], 'summary' => 'Tana'],
            'package' => ['weight' => 'lt_2'],
        ], $this->bearer($client))->assertStatus(422)->assertJsonPath('error.code', 'outside_service_area');
    }

    // --- Annulation ---------------------------------------------------------

    public function test_a_courier_who_gives_up_hands_the_delivery_back(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();
        $delivery = $this->order($client);
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($driver))->assertOk();

        $this->postJson("/deliveries/{$delivery['id']}/cancel", ['reason' => 'Crevaison'], $this->bearer($driver))
            ->assertOk()->assertJsonPath('status', 'en_attente')->assertJsonPath('driverId', null);

        // Elle repart aussitot aux autres livreurs.
        $this->getJson('/deliveries/available', $this->bearer($this->driver()))->assertJsonCount(1, 'items');
    }

    public function test_the_client_cancels_for_free_just_after_acceptance_then_pays_a_fee(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();

        $quick = $this->order($client);
        $this->postJson("/deliveries/{$quick['id']}/accept", [], $this->bearer($driver))->assertOk();
        $this->postJson("/deliveries/{$quick['id']}/cancel", [], $this->bearer($client))
            ->assertOk()->assertJsonPath('cancelFee', 0);

        $late = $this->order($client);
        $this->postJson("/deliveries/{$late['id']}/accept", [], $this->bearer($driver))->assertOk();
        DeliveryEvent::where('delivery_id', $late['id'])->where('status', 'assigned')
            ->update(['occurred_at' => Carbon::now()->subMinutes(10)]);
        $fee = $this->postJson("/deliveries/{$late['id']}/cancel", [], $this->bearer($client))
            ->assertOk()->json('cancelFee');
        $this->assertGreaterThanOrEqual(1000, $fee);
    }

    // --- Suivi public --------------------------------------------------------

    public function test_the_public_tracking_code_cannot_be_guessed_and_reveals_only_the_district(): void
    {
        $delivery = $this->order($this->account('client'));

        $this->getJson('/public/track/MC-0000-01')->assertNotFound();
        $this->getJson('/public/track/MC-'.strtoupper(base_convert($delivery['id'], 10, 36)).'-AAAAAA')->assertNotFound();

        $this->getJson('/public/track/'.$delivery['trackingCode'])
            ->assertOk()
            ->assertJsonPath('dropoffSummary', 'Bord de mer');
    }

    // --- Paiement -------------------------------------------------------------

    public function test_a_delivery_is_paid_once_at_its_fixed_price(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();
        $delivery = $this->order($client);
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($driver))->assertOk();

        // Le livreur tente d'encaisser 999 999 Ar : le serveur impose le prix fixe.
        $intent = $this->postJson('/payments/intent', [
            'deliveryId' => $delivery['id'], 'amount' => 999999, 'direction' => 'collect',
        ], $this->bearer($driver))->assertCreated()->json();
        $this->assertSame($delivery['price'], $intent['amount']);

        $this->postJson("/payments/{$intent['id']}/claim", ['token' => $intent['token']], $this->bearer($client))->assertOk();
        $before = $this->getJson('/payments/balance', $this->bearer($client))->json('available');

        // Confirmer deux fois ne debite qu'une fois.
        $this->postJson("/payments/{$intent['id']}/confirm", [], $this->bearer($client))->assertOk()->assertJsonPath('status', 'captured');
        $this->postJson("/payments/{$intent['id']}/confirm", [], $this->bearer($client))->assertOk()->assertJsonPath('status', 'captured');
        $this->assertSame($before - $delivery['price'], MajiPaySandboxAccount::find($client->id)->balance_ariary);

        $this->postJson('/payments/intent', ['deliveryId' => $delivery['id'], 'direction' => 'collect'], $this->bearer($driver))
            ->assertStatus(409)->assertJsonPath('error.code', 'already_paid');
    }

    public function test_a_withdrawal_never_exceeds_the_balance(): void
    {
        $driver = $this->driver();
        $balance = $this->getJson('/payments/balance', $this->bearer($driver))->json('available');

        $this->postJson('/payments/withdraw', ['amount' => $balance + 1], $this->bearer($driver))
            ->assertStatus(422)->assertJsonPath('error.code', 'insufficient_funds');
        $this->postJson('/payments/withdraw', ['amount' => $balance], $this->bearer($driver))
            ->assertOk()->assertJsonPath('available', 0);
    }

    // --- Connexion ------------------------------------------------------------

    public function test_password_guessing_is_blocked_after_five_failures(): void
    {
        $this->postJson('/auth/phone/register', ['phone' => '+261341234500', 'password' => 'majunga2026'])->assertCreated();

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/auth/phone/login', ['phone' => '+261341234500', 'password' => 'mauvais'.$i])->assertStatus(401);
        }
        // Meme le bon mot de passe attend : c'est l'identifiant qui est protege.
        $this->postJson('/auth/phone/login', ['phone' => '+261341234500', 'password' => 'majunga2026'])
            ->assertStatus(429)->assertJsonPath('error.code', 'too_many_attempts');
    }

    public function test_changing_the_password_closes_the_other_sessions(): void
    {
        $session = $this->postJson('/auth/phone/register', ['phone' => '+261341234511', 'password' => 'majunga2026'])
            ->assertCreated()->json('session');
        $other = $this->postJson('/auth/phone/login', ['phone' => '+261341234511', 'password' => 'majunga2026'])
            ->assertOk()->json('session');

        $this->postJson('/auth/password/change', ['currentPassword' => 'majunga2026', 'newPassword' => 'nouveau-2026'],
            ['Authorization' => 'Bearer '.$session['accessToken']])->assertNoContent();

        $this->postJson('/auth/refresh', ['refreshToken' => $other['refreshToken']])->assertStatus(401);
        $this->postJson('/auth/refresh', ['refreshToken' => $session['refreshToken']])->assertOk();
    }

    public function test_an_unknown_route_answers_in_json(): void
    {
        $this->getJson('/nexiste-pas')->assertNotFound()->assertJsonPath('error.code', 'not_found');
        $this->get('/nexiste-pas')->assertNotFound()->assertJsonPath('error.code', 'not_found');
    }

    // --- Terrain ---------------------------------------------------------------

    public function test_an_emergency_alert_is_always_accepted_once_and_reaches_the_admins(): void
    {
        $admin = $this->account('admin');
        $driver = $this->driver();

        $this->postJson('/drivers/emergency', ['id' => 'sos_1'], $this->bearer($driver))->assertCreated();
        $this->postJson('/drivers/emergency', ['id' => 'sos_1', 'kind' => 'accident'], $this->bearer($driver))->assertOk();

        $this->assertSame(1, Notification::where('user_id', $admin->id)->where('type', 'emergency')->count());
        $this->getJson('/drivers/emergency?unacknowledged=true', $this->bearer($admin))->assertJsonCount(1, 'items');
        $this->postJson('/admin/emergencies/sos_1/acknowledge', [], $this->bearer($admin))->assertOk();
        $this->getJson('/drivers/emergency?unacknowledged=true', $this->bearer($admin))->assertJsonCount(0, 'items');
    }

    public function test_custody_reports_are_verified_chained_and_sealed(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();
        $delivery = $this->order($client);
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($driver))->assertOk();

        $pickup = $this->sealed(['deliveryId' => $delivery['id'], 'stage' => 'pickup', 'point' => ['lat' => -15.71, 'lng' => 46.0], 'otpVerified' => false]);
        $url = "/deliveries/{$delivery['id']}/custody";

        $this->postJson($url.'/pickup', [...$pickup, 'hash' => str_repeat('0', 64)], $this->bearer($driver))
            ->assertStatus(422)->assertJsonPath('error.code', 'hash_mismatch');
        $this->postJson($url.'/pickup', $pickup, $this->bearer($client))->assertForbidden();
        $this->postJson($url.'/pickup', $pickup, $this->bearer($driver))->assertCreated()->assertJsonStructure(['serverTimestamp']);
        $this->postJson($url.'/pickup', $pickup, $this->bearer($driver))->assertOk();

        $broken = $this->sealed(['deliveryId' => $delivery['id'], 'stage' => 'handover', 'previousHash' => str_repeat('a', 64)]);
        $this->postJson($url.'/handover', $broken, $this->bearer($driver))->assertStatus(422)->assertJsonPath('error.code', 'chain_broken');
        $handover = $this->sealed(['deliveryId' => $delivery['id'], 'stage' => 'handover', 'previousHash' => $pickup['hash']]);
        $this->postJson($url.'/handover', $handover, $this->bearer($driver))->assertCreated();

        $this->getJson($url, $this->bearer($client))->assertOk()
            ->assertJsonPath('pickup.hash', $pickup['hash'])
            ->assertJsonPath('handover.previousHash', $pickup['hash']);
    }

    public function test_the_live_trace_shows_the_courier_only_during_the_delivery(): void
    {
        $client = $this->account('client');
        $driver = $this->driver();
        $delivery = $this->order($client);
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($driver))->assertOk();

        $trace = $this->getJson("/deliveries/{$delivery['id']}/trace", $this->bearer($client))->assertOk()->json();
        $this->assertNotNull($trace['driverPosition']);
        $this->assertStringStartsWith('+261 ** ** *** ', $trace['driver']['maskedPhone']);
        $this->getJson("/deliveries/{$delivery['id']}/trace", $this->bearer($this->account('client')))->assertNotFound();

        foreach (['prise_en_charge', 'a_destination'] as $step) {
            $this->advance($driver, $delivery, $step)->assertOk();
        }
        $this->advance($client, $delivery, 'livree')->assertOk();
        $this->assertNull($this->getJson("/deliveries/{$delivery['id']}/trace", $this->bearer($client))->json('driverPosition'));
    }

    public function test_an_admin_reassigns_a_delivery_to_an_available_courier(): void
    {
        $admin = $this->account('superadmin');
        $client = $this->account('client');
        $first = $this->driver();
        $delivery = $this->order($client);
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($first))->assertOk();

        $offline = $this->driver('moto', online: false);
        $this->postJson("/admin/deliveries/{$delivery['id']}/reassign", ['driverId' => $offline->id, 'reason' => 'Livreur en panne de moto'], $this->bearer($admin))
            ->assertStatus(409)->assertJsonPath('error.code', 'driver_unavailable');
        $second = $this->driver();
        $this->postJson("/admin/deliveries/{$delivery['id']}/reassign", ['driverId' => $second->id, 'reason' => 'court'], $this->bearer($admin))
            ->assertStatus(422);
        $this->postJson("/admin/deliveries/{$delivery['id']}/reassign", ['driverId' => $second->id, 'reason' => 'Livreur en panne de moto'], $this->bearer($first))
            ->assertForbidden();

        $this->postJson("/admin/deliveries/{$delivery['id']}/reassign", ['driverId' => $second->id, 'reason' => 'Livreur en panne de moto'], $this->bearer($admin))
            ->assertOk()->assertJsonPath('driverId', (string) $second->id);
    }

    /** Constat scelle comme le fait le mobile : empreinte du corps canonique. */
    private function sealed(array $canonical): array
    {
        $body = json_decode(json_encode($canonical + ['id' => 'rep_'.uniqid()]), false);
        $hash = hash('sha256', OperationsController::canonicalJson($body));

        return [...$canonical, 'id' => $body->id, 'hash' => $hash];
    }
}
