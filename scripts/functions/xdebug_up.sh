xdebugUp() {
    local application_name="$1"

    local apps_root="${APPS_ROOT:-/var/www/html}"
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi
    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    if [[ "$USE_VSC" != "true" ]]; then
        return 0
    fi

    local escaped_application_name
    escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    local application_path="$apps_root/$escaped_application_name"

    if [ ! -d "$application_path" ]; then
        return 0
    fi

    if [ ! -d "$application_path/.vscode" ]; then
        mkdir -p "$application_path/.vscode"
    fi

    local launch_file="$application_path/.vscode/launch.json"
    local extensions_file="$application_path/.vscode/extensions.json"

    cp "$lara_stacker_dir/stubs/.vscode/launch.json" "$launch_file"
    if declare -F sedi >/dev/null 2>&1; then
        sedi "s~\[applicationName\]~$escaped_application_name~g" "$launch_file"
    else
        sed -i "s~\[applicationName\]~$escaped_application_name~g" "$launch_file"
    fi

    if [[ ! -f "$extensions_file" ]]; then
        cp "$lara_stacker_dir/stubs/.vscode/extensions.json" "$extensions_file"
    fi

    echo -e "\nConfigured VSC debug settings for Xdebug (Docker and container path mappings)."
}
