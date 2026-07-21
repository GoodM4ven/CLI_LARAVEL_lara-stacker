#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Applications |> CREATE ]|=-"

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
sourcer "applicationDefaultsUp"
sourcer "diagnosticsUp"

waitForApplicationInContainer() {
    local application_name="$1"
    local retries="${2:-20}"
    local sleep_seconds="${3:-1}"
    local vendor_file="/var/www/html/$application_name/vendor/autoload.php"

    for _ in $(seq 1 "$retries"); do
        if composeExecApp test -f "$vendor_file" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$sleep_seconds"
    done

    return 1
}

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and retry application creation." false
fi

requireHostLaravelInstaller
requireHostNode

# ? Get the application name from the user
echo -ne "\nEnter the application name: "
read application_name

escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_application_name=${escaped_application_name// /}

application_path="$apps_root/$escaped_application_name"

if [ -d "$apps_root/$escaped_application_name" ]; then
    prompt "Application folder already exists!" "Application creation cancelled."
fi

# ? Ensure container is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry application creation." false
    fi
fi
trustHttps || true

# ? Create the Laravel application using Laravel's official defaults for Pest and Boost
echo -e "\nInstalling the application via Laravel's installer..."
if ! (
    cd "$apps_root"
    runAsHostUser laravel new "$escaped_application_name" \
        --database=sqlite \
        --pest \
        --boost \
        --no-node \
        --no-interaction
); then
    prompt "Failed to create the application via laravel new." "Run [./scripts/setup.sh], then retry." false
fi

applicationDefaultsUp "$escaped_application_name"

# ? Ensure the container can see the new application files through OrbStack's bind mount
if ! waitForApplicationInContainer "$escaped_application_name"; then
    echo -e "\nApp container couldn't see the new application yet. Restarting the container...\n"
    composeDown || true
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry application creation." false
    fi
    if ! waitForApplicationInContainer "$escaped_application_name"; then
        prompt "App container can't see the application files." "Check APPS_ROOT in [.env] and Docker file sharing, then retry." false
    fi
fi

autoloadGuard "$escaped_application_name"

# ? Rewire application configuration
envUp "$escaped_application_name" "new"
mysqlUp "$escaped_application_name"
minioUp "$escaped_application_name"
if ! appKeyUp "$escaped_application_name"; then
    prompt "Failed to generate application key." "Ensure the app container is running and retry." false
fi
if ! sessionTableUp "$escaped_application_name"; then
    prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
fi
viteUp "$escaped_application_name"
xdebugUp "$escaped_application_name"
opinionatedUp "$escaped_application_name"
diagnosticsUp "$escaped_application_name"

if ! installHostNpmDependencies "$application_path"; then
    prompt "Failed to install the application's JavaScript dependencies." "Review npm's output and retry." false
fi
if ! runAsHostUser npm run build --prefix "$application_path"; then
    prompt "Failed to build the application's frontend assets." "Review Vite's output and retry." false
fi

if ! registerApplicationDir "$application_path"; then
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
echo -e "\nApplication created successfully! You can access it at: [https://$escaped_application_name.${domain_suffix}${https_suffix}].\n"

echo -n "Press any key to continue..."
read whatever

clear
