#!/bin/bash

clear

# * ===========================
# * Display a status indicator
# * =========================

current_version="???"
is_updateable=false
script_dir="$(pwd)"
git_runner=()
git_remote_url=""

if command -v git &> /dev/null && [ -d ".git" ]; then
    if [[ -n "$SUDO_USER" ]]; then
        git_runner=(sudo -u "$SUDO_USER" git -C "$script_dir")
    else
        git_runner=(git -C "$script_dir")
    fi

    if "${git_runner[@]}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        is_updateable=true
        git_remote_url=$("${git_runner[@]}" config --get remote.origin.url 2>/dev/null || true)

        current_version=$("${git_runner[@]}" describe --tags --abbrev=0 2>/dev/null \
            || "${git_runner[@]}" rev-parse --short HEAD 2>/dev/null \
            || echo "???")
    fi
fi

echo -e "   __     ___   ___   ___        _____ _______ _____ _____ _  __ ______ _   __\n  / /    / _ \\ / _ \\ / _ \\      / ____|__   __|_   _/ ____| |/ /|  ____| | / /\n / /    | | | | | | | | | |____| (___    | |    | || |    | ' / | |__  | |/ / \n \\ \\    | |_| | |_| | |_| |____|\\___ \\   | |    | || |    |  <  |  __| |    \\ \\\n  \\_\\    \\___/ \\___/ \\___/      ____) |  | |   _| || |____| . \\ | |____| |\\  \\\n                          v4 |_____/   |_|  |_____\\_____|_|\\_\\|______|_| \\_\\\n"

release_version="unknown"
if command -v curl >/dev/null 2>&1 && [[ -n "$git_remote_url" ]]; then
    if [[ "$git_remote_url" =~ github.com[:/](.+)/(.+?)(\\.git)?$ ]]; then
        repo_owner="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"
        api_url="https://api.github.com/repos/$repo_owner/$repo_name/releases/latest"
        release_version=$(curl -fsSL --max-time 2 "$api_url" | awk -F'\"' '/\"tag_name\":/ {print $4; exit}')
        if [[ -z "$release_version" ]]; then
            release_version="unknown"
        fi
    fi
fi

echo -e "Local:   $current_version"
echo -e "Release: $release_version\n"

# * ===========
# * Validation
# * =========

# ? ================================================
# ? Source prompt script or abort if it isn't found
# ? ==============================================

prompt_function_dir="./scripts/functions/helpers/prompt.sh"
if [[ ! -f $prompt_function_dir ]]; then
    echo -e "\nError: Working directory isn't the script's main.\n"

    echo -e "Tip: Maybe [cd ~/Downloads/lara-stacker/ && sudo ./lara-stacker.sh] instead.\n"

    echo -n "Press any key to exit..."
    read whatever

    clear
    exit 1
fi

chmod +x $prompt_function_dir
source $prompt_function_dir

# ? Abort if the script isn't run with sudo
if [ "$EUID" -ne 0 ]; then
    prompt "Aborted for missing super-user (sudo) permission." "Run the script using [sudo ./lara-stacker.sh] command."
fi

# ? Ensure that the environment file exists
if [ ! -f "./.env" ]; then
    prompt "Aborted for missing [.env] file." "Copy one using [cp .env.example .env] command then fill its values."
fi

# ? =================================================
# ? Ensure that there is no placeholders in the file
# ? ===============================================

placeholders=("<your-username>" "<your-password>")

while IFS= read -r line; do
    # ? Skip comments and empty lines
    [[ "$line" =~ ^#.*$ || "$line" == "" ]] && continue

    for placeholder in "${placeholders[@]}"; do
        if [[ "$line" == *"$placeholder"* ]]; then
            prompt "Aborted because [.env] file contains a placeholder: '$placeholder'." "Please replace placeholders with values."
        fi
    done
done < "./.env"

# ? ===================================================
# ? Double check for environment variables consistency
# ? =================================================

env_example_vars=$(grep -oE '^[A-Z_]+=' .env.example | sort)
env_vars=$(grep -oE '^[A-Z_]+=' .env | sort)

diff <(echo "$env_example_vars") <(echo "$env_vars") &>/dev/null

if [ $? -ne 0 ]; then
    prompt "Aborted for different environment variables." "Ensure that [.env.example] variables match [.env] ones."
fi

# ? Ensure all side scripts are executable
find ./scripts -type f -not -path "*/functions/*" ! -perm -111 -exec chmod +x {} +

# * ============
# * Preparation
# * ==========

# ? Get environment variables and defaults
lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

# * ========
# * Process
# * ========

# ? Loop the menu until user chooses to exit
counter=0
while true; do
    counter=$((counter + 1))

    echo -e "-=|[ LARA-STACKER $current_version ]|=-\n"

    echo -e "Available Operations:\n"

    echo "1. Start Stack"
    echo "2. Stop Stack"
    echo "3. Stack Status"
    echo "4. List Projects"
    echo "5. Create A Project"
    echo "6. Import A Project"
    echo "7. Refresh A Project"
    echo "8. Delete A Project"
    echo "9. Wire Project .env"
    echo "10. Enable A Project"
    echo "11. Disable A Project"
    echo "12. Trust HTTPS (Caddy CA)"
    echo -e "13. Exit\n"

    if [[ $counter -eq 1 && "$1" ]]; then
        choice="$1"
    else
        read -p "Choose an operation (1-13): " choice
    fi

    clear

    # ? Options logic
    case $choice in
    1)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/up.sh
        ;;
    2)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/down.sh
        ;;
    3)
        RAN_MAIN_SCRIPT="true" ./scripts/status.sh
        ;;
    4)
        RAN_MAIN_SCRIPT="true" ./scripts/list.sh
        ;;
    5)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/create.sh
        ;;
    6)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/import.sh
        ;;
    7)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/refresh.sh
        ;;
    8)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/delete.sh
        ;;
    9)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/env.sh
        ;;
    10)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/enable.sh
        ;;
    11)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/disable.sh
        ;;
    12)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/trust.sh
        ;;
    13)
        echo -e "\nExiting Lara-Stacker...\n"
        exit 0
        ;;
    *)
        prompt "-=|[ LARA-STACKER [$current_version] ]|=-" "Invalid option! Please type one the of digits in the list..." false true
        ;;
    esac
done
