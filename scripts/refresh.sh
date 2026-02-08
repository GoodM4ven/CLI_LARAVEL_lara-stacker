#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Applications |> REFRESH ]|=-"

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

apps_root="${APPS_ROOT:-/var/www/html}"

sourcer "composeCmd"
sourcer "composeUp"
sourcer "composeDown"
sourcer "composeExecApp"
sourcer "envUp"
sourcer "mysqlUp"
sourcer "minioUp"
sourcer "viteUp"
sourcer "xdebugUp"
sourcer "trustHttps"
sourcer "opinionatedUp"
sourcer "workspaceUp"
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

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry refresh." false
fi

# ? List applications and get the application name/number from the user
application_names=()
application_statuses=()
for dir in "$apps_root"/*/; do
    if [ ! -d "$dir" ]; then
        continue
    fi
    if ! isRegisteredApplicationDir "$dir"; then
        continue
    fi
    name=$(basename "$dir")
    status="enabled"
    if isDisabledApplicationDir "$dir"; then
        status="disabled"
    fi
    application_names+=("$name")
    application_statuses+=("$status")
done

application_count=${#application_names[@]}
if [ "$application_count" -eq 0 ]; then
    prompt "No registered applications found." "Use Import to register an existing application or Create a new one."
fi

echo -e "\nAvailable applications:\n"
digits=${#application_count}
if [ "$digits" -lt 2 ]; then
    digits=2
fi
for i in "${!application_names[@]}"; do
    idx=$((i + 1))
    printf "%0*d. %s (%s)\n" "$digits" "$idx" "${application_names[$i]}" "${application_statuses[$i]}"
done

echo -ne "\nEnter application number or name: "
read -r application_input
if [[ -z "$application_input" ]]; then
    prompt "Application selection cannot be empty."
fi

if [[ "$application_input" =~ ^[0-9]+$ ]]; then
    selected_index=$((10#$application_input - 1))
    if [ "$selected_index" -lt 0 ] || [ "$selected_index" -ge "$application_count" ]; then
        prompt "Invalid application selection."
    fi
    application_name="${application_names[$selected_index]}"
else
    application_name="$application_input"
fi

echo

escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_application_name=${escaped_application_name// /}

application_path="$apps_root/$escaped_application_name"
if ! [ -d "$application_path" ]; then
    prompt "Application \"$escaped_application_name\" doesn't exist."
fi
if ! isRegisteredApplicationDir "$application_path"; then
    prompt "Application \"$escaped_application_name\" is not registered." "Run the Import command first."
fi

# ? Ensure container is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry refresh." false
    fi
fi
trustHttps || true

# ? Ensure the container can see the application files (Docker Desktop sync or stale mounts)
if ! waitForApplicationInContainer "$escaped_application_name"; then
    echo -e "\nApp container couldn't see the application yet. Restarting the container...\n"
    composeDown || true
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry refresh." false
    fi
    if ! waitForApplicationInContainer "$escaped_application_name"; then
        prompt "App container can't see the application files." "Check APPS_ROOT in [.env] and Docker file sharing, then retry." false
    fi
fi

# ? Clear dependencies (host)
rm -rf "$application_path/node_modules" "$application_path/vendor" "$application_path/composer.lock" "$application_path/package-lock.json" "$application_path/bun.lock" "$application_path/bun.lockb" 2>/dev/null || true

# ? Reinstall Composer dependencies
requireHostComposer
if ! runAsHostUser composer install --no-interaction --no-scripts --working-dir="$application_path"; then
    prompt "Failed to install Composer dependencies." "Ensure Composer is working on the host and retry." false
fi

# ? Reinstall JS dependencies (if package.json exists)
if [[ -f "$application_path/package.json" ]]; then
    requireHostNode
    if ! runAsHostUser npm install --silent --prefix "$application_path"; then
        prompt "Failed to install npm dependencies." "Ensure Node.js/npm are working on the host and retry." false
    fi
fi

# ? Ensure the container can load autoload.php (reload PHP-FPM or restart if needed)
autoloadGuard "$escaped_application_name"

# ? Clear Laravel caches
if ! composeExecApp php /var/www/html/$escaped_application_name/artisan optimize:clear --quiet; then
    prompt "Failed to run Artisan inside the container." "Ensure the app container is running and can access vendor/autoload.php, then retry." false
fi

# ? Re-wire application configuration
envUp "$escaped_application_name"
viteUp "$escaped_application_name"
xdebugUp "$escaped_application_name"
opinionatedUp "$escaped_application_name"
workspaceUp "$escaped_application_name"
mysqlUp "$escaped_application_name"
minioUp "$escaped_application_name"
if ! sessionTableUp "$escaped_application_name"; then
    prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
fi

# * Display a success indicator
echo -e "\nDone refreshing the application successfully!\n"

read -p "Press any key to continue..." whatever

clear
