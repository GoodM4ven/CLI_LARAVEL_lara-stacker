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

cat <<'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ ║
 _              _____                ____ _______       ____ _  __ ____ _____  
| |       /\   |  __ \     /\       / ___|__   __|/\   / ___| |/ /  ___|  __ \ 
| |      /  \  | |__) |   /  \ ____| (__    | |  /  \ | |   | ' /| |_  | |__) |
| |     / /\ \ |  _  /   / /\ \_____\__ \   | | / /\ \| |   |  < |  _| |  _  / 
| |___ / ____ \| | \ \  / ____ \    ___) |  | |/ ____ \ |___| . \| |___| | \ \ 
|_____/_/    \_\_|  \_\/_/    \_\  |____/   |_/_/    \_\____|_|\_\_____|_|  \_\\
║                                                                              ║
EOF

inner_width=76
right_text="~ GoodM4ven.dev"
left_text="Current: $current_version | Release: $release_version"
max_left=$((inner_width - ${#right_text} - 1))
if ((max_left < 0)); then
    max_left=0
fi
if ((${#left_text} > max_left)); then
    left_text="${left_text:0:max_left}"
fi
spaces=$((inner_width - ${#left_text} - ${#right_text}))
if ((spaces < 1)); then
    spaces=1
fi
printf "║ %s%*s%s ║\n" "$left_text" "$spaces" "" "$right_text"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"

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

    repeat_char() {
        local char=$1
        local count=$2
        printf -v _tmp '%*s' "$count" ''
        printf '%s' "${_tmp// /$char}"
    }

    center_text() {
        local text=$1
        local width=$2
        local len=${#text}
        if ((len >= width)); then
            printf "%-*s" "$width" "$text"
            return
        fi
        local pad=$((width - len))
        local left=$((pad / 2))
        local right=$((pad - left))
        printf "%*s%s%*s" "$left" "" "$text" "$right" ""
    }

    col1_title="Container"
    col2_title="Services"
    col3_title="Applications"

    col1_options=(
        "17|Start"
        "18|Check"
        "19|Stop"
        "20|Certify"
        "21|Purge"
    )

    col2_options=(
        "09|MySQL > List"
        "10|MySQL > Create"
        "11|MySQL > Delete"
        "12|MinIO > List"
        "13|MinIO > Create"
        "14|MinIO > Delete"
        "15|Redis > List"
        "16|Redis > Delete"
    )

    col3_options=(
        "01|List"
        "02|Create"
        "03|Import"
        "04|Refresh"
        "05|Rewire"
        "06|Delete"
        "07|Enable"
        "08|Disable"
    )

    col1_width=22
    col2_width=26
    col3_width=22
    max_lines=$((2 + ${#col1_options[@]}))
    if [ $((2 + ${#col2_options[@]})) -gt $max_lines ]; then
        max_lines=$((2 + ${#col2_options[@]}))
    fi
    if [ $((2 + ${#col3_options[@]})) -gt $max_lines ]; then
        max_lines=$((2 + ${#col3_options[@]}))
    fi

    top_border="⌜$(repeat_char "─" "$((col1_width + 2))")┬$(repeat_char "─" "$((col2_width + 2))")┬$(repeat_char "─" "$((col3_width + 2))")⌝"
    bottom_border="⌞$(repeat_char "─" "$((col1_width + 2))")┴$(repeat_char "─" "$((col2_width + 2))")┴$(repeat_char "─" "$((col3_width + 2))")⌟"

    echo "$top_border"
    for ((i = 0; i < max_lines; i++)); do
        if [ $i -eq 0 ]; then
            col1_line=$(printf "%-*s" "$col1_width" "$col1_title")
            col2_line=$(center_text "$col2_title" "$col2_width")
            col3_line=$(printf "%*s" "$col3_width" "$col3_title")
        elif [ $i -eq 1 ]; then
            col1_line=$(repeat_char "=" "$col1_width")
            col2_line=$(repeat_char "=" "$col2_width")
            col3_line=$(repeat_char "=" "$col3_width")
        else
            idx=$((i - 2))

            if [ $idx -lt ${#col1_options[@]} ]; then
                IFS='|' read -r num label <<< "${col1_options[$idx]}"
                col1_line=$(printf "%-*s" "$col1_width" "${num}. ${label}")
            else
                col1_line=$(printf "%-*s" "$col1_width" "")
            fi

            if [ $idx -lt ${#col2_options[@]} ]; then
                IFS='|' read -r num label <<< "${col2_options[$idx]}"
                left="${num}."
                right=".${num}"
                inner_width=$((col2_width - ${#left} - ${#right} - 6))
                if [ $inner_width -lt 1 ]; then
                    col2_line=$(printf "%-*s" "$col2_width" "${num}. ${label}")
                else
                    centered_label=$(center_text "$label" "$inner_width")
                    col2_line="${left}   ${centered_label}   ${right}"
                fi
            else
                col2_line=$(printf "%-*s" "$col2_width" "")
            fi

            if [ $idx -lt ${#col3_options[@]} ]; then
                IFS='|' read -r num label <<< "${col3_options[$idx]}"
                col3_line=$(printf "%*s" "$col3_width" "${label} .${num}")
            else
                col3_line=$(printf "%-*s" "$col3_width" "")
            fi
        fi

        printf "│ %-*s │ %-*s │ %-*s │\n" \
            "$col1_width" "$col1_line" \
            "$col2_width" "$col2_line" \
            "$col3_width" "$col3_line"
    done
    echo "$bottom_border"

    if [[ $counter -eq 1 && "$1" ]]; then
        choice="$1"
    else
        read -r -p "Choose an operation (1-21, or Q to quit): " choice
    fi
    choice=$(echo "$choice" | tr -d '[:space:]')
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
        echo -e "\nExiting Lara-Stacker...\n"
        exit 0
    fi
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
        RAN_MAIN_SCRIPT="true" ./scripts/env.sh
        ;;
    6)
        RAN_MAIN_SCRIPT="true" ./scripts/delete.sh
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
        RAN_MAIN_SCRIPT="true" ./scripts/minio_list.sh
        ;;
    13)
        RAN_MAIN_SCRIPT="true" ./scripts/minio_create.sh
        ;;
    14)
        RAN_MAIN_SCRIPT="true" ./scripts/minio_delete.sh
        ;;
    15)
        RAN_MAIN_SCRIPT="true" ./scripts/redis_list.sh
        ;;
    16)
        RAN_MAIN_SCRIPT="true" ./scripts/redis_delete.sh
        ;;
    17)
        RAN_MAIN_SCRIPT="true" ./scripts/up.sh
        ;;
    18)
        RAN_MAIN_SCRIPT="true" ./scripts/status.sh
        ;;
    19)
        RAN_MAIN_SCRIPT="true" ./scripts/down.sh
        ;;
    20)
        RAN_MAIN_SCRIPT="true" ./scripts/trust.sh
        ;;
    21)
        RAN_MAIN_SCRIPT="true" ./scripts/purge.sh
        ;;
    *)
        prompt "-=|[ LARA-STACKER [$current_version] ]|=-" "Invalid option! Please type one the of digits in the list..." false true
        ;;
    esac
done
