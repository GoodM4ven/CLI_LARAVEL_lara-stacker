opinionatedUp() {
    local application_name="$1"

    if [[ "$OPINIONATED" != "true" ]]; then
        return 0
    fi

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

    local env_file="$application_path/.env"
    if [ -f "$env_file" ]; then
        awk '
        function is_blank(s) { return s ~ /^[[:space:]]*$/ }
        function strip_cr(s) { sub(/\r$/, "", s); return s }
        function is_target(s) {
            s = strip_cr(s)
            return s ~ /^[[:space:]]*MEMCACHED_HOST[[:space:]]*=[[:space:]]*["\047]?127\\.0\\.0\\.1["\047]?[[:space:]]*(#.*)?$/
        }
        {
            line = $0
            if (is_target(line)) {
                if (has_prev && !prev_blank) {
                    print prev
                }
                has_prev = 0
                next
            }
            if (has_prev) {
                print prev
            }
            prev = line
            prev_blank = is_blank(prev)
            has_prev = 1
        }
        END {
            if (has_prev) {
                print prev
            }
        }' "$env_file" > "$env_file.tmp" && mv "$env_file.tmp" "$env_file"
    fi

    if [ -f "$lara_stacker_dir/stubs/.opinionated/.prettierrc" ]; then
        if [ ! -f "$application_path/.prettierrc" ]; then
            cp "$lara_stacker_dir/stubs/.opinionated/.prettierrc" "$application_path/.prettierrc"
            echo -e "\nCopied opinionated Prettier config."
        fi
    fi
}
