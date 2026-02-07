#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> REWIRE PROJECT ]|=-"

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
sourcer "mysqlUp"
sourcer "minioUp"
sourcer "sessionTable"

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

envUp "$escaped_project_name"
viteUp "$escaped_project_name"
xdebugUp "$escaped_project_name"
opinionatedUp "$escaped_project_name"
workspaceUp "$escaped_project_name"

mysqlUp "$escaped_project_name"
minioUp "$escaped_project_name"

if [[ -n "$(dockerCompose ps -q app)" ]]; then
    if ! sessionTableUp "$escaped_project_name"; then
        prompt "Failed to create session table or run migrations." "Check database connectivity and retry." false
    fi
else
    echo -e "\nApp container is not running; skipped session table migration."
fi

# * The End
echo
echo -n "Press any key to continue..."
read whatever

clear
