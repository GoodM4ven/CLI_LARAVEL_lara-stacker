xdebugUp() {
    local project_name="$1"

    local apps_root="${APPS_ROOT:-/var/www/html}"
    if [[ "$USE_VSC" != "true" ]]; then
        return 0
    fi

    local escaped_project_name
    escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    local project_path="$apps_root/$escaped_project_name"

    if [ ! -d "$project_path" ]; then
        return 0
    fi

    if [ ! -d "$project_path/.vscode" ]; then
        mkdir -p "$project_path/.vscode"
    fi

    cp "$lara_stacker_dir/files/.vscode/launch.json" "$project_path/.vscode/launch.json"

    sed -i "s~\[projectName\]~$escaped_project_name~g" "$project_path/.vscode/launch.json"
    sed -i "s~\[appRoot\]~$apps_root~g" "$project_path/.vscode/launch.json"

    echo -e "\nConfigured VSC debug settings for Xdebug (Docker)."
}
