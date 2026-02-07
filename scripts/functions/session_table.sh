sessionTableUp() {
    local project_name="$1"
    local app_root="${APP_ROOT:-/var/www/html}"
    local project_path="$app_root/$project_name"

    if [[ ! -d "$project_path" ]]; then
        return 1
    fi

    local migration_glob="$project_path/database/migrations/*create_sessions_table*.php"
    if ! ls $migration_glob >/dev/null 2>&1; then
        if ! composeExecApp bash -lc "cd /var/www/html/$project_name && php artisan make:session-table"; then
            if ! ls $migration_glob >/dev/null 2>&1; then
                return 1
            fi
        fi
    fi

    composeExecApp bash -lc "cd /var/www/html/$project_name && php artisan migrate --graceful --ansi" || return 1
}
