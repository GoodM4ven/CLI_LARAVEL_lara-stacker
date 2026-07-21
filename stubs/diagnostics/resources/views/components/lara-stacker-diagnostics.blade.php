@props(['results', 'serviceLinks', 'roundTrip', 'token', 'checkedAt'])

<section class="my-5 border-y border-[#e3e3e0] py-4 dark:border-[#3E3E3A]" aria-label="Lara-Stacker service diagnostics">
    <div class="mb-3 flex items-center justify-between gap-3">
        <div>
            <p class="font-medium">Local services</p>
            <p class="text-[11px] text-[#706f6c] dark:text-[#A1A09A]">{{ $roundTrip ? 'Permanent mail and object created' : 'Live connectivity' }} · {{ $checkedAt->format('H:i:s') }}</p>
        </div>
        <form method="POST" action="{{ route('lara-stacker.diagnostics.run') }}">
            <input type="hidden" name="_diagnostics_token" value="{{ $token }}">
            <button class="rounded-sm bg-[#1b1b18] px-3 py-1.5 text-[11px] font-medium text-white hover:bg-black dark:bg-[#eeeeec] dark:text-[#1C1C1A]" type="submit">Test all</button>
        </form>
    </div>

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
