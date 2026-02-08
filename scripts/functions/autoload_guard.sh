autoloadGuard() {
    local application_name="$1"
    local autoload_path="/var/www/html/$application_name/vendor/autoload.php"

    if [[ -z "$application_name" ]]; then
        echo -e "\nError: autoloadGuard requires an application name."
        return 1
    fi

    if composeExecApp php -r "require '$autoload_path';" >/dev/null 2>&1; then
        return 0
    fi

    # echo -e "\nAutoload check failed. Reloading PHP-FPM..."
    composeExecApp kill -USR2 1 >/dev/null 2>&1 || true
    sleep 1

    if composeExecApp php -r "require '$autoload_path';" >/dev/null 2>&1; then
        return 0
    fi

    # echo -e "\nAutoload still failing. Restarting the container...\n"
    composeDown || true
    if ! composeUp; then
        prompt "Failed to start the Docker container." "Start the container and retry." false
    fi

    if ! composeExecApp php -r "require '$autoload_path';" >/dev/null 2>&1; then
        prompt "App container can't load vendor/autoload.php." "Check APPS_ROOT and Docker file sharing (or run Composer inside the app container) and retry." false
    fi
}
