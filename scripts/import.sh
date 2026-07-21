#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Applications |> IMPORT ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
    chmod +x "$script" 2>/dev/null || true
    if ! source "$script"; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
done

if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

sourcer "helpers.platform"

apps_root="${APPS_ROOT:-/var/www/html}"
apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
if [[ ! -d "$apps_root" ]]; then
    mkdir -p "$apps_root"
    if [[ "$EUID" -eq 0 && -n "${USERNAME:-}" ]]; then
        owner_group=$(resolveUserGroup "$USERNAME")
        chown -R "$USERNAME:$owner_group" "$apps_root" 2>/dev/null || true
    fi
fi

sourcer "composeCmd"
sourcer "composeUp"
sourcer "composeDown"
sourcer "composeExecApp"
sourcer "appKeyUp"
sourcer "envUp"
sourcer "mysqlUp"
sourcer "minioUp"
sourcer "viteUp"
sourcer "xdebugUp"
sourcer "trustHttps"
sourcer "opinionatedUp"
sourcer "sessionTable"
sourcer "dockerHost"
sourcer "hostTools"
sourcer "autoloadGuard"
sourcer "helpers.applicationRegistry"

waitForApplicationInContainer() {
    local application_name="$1"
    local retries="${2:-20}"
    local sleep_seconds="${3:-1}"
    local application_dir="/var/www/html/$application_name"

    for _ in $(seq 1 "$retries"); do
        if composeExecApp test -d "$application_dir" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$sleep_seconds"
    done

    return 1
}

refreshDependenciesAfterImport() {
    local application_name="$1"
    local application_path="$2"

    if [[ -z "$application_name" || -z "$application_path" ]]; then
        echo -e "\nError: refreshDependenciesAfterImport requires app name and path."
        return 1
    fi

    echo -e "\nRefreshing dependencies to recover from import failure..."

    rm -rf \
        "$application_path/vendor" \
        "$application_path/node_modules" 2>/dev/null || true

    requireHostComposer
    requireHostComposerExtensionsForApp "$application_path"
    if ! runAsHostUser composer install --no-interaction --no-scripts --working-dir="$application_path"; then
        return 1
    fi

    if [[ -f "$application_path/package.json" ]]; then
        requireHostNode
        if ! installHostNpmDependencies "$application_path"; then
            return 1
        fi
    fi

    autoloadGuard "$application_name"

    composeExecApp php /var/www/html/$application_name/artisan optimize:clear --quiet >/dev/null 2>&1 || true
}

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and retry application import." false
fi

# ? Get the application path from the user
example_home_path=$(resolveUserHomePath "${USERNAME:-$USER}")
if [[ -z "$example_home_path" ]]; then
    example_home_path="${HOME:-/Users/${USERNAME:-$USER}}"
fi
echo -ne "\nEnter the full application path (e.g., $example_home_path/Code/some_laravel_app): "
read full_directory

full_directory="${full_directory%/}"
application_path=$(dirname "$full_directory")
source_application_name=$(basename "$full_directory")
application_name="$source_application_name"

if [ ! -d "$application_path/$source_application_name" ]; then
    prompt "The application path doesn't exist!" "Application importing cancelled."
fi

resolveDir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        (cd "$dir" 2>/dev/null && pwd -P)
    fi
}

apps_root_real=$(resolveDir "$apps_root")
source_application_real=$(resolveDir "$application_path/$source_application_name")
source_in_apps_root="false"
if [[ -n "$apps_root_real" && -n "$source_application_real" ]]; then
    apps_root_real="${apps_root_real%/}"
    source_application_real="${source_application_real%/}"
    if [[ "$source_application_real" == "$apps_root_real" || "$source_application_real" == "$apps_root_real/"* ]]; then
        source_in_apps_root="true"
    fi
fi

echo -ne "Enter a custom application name (leave empty to use '$source_application_name'): "
read custom_application_name

if [[ -n "$custom_application_name" ]]; then
    application_name="$custom_application_name"
fi

escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_application_name=${escaped_application_name// /}

target_application_path="$apps_root/$escaped_application_name"
source_application_path="$application_path/$source_application_name"
skip_copy="false"
if [[ "$source_in_apps_root" == "true" && "$target_application_path" == "$source_application_path" ]]; then
    skip_copy="true"
fi

if [ -d "$target_application_path" ] && [[ "$skip_copy" != "true" ]]; then
    prompt "An application with the same name already exists!" "Application importing cancelled."
fi

# ? Ensure container is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry application import." false
    fi
fi
trustHttps || true

ensureOwnedByConfiguredUser() {
    local target_path="$1"
    [[ -z "$target_path" || ! -e "$target_path" ]] && return 0
    [[ -z "${USERNAME:-}" ]] && return 0

    local owner_group
    owner_group=$(resolveUserGroup "$USERNAME")

    if chown -R "$USERNAME:$owner_group" "$target_path" >/dev/null 2>&1; then
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$USERNAME:$owner_group" "$target_path" >/dev/null 2>&1 || true
    fi
}

# ? Copy the application into the app root
if [[ "$skip_copy" != "true" ]]; then
    if ! cp -R "$application_path/$source_application_name" "$target_application_path" >/dev/null 2>&1; then
        if command -v sudo >/dev/null 2>&1; then
            sudo cp -R "$application_path/$source_application_name" "$target_application_path" || prompt "Failed to copy application files." "Check read/write permissions and retry." false
        else
            prompt "Failed to copy application files." "Check read/write permissions and retry." false
        fi
    fi
    ensureOwnedByConfiguredUser "$target_application_path"

    echo -e "\nApplication files copied into $apps_root."
else
    ensureOwnedByConfiguredUser "$target_application_path"
    echo -e "\nApplication already in $apps_root. Skipping copy."
fi

# ? Ensure host Node is available if package.json exists
if [[ -f "$target_application_path/package.json" ]]; then
    requireHostNode
fi

# ? Install composer deps if missing
if [[ ! -f "$target_application_path/vendor/autoload.php" ]]; then
    echo -e "\nInstalling Composer dependencies for the application..."
    requireHostComposer
    requireHostComposerExtensionsForApp "$target_application_path"
    if ! runAsHostUser composer install --no-interaction --no-scripts --working-dir="$target_application_path"; then
        prompt "Failed to install Composer dependencies." "Ensure Composer is working on the host and retry." false
    fi
fi

# ? Install JS dependencies if package.json exists and node_modules is missing
if [[ -f "$target_application_path/package.json" && ! -d "$target_application_path/node_modules" ]]; then
    requireHostNode
    if ! installHostNpmDependencies "$target_application_path"; then
        prompt "Failed to install npm dependencies." "Review npm error output above (dependency conflicts/network) and retry." false
    fi
fi

# ? Ensure the container can see the application files through OrbStack's bind mount
if ! waitForApplicationInContainer "$escaped_application_name"; then
    echo -e "\nApp container couldn't see the application yet. Restarting the container...\n"
    composeDown || true
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry application import." false
    fi
    if ! waitForApplicationInContainer "$escaped_application_name"; then
        prompt "App container can't see the application files." "Check APPS_ROOT in [.env] and Docker file sharing, then retry." false
    fi
fi

# ? Ensure the container can load autoload.php (reload PHP-FPM or restart if needed)
autoloadGuard "$escaped_application_name"

# ? Rewire application configuration
envUp "$escaped_application_name" "existing"
viteUp "$escaped_application_name"
xdebugUp "$escaped_application_name"
opinionatedUp "$escaped_application_name"
mysqlUp "$escaped_application_name"
minioUp "$escaped_application_name"
if ! appKeyUp "$escaped_application_name"; then
    prompt "Failed to generate APP_KEY." "Ensure the app container is running and Composer dependencies are installed, then retry." false
fi
if ! sessionTableUp "$escaped_application_name"; then
    echo -e "\nSession table migration failed; attempting dependency refresh..."
    if ! refreshDependenciesAfterImport "$escaped_application_name" "$target_application_path"; then
        prompt "Failed to refresh dependencies after import." "Check Composer/Node and retry." false
    fi
    if ! sessionTableUp "$escaped_application_name"; then
        prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
    fi
fi

if ! registerApplicationDir "$target_application_path"; then
    prompt "Failed to mark application as registered." "Check permissions and retry."
fi

# ? Mark docker setup as done
if [[ ! -f "$lara_stacker_dir/done-docker.flag" ]]; then
    touch "$lara_stacker_dir/done-docker.flag"
fi

# * Display a success message
https_port="${CADDY_HTTPS_PORT:-8443}"
https_suffix=""
if [[ "$https_port" != "443" ]]; then
    https_suffix=":$https_port"
fi
domain_suffix="dev.localhost"
echo -e "Application imported successfully! You can access it at: [https://$escaped_application_name.${domain_suffix}${https_suffix}].\n"

echo -n "Press any key to continue..."
read whatever

clear
