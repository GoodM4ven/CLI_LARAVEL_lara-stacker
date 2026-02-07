#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Service Control |> Redis |> DELETE ]|=-"

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

sourcer "dockerHost"
sourcer "composeCmd"
sourcer "composeUp"

read_env_value() {
    local key="$1"
    local file="$2"
    local line
    local value

    line=$(grep -E "^[[:space:]]*${key}=" "$file" | tail -n 1)
    value=${line#*=}
    value=$(printf '%s' "$value" | sed -E "s/^['\"]?//; s/['\"]?$//")
    echo "$value"
}

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

if [[ -z "$(dockerCompose ps -q redis)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry." false
    fi
fi

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

env_file="$project_path/.env"
prefix=""
if [[ -f "$env_file" ]]; then
    prefix=$(read_env_value "REDIS_PREFIX" "$env_file")
    if [[ -z "$prefix" ]]; then
        prefix=$(read_env_value "CACHE_PREFIX" "$env_file")
    fi
fi
if [[ -z "$prefix" ]]; then
    fallback_prefix=$(echo "$escaped_project_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    prefix="${fallback_prefix}_"
fi

pattern="${prefix}*"
keys=$(dockerCompose exec -T redis redis-cli --scan --pattern "$pattern" 2>/dev/null || true)
if [[ -z "$keys" ]]; then
    prompt "No Redis keys found." "Nothing to delete." false
    exit 0
fi

echo -ne "Type the project name again to confirm deletion of keys with prefix '$prefix': "
read -r confirm_input
confirm_input=$(echo "$confirm_input" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
confirm_input=${confirm_input// /}
if [[ "$confirm_input" != "$escaped_project_name" ]]; then
    prompt "Confirmation mismatch." "Deletion cancelled." false
fi

deleted=0
while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    if dockerCompose exec -T redis redis-cli del "$key" >/dev/null 2>&1; then
        deleted=$((deleted + 1))
    fi
done <<< "$keys"

echo -e "\nDeleted $deleted key(s) with prefix '$prefix'."

echo
echo -n "Press any key to continue..."
read whatever

clear
