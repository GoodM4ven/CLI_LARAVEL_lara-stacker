<?php

declare(strict_types=1);

$applicationPath = rtrim($argv[1] ?? "", DIRECTORY_SEPARATOR);
$routesPath = $applicationPath . "/routes/web.php";
$welcomePath = $applicationPath . "/resources/views/welcome.blade.php";

if (!is_file($routesPath) || !is_file($welcomePath)) {
    fwrite(STDERR, "Missing generated Laravel routes or welcome view.\n");
    exit(1);
}

$routes = file_get_contents($routesPath);
$routeMarker = "LaraStackerDiagnosticsController";

if (!str_contains($routes, $routeMarker)) {
    $defaultRoutes = <<<'PHP'
    <?php

    use Illuminate\Support\Facades\Route;

    Route::get('/', function () {
        return view('welcome');
    });
    PHP;

    $diagnosticRoutes = <<<'PHP'
    <?php

    use App\Http\Controllers\LaraStackerDiagnosticsController;
    use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
    use Illuminate\Session\Middleware\StartSession;
    use Illuminate\Support\Facades\Route;
    use Illuminate\View\Middleware\ShareErrorsFromSession;

    Route::controller(LaraStackerDiagnosticsController::class)
        ->withoutMiddleware([StartSession::class, ShareErrorsFromSession::class, PreventRequestForgery::class])
        ->group(function (): void {
            Route::get('/', 'index')->name('lara-stacker.diagnostics');
            Route::post('/lara-stacker/diagnostics', 'run')->name('lara-stacker.diagnostics.run');
        });
    PHP;

    if (trim($routes) !== trim($defaultRoutes)) {
        fwrite(
            STDERR,
            "The generated routes/web.php no longer matches Laravel's default skeleton.\n",
        );
        exit(1);
    }

    file_put_contents($routesPath, $diagnosticRoutes . PHP_EOL);
}

$welcome = file_get_contents($welcomePath);
$viewMarker = "LARA_STACKER_DIAGNOSTICS";

if (!str_contains($welcome, $viewMarker)) {
    $title =
        '                    <h1 class="mb-1 font-medium">Let\'s get started</h1>';
    $diagnostics = <<<'BLADE'
                        {{-- LARA_STACKER_DIAGNOSTICS --}}
                        <x-lara-stacker-diagnostics
                            :results="$laraStackerResults"
                            :service-links="$laraStackerServiceLinks"
                            :round-trip="$laraStackerRoundTrip"
                            :token="$laraStackerToken"
                            :checked-at="$laraStackerCheckedAt"
                        />
    BLADE;

    if (!str_contains($welcome, $title)) {
        fwrite(STDERR, "Laravel's welcome-page title marker was not found.\n");
        exit(1);
    }

    $welcome = str_replace($title, $title . PHP_EOL . $diagnostics, $welcome);
    file_put_contents($welcomePath, $welcome);
}
