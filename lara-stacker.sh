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

cat <<'EOF'
 _               _____                 _____ _______       _____ _  __ _____ _____  
| |        /\   |  __ \     /\        / ____|__   __|/\   / ____| |/ /  ____|  __ \ 
| |       /  \  | |__) |   /  \ _____| (___    | |  /  \ | |    | ' /| |__  | |__) |
| |      / /\ \ |  _  /   / /\ \______\___ \   | | / /\ \| |    |  < |  __| |  _  / 
| |____ / ____ \| | \ \  / ____ \     ____) |  | |/ ____ \ |____| . \| |____| | \ \ 
|______/_/    \_\_|  \_\/_/    \_\   |_____/   |_/_/    \_\_____|_|\_\______|_|  \_\
EOF

release_version="unknown"
if command -v curl >/dev/null 2>&1 && [[ -n "$git_remote_url" ]]; then
    if [[ "$git_remote_url" =~ github.com[:/]+([^/]+)/([^/]+)(\\.git)?$ ]]; then
        repo_owner="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"
        repo_name="${repo_name%.git}"
        api_url="https://api.github.com/repos/$repo_owner/$repo_name/releases/latest"
        release_json=$(curl -sL --max-time 2 "$api_url" 2>/dev/null || true)
        if [[ -n "$release_json" ]]; then
            release_version=$(printf '%s' "$release_json" | grep -m1 '"tag_name":' | cut -d'"' -f4)
        fi
        if [[ -z "$release_version" ]]; then
            tags_json=$(curl -sL --max-time 2 "https://api.github.com/repos/$repo_owner/$repo_name/tags?per_page=1" 2>/dev/null || true)
            if [[ -n "$tags_json" ]]; then
                release_version=$(printf '%s' "$tags_json" | grep -m1 '"name":' | cut -d'"' -f4)
            fi
        fi
        if [[ -z "$release_version" ]]; then
            release_version="unknown"
        fi
    fi
fi

echo -e "\nLocal:   $current_version"
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

chmod +x $prompt_function_dir 2>/dev/null || true
source $prompt_function_dir

# ? Allow non-sudo runs (Docker Desktop uses user sockets)

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
find ./scripts -type f -not -path "*/functions/*" ! -perm -111 -exec chmod +x {} + 2>/dev/null || true

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

    # echo -e "-=|[ LARA-STACKER $current_version ]|=-\n"

    echo -e "Available Operations:\n"

    echo "    Project Management"
    echo "    =================="
    echo "01. List Projects"
    echo "02. Create Project"
    echo "03. Import Project"
    echo "04. Refresh Project"
    echo "05. Delete Project"
    echo "06. Rewire Project"
    echo "07. Enable Project"
    echo -e "08. Disable Project\n"

    echo "    Service Control"
    echo "    ==============="
    echo "09. List MySQL Databases"
    echo "10. Create MySQL Database"
    echo -e "11. Delete MySQL Database\n"

    echo "    Stack Setup"
    echo "    ==========="
    echo "12. Start Stack"
    echo "13. Stop Stack"
    echo "14. Stack Status"
    echo "15. Trust HTTPS"
    echo "16. Purge Stack (containers/images/volumes/cache)"
    echo -e "17. Exit\n"

    if [[ $counter -eq 1 && "$1" ]]; then
        choice="$1"
    else
        read -p "Choose an operation (1-17): " choice
    fi
    choice=$(echo "$choice" | tr -d '[:space:]')
    if [[ "$choice" =~ ^0+[0-9]+$ ]]; then
        choice="$(echo "$choice" | sed 's/^0\+//')"
        if [[ -z "$choice" ]]; then
            choice="0"
        fi
    fi

    clear

    # ? Options logic
    case $choice in
    1)
        RAN_MAIN_SCRIPT="true" ./scripts/list.sh
        ;;
    2)
        RAN_MAIN_SCRIPT="true" ./scripts/create.sh
        ;;
    3)
        RAN_MAIN_SCRIPT="true" ./scripts/import.sh
        ;;
    4)
        RAN_MAIN_SCRIPT="true" ./scripts/refresh.sh
        ;;
    5)
        RAN_MAIN_SCRIPT="true" ./scripts/delete.sh
        ;;
    6)
        RAN_MAIN_SCRIPT="true" ./scripts/env.sh
        ;;
    7)
        RAN_MAIN_SCRIPT="true" ./scripts/enable.sh
        ;;
    8)
        RAN_MAIN_SCRIPT="true" ./scripts/disable.sh
        ;;
    9)
        RAN_MAIN_SCRIPT="true" ./scripts/mysql_list.sh
        ;;
    10)
        RAN_MAIN_SCRIPT="true" ./scripts/mysql_create.sh
        ;;
    11)
        RAN_MAIN_SCRIPT="true" ./scripts/mysql_delete.sh
        ;;
    12)
        RAN_MAIN_SCRIPT="true" ./scripts/up.sh
        ;;
    13)
        RAN_MAIN_SCRIPT="true" ./scripts/down.sh
        ;;
    14)
        RAN_MAIN_SCRIPT="true" ./scripts/status.sh
        ;;
    15)
        RAN_MAIN_SCRIPT="true" ./scripts/trust.sh
        ;;
    16)
        RAN_MAIN_SCRIPT="true" ./scripts/purge.sh
        ;;
    17)
        echo -e "\nExiting Lara-Stacker...\n"
        exit 0
        ;;
    *)
        prompt "-=|[ LARA-STACKER [$current_version] ]|=-" "Invalid option! Please type one the of digits in the list..." false true
        ;;
    esac
done
