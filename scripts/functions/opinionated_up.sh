opinionatedUp() {
    local project_name="$1"

    if [[ "$OPINIONATED" != "true" ]]; then
        return 0
    fi

    local app_root="${APP_ROOT:-/var/www/html}"

    local escaped_project_name
    escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    local project_path="$app_root/$escaped_project_name"

    if [ ! -d "$project_path" ]; then
        return 0
    fi

    if [ -f "$lara_stacker_dir/files/.opinionated/.prettierrc" ]; then
        if [ ! -f "$project_path/.prettierrc" ]; then
            cp "$lara_stacker_dir/files/.opinionated/.prettierrc" "$project_path/.prettierrc"
            echo -e "\nCopied opinionated Prettier config." >&3
        fi
    fi
}
