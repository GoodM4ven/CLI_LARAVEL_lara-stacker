opinionatedUp() {
    local application_name="$1"

    if [[ "$OPINIONATED" != "true" ]]; then
        return 0
    fi

    local apps_root="${APPS_ROOT:-/var/www/html}"

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
        function is_target(s) { return s ~ /^[[:space:]]*MEMCACHED_HOST=127\\.0\\.0\\.1[[:space:]]*$/ }
        {
            if (is_target($0)) {
                if (has_prev && !prev_blank) {
                    print prev
                }
                has_prev = 0
                next
            }
            if (has_prev) {
                print prev
            }
            prev = $0
            prev_blank = is_blank(prev)
            has_prev = 1
        }
        END {
            if (has_prev) {
                print prev
            }
        }' "$env_file" > "$env_file.tmp" && mv "$env_file.tmp" "$env_file"
    fi

    if [ -f "$lara_stacker_dir/files/.opinionated/.prettierrc" ]; then
        if [ ! -f "$application_path/.prettierrc" ]; then
            cp "$lara_stacker_dir/files/.opinionated/.prettierrc" "$application_path/.prettierrc"
            echo -e "\nCopied opinionated Prettier config."
        fi
    fi
}
