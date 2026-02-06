#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> TRUST HTTPS ]|=-"

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

sourcer "dockerHost"
resolveDockerHost || true

if ! command -v docker >/dev/null 2>&1; then
    prompt "Docker was not found." "Install Docker first and try again." false
fi

if ! ensureDockerAccess; then
    if [[ "$EUID" -eq 0 ]]; then
        prompt "Docker daemon is not reachable." "Try running without sudo: [./lara-stacker.sh]" false
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
    if command -v curl >/dev/null 2>&1; then
        curl -ks "https://localhost:${CADDY_HTTPS_PORT:-8443}" >/dev/null 2>&1 || true
        curl -ks "https://app.localhost:${CADDY_HTTPS_PORT:-8443}" >/dev/null 2>&1 || true
        sleep 1
    fi
    if ! trustCa; then
        echo -e "\nDebug: Caddy root certificate still not found."
        echo "Docker host: ${DOCKER_HOST:-default}"
        echo -e "\nStack containers:"
        dockerCompose ps || true
        echo -e "\nCaddy logs (tail 60):"
        dockerCompose logs --tail 60 caddy 2>/dev/null || true
        echo -e "\nCaddy cert path inside container:"
        dockerCompose exec -T caddy sh -lc "ls -la /data/caddy/pki/authorities/local || true; ls -la /data/caddy/pki/authorities/local/root.crt || true" 2>/dev/null || true
        echo -e "\nAttempting HTTPS probe:"
        curl -k -s -o /dev/null -w "https://app.localhost:${CADDY_HTTPS_PORT:-8443} -> %{http_code}\n" "https://app.localhost:${CADDY_HTTPS_PORT:-8443}" || true
        prompt "Caddy root certificate not found." "Start the stack and visit any https://*.localhost once, then retry." false
    fi
fi

echo -e "\nTrusted Caddy local CA successfully."

echo -n "Press any key to continue..."
read whatever

clear
