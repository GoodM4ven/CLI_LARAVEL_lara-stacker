workspaceUp() {
    local workspaces_dir="${VSC_WORKSPACES_DIR:-}"
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi

    # Workspace files are a VSC-only concept; Zed opens app folders directly
    if ! declare -F resolveDevEditor >/dev/null 2>&1 || [[ "$(resolveDevEditor)" != "vsc" ]]; then
        return 0
    fi

    if declare -F isNullLike >/dev/null 2>&1 && isNullLike "$workspaces_dir"; then
        return 0
    fi
    if [[ -z "$workspaces_dir" ]]; then
        return 0
    fi

    local apps_root="${APPS_ROOT:-/var/www/html}"
    if declare -F normalizePathForHost >/dev/null 2>&1; then
        workspaces_dir=$(normalizePathForHost "$workspaces_dir" "${USERNAME:-}")
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    local escaped_application_name
    escaped_application_name=$(echo "$1" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    mkdir -p "$workspaces_dir"
    if [[ "$EUID" -eq 0 && -n "${USERNAME:-}" ]]; then
        local owner_group
        if declare -F resolveUserGroup >/dev/null 2>&1; then
            owner_group=$(resolveUserGroup "$USERNAME")
        else
            owner_group="$USERNAME"
        fi
        chown -R "$USERNAME:$owner_group" "$workspaces_dir" 2>/dev/null || true
    fi

    local workspace_file="$workspaces_dir/$escaped_application_name.code-workspace"
    if [ -f "$workspace_file" ]; then
        return 0
    fi

    if [ -f "$lara_stacker_dir/stubs/.opinionated/application.code-workspace" ]; then
        cp "$lara_stacker_dir/stubs/.opinionated/application.code-workspace" "$workspace_file"
        if declare -F sedi >/dev/null 2>&1; then
            sedi "s~<applicationsDirectory>~$apps_root~g" "$workspace_file"
            sedi "s~<applicationName>~$escaped_application_name~g" "$workspace_file"
        else
            sed -i "s~<applicationsDirectory>~$apps_root~g" "$workspace_file"
            sed -i "s~<applicationName>~$escaped_application_name~g" "$workspace_file"
        fi
        echo -e "\nCreated VSC workspace file."
    fi
}
