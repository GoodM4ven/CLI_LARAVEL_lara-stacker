#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Docker Stack |> DOWN ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" 2>/dev/null || ! source "$script"; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
done

if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

sourcer "composeCmd"
sourcer "composeDown"

composeDown

echo -e "\nDocker stack is stopped."

echo -n "Press any key to continue..."
read whatever

clear
