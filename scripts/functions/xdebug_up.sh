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

    local dev_editor=""
    if declare -F resolveDevEditor >/dev/null 2>&1; then
        dev_editor=$(resolveDevEditor)
    fi
    if [[ -z "$dev_editor" ]]; then
        return 0
    fi

    local escaped_application_name
    escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    local application_path="$apps_root/$escaped_application_name"

    if [ ! -d "$application_path" ]; then
        return 0
    fi

    local target_dir=""
    local target_file=""
    local stub_file=""
    local editor_label=""

    if [[ "$dev_editor" == "zed" ]]; then
        target_dir="$application_path/.zed"
        target_file="$target_dir/debug.json"
        stub_file="$lara_stacker_dir/stubs/.zed/debug.json"
        editor_label="Zed"
    else
        target_dir="$application_path/.vscode"
        target_file="$target_dir/launch.json"
        stub_file="$lara_stacker_dir/stubs/.vscode/launch.json"
        editor_label="VSC"
    fi

    if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
    fi

    cp "$stub_file" "$target_file"
    if declare -F sedi >/dev/null 2>&1; then
        sedi "s~\[applicationName\]~$escaped_application_name~g" "$target_file"
    else
        sed -i "s~\[applicationName\]~$escaped_application_name~g" "$target_file"
    fi

    echo -e "\nConfigured $editor_label debug settings for Xdebug (Docker and container path mappings)."
}
