workspaceDown() {
    if [[ "$USE_VSC" != "true" ]]; then
        return 0
    fi

    local workspaces_dir="${VSC_WORKSPACES_DIR:-}"
    if [[ -z "$workspaces_dir" ]]; then
        return 0
    fi

    local escaped_project_name
    escaped_project_name=$(echo "$1" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    local workspace_file="$workspaces_dir/$escaped_project_name.code-workspace"
    if [ -f "$workspace_file" ]; then
        rm -f "$workspace_file"
        echo -e "\nDeleted VSC workspace file."
    fi
}
