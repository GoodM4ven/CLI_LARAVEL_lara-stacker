<?php

namespace App\Http\Controllers;

use App\Services\LaraStackerDiagnostics;
use Illuminate\Http\Request;
use Illuminate\View\View;

class LaraStackerDiagnosticsController extends Controller
{
    public function index(LaraStackerDiagnostics $diagnostics): View
    {
        return $this->view($diagnostics, $diagnostics->probeAll(), false);
    }

    public function run(Request $request, LaraStackerDiagnostics $diagnostics): View
    {
        abort_unless(hash_equals($this->token(), (string) $request->input('_diagnostics_token')), 419);

        return $this->view($diagnostics, $diagnostics->runAll(), true);
    }

    /** @param array<string, array<string, mixed>> $results */
    private function view(LaraStackerDiagnostics $diagnostics, array $results, bool $roundTrip): View
    {
        return view('welcome', [
            'laraStackerResults' => $results,
            'laraStackerServiceLinks' => $diagnostics->serviceLinks(),
            'laraStackerRoundTrip' => $roundTrip,
            'laraStackerToken' => $this->token(),
            'laraStackerCheckedAt' => now(),
        ]);
    }

    private function token(): string
    {
        return hash_hmac('sha256', 'lara-stacker-diagnostics', (string) config('app.key'));
    }
}
