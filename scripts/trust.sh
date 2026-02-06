#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> TRUST HTTPS ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" 2>/dev/null || ! source "$script"; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
done

if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

sourcer "dockerHost"
resolveDockerHost || true

if ! command -v docker >/dev/null 2>&1; then
    prompt "Docker was not found." "Install Docker first and try again." false
fi

if ! docker info >/dev/null 2>&1; then
    if [[ "$EUID" -eq 0 ]]; then
        prompt "Docker Desktop is running under your user session." "Run without sudo: [./lara-stacker.sh]" false
    else
        prompt "Docker daemon is not reachable." "Start Docker (or fix your Docker Desktop socket) and try again." false
    fi
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

sourcer "composeCmd"
sourcer "composeUp"
sourcer "trustCa"

# Ensure stack is running
if [[ -z "$(dockerCompose ps -q caddy)" ]]; then
    composeUp
fi

if ! trustCa; then
    prompt "Caddy root certificate not found." "Start the stack and visit any https://*.localhost once, then retry." false
fi

echo -e "\nTrusted Caddy local CA successfully."

echo -n "Press any key to continue..."
read whatever

clear
