envUp() {
    local project_name="$1"

    local app_root="${APP_ROOT:-/var/www/html}"
    local domain_suffix="dev.localhost"

    local escaped_project_name
    escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    local project_path="$app_root/$escaped_project_name"
    local env_file="$project_path/.env"

    if [[ ! -d "$project_path" ]]; then
        prompt "The expected '$project_path' directory was not found." "" false true
        return 1
    fi

    if [[ ! -f "$env_file" ]]; then
        if [[ -f "$project_path/.env.example" ]]; then
            cp "$project_path/.env.example" "$env_file"
        else
            touch "$env_file"
        fi
    fi

    set_env_var() {
        local key="$1"
        local value="$2"
        local escaped_value
        escaped_value=$(printf '%s' "$value" | sed -e 's/[\\/&|]/\\&/g')

        if grep -Eq "^[#[:space:]]*${key}=" "$env_file"; then
            sed -i -E "0,/^[#[:space:]]*${key}=/{s|^[#[:space:]]*${key}=.*|${key}=${escaped_value}|}" "$env_file"
        else
            echo "${key}=${value}" >>"$env_file"
        fi
    }

    local app_domain="${escaped_project_name}.${domain_suffix}"
    local vite_domain="vite-${escaped_project_name}.${domain_suffix}"

    local https_port="${CADDY_HTTPS_PORT:-8443}"
    local https_suffix=""
    if [[ "$https_port" != "443" ]]; then
        https_suffix=":$https_port"
    fi

    local db_name
    db_name=$(echo "$escaped_project_name" | sed 's/\([[:lower:]]\)\([[:upper:]]\)/\1_\2/g' | sed 's/\([[:upper:]]\)\([[:upper:]][[:lower:]]\)/\1_\2/g' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/^_//')

    set_env_var "APP_NAME" "$escaped_project_name"
    set_env_var "APP_URL" "https://${app_domain}${https_suffix}"

    set_env_var "DB_CONNECTION" "mysql"
    set_env_var "DB_HOST" "mysql"
    set_env_var "DB_PORT" "3306"
    set_env_var "DB_DATABASE" "$db_name"
    set_env_var "DB_USERNAME" "root"
    set_env_var "DB_PASSWORD" "$DB_PASSWORD"

    set_env_var "CACHE_STORE" "redis"
    set_env_var "REDIS_HOST" "redis"
    set_env_var "REDIS_PORT" "6379"
    set_env_var "REDIS_PASSWORD" "null"
    set_env_var "REDIS_PREFIX" "${escaped_project_name}_"
    set_env_var "CACHE_PREFIX" "${escaped_project_name}_"

    set_env_var "MAIL_MAILER" "smtp"
    set_env_var "MAIL_HOST" "mailpit"
    set_env_var "MAIL_PORT" "1025"

    set_env_var "FILESYSTEM_DISK" "s3"
    set_env_var "AWS_ACCESS_KEY_ID" "minioadmin"
    set_env_var "AWS_SECRET_ACCESS_KEY" "minioadmin"
    set_env_var "AWS_DEFAULT_REGION" "us-east-1"
    set_env_var "AWS_BUCKET" "$escaped_project_name"
    set_env_var "AWS_ENDPOINT" "http://minio:9000"
    set_env_var "AWS_URL" "http://minio:9000/$escaped_project_name"
    set_env_var "AWS_USE_PATH_STYLE_ENDPOINT" "true"

    set_env_var "VITE_DEV_SERVER_URL" "https://${vite_domain}${https_suffix}"

    echo -e "\nRewired the project's .env file to match the stack."
}
