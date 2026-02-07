cliWrappersUp() {
    local project_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local project_path="$apps_root/$project_name"
    local source_php="$PWD/files/php"
    local dest_php="$project_path/php"

    if [[ ! -d "$project_path" ]]; then
        return 1
    fi

    if [[ -f "$source_php" ]]; then
        if [[ ! -f "$dest_php" ]]; then
            cp "$source_php" "$dest_php"
        fi
        chmod +x "$dest_php" 2>/dev/null || true
    fi
}
