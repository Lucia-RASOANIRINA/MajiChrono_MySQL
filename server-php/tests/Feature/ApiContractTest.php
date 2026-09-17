<?php

namespace Tests\Feature;

use App\Support\Security;
use Tests\TestCase;

class ApiContractTest extends TestCase
{
    public function test_profile_requires_an_access_token(): void
    {
        $this->getJson('/me')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'unauthorized');
    }

    public function test_addresses_require_an_access_token(): void
    {
        $this->getJson('/addresses')
            ->assertStatus(401)
            ->assertJsonPath('error.code', 'unauthorized');
    }

    public function test_media_requires_an_access_token(): void
    {
        $this->postJson('/media', [
            'contentType' => 'image/png',
            'imageBase64' => 'aGVsbG8=',
        ])->assertStatus(401)
            ->assertJsonPath('error.code', 'unauthorized');
    }

    public function test_health_endpoint_is_public(): void
    {
        $this->getJson('/health')
            ->assertOk()
            ->assertJson(['status' => 'ok']);
    }

    public function test_client_delivery_endpoints_require_authentication(): void
    {
        $this->getJson('/deliveries')->assertStatus(401);
        $this->postJson('/deliveries', [])->assertStatus(401);
        $this->getJson('/deliveries/1')->assertStatus(401);
        $this->postJson('/deliveries/1/cancel')->assertStatus(401);
    }

    public function test_password_signup_route_is_implemented(): void
    {
        $this->postJson('/auth/password/signup', [
            'email' => 'invalid',
            'password' => 'short',
        ])->assertStatus(422)
            ->assertJsonPath('error.code', 'invalid_email');
    }

    public function test_protected_auth_routes_require_an_access_token(): void
    {
        $this->postJson('/auth/email/link', ['email' => 'user@example.com'])->assertStatus(401);
        $this->postJson('/auth/password/change', ['newPassword' => 'password123'])->assertStatus(401);
        $this->postJson('/auth/email/change/request', ['email' => 'user@example.com'])->assertStatus(401);
        $this->postJson('/auth/email/change/verify', [])->assertStatus(401);
        $this->postJson('/auth/phone/change/request', ['phone' => '+261341234567'])->assertStatus(401);
        $this->postJson('/auth/phone/change/verify', [])->assertStatus(401);
        $this->getJson('/auth/sessions')->assertStatus(401);
        $this->deleteJson('/auth/sessions/family')->assertStatus(401);
    }

    public function test_password_hash_uses_the_shared_bcrypt_cost(): void
    {
        $hash = Security::hashSecret('password123');

        $this->assertStringStartsWith(
            '$2y$'.str_pad((string) config('app.bcrypt_rounds'), 2, '0', STR_PAD_LEFT).'$',
            $hash,
        );
        $this->assertTrue(Security::verifySecret($hash, 'password123'));
        $this->assertFalse(Security::verifySecret($hash, 'wrong-password'));
    }

    public function test_driver_delivery_routes_require_authentication(): void
    {
        $this->getJson('/deliveries/available')->assertStatus(401);
        $this->postJson('/deliveries/1/accept')->assertStatus(401);
        $this->postJson('/deliveries/1/status', ['status' => 'en_transit'])->assertStatus(401);
        $this->postJson('/deliveries/1/incidents', ['kind' => 'other'])->assertStatus(401);
        $this->getJson('/deliveries/1/incidents')->assertStatus(401);
        $this->postJson('/driver/status', ['online' => false])->assertStatus(401);
    }
}
