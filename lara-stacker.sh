#!/bin/bash

clear

# * ===========================
# * Display a status indicator
# * =========================

current_version="???"
is_updateable=false
script_dir="$(pwd)"

if command -v git &> /dev/null && [ -d ".git" ]; then
    is_updateable=true
    
    # ? Add the current script directory to the Git safe list
    git config --global --add safe.directory "$script_dir"
fi

if [[ "$is_updateable" == true ]]; then
    # ? Fetch the latest commit message that starts with a version tag
    current_version=$(git log --pretty=format:'%s' | grep -o '\[v[0-9]*\.[0-9]*\.[0-9]*\]' | head -1 | tr -d '[]')
fi

echo -e "-=|[ LARA-STACKER $current_version ]|=-"

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
# * ======

# ? =====================
# ? Checking for updates
# ? ===================

if [[ -f "/tmp/updated-lara-stacker.flag" ]]; then
    rm /tmp/updated-lara-stacker.flag
fi

echo -en "\nChecking for updates"
sleep 1
echo -en "."
sleep 1
echo -en "."

update_available=false
latest_version=""

# ? Check for updates if it's possible
if [[ "$is_updateable" == true ]]; then
    git fetch origin

    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse "origin/main")

    if [ "$LOCAL" != "$REMOTE" ]; then
        update_available=true
        latest_version=$(git ls-remote --tags origin | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*$' | sort -V | tail -1)
    fi
fi

echo -en "."

clear

# ? Display the update version, if any
if [ "$update_available" == true ]; then
    echo -e "New version ($latest_version) is available!\n"
fi

# ? Loop the menu until user chooses to exit
counter=0
while true; do
    counter=$((counter + 1))

    echo -e "-=|[ LARA-STACKER $current_version ]|=-\n"

    echo -e "Available Operations:\n"

    options=("1. Manage TALL Projects" "2. Manage MySQL Databases" "3. Manage Apache Sites" "4. Create A Raw Laravel Project" "5. Exit")

    # ? Conditional options
    include_zero=false
    if [[ -f "/tmp/updated-lara-stacker.flag" ]]; then
        rm /tmp/updated-lara-stacker.flag
        update_available=false
    fi
    if [ "$update_available" == true ]; then
        options+=("6. Download Updates")
    fi
    if [[ ! -f "$lara_stacker_dir/done-setup.flag" ]]; then
        options+=("0. Initial Setup")
        include_zero=true
    fi

    for opt in "${options[@]}"; do
        echo "$opt "
    done

    echo ""
    if [[ $counter -eq 1 && "$1" ]]; then
        choice="$1"
    else
        if [ "$include_zero" == true ]; then
            options_count=$((${#options[@]} - 1))
            read -p "Choose an operation (0-$options_count): " choice
        else
            options_count=$((${#options[@]}))
            read -p "Choose an operation (1-$options_count): " choice
        fi
    fi

    clear

    # ? Options logic
    case $choice in
    0)
        if [[ -f "$lara_stacker_dir/done-setup.flag" ]]; then
            prompt "-=|[ LARA-STACKER [$current_version] ]|=-" "Invalid option! Please type one the of digits in the list..." false
        else
            sudo RAN_MAIN_SCRIPT="true" ./scripts/setup.sh
        fi
        ;;
    1)
        while true; do
            clear

            echo -e "-=|[ Lara-Stacker |> TALL PROJECTS MANAGEMENT ]|=-\n"

            echo -e "TALL Stack Frameworks:\n"

            echo "- TailwindCSS"
            echo "- AlpineJS"
            echo "- Livewire"
            echo -e "- Laravel\n"

            echo -e "Available Operations:\n"

            echo "1. List All Projects"
            echo "2. Create A Project"
            echo "3. Delete A Project"
            echo "4. Import A Project"
            echo "5. Refresh A Project"
            echo -e "6. Go Back To Main Menu\n"

            read -p "Choose an operation (1-6): " stack_choice

            case $stack_choice in
            1)
                RAN_MAIN_SCRIPT="true" ./scripts/TALL/list.sh
                ;;
            2)
                sudo RAN_MAIN_SCRIPT="true" ./scripts/TALL/create.sh
                ;;
            3)
                sudo RAN_MAIN_SCRIPT="true" ./scripts/TALL/delete.sh
                ;;
            4)
                sudo RAN_MAIN_SCRIPT="true" ./scripts/TALL/import.sh
                ;;
            5)
                sudo RAN_MAIN_SCRIPT="true" ./scripts/TALL/refresh.sh
                ;;
            6)
                clear
                break
                ;;
            *)
                clear
                prompt "-=|[ Lara-Stacker |> TALL PROJECTS MANAGEMENT ]|=-" "Invalid option! Please type one the of digits in the list..." false true
                ;;
            esac
        done
        ;;
    2)
        while true; do
            clear

            echo -e "-=|[ Lara-Stacker |> MYSQL DATABASE MANAGEMENT ]|=-\n"

            echo -e "Available Operations:\n"

            echo "1. List All Databases"
            echo "2. Create A Database"
            echo "3. Delete A Database"
            echo -e "4. Go Back To Main Menu\n"

            read -p "Choose an operation (1-4): " db_choice

            case $db_choice in
            1)
                RAN_MAIN_SCRIPT="true" ./scripts/mysql/list.sh
                ;;
            2)
                RAN_MAIN_SCRIPT="true" ./scripts/mysql/create.sh
                ;;
            3)
                RAN_MAIN_SCRIPT="true" ./scripts/mysql/delete.sh
                ;;
            4)
                clear
                break
                ;;
            *)
                clear
                prompt "-=|[ Lara-Stacker |> MYSQL DATABASE MANAGEMENT ]|=-" "Invalid option! Please type one the of digits in the list..." false true
                ;;
            esac
        done
        ;;
    3)
        while true; do
            clear

            echo -e "-=|[ Lara-Stacker |> APACHE SITE MANAGEMENT ]|=-\n"

            echo -e "Available Operations:\n"

            echo "1. List All Sites"
            echo "2. Enable A Site"
            echo "3. Disable A Site"
            echo -e "4. Go Back To Main Menu\n"

            read -p "Choose an operation (1-4): " site_choice

            case $site_choice in
            1)
                RAN_MAIN_SCRIPT="true" ./scripts/apache/list.sh
                ;;
            2)
                RAN_MAIN_SCRIPT="true" ./scripts/apache/enable.sh
                ;;
            3)
                RAN_MAIN_SCRIPT="true" ./scripts/apache/disable.sh
                ;;
            4)
                clear
                break
                ;;
            *)
                clear
                prompt "-=|[ Lara-Stacker |> APACHE SITE MANAGEMENT ]|=-" "Invalid option! Please type one the of digits in the list..." false true
                ;;
            esac
        done
        ;;
    4)
        sudo RAN_MAIN_SCRIPT="true" ./scripts/create_raw.sh
        ;;
    5)
        echo -e "\nExiting Lara-Stacker...\n"
        exit 0
        ;;
    6)
        if [ "$update_available" == false ]; then
            prompt "-=|[ LARA-STACKER [$current_version] ]|=-" "Invalid option! Please type one the of digits in the list..." false
        else
            sudo RAN_MAIN_SCRIPT="true" ./scripts/update.sh
        fi
        ;;
    *)
        prompt "-=|[ LARA-STACKER [$current_version] ]|=-" "Invalid option! Please type one the of digits in the list..." false true
        ;;
    esac
done
