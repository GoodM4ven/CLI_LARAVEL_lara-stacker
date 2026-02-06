#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> PROJECTS LIST ]|=-"

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

app_root="${APP_ROOT:-/var/www/html}"

count=0
for dir in $(ls -d $app_root/*/ 2>/dev/null); do
    if [ ! -d "$dir" ]; then
        continue
    fi
    ((count++))
    status="enabled"
    if [ -f "$dir/.disabled" ]; then
        status="disabled"
    fi
    echo "$dir ($status)"
done

if [ $count -gt 0 ]; then
    echo ""
fi

echo -e "Total projects: $count\n"

read -p "Press any key to continue..." whatever

clear
