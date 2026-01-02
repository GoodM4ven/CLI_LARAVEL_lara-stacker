mysqlUp() {
    # ? Take in the arguments
    local db_or_project_name="$1"
    local deal_with_project_files="${2:-true}"

    local projects_directory=/var/www/html

    # ? Format the name
    db_or_project_name=$(echo "$db_or_project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    db_or_project_name=${db_or_project_name// /}

    db_name=$(echo "$db_or_project_name" | sed 's/\([[:lower:]]\)\([[:upper:]]\)/\1_\2/g' | sed 's/\([[:upper:]]\)\([[:upper:]][[:lower:]]\)/\1_\2/g' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/^_//')

    # ? Create the DB if it doesn't exist
    export MYSQL_PWD=$DB_PASSWORD
    if mysql -u root -e "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$db_name'" | grep "$db_name" >/dev/null; then
        echo -e "\nMySQL database '$db_name' already exists!" >&3
    else
        mysql -u root -e "CREATE DATABASE $db_name;"
        echo -e "\nCreated '$db_name' MySQL database." >&3
    fi

    if [[ "$deal_with_project_files" == true ]]; then
        cd $projects_directory/$db_or_project_name

        # ? Modify the Laravel project's environment variables
        local env_file="./.env"

        set_env_var() {
            local key="$1"
            local value="$2"
            local escaped_value
            escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\\/&|]/\\&/g')

            if grep -q "^$key=" "$env_file"; then
                sed -i -E "s|^$key=.*|$key=$escaped_value|" "$env_file"
            else
                echo "$key=$value" >>"$env_file"
            fi
        }

        set_env_var "DB_CONNECTION" "mysql"
        set_env_var "DB_HOST" "127.0.0.1"
        set_env_var "DB_PORT" "3306"
        set_env_var "DB_DATABASE" "$db_name"
        set_env_var "DB_USERNAME" "root"
        set_env_var "DB_PASSWORD" "$DB_PASSWORD"

        echo -e "\nSet up MySQL in the project's environment variables file." >&3
    fi
}
