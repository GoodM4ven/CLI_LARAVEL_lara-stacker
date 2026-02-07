#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> PROJECTS LIST ]|=-"
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

apps_root="${APPS_ROOT:-/var/www/html}"
domain_suffix="dev.localhost"
https_port="${CADDY_HTTPS_PORT:-8443}"
https_suffix=""
if [[ "$https_port" != "443" ]]; then
    https_suffix=":$https_port"
fi
sourcer "helpers.projectRegistry"

count=0
for dir in $(ls -d $apps_root/*/ 2>/dev/null); do
    if [ ! -d "$dir" ]; then
        continue
    fi
    if ! isRegisteredProjectDir "$dir"; then
        continue
    fi
    project_name=$(basename "$dir")
    ((count++))
    status="enabled"
    if [ -f "$dir/.disabled" ]; then
        status="disabled"
    fi
    project_url="https://${project_name}.${domain_suffix}${https_suffix}"
    echo "${project_url} -> ${dir%/} ($status)"
done

if [ $count -gt 0 ]; then
    echo ""
else
    echo "No registered projects found. Use Import to register an existing project."
    echo ""
fi

echo -e "Total projects: $count\n"

read -p "Press any key to continue..." whatever

clear
