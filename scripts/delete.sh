#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> DELETE ]|=-"

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

# ? Set the echoing level
conditional_quiet="--quiet"
cancel_suppression=false
case $LOGGING_LEVEL in
2)
    exec 3>&1
    conditional_quiet=""
    cancel_suppression=true
    ;;
*)
    exec 3>&1
    exec >/dev/null
    ;;
esac

app_root="${APP_ROOT:-/var/www/html}"

sourcer "composeCmd"
sourcer "composeUp"
sourcer "mysqlDown"
sourcer "minioDown"

# ? Get the project name from the user
echo -ne "\nEnter the project name: " >&3
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

project_path="$app_root/$escaped_project_name"
if ! [ -d "$project_path" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist." "" $cancel_suppression
fi

# ? Ensure stack is up (for DB/bucket cleanup)
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    composeUp
fi

mysqlDown "$escaped_project_name"
minioDown "$escaped_project_name"

sudo rm -rf "$project_path"

echo -e "\nDeleted project files." >&3

# * Display a success message
echo -e "\nProject $project_name deleted successfully!\n" >&3

# * Prompt to continue
echo -n "Press any key to continue..." >&3
read whatever

clear >&3
