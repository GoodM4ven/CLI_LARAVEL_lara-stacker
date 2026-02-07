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

    if [ -f "$lara_stacker_dir/files/.opinionated/.prettierrc" ]; then
        if [ ! -f "$application_path/.prettierrc" ]; then
            cp "$lara_stacker_dir/files/.opinionated/.prettierrc" "$application_path/.prettierrc"
            echo -e "\nCopied opinionated Prettier config."
        fi
    fi
}
