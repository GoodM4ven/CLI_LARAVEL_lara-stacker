envUp() {
    local application_name="$1"
    local env_mode="${2:-existing}"

    local apps_root="${APPS_ROOT:-/var/www/html}"
    local domain_suffix="dev.localhost"

    local escaped_application_name
    escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    local application_path="$apps_root/$escaped_application_name"
    local env_file="$application_path/.env"
    local env_example_file="$application_path/.env.example"

    local wire_host="127.0.0.1"
    local mysql_host="$wire_host"
    local mysql_port="${MYSQL_PORT:-3307}"
    local redis_host="$wire_host"
    local redis_port="${REDIS_PORT:-6380}"
    local mail_host="$wire_host"
    local mail_port="${MAILPIT_SMTP_PORT:-1026}"
    local minio_endpoint="http://${wire_host}:${MINIO_PORT:-9100}"
    local minio_url="http://${wire_host}:${MINIO_PORT:-9100}/${escaped_application_name}"
    local minio_url_https="https://${wire_host}:${MINIO_PORT:-9100}/${escaped_application_name}"
    local container_minio_endpoint="http://minio:9000"
    local container_minio_url="http://minio:9000/$escaped_application_name"
    local container_minio_url_https="https://minio:9000/$escaped_application_name"

    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi

    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi
    application_path="$apps_root/$escaped_application_name"
    env_file="$application_path/.env"
    env_example_file="$application_path/.env.example"

    if [[ ! -d "$application_path" ]]; then
        prompt "The expected '$application_path' directory was not found." "" false true
        return 1
    fi

    local env_preexists="false"
    if [[ -f "$env_file" ]]; then
        env_preexists="true"
    else
        if [[ -f "$application_path/.env.example" ]]; then
            cp "$application_path/.env.example" "$env_file"
        else
            touch "$env_file"
        fi
    fi

    read_env_value() {
        local key="$1"
        local file="$2"
        local value=""

        if [[ -f "$file" ]]; then
            value=$(sed -n -E "s/^[[:space:]]*${key}=//p" "$file" | tail -n 1)
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

    local preference_file=""
    if [[ "$env_mode" != "new" ]]; then
        use_mysql="false"
        use_redis="false"
        use_minio="false"

        if [[ -f "$env_example_file" ]]; then
            preference_file="$env_example_file"
        elif [[ "$env_preexists" == "true" ]]; then
            preference_file="$env_file"
        fi
    fi

    if [[ -n "$preference_file" ]]; then
        local preferred_db_connection
        preferred_db_connection=$(read_env_value "DB_CONNECTION" "$preference_file")
        if [[ -n "$preferred_db_connection" && ( "$preferred_db_connection" == "mysql" || "$preferred_db_connection" == "mariadb" ) ]]; then
            use_mysql="true"
        fi

        local preferred_cache_store
        preferred_cache_store=$(read_env_value "CACHE_STORE" "$preference_file")
        local preferred_cache_driver
        preferred_cache_driver=$(read_env_value "CACHE_DRIVER" "$preference_file")
        local preferred_cache_setting="$preferred_cache_store"
        if [[ -z "$preferred_cache_setting" ]]; then
            preferred_cache_setting="$preferred_cache_driver"
        fi
        if [[ -n "$preferred_cache_setting" && "$preferred_cache_setting" == "redis" ]]; then
            use_redis="true"
        fi

        local preferred_filesystem_disk
        preferred_filesystem_disk=$(read_env_value "FILESYSTEM_DISK" "$preference_file")
        local preferred_filesystem_driver
        preferred_filesystem_driver=$(read_env_value "FILESYSTEM_DRIVER" "$preference_file")
        local preferred_filesystem_setting="$preferred_filesystem_disk"
        if [[ -z "$preferred_filesystem_setting" ]]; then
            preferred_filesystem_setting="$preferred_filesystem_driver"
        fi
        if [[ -n "$preferred_filesystem_setting" && "$preferred_filesystem_setting" == "s3" ]]; then
            use_minio="true"
        fi

        local preferred_aws_endpoint
        preferred_aws_endpoint=$(read_env_value "AWS_ENDPOINT" "$preference_file")
        local preferred_aws_url
        preferred_aws_url=$(read_env_value "AWS_URL" "$preference_file")
        if [[ -n "$preferred_aws_endpoint" || -n "$preferred_aws_url" ]]; then
            use_minio="true"
        fi
    fi

    # Creation deliberately enables the full stack. Import and rewire preserve
    # an existing application's database, cache, and filesystem preferences.
    if [[ "$env_preexists" == "true" && "$env_mode" != "new" ]]; then
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

        if [[ -n "$existing_db_connection" ]]; then
            if [[ "$existing_db_connection" == "mysql" || "$existing_db_connection" == "mariadb" ]]; then
                use_mysql="true"
            else
                use_mysql="false"
            fi
        fi

        local cache_setting="$existing_cache_store"
        if [[ -z "$cache_setting" ]]; then
            cache_setting="$existing_cache_driver"
        fi
        if [[ -n "$cache_setting" ]]; then
            if [[ "$cache_setting" == "redis" ]]; then
                use_redis="true"
            else
                use_redis="false"
            fi
        fi

        local fs_setting="$existing_filesystem_disk"
        if [[ -z "$fs_setting" ]]; then
            fs_setting="$existing_filesystem_driver"
        fi
        if [[ -n "$fs_setting" ]]; then
            if [[ "$fs_setting" == "s3" ]]; then
                use_minio="true"
            else
                use_minio="false"
            fi
        fi
        if [[ -n "$existing_aws_endpoint" ]]; then
            if [[ "$existing_aws_endpoint" == "$minio_endpoint" || "$existing_aws_endpoint" == "$container_minio_endpoint" ]]; then
                use_minio="true"
            else
                use_minio="false"
            fi
        fi
        if [[ -z "$existing_aws_endpoint" && -n "$existing_aws_url" ]]; then
            if [[ "$existing_aws_url" == "$minio_url" || "$existing_aws_url" == "$minio_url_https" || "$existing_aws_url" == "$container_minio_url" || "$existing_aws_url" == "$container_minio_url_https" ]]; then
                use_minio="true"
            else
                use_minio="false"
            fi
        fi
    fi

    set_env_var_in_group() {
        local key="$1"
        local value="$2"
        shift 2
        local group_keys=("$@")
        local key_value_line="${key}=${value}"

        # Preserve Laravel's original .env layout. Replace an active or commented
        # key exactly where Laravel placed it; only insert when the key is absent.
        if grep -Eq "^[[:space:]]*#?[[:space:]]*${key}=" "$env_file"; then
            local tmp_replace
            tmp_replace=$(mktemp "${TMPDIR:-/tmp}/stacker-env-up.XXXXXX")
            awk -v key="$key" -v kv="$key_value_line" '
            BEGIN { replaced = 0 }
            {
                if (!replaced && $0 ~ "^[[:space:]]*#?[[:space:]]*" key "=") {
                    print kv
                    replaced = 1
                    next
                }
                print
            }' "$env_file" >"$tmp_replace" && mv "$tmp_replace" "$env_file"
            return
        fi

        local before_key=""
        local after_key=""
        local seen_target="false"
        local candidate

        for candidate in "${group_keys[@]}"; do
            if [[ "$candidate" == "$key" ]]; then
                seen_target="true"
                continue
            fi

            if grep -Eq "^[[:space:]]*${candidate}=" "$env_file"; then
                if [[ "$seen_target" == "true" ]]; then
                    if [[ -z "$before_key" ]]; then
                        before_key="$candidate"
                    fi
                else
                    after_key="$candidate"
                fi
            fi
        done

        if [[ -n "$after_key" ]]; then
            local tmp_after
            tmp_after=$(mktemp "${TMPDIR:-/tmp}/stacker-env-up.XXXXXX")
            awk -v anchor="$after_key" -v kv="$key_value_line" '
            BEGIN { inserted = 0 }
            {
                print
                if (!inserted && $0 ~ "^[[:space:]]*" anchor "=") {
                    print kv
                    inserted = 1
                }
            }
            END {
                if (!inserted) {
                    print kv
                }
            }' "$env_file" >"$tmp_after" && mv "$tmp_after" "$env_file"
            return
        fi

        if [[ -n "$before_key" ]]; then
            local tmp_before
            tmp_before=$(mktemp "${TMPDIR:-/tmp}/stacker-env-up.XXXXXX")
            awk -v anchor="$before_key" -v kv="$key_value_line" '
            BEGIN { inserted = 0 }
            {
                if (!inserted && $0 ~ "^[[:space:]]*" anchor "=") {
                    print kv
                    inserted = 1
                }
                print
            }
            END {
                if (!inserted) {
                    print kv
                }
            }' "$env_file" >"$tmp_before" && mv "$tmp_before" "$env_file"
            return
        fi

        echo "${key}=${value}" >>"$env_file"
    }

    local app_domain="${escaped_application_name}.${domain_suffix}"
    local vite_domain="vite-${escaped_application_name}.${domain_suffix}"

    local https_port="${CADDY_HTTPS_PORT:-8443}"
    local https_suffix=""
    if [[ "$https_port" != "443" ]]; then
        https_suffix=":$https_port"
    fi

    local db_name
    db_name=$(echo "$escaped_application_name" | sed 's/\([[:lower:]]\)\([[:upper:]]\)/\1_\2/g' | sed 's/\([[:upper:]]\)\([[:upper:]][[:lower:]]\)/\1_\2/g' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/^_//')

    local app_group=(APP_NAME APP_ENV APP_KEY APP_DEBUG APP_URL APP_LOCALE APP_FALLBACK_LOCALE APP_FAKER_LOCALE)
    local db_group=(DB_CONNECTION DB_HOST DB_PORT DB_DATABASE DB_USERNAME DB_PASSWORD)
    local cache_redis_group=(CACHE_STORE CACHE_DRIVER CACHE_PREFIX REDIS_CLIENT REDIS_HOST REDIS_PASSWORD REDIS_PORT REDIS_PREFIX)
    local mail_group=(MAIL_MAILER MAIL_SCHEME MAIL_HOST MAIL_PORT MAIL_USERNAME MAIL_PASSWORD MAIL_FROM_ADDRESS MAIL_FROM_NAME)
    local aws_group=(FILESYSTEM_DISK FILESYSTEM_DRIVER AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION AWS_BUCKET AWS_USE_PATH_STYLE_ENDPOINT AWS_ENDPOINT AWS_URL)
    local vite_group=(VITE_APP_NAME VITE_DEV_SERVER_URL)
    local reverb_group=(BROADCAST_CONNECTION REVERB_APP_ID REVERB_APP_KEY REVERB_APP_SECRET REVERB_HOST REVERB_PORT REVERB_SCHEME REVERB_SERVER_HOST REVERB_SERVER_PORT VITE_REVERB_APP_KEY VITE_REVERB_HOST VITE_REVERB_PORT VITE_REVERB_SCHEME)

    set_env_var_in_group "APP_NAME" "$escaped_application_name" "${app_group[@]}"
    set_env_var_in_group "APP_URL" "https://${app_domain}${https_suffix}" "${app_group[@]}"

    if [[ "$use_mysql" == "true" ]]; then
        set_env_var_in_group "DB_CONNECTION" "mysql" "${db_group[@]}"
        set_env_var_in_group "DB_HOST" "$mysql_host" "${db_group[@]}"
        set_env_var_in_group "DB_PORT" "$mysql_port" "${db_group[@]}"
        set_env_var_in_group "DB_DATABASE" "$db_name" "${db_group[@]}"
        set_env_var_in_group "DB_USERNAME" "root" "${db_group[@]}"
        set_env_var_in_group "DB_PASSWORD" "$DB_PASSWORD" "${db_group[@]}"
    else
        local existing_db_connection
        existing_db_connection=$(read_env_value "DB_CONNECTION" "$env_file")
        if [[ "$existing_db_connection" == "sqlite" ]]; then
            local existing_db_database
            existing_db_database=$(read_env_value "DB_DATABASE" "$env_file")
            if [[ -z "$existing_db_database" || "$existing_db_database" == "$escaped_application_name" ]]; then
                set_env_var_in_group "DB_DATABASE" "database/database.sqlite" "${db_group[@]}"
            fi
        fi
    fi

    if [[ "$use_redis" == "true" ]]; then
        set_env_var_in_group "CACHE_STORE" "redis" "${cache_redis_group[@]}"
        set_env_var_in_group "CACHE_PREFIX" "${escaped_application_name}_" "${cache_redis_group[@]}"
        set_env_var_in_group "REDIS_HOST" "$redis_host" "${cache_redis_group[@]}"
        set_env_var_in_group "REDIS_PORT" "$redis_port" "${cache_redis_group[@]}"
        set_env_var_in_group "REDIS_PREFIX" "${escaped_application_name}_" "${cache_redis_group[@]}"
        set_env_var_in_group "REDIS_PASSWORD" "null" "${cache_redis_group[@]}"
    fi

    set_env_var_in_group "MAIL_MAILER" "smtp" "${mail_group[@]}"
    set_env_var_in_group "MAIL_HOST" "$mail_host" "${mail_group[@]}"
    set_env_var_in_group "MAIL_PORT" "$mail_port" "${mail_group[@]}"

    if [[ "$use_minio" == "true" ]]; then
        set_env_var_in_group "FILESYSTEM_DISK" "s3" "${aws_group[@]}"
        set_env_var_in_group "AWS_ACCESS_KEY_ID" "minioadmin" "${aws_group[@]}"
        set_env_var_in_group "AWS_SECRET_ACCESS_KEY" "minioadmin" "${aws_group[@]}"
        set_env_var_in_group "AWS_DEFAULT_REGION" "us-east-1" "${aws_group[@]}"
        set_env_var_in_group "AWS_BUCKET" "$escaped_application_name" "${aws_group[@]}"
        set_env_var_in_group "AWS_ENDPOINT" "$minio_endpoint" "${aws_group[@]}"
        set_env_var_in_group "AWS_URL" "$minio_url" "${aws_group[@]}"
        set_env_var_in_group "AWS_USE_PATH_STYLE_ENDPOINT" "true" "${aws_group[@]}"
    fi

    set_env_var_in_group "VITE_DEV_SERVER_URL" "https://${vite_domain}${https_suffix}" "${vite_group[@]}"

    if grep -Eq '^[[:space:]]*BROADCAST_CONNECTION=reverb$|^[[:space:]]*REVERB_APP_KEY=' "$env_file"; then
        set_env_var_in_group "BROADCAST_CONNECTION" "reverb" "${reverb_group[@]}"
        set_env_var_in_group "REVERB_HOST" "$app_domain" "${reverb_group[@]}"
        set_env_var_in_group "REVERB_PORT" "$https_port" "${reverb_group[@]}"
        set_env_var_in_group "REVERB_SCHEME" "https" "${reverb_group[@]}"
        set_env_var_in_group "REVERB_SERVER_HOST" "0.0.0.0" "${reverb_group[@]}"
        set_env_var_in_group "REVERB_SERVER_PORT" "8080" "${reverb_group[@]}"
        set_env_var_in_group "VITE_REVERB_APP_KEY" '${REVERB_APP_KEY}' "${reverb_group[@]}"
        set_env_var_in_group "VITE_REVERB_HOST" '${REVERB_HOST}' "${reverb_group[@]}"
        set_env_var_in_group "VITE_REVERB_PORT" '${REVERB_PORT}' "${reverb_group[@]}"
        set_env_var_in_group "VITE_REVERB_SCHEME" '${REVERB_SCHEME}' "${reverb_group[@]}"
    fi

    echo -e "\nRewired the application's .env file to match host-exposed services."
}
