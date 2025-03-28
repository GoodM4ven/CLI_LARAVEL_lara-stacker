apacheUp() {
    # ? Take in the arguments
    local site_name="$1"
    local cancel_suppression="$2"
    local is_importing_instead="${3:-false}"

    local projects_directory=/var/www/html

    # ? Escape and format the name
    local escaped_project_name=$(echo "$site_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    # ? Abort if the project files don't exist
    if [[ ! -d "$projects_directory/$escaped_project_name" ]]; then
        prompt "The expected '$projects_directory/$escaped_project_name' directory was not found." \
            "Make sure you have a TALL project first." \
            $cancel_suppression \
            true \
            false
    fi

    # ? Add an entry for the site to the /etc/hosts file if it doesn't exist
    if ! grep -q "127.0.0.1 $escaped_project_name.test" /etc/hosts; then
        echo "127.0.0.1 $escaped_project_name.test" | sudo tee -a /etc/hosts >/dev/null

        echo -e "\nAdded the site to [/etc/hosts] file." >&3
    else
        echo -e "\nThe site $escaped_project_name.test is already in the [/etc/hosts] file." >&3
    fi

    # ? Generate SSL certificate files
    sudo -i -u $USERNAME bash <<EOF
cd $projects_directory/$escaped_project_name
if [ ! -d "./.certs" ]; then
    mkdir .certs
fi
cd .certs
if $cancel_suppression; then
    mkcert $escaped_project_name.test 2>&1
else
    mkcert $escaped_project_name.test 2>&1 >/dev/null
fi
EOF

    echo -e "\nRegenerated SSL certificates for the site." >&3

    # ? ===============================================================================
    # ? Generate and enable an Apache2 config file for the project if it doesn't exist
    # ? =============================================================================

    file_path="/etc/apache2/sites-available/$escaped_project_name.conf"

    if [ ! -f "$file_path" ]; then
        sudo touch "$file_path"

        sudo chmod 777 "$file_path"

        sudo echo "<VirtualHost *:80>
        ServerName $escaped_project_name.test
        DocumentRoot $projects_directory/$escaped_project_name/public
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
        RewriteEngine On
        RewriteCond %{HTTPS} off
        RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
        FallbackResource /index.php
    </VirtualHost>

    <IfModule mod_ssl.c>
        <VirtualHost *:443>
            ServerName $escaped_project_name.test
            DocumentRoot $projects_directory/$escaped_project_name/public
            ErrorLog ${APACHE_LOG_DIR}/error.log
            CustomLog ${APACHE_LOG_DIR}/access.log combined

            SSLEngine on
            SSLCertificateFile $projects_directory/$escaped_project_name/.certs/$escaped_project_name.test.pem
            SSLCertificateKeyFile $projects_directory/$escaped_project_name/.certs/$escaped_project_name.test-key.pem
            FallbackResource /index.php
        </VirtualHost>
    </IfModule>" | sudo tee /etc/apache2/sites-available/$escaped_project_name.conf >/dev/null

        sudo a2ensite -q $escaped_project_name

        sudo service apache2 restart

        echo -e "\nCreated and activated the site's Apache config file." >&3
    else
        echo -e "\nThe site Apache configuration for '$escaped_project_name' already exists!" >&3
    fi

    cd $projects_directory/$escaped_project_name

    # ? Link the site URL in the env file
    sed -i "s/APP_NAME=Laravel/APP_NAME=\"$escaped_project_name\"/g" ./.env
    sed -i "s|APP_URL=http://localhost|APP_URL=https://$escaped_project_name.test|g" ./.env

    echo -e "\nLinked the site URL in the project's env file." >&3

    # ? Append .certs to .gitignore if not already ignored
    if ! grep ".certs" .gitignore; then
        echo "/.certs" >> .gitignore
        echo -e "\nAdded .certs folder to .gitignore." >&3
    fi
}
