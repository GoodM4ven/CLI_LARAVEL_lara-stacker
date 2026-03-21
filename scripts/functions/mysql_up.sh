mysqlUp() {
    echo

    local db_or_application_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi
    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    # Format name
    db_or_application_name=$(echo "$db_or_application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    db_or_application_name=${db_or_application_name// /}

    local application_path="$apps_root/$db_or_application_name"
    local env_file="$application_path/.env"

    read_env_value() {
        local key="$1"
        local file="$2"
        local value=""

        if [[ -f "$file" ]]; then
            value=$(sed -n -E "s/^[#[:space:]]*${key}=//p" "$file" | tail -n 1)
            value="${value%%\r}"
            value="${value%%#*}"
            value=$(echo "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
        fi

        echo "$value"
    }

    if [[ -f "$env_file" ]]; then
        local db_connection
        db_connection=$(read_env_value "DB_CONNECTION" "$env_file")
        if [[ -n "$db_connection" && "$db_connection" != "mysql" && "$db_connection" != "mariadb" ]]; then
            echo -e "DB_CONNECTION is '$db_connection'; skipped MySQL database creation."
            return 0
        fi
    fi

    local db_name
    db_name=$(echo "$db_or_application_name" | sed 's/\([[:lower:]]\)\([[:upper:]]\)/\1_\2/g' | sed 's/\([[:upper:]]\)\([[:upper:]][[:lower:]]\)/\1_\2/g' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/^_//')

    if [[ -z "$(dockerCompose ps -q mysql)" ]]; then
        echo -e "\nMySQL container is not running; skipped database creation."
        return 0
    fi

    dockerCompose exec -T mysql mysql -u root -p"$DB_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS $db_name;"

    echo -e "\nCreated '$db_name' MySQL database (if missing)."
}
