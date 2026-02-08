#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Applications |> ENABLE ]|=-"

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

escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_application_name=${escaped_application_name// /}

application_path="$apps_root/$escaped_application_name"

if ! [ -d "$application_path" ]; then
    prompt "Application \"$escaped_application_name\" doesn't exist."
fi
if ! isRegisteredApplicationDir "$application_path"; then
    prompt "Application \"$escaped_application_name\" is not registered." "Run the Import command first."
fi

disabled_marker="$application_path/.disabled"
public_disabled_marker="$application_path/public/.disabled"

if isDisabledApplicationDir "$application_path"; then
    rm -f "$disabled_marker" "$public_disabled_marker"
    echo -e "\nEnabled the application."
else
    echo -e "\nApplication is already enabled."
fi

# * Prompt to continue
echo
echo -n "Press any key to continue..."
read whatever

clear
