#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> REFRESH ]|=-"

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

app_root="${APP_ROOT:-/var/www/html}"

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

project_path="$app_root/$escaped_project_name"
if ! [ -d "$project_path" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist."
fi

# ? Ensure stack is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    composeUp
fi
if [[ "${AUTO_TRUST_HTTPS:-true}" == "true" ]]; then
    trustCa || true
fi

# ? Clear dependencies
composeExecApp bash -lc "cd /var/www/html/$escaped_project_name && rm -rf node_modules vendor composer.lock package-lock.json bun.lock bun.lockb"

# ? Reinstall Composer dependencies
composeExecApp composer install --no-interaction --working-dir="/var/www/html/$escaped_project_name"

# ? Reinstall JS dependencies (if package.json exists)
if [[ -f "$project_path/package.json" ]]; then
    composeExecApp npm install --silent --prefix "/var/www/html/$escaped_project_name"
fi

# ? Clear Laravel caches
composeExecApp php /var/www/html/$escaped_project_name/artisan optimize:clear --quiet

# ? Re-wire project configuration
envUp "$escaped_project_name"
viteUp "$escaped_project_name"
xdebugUp "$escaped_project_name"
opinionatedUp "$escaped_project_name"
workspaceUp "$escaped_project_name"
mysqlUp "$escaped_project_name"
minioUp "$escaped_project_name"

# * Display a success indicator
echo -e "\nDone refreshing the project successfully!\n"

# * Prompt to continue
read -p "Press any key to continue..." whatever

clear
