#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> IMPORT ]|=-"

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
sourcer "trustHttps"
sourcer "opinionatedUp"
sourcer "workspaceUp"
sourcer "sessionTable"
sourcer "cliWrappers"
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

waitForAutoloadInContainer() {
    local project_name="$1"
    local retries="${2:-30}"
    local sleep_seconds="${3:-2}"
    local autoload_file="/var/www/html/$project_name/vendor/autoload.php"

    for _ in $(seq 1 "$retries"); do
        if composeExecApp php -r "require '$autoload_file';" >/dev/null 2>&1; then
            return 0
        fi
        sleep "$sleep_seconds"
    done

    return 1
}

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry project import." false
fi

# ? Get the project path from the user
echo -ne "\nEnter the full project path (e.g., /home/$USERNAME/Code/some_laravel_app): "
read full_directory

full_directory="${full_directory%/}"
project_path=$(dirname "$full_directory")
source_project_name=$(basename "$full_directory")
project_name="$source_project_name"

if [ ! -d "$project_path/$source_project_name" ]; then
    prompt "The project path doesn't exist!" "Project importing cancelled."
fi

echo -ne "Enter a custom project name (leave empty to use '$source_project_name'): "
read custom_project_name

if [[ -n "$custom_project_name" ]]; then
    project_name="$custom_project_name"
fi

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

if [ -d "$app_root/$escaped_project_name" ]; then
    prompt "A project with the same name already exists!" "Project importing cancelled."
fi

# ? Ensure stack is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry project import." false
    fi
fi
trustHttps || true

# ? Copy the project into the app root
sudo cp -r "$project_path/$source_project_name" "$app_root/$escaped_project_name"
sudo chown -R "$USERNAME:$USERNAME" "$app_root/$escaped_project_name"

echo -e "\nProject files copied into $app_root."

# ? Ensure host Node is available if package.json exists
if [[ -f "$app_root/$escaped_project_name/package.json" ]]; then
    requireHostNode
fi

# ? Install composer deps if missing
if [[ ! -f "$app_root/$escaped_project_name/vendor/autoload.php" ]]; then
    echo -e "\nInstalling Composer dependencies for the project..."
    requireHostComposer
    if ! runAsHostUser composer install --no-interaction --no-scripts --working-dir="$app_root/$escaped_project_name"; then
        prompt "Failed to install Composer dependencies." "Ensure Composer is working on the host and retry." false
    fi
fi

# ? Ensure the container can see the project files
if ! waitForProjectInContainer "$escaped_project_name"; then
    prompt "App container can't see the project files." "Check APP_ROOT in [.env] and Docker file sharing, then retry." false
fi

# ? Ensure autoload is visible inside the container (mount sync can lag)
if ! waitForAutoloadInContainer "$escaped_project_name"; then
    dockerCompose restart app >/dev/null 2>&1 || true
    if ! waitForAutoloadInContainer "$escaped_project_name"; then
        prompt "App container can't load vendor/autoload.php." "Check APP_ROOT and Docker file sharing (or run Composer inside the app container) and retry." false
    fi
fi

# ? Rewire project configuration
envUp "$escaped_project_name"
viteUp "$escaped_project_name"
xdebugUp "$escaped_project_name"
opinionatedUp "$escaped_project_name"
workspaceUp "$escaped_project_name"
cliWrappersUp "$escaped_project_name"
mysqlUp "$escaped_project_name"
minioUp "$escaped_project_name"
if ! sessionTableUp "$escaped_project_name"; then
    prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
fi

# ? Mark docker setup as done
if [[ ! -f "$lara_stacker_dir/done-docker.flag" ]]; then
    touch "$lara_stacker_dir/done-docker.flag"
fi

# * Display a success message
https_port="${CADDY_HTTPS_PORT:-8443}"
https_suffix=""
if [[ "$https_port" != "443" ]]; then
    https_suffix=":$https_port"
fi
domain_suffix="dev.localhost"
echo -e "\nProject imported successfully! You can access it at: [https://$escaped_project_name.${domain_suffix}${https_suffix}].\n"

# * Prompt to continue
echo
echo -n "Press any key to continue..."
read whatever

clear
