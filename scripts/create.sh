#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> CREATE ]|=-"

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
if [[ ! -d "$app_root" ]]; then
    mkdir -p "$app_root"
    chown -R "$USERNAME:$USERNAME" "$app_root"
fi

sourcer "composeCmd"
sourcer "composeUp"
sourcer "composeExecApp"
sourcer "envUp"
sourcer "mysqlUp"
sourcer "minioUp"
sourcer "viteUp"
sourcer "xdebugUp"
sourcer "trustCa"
sourcer "opinionatedUp"
sourcer "workspaceUp"

# ? Get the project name from the user
echo -ne "\nEnter the project name: "
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

if [ -d "$app_root/$escaped_project_name" ]; then
    prompt "Project folder already exists!" "Project creation cancelled."
fi

# ? Ensure stack is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    composeUp
fi
if [[ "${AUTO_TRUST_HTTPS:-true}" == "true" ]]; then
    trustCa || true
fi

# ? Create the Laravel project
echo -e "\nInstalling the project via Composer..."
composeExecApp composer create-project laravel/laravel "/var/www/html/$escaped_project_name" -n

# ? Wire project configuration
envUp "$escaped_project_name"
viteUp "$escaped_project_name"
xdebugUp "$escaped_project_name"
opinionatedUp "$escaped_project_name"
workspaceUp "$escaped_project_name"
mysqlUp "$escaped_project_name"
minioUp "$escaped_project_name"

# ? Mark docker setup as done
if [[ ! -f "$lara_stacker_dir/done-docker.flag" ]]; then
    touch "$lara_stacker_dir/done-docker.flag"
fi

# * Display a success message
echo -e "\nProject created successfully! You can access it at: [https://$escaped_project_name.localhost].\n"

# * Prompt to continue
echo -n "Press any key to continue..."
read whatever

clear
