#!/bin/bash

clear

# * Display a status indicator
echo -e "-=|[ Lara-Stacker |> TALL Projects Management |> REFRESH ]|=-"

# * ===========
# * Validation
# * =========

# ? Source the helper function scripts first
functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]] || ! chmod +x "$script" || ! source "$script"; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
done

# ? Ensure the script isn't ran directly
if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

# ? Confirm if setup script isn't run already
sourcer "helpers.continueOrAbort"
if [ ! -e "$PWD/done-setup.flag" ]; then
    continueOrAbort "Setup script isn't run yet." "Aborting..."
fi

# * ============
# * Preparation
# * ==========

# ? Get environment variables and defaults
lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

# ? Set the echoing level
conditional_quiet="--quiet"
cancel_suppression=false
case $LOGGING_LEVEL in
# Notifications Only
1)
    exec 3>&1
    exec >/dev/null 2>&1
    ;;
# Notifications + Errors + Warnings
2)
    exec 3>&1
    exec >/dev/null
    ;;
# Everything
*)
    exec 3>&1
    conditional_quiet=""
    cancel_suppression=true
    ;;
esac

# * ========
# * Process
# * ======

# ? Get the project name from the user
echo -ne "\nEnter the project name: " >&3
read project_name

escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
escaped_project_name=${escaped_project_name// /}

projects_directory=/var/www/html

# ? Check if the project doesn't exist
if ! [ -d "$projects_directory/$escaped_project_name" ]; then
    prompt "Project \"$escaped_project_name\" doesn't exist." "" $cancel_suppression
fi

# ? ========================================================
# ? Ensure the project is cleared off of anything ephemiral
# ? ======================================================

project_path=$projects_directory/$escaped_project_name

# ? Delete temporary files and folders
echo -e "\nDeleted dependencies.\n" >&3

sudo rm -rf "$project_path/node_modules"
sudo rm -rf "$project_path/vendor"
sudo rm -rf "$project_path/composer.lock"
sudo rm -rf "$project_path/bun.lock"
sudo rm -rf "$project_path/bun.lockb"
sudo rm -rf "$project_path/package-lock.json"

# ? Reinstall dependencies
echo -e "Reinstalling dependencies...\n" >&3

cd "$project_path"

sudo -i -u $USERNAME bash <<EOF
cd "$project_path"
if $cancel_suppression; then
    composer install --no-cache $conditional_quiet 2>&1
else
    composer install --no-cache $conditional_quiet 2>&1 >/dev/null
fi
EOF

package_manager=""
BUN_PATH=""

if command -v bun >/dev/null 2>&1; then
    BUN_PATH="$(command -v bun)"
elif [ -x "/home/$USERNAME/.bun/bin/bun" ]; then
    BUN_PATH="/home/$USERNAME/.bun/bin/bun"
fi

if [[ -n "$BUN_PATH" ]]; then
    package_manager="bun"
elif command -v npm >/dev/null 2>&1; then
    package_manager="npm"
fi

case "$package_manager" in
    bun)
        sudo -i -u $USERNAME bash <<EOF
cd "$project_path"
if $cancel_suppression; then
    "$BUN_PATH" install --no-interaction 2>&1
else
    "$BUN_PATH" install --no-interaction 2>&1 >/dev/null
fi
EOF
        ;;
    npm)
        sudo -i -u $USERNAME bash <<EOF
cd "$project_path"
if $cancel_suppression; then
    npm install 2>&1
else
    npm install 2>&1 >/dev/null
fi
EOF
        ;;
    *)
        echo -e "Skipped JS dependencies reinstall (bun/npm not found)." >&3
        ;;
esac

cd "$project_path"

# ? Clear Laravel cache
echo -e "Clearing Laravel caches...\n" >&3

sudo -i -u $USERNAME bash <<EOF
cd "$project_path"
if $cancel_suppression; then
    php artisan optimize:clear --quiet
else
    php artisan optimize:clear --quiet >/dev/null
fi
EOF

# ? Restart system services
echo -e "Restarted Apache service.\n" >&3

sudo systemctl restart apache2

# ? Check system services
echo -e "Checking up system services...\n" >&3

status=$(systemctl is-active "apache2" 2>/dev/null || echo "unknown")
echo -e "  apache2 => $status" >&3

php_fpm_service=$(systemctl list-units --type=service --all | grep -Eo 'php[0-9]+\.[0-9]+-fpm\.service' | head -n 1)
status=$(systemctl is-active "$php_fpm_service" 2>/dev/null || echo "unknown")
echo -e "  $php_fpm_service => $status" >&3

status=$(systemctl is-active "mysql" 2>/dev/null || echo "unknown")
echo -e "  mysql => $status" >&3

status=$(systemctl is-active "redis" 2>/dev/null || echo "unknown")
echo -e "  redis => $status" >&3

status=$(systemctl is-active "mailpit" 2>/dev/null || echo "unknown")
echo -e "  mailpit => $status" >&3

status=$(systemctl is-active "minio" 2>/dev/null || echo "unknown")
echo -e "  minio => $status\n" >&3

# ? Double-checking files ownership and permissions
echo -e "Owned the project files again.\n" >&3

sudo $lara_stacker_dir/scripts/helpers/permit.sh $project_path

# ? Display a success indicator
echo -e "Done clearing the project successfully!\n" >&3

# * ========
# * The End
# * ======

# * Prompt to continue
read -p "Press any key to continue..." whatever

clear
