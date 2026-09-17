<?php

namespace Tests\Feature;

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
}
