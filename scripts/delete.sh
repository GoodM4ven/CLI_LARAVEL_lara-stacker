#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> DELETE ]|=-"

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
sourcer "mysqlDown"
sourcer "minioDown"
sourcer "dockerHost"

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry deletion. Project files were not removed." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
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

# ? Ensure stack is up (for DB/bucket cleanup)
if ! composeUp; then
    prompt "Failed to start the Docker stack." "Start the stack and retry deletion. Project files were not removed." false
fi

if [[ -z "$(dockerCompose ps -q mysql)" ]]; then
    prompt "MySQL container is not running." "Start the stack and retry deletion. Project files were not removed." false
fi

if ! mysqlDown "$escaped_project_name"; then
    prompt "Failed to delete MySQL database." "Project files were not removed." false
fi

minio_enabled="false"
if [[ -n "$DOCKER_PROFILES" ]]; then
    if echo ",$DOCKER_PROFILES," | tr '[:upper:]' '[:lower:]' | grep -q ",minio,"; then
        minio_enabled="true"
    fi
fi

if [[ "$minio_enabled" == "true" ]]; then
    if ! minioDown "$escaped_project_name"; then
        prompt "Failed to delete MinIO bucket." "Project files were not removed." false
    fi
fi

if rm -rf "$project_path" 2>/dev/null; then
    :
else
    if command -v sudo >/dev/null 2>&1; then
        if ! sudo rm -rf "$project_path"; then
            prompt "Failed to delete project files." "Check permissions and retry." false
        fi
    else
        prompt "Failed to delete project files." "Install sudo or fix permissions and retry." false
    fi
fi

echo -e "\nDeleted project files."

# * Display a success message
echo -e "\nProject $project_name deleted successfully!\n"

# * Prompt to continue
echo -n "Press any key to continue..."
read whatever

clear
