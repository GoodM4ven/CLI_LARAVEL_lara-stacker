workspaceUp() {
    if [[ "$USE_VSC" != "true" ]]; then
        return 0
    fi

    local workspaces_dir="${VSC_WORKSPACES_DIR:-}"
    if [[ -z "$workspaces_dir" ]]; then
        return 0
    fi

    local apps_root="${APPS_ROOT:-/var/www/html}"

    local escaped_application_name
    escaped_application_name=$(echo "$1" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    mkdir -p "$workspaces_dir"
    chown -R "$USERNAME:$USERNAME" "$workspaces_dir"

    local workspace_file="$workspaces_dir/$escaped_application_name.code-workspace"
    if [ -f "$workspace_file" ]; then
        return 0
    fi

    if [ -f "$lara_stacker_dir/files/.opinionated/application.code-workspace" ]; then
        cp "$lara_stacker_dir/files/.opinionated/application.code-workspace" "$workspace_file"
        sed -i "s~<applicationsDirectory>~$apps_root~g" "$workspace_file"
        sed -i "s~<applicationName>~$escaped_application_name~g" "$workspace_file"
        echo -e "\nCreated VSC workspace file."
    fi
}
