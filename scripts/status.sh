#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Container |> STATUS ]|=-"

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

if ! command -v docker >/dev/null 2>&1; then
    echo -e "\nDocker was not found.\n"
    echo
    echo -n "Press any key to continue..."
    read whatever
    clear
    exit 0
fi

if ! ensureDockerAccess; then
    if [[ "$EUID" -eq 0 ]]; then
        echo -e "\nDocker Desktop is running under your user session."
        echo -e "Run without sudo: ./lara-stacker.sh\n"
    else
        echo -e "\nDocker daemon is not reachable. Start Docker and try again.\n"
    fi
    echo
    echo -n "Press any key to continue..."
    read whatever
    clear
    exit 0
fi

if ! docker compose version >/dev/null 2>&1; then
    echo -e "\nDocker Compose (v2) was not found.\n"
    echo
    echo -n "Press any key to continue..."
    read whatever
    clear
    exit 0
fi

sourcer "composeCmd"
sourcer "composePs"

echo
echo -e "Running services:\n"
composePs

echo
echo -n "Press any key to continue..."
read whatever

clear
