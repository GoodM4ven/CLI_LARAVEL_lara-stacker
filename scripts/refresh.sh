#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> REFRESH ]|=-"

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

sourcer "composeCmd"
sourcer "composeUp"
sourcer "composeExecApp"
sourcer "envUp"
sourcer "mysqlUp"
sourcer "minioUp"
sourcer "viteUp"
sourcer "xdebugUp"
sourcer "trustHttps"
sourcer "opinionatedUp"
sourcer "workspaceUp"
sourcer "sessionTable"
sourcer "dockerHost"
sourcer "hostTools"

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry refresh." false
fi

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
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry refresh." false
    fi
fi
if [[ "${AUTO_TRUST_HTTPS:-true}" == "true" ]]; then
    trustHttps || true
fi

# ? Clear dependencies (host)
rm -rf "$project_path/node_modules" "$project_path/vendor" "$project_path/composer.lock" "$project_path/package-lock.json" "$project_path/bun.lock" "$project_path/bun.lockb" 2>/dev/null || true

# ? Reinstall Composer dependencies
requireHostComposer
if ! runAsHostUser composer install --no-interaction --no-scripts --working-dir="$project_path"; then
    prompt "Failed to install Composer dependencies." "Ensure Composer is working on the host and retry." false
fi

# ? Reinstall JS dependencies (if package.json exists)
if [[ -f "$project_path/package.json" ]]; then
    requireHostNode
    if ! runAsHostUser npm install --silent --prefix "$project_path"; then
        prompt "Failed to install npm dependencies." "Ensure Node.js/npm are working on the host and retry." false
    fi
fi

# ? Clear Laravel caches
if ! composeExecApp php /var/www/html/$escaped_project_name/artisan optimize:clear --quiet; then
    prompt "App container is not running." "Start the stack and retry refresh." false
fi

# ? Re-wire project configuration
envUp "$escaped_project_name"
viteUp "$escaped_project_name"
xdebugUp "$escaped_project_name"
opinionatedUp "$escaped_project_name"
workspaceUp "$escaped_project_name"
mysqlUp "$escaped_project_name"
minioUp "$escaped_project_name"
if ! sessionTableUp "$escaped_project_name"; then
    prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
fi

# * Display a success indicator
echo -e "\nDone refreshing the project successfully!\n"

# * Prompt to continue
echo
read -p "Press any key to continue..." whatever

clear
