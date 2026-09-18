<?php

namespace Tests\Feature;

use Tests\TestCase;

class DisputeTest extends TestCase
{
    public function test_dispute_routes_require_authentication(): void
    {
        $this->getJson('/disputes')->assertStatus(401)->assertJsonPath('error.code', 'unauthorized');
        $this->postJson('/disputes', [])->assertStatus(401)->assertJsonPath('error.code', 'unauthorized');
        $this->getJson('/disputes/1')->assertStatus(401)->assertJsonPath('error.code', 'unauthorized');
        $this->postJson('/disputes/1/messages', [])->assertStatus(401)->assertJsonPath('error.code', 'unauthorized');
        $this->postJson('/disputes/1/decision', [])->assertStatus(401)->assertJsonPath('error.code', 'unauthorized');
    }
}
