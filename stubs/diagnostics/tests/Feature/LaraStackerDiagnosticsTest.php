<?php

use App\Services\LaraStackerDiagnostics;

function healthyLaraStackerResults(): array
{
    return collect(['mysql' => 'MySQL', 'redis' => 'Redis', 'mailpit' => 'Mailpit', 'minio' => 'MinIO'])
        ->mapWithKeys(fn (string $name, string $id): array => [$id => [
            'id' => $id,
            'name' => $name,
            'healthy' => true,
            'summary' => 'Connected',
            'detail' => 'Service responded',
            'latency' => '1.0 ms',
        ]])->all();
}

beforeEach(function (): void {
    $this->mock(LaraStackerDiagnostics::class, function ($mock): void {
        $mock->shouldReceive('probeAll')->andReturn(healthyLaraStackerResults());
        $mock->shouldReceive('runAll')->andReturn(healthyLaraStackerResults());
        $mock->shouldReceive('serviceLinks')->andReturn([
            'mailpit' => 'https://mailpit.dev.localhost',
            'minio' => 'https://minio.dev.localhost',
        ]);
    });
});

it('shows all four local services on the welcome page', function (): void {
    $this->get('/')->assertOk()->assertSeeTextInOrder(['MySQL', 'Redis', 'Mailpit', 'MinIO']);
});

it('runs the service round trips with a valid token', function (): void {
    $token = hash_hmac('sha256', 'lara-stacker-diagnostics', (string) config('app.key'));

    $this->post('/lara-stacker/diagnostics', ['_diagnostics_token' => $token])
        ->assertOk()
        ->assertSee('Permanent mail and object created');
});
