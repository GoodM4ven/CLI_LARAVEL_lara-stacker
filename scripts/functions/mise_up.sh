miseUp() {
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

    local escaped_application_name
    escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    local application_path="$apps_root/$escaped_application_name"

    if [ ! -d "$application_path" ]; then
        return 0
    fi

    # Respect an existing pin; only seed one so `art`/`composer` in the app dir
    # resolve the same PHP version the container runs
    local mise_file="$application_path/mise.toml"
    if [ -f "$mise_file" ] || [ -f "$application_path/.mise.toml" ]; then
        return 0
    fi

    local php_version="${PHP_VERSION:-8.4}"

    cp "$lara_stacker_dir/stubs/mise.toml" "$mise_file"
    if declare -F sedi >/dev/null 2>&1; then
        sedi "s~\[phpVersion\]~$php_version~g" "$mise_file"
    else
        sed -i "s~\[phpVersion\]~$php_version~g" "$mise_file"
    fi

    echo -e "\nPinned PHP $php_version in the application's [mise.toml] (matching the container)."
}
