#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> WIRE ENV ]|=-"

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

sourcer "envUp"
sourcer "viteUp"
sourcer "xdebugUp"
sourcer "opinionatedUp"
sourcer "workspaceUp"

# ? Get the project name from the user
echo -ne "\nEnter the project name: "
read project_name

envUp "$project_name"
viteUp "$project_name"
xdebugUp "$project_name"
opinionatedUp "$project_name"
workspaceUp "$project_name"

# * The End
echo -e "\nPress any key to continue..."
read whatever

clear
