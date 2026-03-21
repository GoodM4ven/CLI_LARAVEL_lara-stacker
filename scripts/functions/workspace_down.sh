workspaceDown() {
    if [[ "$USE_VSC" != "true" ]]; then
        return 0
    fi

    local workspaces_dir="${VSC_WORKSPACES_DIR:-}"
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi
    if declare -F isNullLike >/dev/null 2>&1 && isNullLike "$workspaces_dir"; then
        return 0
    fi
    if [[ -z "$workspaces_dir" ]]; then
        return 0
    fi
    if declare -F normalizePathForHost >/dev/null 2>&1; then
        workspaces_dir=$(normalizePathForHost "$workspaces_dir" "${USERNAME:-}")
    fi

    local escaped_application_name
    escaped_application_name=$(echo "$1" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    local workspace_file="$workspaces_dir/$escaped_application_name.code-workspace"
    if [ -f "$workspace_file" ]; then
        rm -f "$workspace_file"
        echo -e "\nDeleted VSC workspace file."
    fi
}
