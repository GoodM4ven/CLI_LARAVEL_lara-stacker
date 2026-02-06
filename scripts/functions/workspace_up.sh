workspaceUp() {
    if [[ "$USE_VSC" != "true" ]]; then
        return 0
    fi

    local workspaces_dir="${VSC_WORKSPACES_DIR:-}"
    if [[ -z "$workspaces_dir" ]]; then
        return 0
    fi

    local app_root="${APP_ROOT:-/var/www/html}"

    local escaped_project_name
    escaped_project_name=$(echo "$1" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    mkdir -p "$workspaces_dir"
    chown -R "$USERNAME:$USERNAME" "$workspaces_dir"

    local workspace_file="$workspaces_dir/$escaped_project_name.code-workspace"
    if [ -f "$workspace_file" ]; then
        return 0
    fi

    if [ -f "$lara_stacker_dir/files/.opinionated/project.code-workspace" ]; then
        cp "$lara_stacker_dir/files/.opinionated/project.code-workspace" "$workspace_file"
        sed -i "s~<projectsDirectory>~$app_root~g" "$workspace_file"
        sed -i "s~<projectName>~$escaped_project_name~g" "$workspace_file"
        echo -e "\nCreated VSC workspace file." >&3
    fi
}
