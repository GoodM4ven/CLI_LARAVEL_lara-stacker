#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> CREATE ]|=-"

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
sourcer "composeDown"
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
    local vendor_file="/var/www/html/$project_name/vendor/autoload.php"

    for _ in $(seq 1 "$retries"); do
        if composeExecApp test -f "$vendor_file" >/dev/null 2>&1; then
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
    prompt "Docker daemon is not reachable." "Start Docker and retry project creation." false
fi

requireHostComposer
requireHostNode

# ? Get the project name from the user
echo -ne "\nEnter the project name: "
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

project_path="$app_root/$escaped_project_name"

if [ -d "$app_root/$escaped_project_name" ]; then
    prompt "Project folder already exists!" "Project creation cancelled."
fi

# ? Ensure stack is up
if [[ -z "$(dockerCompose ps -q app)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry project creation." false
    fi
fi
if [[ "${AUTO_TRUST_HTTPS:-true}" == "true" ]]; then
    trustHttps || true
fi

# ? Create the Laravel project (host composer)
echo -e "\nInstalling the project via Composer..."
if ! runAsHostUser composer create-project laravel/laravel "$project_path" --no-interaction --no-scripts; then
    prompt "Failed to create the project via Composer." "Ensure Composer is working on the host and retry." false
fi

# ? Ensure the container can see the new project files (Docker Desktop sync or stale mounts)
if ! waitForProjectInContainer "$escaped_project_name"; then
    echo -e "\nApp container couldn't see the new project yet. Restarting the stack...\n"
    composeDown || true
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry project creation." false
    fi
    if ! waitForProjectInContainer "$escaped_project_name"; then
        prompt "App container can't see the project files." "Check APP_ROOT in [.env] and Docker file sharing, then retry." false
    fi
fi

if ! waitForAutoloadInContainer "$escaped_project_name"; then
    echo -e "\nAutoload files are not fully visible inside the app container yet. Restarting the stack...\n"
    composeDown || true
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry project creation." false
    fi
    if ! waitForAutoloadInContainer "$escaped_project_name"; then
        prompt "App container can't load vendor/autoload.php." "Check APP_ROOT and Docker file sharing (or run Composer inside the app container) and retry." false
    fi
fi

# ? Rewire project configuration
envUp "$escaped_project_name"
mysqlUp "$escaped_project_name"
minioUp "$escaped_project_name"
if ! composeExecApp php /var/www/html/$escaped_project_name/artisan key:generate --ansi; then
    prompt "Failed to generate application key." "Ensure the app container is running and retry." false
fi
if ! sessionTableUp "$escaped_project_name"; then
    prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
fi
viteUp "$escaped_project_name"
xdebugUp "$escaped_project_name"
opinionatedUp "$escaped_project_name"
workspaceUp "$escaped_project_name"
cliWrappersUp "$escaped_project_name"

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
echo -e "\nProject created successfully! You can access it at: [https://$escaped_project_name.${domain_suffix}${https_suffix}].\n"

echo -n "Press any key to continue..."
read whatever

clear
