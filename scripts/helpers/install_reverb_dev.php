<?php

declare(strict_types=1);

$applicationPath = rtrim($argv[1] ?? '', DIRECTORY_SEPARATOR);
$composerPath = $applicationPath . '/composer.json';

if (!is_file($composerPath)) {
    fwrite(STDERR, "Missing composer.json.\n");
    exit(1);
}

$composer = (string) file_get_contents($composerPath);
$reverbCommand = 'php artisan reverb:start --host=0.0.0.0 --port=8080';

if (str_contains($composer, $reverbCommand)) {
    exit(0);
}

$devCommandMarker = '\\"npm run dev\\"';
$devCommandPosition = strpos($composer, $devCommandMarker);
$namesMarker = ' --names=';
$namesPosition = $devCommandPosition === false
    ? false
    : strpos($composer, $namesMarker, $devCommandPosition + strlen($devCommandMarker));
$killOthersMarker = ' --kill-others';
$killOthersPosition = $namesPosition === false
    ? false
    : strpos($composer, $killOthersMarker, $namesPosition + strlen($namesMarker));

if ($devCommandPosition === false || $namesPosition === false || $killOthersPosition === false) {
    fwrite(STDERR, "The Composer dev script did not match Laravel's supported layout.\n");
    exit(1);
}

$names = substr($composer, $namesPosition + strlen($namesMarker), $killOthersPosition - ($namesPosition + strlen($namesMarker)));
$names = trim($names);
$replacement = $devCommandMarker
    . ' ' . '\\' . '"' . $reverbCommand . '\\' . '"'
    . $namesMarker . $names . ',reverb';
$updated = substr_replace($composer, $replacement, $devCommandPosition, $killOthersPosition - $devCommandPosition);

file_put_contents($composerPath, $updated);
