<?php

namespace App\Services;

use Illuminate\Filesystem\FilesystemAdapter;
use Illuminate\Mail\Message;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

class LaraStackerDiagnostics
{
    /** @return array<string, array<string, mixed>> */
    public function probeAll(): array
    {
        return [
            'mysql' => $this->check('mysql', 'MySQL', fn (): array => $this->probeMysql()),
            'redis' => $this->check('redis', 'Redis', fn (): array => $this->probeRedis()),
            'mailpit' => $this->check('mailpit', 'Mailpit', fn (): array => $this->probeMailpit()),
            'minio' => $this->check('minio', 'MinIO', fn (): array => $this->probeMinio()),
        ];
    }

    /** @return array<string, array<string, mixed>> */
    public function runAll(): array
    {
        return [
            'mysql' => $this->check('mysql', 'MySQL', fn (): array => $this->roundTripMysql()),
            'redis' => $this->check('redis', 'Redis', fn (): array => $this->roundTripRedis()),
            'mailpit' => $this->check('mailpit', 'Mailpit', fn (): array => $this->sendMail()),
            'minio' => $this->check('minio', 'MinIO', fn (): array => $this->storeMinioFile()),
        ];
    }

    /** @return array{mailpit: string, minio: string} */
    public function serviceLinks(): array
    {
        return [
            'mailpit' => $this->stackerUrl('mailpit', 8025),
            'minio' => $this->stackerUrl('minio', 9001),
        ];
    }

    private function probeMysql(): array
    {
        $row = DB::selectOne('SELECT VERSION() AS version');

        return ['summary' => 'Connected', 'detail' => (string) $row->version];
    }

    private function roundTripMysql(): array
    {
        $connection = DB::connection();
        $table = 'lara_stacker_'.Str::lower(Str::random(10));
        $value = (string) Str::uuid();
        $connection->statement("CREATE TEMPORARY TABLE `{$table}` (`value` VARCHAR(36) NOT NULL)");

        try {
            $connection->table($table)->insert(['value' => $value]);
            if ($connection->table($table)->value('value') !== $value) {
                throw new \RuntimeException('MySQL returned a different value.');
            }
        } finally {
            $connection->statement("DROP TEMPORARY TABLE IF EXISTS `{$table}`");
        }

        return ['summary' => 'Read/write passed', 'detail' => 'Temporary row cleaned up'];
    }

    private function probeRedis(): array
    {
        $pong = Redis::connection()->command('ping');
        if (! in_array($pong, [true, 1, '1', 'PONG', '+PONG'], true)) {
            throw new \RuntimeException('Redis did not return PONG.');
        }

        return ['summary' => 'Connected', 'detail' => 'PING returned PONG'];
    }

    private function roundTripRedis(): array
    {
        $redis = Redis::connection();
        $key = 'lara-stacker:diagnostics:'.Str::uuid();
        $value = Str::random(24);

        try {
            $redis->set($key, $value, 'EX', 30);
            if ($redis->get($key) !== $value) {
                throw new \RuntimeException('Redis returned a different value.');
            }
        } finally {
            $redis->del($key);
        }

        return ['summary' => 'Read/write passed', 'detail' => 'Ephemeral key cleaned up'];
    }

    private function probeMailpit(): array
    {
        $mailer = config('mail.default');
        $host = (string) config("mail.mailers.{$mailer}.host");
        $port = (int) config("mail.mailers.{$mailer}.port");
        $socket = @stream_socket_client("tcp://{$host}:{$port}", $errorNumber, $errorMessage, 2);
        if ($socket === false) {
            throw new \RuntimeException("SMTP connection failed: {$errorMessage} ({$errorNumber})");
        }
        $banner = trim((string) fgets($socket, 512));
        fclose($socket);
        if (! str_starts_with($banner, '220')) {
            throw new \RuntimeException('SMTP returned an unexpected greeting.');
        }

        return ['summary' => 'Connected', 'detail' => 'SMTP is accepting mail'];
    }

    private function sendMail(): array
    {
        $recipient = 'diagnostics@lara-stacker.test';
        Mail::raw('Lara-Stacker diagnostics passed at '.now()->toIso8601String(), function (Message $message) use ($recipient): void {
            $message->to($recipient)->subject('Lara-Stacker diagnostics passed');
        });

        return ['summary' => 'Email preserved', 'detail' => "Open Mailpit to inspect {$recipient}"];
    }

    private function probeMinio(): array
    {
        $this->minioDisk()->files('lara-stacker-diagnostics');

        return ['summary' => 'Connected', 'detail' => 'Bucket listing succeeded'];
    }

    private function storeMinioFile(): array
    {
        $disk = $this->minioDisk();
        $path = 'lara-stacker-diagnostics/'.now()->format('Ymd-His').'-'.Str::uuid().'.txt';
        $contents = 'Lara-Stacker diagnostics passed at '.now()->toIso8601String();
        $disk->put($path, $contents);
        if ($disk->get($path) !== $contents) {
            throw new \RuntimeException('MinIO returned different object contents.');
        }

        return ['summary' => 'File preserved', 'detail' => $path];
    }

    private function minioDisk(): FilesystemAdapter
    {
        $configuration = config('filesystems.disks.s3', []);
        $configuration['throw'] = true;

        return Storage::build($configuration);
    }

    private function check(string $id, string $name, callable $operation): array
    {
        $startedAt = hrtime(true);

        try {
            $result = $operation();

            return compact('id', 'name') + $result + [
                'healthy' => true,
                'latency' => number_format((hrtime(true) - $startedAt) / 1_000_000, 1).' ms',
            ];
        } catch (Throwable $exception) {
            report($exception);

            return compact('id', 'name') + [
                'healthy' => false,
                'summary' => 'Unavailable',
                'detail' => $this->safeError($exception),
                'latency' => number_format((hrtime(true) - $startedAt) / 1_000_000, 1).' ms',
            ];
        }
    }

    private function safeError(Throwable $exception): string
    {
        $message = $exception->getMessage();
        $secrets = array_filter([
            config('database.connections.mysql.password'),
            config('database.redis.default.password'),
            config('filesystems.disks.s3.secret'),
        ], fn (mixed $secret): bool => is_string($secret) && $secret !== '');

        return Str::limit(str_replace($secrets, '[redacted]', $message), 90);
    }

    private function stackerUrl(string $service, int $fallbackPort): string
    {
        $appUrl = (string) config('app.url');
        $host = parse_url($appUrl, PHP_URL_HOST);
        if (is_string($host) && str_ends_with($host, '.dev.localhost')) {
            $port = parse_url($appUrl, PHP_URL_PORT);

            return "https://{$service}.dev.localhost".($port ? ":{$port}" : '');
        }

        return "http://127.0.0.1:{$fallbackPort}";
    }
}
