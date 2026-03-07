#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Applications |> REWIRE ]|=-"

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

sourcer "envUp"
sourcer "viteUp"
sourcer "xdebugUp"
sourcer "opinionatedUp"
sourcer "workspaceUp"
sourcer "composeCmd"
sourcer "composeExecApp"
sourcer "appKeyUp"
sourcer "mysqlUp"
sourcer "minioUp"
sourcer "sessionTable"
sourcer "hostTools"
sourcer "helpers.applicationRegistry"

# ? List applications and get the application name/number from the user
application_names=()
application_statuses=()
for dir in "$apps_root"/*/; do
    if [ ! -d "$dir" ]; then
        continue
    fi
    if ! isRegisteredApplicationDir "$dir"; then
        continue
    fi
    name=$(basename "$dir")
    status="enabled"
    if isDisabledApplicationDir "$dir"; then
        status="disabled"
    fi
    application_names+=("$name")
    application_statuses+=("$status")
done

application_count=${#application_names[@]}
if [ "$application_count" -eq 0 ]; then
    prompt "No registered applications found." "Use Import to register an existing application or Create a new one."
fi

echo -e "\nAvailable applications:\n"
digits=${#application_count}
if [ "$digits" -lt 2 ]; then
    digits=2
fi
for i in "${!application_names[@]}"; do
    idx=$((i + 1))
    printf "%0*d. %s (%s)\n" "$digits" "$idx" "${application_names[$i]}" "${application_statuses[$i]}"
done

echo -ne "\nEnter application number or name: "
read -r application_input
if [[ -z "$application_input" ]]; then
    prompt "Application selection cannot be empty."
fi

if [[ "$application_input" =~ ^[0-9]+$ ]]; then
    selected_index=$((10#$application_input - 1))
    if [ "$selected_index" -lt 0 ] || [ "$selected_index" -ge "$application_count" ]; then
        prompt "Invalid application selection."
    fi
    application_name="${application_names[$selected_index]}"
else
    application_name="$application_input"
fi

echo

escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_application_name=${escaped_application_name// /}

application_path="$apps_root/$escaped_application_name"
if ! [ -d "$application_path" ]; then
    prompt "Application \"$escaped_application_name\" doesn't exist."
fi
if ! isRegisteredApplicationDir "$application_path"; then
    prompt "Application \"$escaped_application_name\" is not registered." "Run the Import command first."
fi

autoload_ready="true"
if [[ ! -f "$application_path/vendor/autoload.php" ]]; then
    echo -e "\nWarning: vendor/autoload.php not found. Artisan commands will fail until Composer dependencies are installed."
    echo -ne "Install Composer dependencies now? (Y/n): "
    read -r install_confirm
    install_confirm=$(echo "$install_confirm" | tr '[:upper:]' '[:lower:]')
    if [[ -z "$install_confirm" || "$install_confirm" == "y" || "$install_confirm" == "yes" ]]; then
        echo -e "\nInstalling Composer dependencies..."
        requireHostComposer
        if ! runAsHostUser composer install --no-interaction --no-scripts --working-dir="$application_path"; then
            prompt "Failed to install Composer dependencies." "Ensure Composer is working on the host and retry."
        fi
    else
        autoload_ready="false"
    fi
fi

if [[ "$autoload_ready" == "true" && -n "$(dockerCompose ps -q app)" ]]; then
    if ! composeExecApp php -r "require '/var/www/html/$escaped_application_name/vendor/autoload.php';" >/dev/null 2>&1; then
        echo -e "\nWarning: App container can't load vendor/autoload.php yet. You may need to restart containers or run Refresh."
        autoload_ready="false"
    fi
fi

envUp "$escaped_application_name" "existing"
viteUp "$escaped_application_name"
xdebugUp "$escaped_application_name"
opinionatedUp "$escaped_application_name"
workspaceUp "$escaped_application_name"

mysqlUp "$escaped_application_name"
minioUp "$escaped_application_name"

if [[ "$autoload_ready" == "true" ]]; then
    if ! appKeyUp "$escaped_application_name"; then
        prompt "Failed to generate APP_KEY." "Run 'php artisan key:generate' after dependencies are installed." false
    fi
else
    echo -e "\nSkipped APP_KEY generation because vendor/autoload.php is missing."
fi

if [[ -n "$(dockerCompose ps -q app)" ]]; then
    if [[ "$autoload_ready" == "true" ]]; then
        if ! sessionTableUp "$escaped_application_name"; then
            prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
        fi
    else
        echo -e "\nSkipped session table migration because vendor/autoload.php is missing."
    fi
else
    echo -e "\nApp container is not running; skipped session table migration."
fi

# * The End
echo
echo -n "Press any key to continue..."
read whatever

clear
