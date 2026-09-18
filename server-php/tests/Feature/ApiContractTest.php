<?php

namespace Tests\Feature;

use App\Models\Delivery;
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

    public function test_delivery_public_tracking_code_uses_the_site_format(): void
    {
        $delivery = new Delivery;
        $delivery->id = 123;

        $this->assertSame('MC-0000-3F', $delivery->publicTrackingCode());
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
        $this->postJson('/tracking/batch', ['points' => []])->assertStatus(401);
        $this->getJson('/driver/vehicle')->assertStatus(401);
        $this->patchJson('/driver/vehicle', ['type' => 'moto'])->assertStatus(401);
        $this->getJson('/relay-points')->assertStatus(401);
    }

    public function test_driver_kyc_routes_require_authentication(): void
    {
        $this->getJson('/drivers/kyc/status')->assertStatus(401);
        $this->getJson('/drivers/kyc/messages')->assertStatus(401);
        $this->postJson('/drivers/kyc/messages', ['body' => 'Bonjour'])->assertStatus(401);
        $this->postJson('/drivers/kyc/documents/cin_front', [])->assertStatus(401);
        $this->deleteJson('/drivers/kyc/documents/cin_front')->assertStatus(401);
        $this->postJson('/drivers/kyc')->assertStatus(401);
        $this->getJson('/accounts/1/kyc/cin_front')->assertStatus(401);
    }

    public function test_admin_kyc_routes_require_authentication(): void
    {
        $this->getJson('/kyc')->assertStatus(401);
        $this->getJson('/kyc/1/documents')->assertStatus(401);
        $this->getJson('/kyc/1/messages')->assertStatus(401);
        $this->postJson('/kyc/1/messages', ['body' => 'Bonjour'])->assertStatus(401);
        $this->postJson('/kyc/1/review', ['approve' => true, 'reason' => 'Valide'])->assertStatus(401);
    }

    public function test_chat_routes_require_authentication(): void
    {
        $this->getJson('/conversations')->assertStatus(401);
        $this->getJson('/deliveries/1/messages')->assertStatus(401);
        $this->postJson('/deliveries/1/messages', ['body' => 'Bonjour'])->assertStatus(401);
        $this->postJson('/deliveries/1/messages/read')->assertStatus(401);
    }

    public function test_review_routes_require_authentication(): void
    {
        $this->postJson('/reviews', ['deliveryId' => 1, 'stars' => 5])->assertStatus(401);
        $this->getJson('/reviews/delivery/1')->assertStatus(401);
    }

    public function test_support_routes_require_authentication(): void
    {
        $this->getJson('/notifications')->assertStatus(401);
        $this->postJson('/notifications/1/read')->assertStatus(401);
        $this->postJson('/contact', ['subject' => 'Aide', 'message' => 'Bonjour'])->assertStatus(401);
        $this->getJson('/admin/contact')->assertStatus(401);
        $this->postJson('/admin/contact/1/reply', ['reply' => 'Réponse'])->assertStatus(401);
        $this->getJson('/disputes/1/files')->assertStatus(401);
        $this->postJson('/disputes/1/files', [])->assertStatus(401);
    }
}
