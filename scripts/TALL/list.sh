#!/bin/bash

clear

# * Display a status indicator
echo -e "-=|[ Lara-Stacker |> TALL Projects Management |> LIST ]|=-\n"

# * ===========
# * Validation
# * =========

# ? Source the helper function scripts first
functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" || ! source "$script"; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
done

# ? Ensure the script isn't ran directly
if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

# * ============
# * Preparation
# * ==========

# ? Get environment variables and defaults
lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

# * ========
# * Process
# * ======

# ? ===========================================
# ? Count and list directories and their names
# ? =========================================

projects_directory=/var/www/html

count=0
for dir in $(ls -d $projects_directory/*/ 2>/dev/null); do
    if [ ! -d "$dir" ]; then
        continue
    fi
    ((count++))
    echo "$dir"
done

if [ $count -gt 0 ]; then
    echo ""
fi

# * Display the total count of directories found
echo -e "Total projects: $count\n"

# * ========
# * The End
# * ======

# * Prompt to continue
read -p "Press any key to continue..." whatever

clear
