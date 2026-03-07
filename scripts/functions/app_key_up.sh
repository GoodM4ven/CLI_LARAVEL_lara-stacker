appKeyUp() {
    local application_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local application_path="$apps_root/$application_name"
    local env_file="$application_path/.env"
    local app_key=""

    if [[ -z "$application_name" ]]; then
        echo -e "\nError: appKeyUp requires an application name."
        return 1
    fi

    if [[ -f "$env_file" ]]; then
        app_key=$(sed -n -E 's/^[[:space:]]*APP_KEY=//p' "$env_file" | tail -n 1)
        app_key="${app_key%%\r}"
        app_key="${app_key%%#*}"
        app_key=$(echo "$app_key" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        app_key="${app_key%\"}"
        app_key="${app_key#\"}"
        app_key="${app_key%\'}"
        app_key="${app_key#\'}"
    fi

    if [[ -n "$app_key" ]]; then
        return 0
    fi

    composeExecApp php "/var/www/html/$application_name/artisan" key:generate --ansi
}
