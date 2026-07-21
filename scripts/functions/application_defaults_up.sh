applicationDefaultsUp() {
    local application_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"

    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    local application_path="$apps_root/$application_name"
    if [[ ! -f "$application_path/artisan" || ! -f "$application_path/composer.json" ]]; then
        prompt "Laravel application files are incomplete." "Expected artisan and composer.json in [$application_path]." false
    fi

    mkdir -p "$application_path/database"
    touch "$application_path/database/database.sqlite"

    requireHostComposer

    if ! runAsHostUser composer show league/flysystem-aws-s3-v3 --working-dir="$application_path" >/dev/null 2>&1; then
        echo -e "\nInstalling the S3 filesystem adapter required by MinIO..."
        runAsHostUser composer require 'league/flysystem-aws-s3-v3:^3.0' --with-all-dependencies --no-interaction --working-dir="$application_path" \
            || prompt "Failed to install league/flysystem-aws-s3-v3." "Review Composer's output and retry." false
    fi

    if ! runAsHostUser composer show laravel/reverb --working-dir="$application_path" >/dev/null 2>&1; then
        echo -e "\nInstalling Laravel Reverb and broadcasting scaffolding..."
        runInApplicationAsHostUser "$application_path" php artisan install:broadcasting \
            --reverb \
            --without-node \
            --no-interaction \
            "--composer=$HOST_COMPOSER_CMD" \
            || prompt "Failed to install Laravel Reverb." "Review the Artisan and Composer output, then retry." false
    fi

    requireHostNode
    if ! grep -Eq '"laravel-echo"' "$application_path/package.json" \
        || ! grep -Eq '"pusher-js"' "$application_path/package.json"; then
        echo -e "\nInstalling Laravel Echo and the Reverb client dependency..."
        runAsHostUser npm install --save-dev laravel-echo pusher-js --ignore-scripts --prefix "$application_path" \
            || prompt "Failed to install Laravel Echo dependencies." "Review npm's output and retry." false
    fi

    if ! runAsHostUser composer show laravel/boost --working-dir="$application_path" >/dev/null 2>&1; then
        prompt "Laravel Boost was not installed by laravel new." "Update laravel/installer globally and retry application creation." false
    fi
    if ! runAsHostUser composer show pestphp/pest --working-dir="$application_path" >/dev/null 2>&1 \
        || ! runAsHostUser composer show pestphp/pest-plugin-laravel --working-dir="$application_path" >/dev/null 2>&1; then
        prompt "Pest was not installed by laravel new." "Update laravel/installer globally and retry application creation." false
    fi

    echo -e "\nVerified SQLite, Boost, Pest, Reverb, and the MinIO filesystem adapter."
}
