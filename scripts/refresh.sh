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

apps_root="${APPS_ROOT:-/var/www/html}"

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

waitForProjectInContainer() {
    local project_name="$1"
    local retries="${2:-20}"
    local sleep_seconds="${3:-1}"
    local project_dir="/var/www/html/$project_name"

    for _ in $(seq 1 "$retries"); do
        if composeExecApp test -d "$project_dir" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$sleep_seconds"
    done

    return 1
}

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry refresh." false
fi

# ? List projects and get the project name/number from the user
project_names=()
project_statuses=()
for dir in "$apps_root"/*/; do
    if [ ! -d "$dir" ]; then
        continue
    fi
    name=$(basename "$dir")
    status="enabled"
    if [ -f "$dir/.disabled" ]; then
        status="disabled"
    fi
    project_names+=("$name")
    project_statuses+=("$status")
done

project_count=${#project_names[@]}
if [ "$project_count" -eq 0 ]; then
    prompt "No projects found." "Create a project first."
fi

echo -e "\nAvailable projects:\n"
digits=${#project_count}
if [ "$digits" -lt 2 ]; then
    digits=2
fi
for i in "${!project_names[@]}"; do
    idx=$((i + 1))
    printf "%0*d. %s (%s)\n" "$digits" "$idx" "${project_names[$i]}" "${project_statuses[$i]}"
done

echo -ne "\nEnter project number or name: "
read -r project_input
if [[ -z "$project_input" ]]; then
    prompt "Project selection cannot be empty."
fi

if [[ "$project_input" =~ ^[0-9]+$ ]]; then
    selected_index=$((10#$project_input - 1))
    if [ "$selected_index" -lt 0 ] || [ "$selected_index" -ge "$project_count" ]; then
        prompt "Invalid project selection."
    fi
    project_name="${project_names[$selected_index]}"
else
    project_name="$project_input"
fi

echo

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

project_path="$apps_root/$escaped_project_name"
if ! [ -d "$project_path" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist."
fi

# ? Ensure stack is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry refresh." false
    fi
fi
trustHttps || true

# ? Ensure the container can see the project files (Docker Desktop sync or stale mounts)
if ! waitForProjectInContainer "$escaped_project_name"; then
    prompt "App container can't see the project files." "Check APPS_ROOT in [.env] and Docker file sharing, then retry." false
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

# ? Restart app container to refresh autoload visibility (no wait/retry)
dockerCompose restart app >/dev/null 2>&1 || true
if ! composeExecApp php -r "require '/var/www/html/$escaped_project_name/vendor/autoload.php';" >/dev/null 2>&1; then
    prompt "App container can't load vendor/autoload.php." "Check APPS_ROOT and Docker file sharing (or run Composer inside the app container) and retry." false
fi

# ? Clear Laravel caches
if ! composeExecApp php /var/www/html/$escaped_project_name/artisan optimize:clear --quiet; then
    prompt "Failed to run Artisan inside the container." "Ensure the app container is running and can access vendor/autoload.php, then retry." false
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

read -p "Press any key to continue..." whatever

clear
