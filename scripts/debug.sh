#!/bin/bash

clear
echo -e "-=|[ Lara-Stacker |> Container |> DEBUG ]|=-"

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
sourcer "xdebugUp"

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and try again."
fi
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    prompt "The app container is not running." "Run Start before debugging."
fi

apps_root=$(normalizePathForHost "${APPS_ROOT:-/Users/${USERNAME:-$USER}/Code/Laravel}" "${USERNAME:-}")
if [[ "$(resolveDevEditor)" != "zed" ]]; then
    prompt "Container debugging requires DEV_EDITOR=zed." "Update [.env], then Rewire the application once."
fi
selectRegisteredApplication "$apps_root"
xdebugUp "$SELECTED_APPLICATION_NAME"

if command -v zed >/dev/null 2>&1; then
    zed "$SELECTED_APPLICATION_PATH"
fi

echo -e "\nZed is configured with the \"PHP: Listen to Xdebug\" launch task."
echo "Run your manually configured debugger-start shortcut in Zed (or use the command palette: debugger: start)."
echo "Select \"PHP: Listen to Xdebug\", wait for the debug session to start, then return here."
echo -e "\nXdebug remains trigger-only; no container restart or rebuild is needed."
echo -ne "\nPress Enter once Zed is listening..."
read -r

echo "1. Open a triggered web request (the Chromium Xdebug Helper is preferred for normal browsing)"
echo "2. Run a triggered Artisan command"
echo -ne "\nChoose debug request type: "
read -r debug_type

case "$debug_type" in
    1)
        echo -ne "Route to open [/]: "
        read -r route
        route="${route:-/}"
        [[ "$route" == /* ]] || route="/$route"

        https_port="${CADDY_HTTPS_PORT:-443}"
        https_suffix=""
        if [[ "$https_port" != "443" ]]; then
            https_suffix=":$https_port"
        fi
        separator="?"
        [[ "$route" == *\?* ]] && separator="&"
        debug_url="https://${SELECTED_APPLICATION_NAME}.dev.localhost${https_suffix}${route}${separator}XDEBUG_TRIGGER=1"
        echo -e "\nOpening $debug_url"
        open "$debug_url"
        ;;
    2)
        echo -ne "Artisan arguments [about]: "
        read -r artisan_input
        artisan_input="${artisan_input:-about}"
        read -r -a artisan_args <<< "$artisan_input"
        echo
        dockerCompose exec -T \
            -e XDEBUG_MODE=debug \
            -e XDEBUG_TRIGGER=1 \
            -w "/var/www/html/$SELECTED_APPLICATION_NAME" \
            app php artisan "${artisan_args[@]}"
        ;;
    *)
        prompt "Invalid debug request type."
        ;;
esac

echo
echo -n "Press any key to continue..."
read -r whatever
clear
