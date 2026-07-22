<?php

namespace App\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class LaraStackerWelcomePing implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public string $sender,
        public string $message,
        public string $pageId,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new Channel('lara-stacker.welcome')];
    }

    public function broadcastAs(): string
    {
        return 'lara-stacker.welcome-ping';
    }
}
