#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Services |> MinIO |> DELETE ]|=-"

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
    prompt "OrbStack's Docker daemon is not reachable." "Open OrbStack and retry." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

if [[ -z "$(dockerCompose ps -q minio)" ]] || [[ -z "$(dockerCompose ps -q minio-client)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry." false
    fi
fi

echo -ne "\nEnter bucket name to delete: "
read bucket_input

bucket_name=$(echo "$bucket_input" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
bucket_name=${bucket_name// /}
if [[ -z "$bucket_name" ]]; then
    prompt "Invalid bucket name." "Use letters, numbers, dashes, or underscores." false
fi

echo -ne "Type the bucket name again to confirm: "
read bucket_confirm
bucket_confirm=$(echo "$bucket_confirm" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
bucket_confirm=${bucket_confirm// /}
if [[ "$bucket_confirm" != "$bucket_name" ]]; then
    prompt "Confirmation mismatch." "Deletion cancelled." false
fi

if ! dockerCompose exec -T minio-client mc alias set local http://minio:9000 minioadmin minioadmin >/dev/null 2>&1; then
    prompt "Failed to configure MinIO client." "Check MinIO container status and retry." false
fi

if ! dockerCompose exec -T minio-client mc rb -r --force local/"$bucket_name" >/dev/null 2>&1; then
    prompt "Failed to delete bucket." "Check MinIO container status and retry." false
fi

echo -e "\nBucket '$bucket_name' deleted (if it existed)."

echo
echo -n "Press any key to continue..."
read whatever

clear
