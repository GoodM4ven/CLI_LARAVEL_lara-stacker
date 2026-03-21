#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Applications |> LIST ]|=-"
echo

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
domain_suffix="dev.localhost"
https_port="${CADDY_HTTPS_PORT:-8443}"
https_suffix=""
if [[ "$https_port" != "443" ]]; then
    https_suffix=":$https_port"
fi
sourcer "helpers.applicationRegistry"

count=0
for dir in $(ls -d $apps_root/*/ 2>/dev/null); do
    if [ ! -d "$dir" ]; then
        continue
    fi
    if ! isRegisteredApplicationDir "$dir"; then
        continue
    fi
    application_name=$(basename "$dir")
    ((count++))
    status="enabled"
    if isDisabledApplicationDir "$dir"; then
        status="disabled"
    fi
    application_url="https://${application_name}.${domain_suffix}${https_suffix}"
    echo "${application_url} -> ${dir%/} ($status)"
done

if [ $count -gt 0 ]; then
    echo ""
else
    echo "No registered apps found. Use Import to register an existing application."
    echo ""
fi

echo -e "Total applications: $count\n"

read -p "Press any key to continue..." whatever

clear
