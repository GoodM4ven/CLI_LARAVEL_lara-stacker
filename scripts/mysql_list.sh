#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Services |> MySQL |> LIST ]|=-"

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

sourcer "dockerHost"
sourcer "composeCmd"
sourcer "composeUp"

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

if [[ -z "$(dockerCompose ps -q mysql)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry." false
    fi
fi

echo -e "\nMySQL databases:\n"
if ! dockerCompose exec -T mysql mysql -u root -p"$DB_PASSWORD" -e "SHOW DATABASES;" 2>/dev/null; then
    prompt "Failed to list databases." "Check MySQL container status and retry." false
fi

echo
echo -n "Press any key to continue..."
read whatever

clear
