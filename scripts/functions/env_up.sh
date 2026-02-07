envUp() {
    local project_name="$1"

    local apps_root="${APPS_ROOT:-/var/www/html}"
    local domain_suffix="dev.localhost"

    local escaped_project_name
    escaped_project_name=$(echo "$project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_project_name=${escaped_project_name// /}

    local project_path="$apps_root/$escaped_project_name"
    local env_file="$project_path/.env"

    if [[ ! -d "$project_path" ]]; then
        prompt "The expected '$project_path' directory was not found." "" false true
        return 1
    fi

    local env_preexists="false"
    if [[ -f "$env_file" ]]; then
        env_preexists="true"
    else
        if [[ -f "$project_path/.env.example" ]]; then
            cp "$project_path/.env.example" "$env_file"
        else
            touch "$env_file"
        fi
    fi

    read_env_value() {
        local key="$1"
        local file="$2"
        local value=""

        if [[ -f "$file" ]]; then
            value=$(sed -n -E "s/^[#[:space:]]*${key}=//p" "$file" | tail -n 1)
            value="${value%%\r}"
            value="${value%%#*}"
            value=$(echo "$value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
            value="${value%\"}"
            value="${value#\"}"
            value="${value%\'}"
            value="${value#\'}"
        fi

        echo "$value"
    }

    local use_mysql="true"
    local use_redis="true"
    local use_minio="true"

    if [[ "$env_preexists" == "true" ]]; then
        local existing_db_connection
        existing_db_connection=$(read_env_value "DB_CONNECTION" "$env_file")
        local existing_cache_store
        existing_cache_store=$(read_env_value "CACHE_STORE" "$env_file")
        local existing_cache_driver
        existing_cache_driver=$(read_env_value "CACHE_DRIVER" "$env_file")
        local existing_filesystem_disk
        existing_filesystem_disk=$(read_env_value "FILESYSTEM_DISK" "$env_file")
        local existing_filesystem_driver
        existing_filesystem_driver=$(read_env_value "FILESYSTEM_DRIVER" "$env_file")
        local existing_aws_endpoint
        existing_aws_endpoint=$(read_env_value "AWS_ENDPOINT" "$env_file")
        local existing_aws_url
        existing_aws_url=$(read_env_value "AWS_URL" "$env_file")

        if [[ -n "$existing_db_connection" && "$existing_db_connection" != "mysql" && "$existing_db_connection" != "mariadb" ]]; then
            use_mysql="false"
        fi

        local cache_setting="$existing_cache_store"
        if [[ -z "$cache_setting" ]]; then
            cache_setting="$existing_cache_driver"
        fi
        if [[ -n "$cache_setting" && "$cache_setting" != "redis" ]]; then
            use_redis="false"
        fi

        local fs_setting="$existing_filesystem_disk"
        if [[ -z "$fs_setting" ]]; then
            fs_setting="$existing_filesystem_driver"
        fi
        if [[ -n "$fs_setting" && "$fs_setting" != "s3" ]]; then
            use_minio="false"
        fi
        if [[ -n "$existing_aws_endpoint" && "$existing_aws_endpoint" != "http://minio:9000" ]]; then
            use_minio="false"
        fi
        if [[ -z "$existing_aws_endpoint" && -n "$existing_aws_url" && "$existing_aws_url" != "http://minio:9000/$escaped_project_name" && "$existing_aws_url" != "https://minio:9000/$escaped_project_name" ]]; then
            use_minio="false"
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

    if [[ "$use_mysql" == "true" ]]; then
        set_env_var "DB_CONNECTION" "mysql"
        set_env_var "DB_HOST" "mysql"
        set_env_var "DB_PORT" "3306"
        set_env_var "DB_DATABASE" "$db_name"
        set_env_var "DB_USERNAME" "root"
        set_env_var "DB_PASSWORD" "$DB_PASSWORD"
    fi

    if [[ "$use_redis" == "true" ]]; then
        set_env_var "CACHE_STORE" "redis"
        set_env_var "REDIS_HOST" "redis"
        set_env_var "REDIS_PORT" "6379"
        set_env_var "REDIS_PASSWORD" "null"
        set_env_var "REDIS_PREFIX" "${escaped_project_name}_"
        set_env_var "CACHE_PREFIX" "${escaped_project_name}_"
    fi

    set_env_var "MAIL_MAILER" "smtp"
    set_env_var "MAIL_HOST" "mailpit"
    set_env_var "MAIL_PORT" "1025"

    if [[ "$use_minio" == "true" ]]; then
        set_env_var "FILESYSTEM_DISK" "s3"
        set_env_var "AWS_ACCESS_KEY_ID" "minioadmin"
        set_env_var "AWS_SECRET_ACCESS_KEY" "minioadmin"
        set_env_var "AWS_DEFAULT_REGION" "us-east-1"
        set_env_var "AWS_BUCKET" "$escaped_project_name"
        set_env_var "AWS_ENDPOINT" "http://minio:9000"
        set_env_var "AWS_URL" "http://minio:9000/$escaped_project_name"
        set_env_var "AWS_USE_PATH_STYLE_ENDPOINT" "true"
    fi

    set_env_var "VITE_DEV_SERVER_URL" "https://${vite_domain}${https_suffix}"

    echo -e "\nRewired the project's .env file to match the stack."
}
