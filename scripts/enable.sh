#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> ENABLE ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" || ! source "$script"; then
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
echo -ne "\nEnter the project name: " >&3
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

app_root="${APP_ROOT:-/var/www/html}"
project_path="$app_root/$escaped_project_name"

if ! [ -d "$project_path" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist." "" true
fi

if [ -f "$project_path/.disabled" ]; then
    rm -f "$project_path/.disabled"
    echo -e "\nEnabled the project." >&3
else
    echo -e "\nProject is already enabled." >&3
fi

# * Prompt to continue
echo -n "Press any key to continue..." >&3
read whatever

clear >&3
