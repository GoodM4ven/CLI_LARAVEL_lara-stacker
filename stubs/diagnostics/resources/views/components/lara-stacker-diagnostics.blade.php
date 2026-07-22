@props(['results', 'serviceLinks', 'roundTrip', 'token', 'checkedAt', 'reverbEnabled'])

<section class="my-5 border-y border-[#e3e3e0] py-4 dark:border-[#3E3E3A]" aria-label="Lara-Stacker service diagnostics">
    <div class="mb-3 flex items-center justify-between gap-3">
        <div>
            <p class="font-medium">Local services</p>
            <p class="text-[11px] text-[#706f6c] dark:text-[#A1A09A]">{{ $roundTrip ? 'Permanent mail and object created' : 'Live connectivity' }} · {{ $checkedAt->format('H:i:s') }}</p>
        </div>
        <form method="POST" action="{{ route('lara-stacker.diagnostics.run') }}">
            <input type="hidden" name="_diagnostics_token" value="{{ $token }}">
            <button class="rounded-sm bg-[#1b1b18] px-3 py-1.5 text-[11px] font-medium text-white transition-colors duration-150 ease-out hover:bg-[#34342f] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#f53003] focus-visible:ring-offset-2 focus-visible:ring-offset-white active:bg-[#4a4a44] dark:bg-[#eeeeec] dark:text-[#1C1C1A] dark:hover:bg-[#d7d7d2] dark:focus-visible:ring-offset-[#161615] dark:active:bg-[#c5c5bf]" type="submit">Test all</button>
        </form>
    </div>

    @if($reverbEnabled)
        <div class="mt-3 flex items-center justify-between gap-3 rounded-sm border border-dashed border-[#e3e3e0] px-2.5 py-2 dark:border-[#3E3E3A]" data-lara-stacker-ping-box>
            <div class="min-w-0">
                <p class="font-medium">Reverb live ping</p>
                <p class="truncate text-[11px] text-[#706f6c] dark:text-[#A1A09A]" data-lara-stacker-ping-status aria-live="polite">Waiting for another welcome page</p>
            </div>
            <button class="shrink-0 rounded-sm border border-[#1b1b18] px-2.5 py-1.5 text-[11px] font-medium text-[#1b1b18] transition-colors duration-150 ease-out hover:bg-[#1b1b18] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#f53003] focus-visible:ring-offset-2 focus-visible:ring-offset-white active:bg-[#34342f] disabled:cursor-wait disabled:opacity-60 dark:border-[#eeeeec] dark:text-[#eeeeec] dark:hover:bg-[#eeeeec] dark:hover:text-[#1C1C1A] dark:focus-visible:ring-offset-[#161615] dark:active:bg-[#d7d7d2]" type="button" data-lara-stacker-ping data-url="{{ route('lara-stacker.welcome.ping') }}" data-token="{{ $token }}">Ping open pages</button>
        </div>
    @endif

    <div class="grid grid-cols-2 gap-2">
        @foreach($results as $result)
            <div class="min-w-0 rounded-sm border border-[#e3e3e0] p-2.5 dark:border-[#3E3E3A]">
                <div class="flex items-center justify-between gap-2">
                    <span class="font-medium">{{ $result['name'] }}</span>
                    <span class="h-1.5 w-1.5 shrink-0 rounded-full {{ $result['healthy'] ? 'bg-emerald-500' : 'bg-[#f53003]' }}" title="{{ $result['healthy'] ? 'Healthy' : 'Unavailable' }}"></span>
                </div>
                <p class="mt-1 truncate text-[11px] text-[#706f6c] dark:text-[#A1A09A]" title="{{ $result['detail'] }}">{{ $result['summary'] }} · {{ $result['latency'] }}</p>
                @if(isset($serviceLinks[$result['id']]))
                    <a class="mt-1 inline-block text-[11px] font-medium text-[#f53003] underline underline-offset-2 dark:text-[#FF4433]" href="{{ $serviceLinks[$result['id']] }}" target="_blank" rel="noreferrer">Open dashboard ↗</a>
                @endif
            </div>
        @endforeach
    </div>
</section>
