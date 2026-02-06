#!/bin/bash

clear

# * Display a status indicator
echo -e "-=|[ Lara-Stacker |> Docker Stack |> UP ]|=-"

# * ==========
# * Validation
# * ==========

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" || ! source "$script"; then
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

if ! command -v docker >/dev/null 2>&1; then
    prompt "Docker was not found." "Install Docker first and try again." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

compose_file="${DOCKER_COMPOSE_FILE:-$lara_stacker_dir/compose.yaml}"
if [[ ! -f "$compose_file" ]]; then
    prompt "Missing docker compose file: $compose_file" "" false
fi

# ? Ensure app root exists
app_root="${APP_ROOT:-/var/www/html}"
if [[ ! -d "$app_root" ]]; then
    mkdir -p "$app_root"
fi

owner="$(stat -c %U "$app_root" 2>/dev/null || echo "")"
if [[ "$owner" != "$USERNAME" ]]; then
    chown -R "$USERNAME:$USERNAME" "$app_root"
fi

# * ========
# * Process
# * ========

sourcer "composeCmd"
sourcer "composeUp"
sourcer "trustCa"

composeUp

if [[ "${AUTO_TRUST_HTTPS:-true}" == "true" ]]; then
    if ! trustCa; then
        echo -e "\nHTTPS trust was not installed yet. Use \"Trust HTTPS (Caddy CA)\" from the menu." >&3
    fi
fi

# ? Mark docker setup as done
if [[ ! -f "$lara_stacker_dir/done-docker.flag" ]]; then
    touch "$lara_stacker_dir/done-docker.flag"
fi

echo -e "\nDocker stack is running."

# * ========
# * The End
# * ========

echo -n "Press any key to continue..."
read whatever

clear
