<?php

namespace Tests\Feature;

use App\Models\Account;
use App\Models\DriverState;
use App\Models\DriverVehicle;
use App\Support\Security;
use Tests\Concerns\BuildsSharedSchema;
use Tests\TestCase;

/**
 * Livraison a prix fixe et attribution rapide, de bout en bout sur SQLite.
 *
 * Les tables partagees avec le site (`users`, `deliveries`, `drivers`...) ne
 * sont pas creees par les migrations Laravel : le test en pose une forme
 * minimale, puis applique la migration du vehicule par-dessus, comme en
 * production.
 */
class DeliveryDispatchTest extends TestCase
{
    use BuildsSharedSchema;

    private const MAHABIBO = ['lat' => -15.7100, 'lng' => 46.3285];

    private const BAOBAB = ['lat' => -15.7224, 'lng' => 46.3108];

    protected function setUp(): void
    {
        parent::setUp();

        $this->buildSharedSchema();
    }

    private function bearer(Account $account): array
    {
        [$token] = Security::issueAccessToken((string) $account->id, $account->role, 'fam');

        return ['Authorization' => 'Bearer '.$token];
    }

    private function client(): Account
    {
        return Account::create(['full_name' => 'Hery', 'role' => 'client', 'password_hash' => '']);
    }

    private function driver(string $name, string $vehicle, array $at = self::MAHABIBO): Account
    {
        $driver = Account::create([
            'full_name' => $name, 'role' => 'driver', 'kyc_status' => 'approved', 'password_hash' => '',
        ]);
        DriverState::create(['user_id' => $driver->id, 'online' => true, 'lat' => $at['lat'], 'lng' => $at['lng']]);
        DriverVehicle::create(['account_id' => $driver->id, 'vehicle_type' => $vehicle]);

        return $driver;
    }

    private function place(array $point, string $district): array
    {
        return ['point' => $point, 'district' => $district, 'landmark' => $district, 'contactPhone' => '+261340000001', 'summary' => $district];
    }

    private function order(Account $client, string $vehicle, string $weight = 'lt_2', ?int $clientPrice = 100)
    {
        return $this->postJson('/deliveries', [
            'pickup' => $this->place(self::MAHABIBO, 'Mahabibo'),
            'dropoff' => $this->place(self::BAOBAB, 'Bord de mer'),
            'kind' => 'standard',
            'package' => ['weight' => $weight],
            'slot' => ['immediate' => true],
            'vehicle' => $vehicle,
            'price' => $clientPrice,
        ], $this->bearer($client));
    }

    public function test_the_server_sets_the_fixed_price_whatever_the_phone_sends(): void
    {
        // Mahabibo -> Baobab : ~2,3 km. Moto : 2 000 + 2,3 x 800, plancher 2 000.
        $ride = $this->order($this->client(), 'moto', 'lt_2', 100)
            ->assertCreated()
            ->assertJsonPath('vehicle', 'moto')
            ->json();

        $this->assertGreaterThan(3500, $ride['price']);
        $this->assertLessThan(4500, $ride['price']);

        $van = $this->order($this->client(), 'van')->assertCreated()->json();
        $this->assertGreaterThanOrEqual(15000, $van['price']);
    }

    public function test_a_request_only_reaches_couriers_with_the_right_vehicle_nearest_first(): void
    {
        $client = $this->client();
        $nearTricycle = $this->driver('Naina', 'tricycle', self::MAHABIBO);
        $farTricycle = $this->driver('Fara', 'tricycle', ['lat' => -15.6668, 'lng' => 46.3512]);
        $moto = $this->driver('Tojo', 'moto');

        $delivery = $this->order($client, 'tricycle', 'gt_15')->assertCreated()->json();

        $this->getJson('/deliveries/available', $this->bearer($moto))
            ->assertOk()->assertJsonCount(0, 'items');

        $near = $this->getJson('/deliveries/available', $this->bearer($nearTricycle))
            ->assertOk()->assertJsonCount(1, 'items')->json('items.0.pickupDistanceKm');
        $far = $this->getJson('/deliveries/available', $this->bearer($farTricycle))
            ->assertOk()->json('items.0.pickupDistanceKm');
        $this->assertLessThan($far, $near);

        // Le premier qui accepte prend la course ; le second arrive trop tard.
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($nearTricycle))
            ->assertOk()->assertJsonPath('driverName', 'Naina');
        $this->postJson("/deliveries/{$delivery['id']}/accept", [], $this->bearer($farTricycle))
            ->assertStatus(409);
    }

    public function test_a_heavy_parcel_is_refused_on_a_moto(): void
    {
        $this->order($this->client(), 'moto', 'gt_15')
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'vehicle_too_small');
    }

    public function test_a_delivery_outside_majunga_is_refused(): void
    {
        $this->postJson('/deliveries', [
            'pickup' => $this->place(['lat' => -18.8792, 'lng' => 47.5079], 'Analakely'),
            'dropoff' => $this->place(['lat' => -18.9010, 'lng' => 47.5490], 'Ambohipo'),
            'package' => ['weight' => 'lt_2'],
            'vehicle' => 'moto',
        ], $this->bearer($this->client()))->assertStatus(422)
            ->assertJsonPath('error.code', 'outside_service_area');
    }

    public function test_phone_registration_opens_a_session_and_login_uses_the_password(): void
    {
        $this->postJson('/auth/phone/register', ['phone' => '+261341234567', 'password' => 'majunga2026'])
            ->assertCreated()
            ->assertJsonPath('linked', true)
            ->assertJsonStructure(['session' => ['accessToken', 'refreshToken'], 'account']);

        $this->postJson('/auth/phone/register', ['phone' => '+261341234567', 'password' => 'majunga2026'])
            ->assertStatus(409)->assertJsonPath('error.code', 'phone_taken');

        $this->postJson('/auth/phone/login', ['phone' => '+261341234567', 'password' => 'mauvais-mdp'])
            ->assertStatus(401);
        $this->postJson('/auth/phone/login', ['phone' => '+261341234567', 'password' => 'majunga2026'])
            ->assertOk()->assertJsonPath('linked', true);
        $this->postJson('/auth/phone/login', ['phone' => '+261349999999', 'password' => 'majunga2026'])
            ->assertStatus(404)->assertJsonPath('error.code', 'phone_not_registered');
    }

    public function test_phone_signup_and_login_with_the_device_lock_instead_of_sms(): void
    {
        $key = str_repeat('k', 43);

        // Inscription : la cle de ce telephone suffit, sans SMS ni mot de passe.
        $session = $this->postJson('/auth/phone/register', ['phone' => '+261341112233', 'deviceSecret' => $key])
            ->assertCreated()
            ->assertJsonPath('linked', true)
            ->json('session.accessToken');

        // Meme telephone, deverrouille : connexion directe.
        $this->postJson('/auth/phone/login', ['phone' => '+261341112233', 'deviceSecret' => $key])
            ->assertOk()->assertJsonPath('linked', true);

        // Autre telephone (autre cle) : refuse, avec un code explicite.
        $this->postJson('/auth/phone/login', ['phone' => '+261341112233', 'deviceSecret' => str_repeat('x', 43)])
            ->assertStatus(401)->assertJsonPath('error.code', 'device_not_recognized');

        // Sans cle ni mot de passe, l'application sait qu'il faut un secours.
        $this->postJson('/auth/phone/login', ['phone' => '+261341112233'])
            ->assertStatus(409)->assertJsonPath('error.code', 'password_not_set');

        // Un nouveau telephone se lie au compte une fois la session ouverte.
        $other = str_repeat('n', 43);
        $this->postJson('/auth/devices', ['deviceSecret' => $other], ['Authorization' => 'Bearer '.$session])
            ->assertNoContent();
        $this->postJson('/auth/phone/login', ['phone' => '+261341112233', 'deviceSecret' => $other])
            ->assertOk();
    }

    public function test_phone_signup_requires_a_device_key_or_a_password(): void
    {
        $this->postJson('/auth/phone/register', ['phone' => '+261341112244'])
            ->assertStatus(422)->assertJsonPath('error.code', 'credential_required');
        $this->postJson('/auth/phone/register', ['phone' => '+261341112244', 'deviceSecret' => 'court'])
            ->assertStatus(422)->assertJsonPath('error.code', 'weak_device_secret');
    }
}
