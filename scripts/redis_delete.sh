#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Services |> Redis |> DELETE ]|=-"

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

sourcer "helpers.platform"
apps_root="${APPS_ROOT:-/var/www/html}"
apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")

sourcer "dockerHost"
sourcer "composeCmd"
sourcer "composeUp"
sourcer "helpers.applicationRegistry"

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
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and retry." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

if [[ -z "$(dockerCompose ps -q redis)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry." false
    fi
fi

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
prefix=""
app_is_registered="false"

if [[ -d "$application_path" ]] && isRegisteredApplicationDir "$application_path"; then
    app_is_registered="true"
    env_file="$application_path/.env"
    if [[ -f "$env_file" ]]; then
        prefix=$(read_env_value "REDIS_PREFIX" "$env_file")
        if [[ -z "$prefix" ]]; then
            prefix=$(read_env_value "CACHE_PREFIX" "$env_file")
        fi
    fi
else
    echo -e "Warning: Application \"$escaped_application_name\" is missing or not registered."
    echo -ne "Continue with manual Redis prefix deletion? (y/N): "
    read -r manual_confirm
    manual_confirm=$(echo "$manual_confirm" | tr '[:upper:]' '[:lower:]')
    if [[ "$manual_confirm" != "y" && "$manual_confirm" != "yes" ]]; then
        prompt "Deletion cancelled." "" "" false
        exit 0
    fi

    fallback_prefix=$(echo "$escaped_application_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    fallback_prefix="${fallback_prefix}_"
    echo -ne "Enter Redis key prefix to delete (leave empty for '$fallback_prefix'): "
    read -r prefix_input
    if [[ -n "$prefix_input" ]]; then
        prefix="$prefix_input"
    else
        prefix="$fallback_prefix"
    fi
fi

if [[ -z "$prefix" ]]; then
    fallback_prefix=$(echo "$escaped_application_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    prefix="${fallback_prefix}_"
fi

pattern="${prefix}*"
keys=$(dockerCompose exec -T redis redis-cli --scan --pattern "$pattern" 2>/dev/null || true)
if [[ -z "$keys" ]]; then
    prompt "No Redis keys found." "Nothing to delete." false
    exit 0
fi

if [[ "$app_is_registered" == "true" ]]; then
    echo -ne "Type the application name again to confirm deletion of keys with prefix '$prefix': "
    read -r confirm_input
    confirm_input=$(echo "$confirm_input" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    confirm_input=${confirm_input// /}
    if [[ "$confirm_input" != "$escaped_application_name" ]]; then
        prompt "Confirmation mismatch." "Deletion cancelled." false
    fi
else
    echo -ne "Type the prefix again to confirm deletion of keys with prefix '$prefix': "
    read -r confirm_input
    if [[ "$confirm_input" != "$prefix" ]]; then
        prompt "Confirmation mismatch." "Deletion cancelled." false
    fi
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
