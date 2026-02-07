sessionTableUp() {
    local application_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local application_path="$apps_root/$application_name"

    if [[ ! -d "$application_path" ]]; then
        return 1
    fi

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

    local env_file="$application_path/.env"
    if [[ -f "$env_file" ]]; then
        local db_connection
        db_connection=$(read_env_value "DB_CONNECTION" "$env_file")
        if [[ -n "$db_connection" && "$db_connection" != "mysql" && "$db_connection" != "mariadb" && "$db_connection" != "sqlite" ]]; then
            echo -e "\nDB_CONNECTION is '$db_connection'; skipped session table migration."
            return 0
        fi
    fi

    local migration_glob="$application_path/database/migrations/*create_sessions_table*.php"
    local sessions_declared="false"

    if ls $migration_glob >/dev/null 2>&1; then
        sessions_declared="true"
    elif grep -R -E "Schema::create\\(['\"]sessions['\"]" "$application_path/database/migrations" >/dev/null 2>&1; then
        sessions_declared="true"
    fi

    if [[ "$sessions_declared" != "true" ]]; then
        if ! composeExecApp bash -lc "cd /var/www/html/$application_name && php artisan make:session-table"; then
            if ! ls $migration_glob >/dev/null 2>&1; then
                return 1
            fi
        fi
    fi

    composeExecApp bash -lc "cd /var/www/html/$application_name && php artisan migrate --graceful --ansi" || return 1
}
