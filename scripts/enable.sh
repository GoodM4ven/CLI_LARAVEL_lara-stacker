#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> ENABLE ]|=-"

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

# ? Get the project name from the user
echo -ne "\nEnter the project name: "
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

apps_root="${APPS_ROOT:-/var/www/html}"
project_path="$apps_root/$escaped_project_name"

if ! [ -d "$project_path" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist."
fi

if [ -f "$project_path/.disabled" ]; then
    rm -f "$project_path/.disabled"
    echo -e "\nEnabled the project."
else
    echo -e "\nProject is already enabled."
fi

# * Prompt to continue
echo
echo -n "Press any key to continue..."
read whatever

clear
