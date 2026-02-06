#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> DELETE ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" 2>/dev/null || ! source "$script"; then
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

sourcer "composeCmd"
sourcer "composeUp"
sourcer "mysqlDown"
sourcer "minioDown"

# ? Get the project name from the user
echo -ne "\nEnter the project name: "
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

project_path="$app_root/$escaped_project_name"
if ! [ -d "$project_path" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist."
fi

# ? Ensure stack is up (for DB/bucket cleanup)
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    composeUp
fi

mysqlDown "$escaped_project_name"
minioDown "$escaped_project_name"

sudo rm -rf "$project_path"

echo -e "\nDeleted project files."

# * Display a success message
echo -e "\nProject $project_name deleted successfully!\n"

# * Prompt to continue
echo -n "Press any key to continue..."
read whatever

clear
