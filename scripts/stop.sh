#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Container |> STOP ]|=-"
echo

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
    if [[ "$EUID" -eq 0 ]]; then
        prompt "Docker daemon is not reachable." "Try running without sudo: [./lara-stacker.sh]" false
    else
        prompt "Docker daemon is not reachable." "Start Docker (or fix your Docker Desktop socket) and try again." false
    fi
fi

sourcer "composeCmd"
sourcer "composeDown"

composeDown

if [[ $? -ne 0 ]]; then
    prompt "Failed to stop the Docker container." "Check Docker daemon and socket permissions, then retry." false
fi

echo -e "\nDocker container is stopped."

echo
echo -n "Press any key to continue..."
read whatever

clear
