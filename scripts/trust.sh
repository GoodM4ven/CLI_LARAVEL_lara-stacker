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
sourcer "trustHttps"

# Ensure stack is running (also restarts if trust mode changed)
composeUp
if [[ $? -ne 0 ]]; then
    prompt "Failed to start Docker stack." "Check Docker daemon/compose output, then retry." false
fi

if [[ "${HTTPS_TRUST_MODE:-caddy}" == "mkcert" ]]; then
    if ! trustHttps; then
        prompt "mkcert trust failed." "Install mkcert on the host and retry (or set HTTPS_TRUST_MODE=caddy)." false
    fi
    dockerCompose up -d --force-recreate caddy >/dev/null 2>&1 || true
    echo -e "\nTrusted HTTPS via mkcert successfully."
else
    if ! trustHttps; then
        if command -v curl >/dev/null 2>&1; then
            curl -ks "https://localhost:${CADDY_HTTPS_PORT:-8443}" >/dev/null 2>&1 || true
            curl -ks "https://app.localhost:${CADDY_HTTPS_PORT:-8443}" >/dev/null 2>&1 || true
            sleep 1
        fi
        if ! trustHttps; then
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
fi

echo
echo -n "Press any key to continue..."
read whatever

clear
