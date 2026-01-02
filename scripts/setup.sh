#!/bin/bash

clear

# * Display a status indicator
echo -e "-=|[ Lara-Stacker |> SETUP ]|=-"

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

# ? Check if VSCodium or VSC is installed
USING_VSC=false
if command -v codium >/dev/null 2>&1 || command -v code >/dev/null 2>&1; then
    USING_VSC=true
fi

# * =====================
# * Preparing The System
# * ===================

echo -e "\nInstalling system packages..." >&3

if $cancel_suppression; then
    sudo apt install git curl php apache2 php-curl php-xml php-dom php-bcmath php-zip sqlite3 php-sqlite3 -y 2>&1
else
    sudo apt install git curl php apache2 php-curl php-xml php-dom php-bcmath php-zip sqlite3 php-sqlite3 -y 2>&1 >/dev/null
fi

# ? Dynamically get the PHP version
PHP_VERSION=$(php -v | head -n 1 | cut -d ' ' -f 2 | cut -d '.' -f 1,2)
PHP_INI_APACHE="/etc/php/${PHP_VERSION}/apache2/php.ini"
PHP_INI_CLI="/etc/php/${PHP_VERSION}/cli/php.ini"

# ? Update PHP server variables
sudo sed -i "s~post_max_size = 8M~post_max_size = 100M~g" "$PHP_INI_APACHE"
sudo sed -i "s~upload_max_filesize = 2M~upload_max_filesize = 100M~g" "$PHP_INI_APACHE"
sudo sed -i "s~variables_order = \"GPCS\"~variables_order = \"EGPCS\"~g" "$PHP_INI_APACHE"
sudo sed -i'' -e 's/zend\.exception_ignore_args\s*=\s*On/zend.exception_ignore_args = Off/' "$PHP_INI_APACHE"
sudo sed -i'' -e 's/zend\.exception_ignore_args\s*=\s*On/zend.exception_ignore_args = Off/' "$PHP_INI_CLI"

# ? Restart services
sudo systemctl start apache2
sudo a2enmod rewrite
sudo systemctl restart apache2
sudo a2enmod ssl
sudo systemctl restart apache2

# ? Grant user write permissions
sudo usermod -a -G www-data $USERNAME

echo -e "\nAdded the environment's user to [www-data] group." >&3

projects_directory=/var/www/html

# ? Setup permissions permanently
sudo setfacl -Rdm g:www-data:rwx $projects_directory
sudo chown -R :www-data $projects_directory
sudo chmod -R g+rwx $projects_directory

echo -e "\nSet up permissions in the projects directly permanently." >&3

# ? Install media packages
echo -e "\nInstalling media packages..." >&3

if $cancel_suppression; then
    sudo apt install php-imagick php-gd ghostscript ffmpeg -y 2>&1
else
    sudo apt install php-imagick php-gd ghostscript ffmpeg -y 2>&1 >/dev/null
fi

# ? Install Xdebug
echo -e "\nInstalling PHP Xdebug..." >&3

if $cancel_suppression; then
    sudo apt install php-xdebug -y 2>&1
else
    sudo apt install php-xdebug -y 2>&1 >/dev/null
fi

sudo mkdir -p /var/log/xdebug
sudo touch /var/log/xdebug/xdebug.log
sudo chown www-data:adm /var/log/xdebug/xdebug.log
sudo chmod 640 /var/log/xdebug/xdebug.log

XDEBUG_MODS="/etc/php/${PHP_VERSION}/mods-available/xdebug.ini"
XDEBUG_APACHE_CONF="/etc/php/${PHP_VERSION}/apache2/conf.d/99-xdebug.ini"
XDEBUG_CLI_CONF="/etc/php/${PHP_VERSION}/cli/conf.d/99-xdebug.ini"

sudo bash -c "cat > '$XDEBUG_MODS' <<'XEOF'
zend_extension=xdebug.so
XEOF"

sudo bash -c "cat > '$XDEBUG_APACHE_CONF' <<'XEOF'
; Xdebug (Apache SAPI)
; Features: develop,debug for day-to-day; coverage is intentionally OFF by default
xdebug.mode=develop,debug,coverage

; Start only when triggered (browser extension / cookie / GET / POST / env)
xdebug.start_with_request=trigger

; Auto-discover client host (Docker/WSL/VPN friendly). Alternatively set xdebug.client_host.
xdebug.discover_client_host=1
xdebug.client_port=9003

; Logging — keep low to avoid noise; raise to 7-10 if troubleshooting.
xdebug.log=/var/log/xdebug/xdebug.log
xdebug.log_level=0
XEOF"

sudo bash -c "cat > '$XDEBUG_CLI_CONF' <<'XEOF'
; Xdebug (CLI)
xdebug.mode=develop,debug,coverage
xdebug.start_with_request=trigger
xdebug.discover_client_host=1
xdebug.client_port=9003
xdebug.log=/var/log/xdebug/xdebug.log
xdebug.log_level=0
XEOF"

# sudo $lara_stacker_dir/scripts/helpers/permit.sh /var/log/xdebug

sudo systemctl restart apache2

# ? Install Redis
echo -e "\nInstalling Redis..." >&3

if $cancel_suppression; then
    sudo apt install redis php-redis -y 2>&1
    sudo phpenmod redis 2>&1
else
    sudo apt install redis php-redis -y 2>&1 >/dev/null
    sudo phpenmod redis 2>&1 >/dev/null
fi

sudo systemctl restart apache2

# ? Install Google Chrome (for Laravel Dusk)
if ! command -v google-chrome-stable &>/dev/null; then
    cd /home/$USERNAME/Downloads/
    if $cancel_suppression; then
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb 2>&1
        sudo apt install -y ./google-chrome-stable_current_amd64.deb 2>&1
    else
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb 2>&1 >/dev/null
        sudo apt install -y ./google-chrome-stable_current_amd64.deb 2>&1 >/dev/null
    fi
    rm google-chrome-stable_current_amd64.deb
fi

if $OPINIONATED; then

    # ? Install Bun
    if ! command -v bun &>/dev/null; then
        echo -e "\nInstalling Bun front-end package manager..." >&3

        sudo -i -u $USERNAME bash <<EOF
if $cancel_suppression; then
    curl -fsSL https://bun.sh/install | bash 2>&1
else
    curl -fsSL https://bun.sh/install | bash 2>&1 >/dev/null
fi
EOF

        export BUN="/home/$USERNAME/.bun/bin/bun"
    fi

    # ? Install Graphite
    sudo -i -u $USERNAME bash <<EOF
if $cancel_suppression; then
    $BUN add -g @withgraphite/graphite-cli@stable 2>&1
else
    $BUN add -g @withgraphite/graphite-cli@stable 2>&1 >/dev/null
fi
EOF

    echo -e "\nInstalled Graphite version control CLI." >&3
fi

# ? Install Composer (globally)
echo -e "\nInstalling composer globally..." >&3

if $cancel_suppression; then
    sudo apt install composer -y 2>&1
else
    sudo apt install composer -y 2>&1 >/dev/null
fi

echo -e "\nexport PATH=\"\$PATH:/home/$USERNAME/.config/composer/vendor/bin\"" >>/home/$USERNAME/.bashrc

# ? Install mkcert
echo -e "\nInstalling mkcert for SSL generation..." >&3

if $cancel_suppression; then
    sudo apt install mkcert libnss3-tools -y 2>&1
else
    sudo apt install mkcert libnss3-tools -y 2>&1 >/dev/null
fi

# ? Install MySQL
echo -e "\nInstalling MySQL and setting its root password..." >&3

if $cancel_suppression; then
    sudo apt install mysql-server -y 2>&1
else
    sudo apt install mysql-server -y 2>&1 >/dev/null
fi

sudo systemctl start mysql

sudo mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$DB_PASSWORD';"

if $cancel_suppression; then
    sudo apt install php-mysql -y 2>&1
else
    sudo apt install php-mysql -y 2>&1 >/dev/null
fi

sudo service apache2 restart

# ? Create a database for Pest
export MYSQL_PWD=$DB_PASSWORD
mysql -u root -e "CREATE DATABASE pest;"

echo -e "\nCreated a \"pest\" MySQL database for testing." >&3

# ? Install Mailpit (service)
echo -e "\nInstalling Mailpit and setting up a service for it..." >&3

mkdir /home/$USERNAME/Downloads/mailpit
cd /home/$USERNAME/Downloads/mailpit

release_url=$(curl -s https://api.github.com/repos/axllent/mailpit/releases/latest | grep "browser_download_url.*mailpit-linux-amd64.tar.gz" | cut -d : -f 2,3 | tr -d \")
if $cancel_suppression; then
    curl -L -o mailpit-linux-amd64.tar.gz $release_url 2>&1
else
    curl -L -o mailpit-linux-amd64.tar.gz $release_url 2>&1 >/dev/null
fi

tar -xzf mailpit-linux-amd64.tar.gz
sudo chown $USERNAME:$USERNAME mailpit
sudo chmod +x mailpit
sudo mv mailpit /usr/local/bin/

cd ..
sudo rm -rf mailpit

echo "[Unit]
Description=Mailpit
After=network.target

[Service]
User=$USERNAME
Group=$USERNAME
WorkingDirectory=/usr/local/bin
ExecStart=/usr/local/bin/mailpit
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/mailpit.service >/dev/null

sudo systemctl daemon-reload
if $cancel_suppression; then
    sudo systemctl enable mailpit.service 2>&1
else
    sudo systemctl enable mailpit.service 2>&1 >/dev/null
fi
sudo systemctl start mailpit.service

# ? Add an entry for the service to the /etc/hosts file if it doesn't exist
if ! grep -q "127.0.0.1 mailpit" /etc/hosts; then
    echo "127.0.0.1 mailpit" | sudo tee -a /etc/hosts >/dev/null

    echo -e "\nAdded the service to [/etc/hosts] file." >&3
else
    echo -e "\nThe service mailpit is already in the [/etc/hosts] file." >&3
fi

# ? Install MinIO (server, client, and service)
echo -e "\nInstalling MinIO and setting up a service for it..." >&3

mkdir /home/$USERNAME/Downloads/minio
cd /home/$USERNAME/Downloads/minio

if $cancel_suppression; then
    wget https://dl.min.io/server/minio/release/linux-amd64/minio 2>&1
    wget https://dl.min.io/client/mc/release/linux-amd64/mc 2>&1
else
    wget https://dl.min.io/server/minio/release/linux-amd64/minio 2>&1 >/dev/null
    wget https://dl.min.io/client/mc/release/linux-amd64/mc 2>&1 >/dev/null
fi

sudo chown $USERNAME:$USERNAME minio
sudo chmod +x minio
sudo chown $USERNAME:$USERNAME mc
sudo chmod +x mc

sudo mv minio /usr/local/bin/
sudo mv mc /usr/local/bin/minio-client

cd ..
sudo rm -rf minio

mkdir -p /home/$USERNAME/.config/minio/data
sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/minio/data

echo "[Unit]
Description=MinIO
After=network.target

[Service]
User=$USERNAME
Group=$USERNAME
WorkingDirectory=/usr/local/bin
Environment=\"MINIO_ROOT_USER=minioadmin\"
Environment=\"MINIO_ROOT_PASSWORD=minioadmin\"
ExecStart=/usr/local/bin/minio server /home/$USERNAME/.config/minio/data --console-address \":9001\"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target" | sudo tee /etc/systemd/system/minio.service >/dev/null

sudo systemctl daemon-reload
if $cancel_suppression; then
    sudo systemctl enable minio.service 2>&1
else
    sudo systemctl enable minio.service 2>&1 >/dev/null
fi
sudo systemctl start minio.service

# ? Add an entry for the service to the /etc/hosts file if it doesn't exist
if ! grep -q "127.0.0.1 minio" /etc/hosts; then
    echo "127.0.0.1 minio" | sudo tee -a /etc/hosts >/dev/null

    echo -e "\nAdded the service to [/etc/hosts] file." >&3
else
    echo -e "\nThe service minio is already in the [/etc/hosts] file." >&3
fi

sleep 5

sudo -i -u $USERNAME bash <<EOF
minio-client alias set myminio http://localhost:9000 minioadmin minioadmin
EOF

if [ -n "$EXPOSE_TOKEN" ]; then
    # ? Install Expose
    echo -e "\nInstalling Expose and setting up its token to be ready to use..." >&3

    cd /home/$USERNAME/Downloads
    if $cancel_suppression; then
        curl https://github.com/beyondcode/expose/raw/master/builds/expose -L --output expose 2>&1
    else
        curl https://github.com/beyondcode/expose/raw/master/builds/expose -L --output expose 2>&1 >/dev/null
    fi

    sudo chown $USERNAME:$USERNAME expose
    sudo chmod +x expose

    sudo mv expose /usr/local/bin/

    sudo -i -u $USERNAME bash <<EOF
expose token $EXPOSE_TOKEN
EOF
fi

# * =========================
# * Extra Opinionated Setups
# * =======================

if [ "$OPINIONATED" == true ]; then
    # ? Link projects directory
    sudo -i -u $USERNAME bash <<EOF
mkdir /home/$USERNAME/Code
cd /home/$USERNAME/Code
ln -s $projects_directory/
EOF

    cd /home/$USERNAME/Code
    final_folder=$(basename $projects_directory)
    sudo mv $final_folder ./Laravel

    sudo $lara_stacker_dir/scripts/helpers/permit.sh /home/$USERNAME/Code

    echo -e "\nLinked projects directory into [~/Code/Laravel] directory." >&3

    # ? Install Firacode font (if VSC installed)
    if [ $USING_VSC == true ]; then
        if $cancel_suppression; then
            sudo apt install fonts-firacode -y 2>&1
        else
            sudo apt install fonts-firacode -y 2>&1 >/dev/null
        fi

        echo -e "\nInstalled Firacode font for VSC." >&3
    fi

    # ? Create .packages directory
    sudo mkdir $projects_directory/.packages

    sudo $lara_stacker_dir/scripts/helpers/permit.sh $projects_directory/.packages

    echo -e "\nCreated a [$projects_directory/.packages] directory." >&3

    # ? Add helper aliases to .bashrc
    echo -e "\n# Laravel Aliases\nalias cda='composer dump-autoload'\nalias art='php artisan'\nalias wipe='php artisan db:wipe'\nalias fresh='php artisan migrate:fresh'\nalias mfs='php artisan migrate:fresh --seed'\nalias opt='php artisan optimize:clear'\nalias dev='bun run dev'\n" >>/home/$USERNAME/.bashrc

    echo -e "\nAdded some helper aliases to [.bashrc] file. Check 'art' out!" >&3
fi

# * ========
# * The End
# * ======

# ? Mark setup as done
touch $lara_stacker_dir/done-setup.flag
sudo $lara_stacker_dir/scripts/helpers/permit.sh $lara_stacker_dir/done-setup.flag

# ? Conclude everything
echo -e "\nSetup done successfully. The following are required:\n" >&3

echo -e "- Ensure that your web browser is ran properly (launched) once." >&3
echo -e "- Run [mkcert -install] command so SSL certificates can be generated." >&3
echo -e "- Restart the operating system for permissions and services to work.\n" >&3

# ? Prompt to continue
echo -n "Press any key to continue..." >&3
read whatever

clear >&3
