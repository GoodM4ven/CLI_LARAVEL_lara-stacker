#!/bin/bash

clear

# * Display a status indicator
echo -e "-=|[ Lara-Stacker |> Container |> START ]|=-"
echo

# * ==========
# * Validation
# * ==========

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

# * ==========
# * Preparation
# * ==========

lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

sourcer "helpers.platform"
sourcer "dockerHost"
resolveDockerHost || true

if ! command -v docker >/dev/null 2>&1; then
    prompt "Docker was not found." "Install and start OrbStack, then try again." false
fi

if ! ensureDockerAccess; then
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and run Lara-Stacker without sudo." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Reinstall or update OrbStack, which supplies Docker Compose v2." false
fi

compose_file="${DOCKER_COMPOSE_FILE:-$lara_stacker_dir/configurations/compose.yaml}"
if [[ ! -f "$compose_file" ]]; then
    prompt "Missing docker compose file: $compose_file" "" false
fi

# ? Ensure app root exists
apps_root="${APPS_ROOT:-/var/www/html}"
apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
if [[ ! -d "$apps_root" ]]; then
    mkdir -p "$apps_root"
fi

# * ========
# * Process
# * ========

sourcer "composeCmd"
sourcer "composeUp"
sourcer "trustHttps"

if ! trustHttps; then
    prompt "mkcert trust failed." "Install mkcert on the host and retry." false
fi

composeUp
if [[ $? -ne 0 ]]; then
    prompt "Failed to start the container stack." "Check the OrbStack build output above (mirror speed or package errors), then retry." false
fi

dockerCompose up -d --force-recreate caddy >/dev/null 2>&1 || true
if [[ -n "${TAILSCALE_AUTH_KEY:-}" && "$TAILSCALE_AUTH_KEY" != *"<your-"* ]]; then
    dockerCompose up -d tailscale >/dev/null 2>&1 || true
fi

# ? Mark docker setup as done
if [[ ! -f "$lara_stacker_dir/done-docker.flag" ]]; then
    touch "$lara_stacker_dir/done-docker.flag"
fi

echo -e "\nDocker container is running."

# * ========
# * The End
# * ========

echo
echo -n "Press any key to continue..."
read whatever

clear
