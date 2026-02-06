#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> PURGE ]|=-"

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
resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and try again." false
fi

sourcer "composeCmd"

echo -e "\nThis will REMOVE containers, images, volumes, networks, and build caches for lara-stacker."
read -p "Type 'purge' to continue: " confirm
if [[ "$confirm" != "purge" ]]; then
    echo -e "\nCancelled.\n"
    echo -n "Press any key to continue..."
    read whatever
    clear
    exit 0
fi

dockerCompose down -v --remove-orphans

docker image rm -f lara-stacker-app:latest >/dev/null 2>&1 || true
docker builder prune -f >/dev/null 2>&1 || true

for vol in caddy_data caddy_config mysql_data minio_data postgres_data; do
    docker volume rm -f "lara-stacker_${vol}" >/dev/null 2>&1 || true
done

docker network rm -f lara-stacker_default >/dev/null 2>&1 || true

echo -e "\nPurge completed."
echo -n "Press any key to continue..."
read whatever

clear
