#!/bin/bash

clear
echo -e "-=|[ Lara-Stacker |> Services |> TAILSCALE FUNNEL ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! source "$script"; then
        echo "Missing essential script: $script"
        exit 1
    fi
done

if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

lara_stacker_dir=$PWD
source "$lara_stacker_dir/.env"

sourcer "helpers.platform"
sourcer "helpers.applicationRegistry"
sourcer "helpers.applicationSelect"
sourcer "dockerHost"
sourcer "composeCmd"
sourcer "composeUp"

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and try again."
fi

tailscaleExec() {
    dockerCompose --profile tailscale exec -T tailscale tailscale "$@"
}

echo -e "\nThe Tailscale container keeps a dedicated tailnet identity in a Docker volume."
echo "1. Install/start Funnel and expose an app"
echo "2. Show Funnel status"
echo "3. Stop Funnel"
echo -ne "\nChoose an operation: "
read -r tailscale_operation

case "$tailscale_operation" in
    1)
        if [[ -z "${TAILSCALE_AUTH_KEY:-}" || "$TAILSCALE_AUTH_KEY" == *"<your-"* ]]; then
            prompt "TAILSCALE_AUTH_KEY is not configured." "Generate an auth key in the Tailscale admin portal, put it in [.env], enable HTTPS/Funnel for the tailnet, then retry."
        fi

        apps_root=$(normalizePathForHost "${APPS_ROOT:-/Users/${USERNAME:-$USER}/Code/Laravel}" "${USERNAME:-}")
        selectRegisteredApplication "$apps_root"

        funnel_link="$apps_root/_funnel_app"
        if [[ -e "$funnel_link" && ! -L "$funnel_link" ]]; then
            prompt "Cannot update $funnel_link because it is not a symlink." "Move that path and retry."
        fi
        rm -f "$funnel_link"
        ln -s "$SELECTED_APPLICATION_NAME" "$funnel_link"

        if [[ -z "$(dockerCompose ps -q app)" ]]; then
            composeUp || prompt "Failed to start the Lara-Stacker services."
        fi

        echo -e "\nInstalling the official Tailscale container image..."
        dockerCompose --profile tailscale pull tailscale \
            || prompt "Failed to download the Tailscale container image."
        dockerCompose --profile tailscale up -d tailscale \
            || prompt "Failed to start the Tailscale service." "Check the auth key and OrbStack logs."

        tailscale_ready="false"
        for _ in {1..30}; do
            if tailscaleExec status >/dev/null 2>&1; then
                tailscale_ready="true"
                break
            fi
            sleep 1
        done
        if [[ "$tailscale_ready" != "true" ]]; then
            prompt "Tailscale did not authenticate." "Review [docker compose logs tailscale], approve the device in the Tailscale admin portal if required, and verify the auth key."
        fi

        if ! tailscaleExec funnel --yes --bg --https=443 http://127.0.0.1:8081; then
            prompt "Tailscale Funnel could not be enabled." "In the Tailscale admin portal, enable MagicDNS, HTTPS certificates, and the Funnel node attribute, then retry."
        fi

        funnel_url=$(tailscaleExec funnel status 2>/dev/null \
            | grep -Eo 'https://[a-zA-Z0-9.-]+\.ts\.net' | head -n 1 || true)
        echo -e "\n$SELECTED_APPLICATION_NAME is exposed through ${funnel_url:-the Tailscale Funnel shown above}."
        echo "Reverb is proxied on the same public domain through /app to host port ${TAILSCALE_REVERB_PORT:-8080}."
        ;;
    2)
        if [[ -z "$(dockerCompose --profile tailscale ps -q tailscale)" ]]; then
            echo -e "\nThe Tailscale service is not running."
        else
            echo
            tailscaleExec status || true
            echo
            tailscaleExec funnel status || true
        fi
        ;;
    3)
        if [[ -n "$(dockerCompose --profile tailscale ps -q tailscale)" ]]; then
            tailscaleExec funnel reset >/dev/null 2>&1 || true
            dockerCompose --profile tailscale stop tailscale
        fi
        apps_root=$(normalizePathForHost "${APPS_ROOT:-/Users/${USERNAME:-$USER}/Code/Laravel}" "${USERNAME:-}")
        [[ -L "$apps_root/_funnel_app" ]] && rm -f "$apps_root/_funnel_app"
        echo -e "\nTailscale Funnel is stopped; its authenticated identity remains in the persistent volume."
        ;;
    *)
        prompt "Invalid Tailscale operation."
        ;;
esac

echo
echo -n "Press any key to continue..."
read -r whatever
clear
