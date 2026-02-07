#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Service Control |> MinIO |> CREATE ]|=-"

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

if [[ -z "$(dockerCompose ps -q minio)" ]] || [[ -z "$(dockerCompose ps -q minio-client)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry." false
    fi
fi

echo -ne "\nEnter bucket name: "
read bucket_input

bucket_name=$(echo "$bucket_input" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
bucket_name=${bucket_name// /}
if [[ -z "$bucket_name" ]]; then
    prompt "Invalid bucket name." "Use letters, numbers, dashes, or underscores." false
fi

if ! dockerCompose exec -T minio-client mc alias set local http://minio:9000 minioadmin minioadmin >/dev/null 2>&1; then
    prompt "Failed to configure MinIO client." "Check MinIO container status and retry." false
fi

dockerCompose exec -T minio-client mc mb -p local/"$bucket_name" >/dev/null 2>&1 || true
if ! dockerCompose exec -T minio-client mc anonymous set public local/"$bucket_name" >/dev/null 2>&1; then
    prompt "Failed to set bucket public." "Check MinIO container status and retry." false
fi

echo -e "\nBucket '$bucket_name' created (if it didn't already exist) and set to public."

echo
echo -n "Press any key to continue..."
read whatever

clear
