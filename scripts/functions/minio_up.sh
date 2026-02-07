minioUp() {
    local bucket_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"

    bucket_name=$(echo "$bucket_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    bucket_name=${bucket_name// /}

    local application_path="$apps_root/$bucket_name"
    local env_file="$application_path/.env"

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

    if [[ -f "$env_file" ]]; then
        local filesystem_disk
        filesystem_disk=$(read_env_value "FILESYSTEM_DISK" "$env_file")
        if [[ -z "$filesystem_disk" ]]; then
            filesystem_disk=$(read_env_value "FILESYSTEM_DRIVER" "$env_file")
        fi

        local aws_endpoint
        aws_endpoint=$(read_env_value "AWS_ENDPOINT" "$env_file")
        local aws_url
        aws_url=$(read_env_value "AWS_URL" "$env_file")

        if [[ -n "$filesystem_disk" && "$filesystem_disk" != "s3" ]]; then
            echo -e "\nFILESYSTEM_DISK is '$filesystem_disk'; skipped MinIO bucket creation."
            return 0
        fi
        if [[ -n "$aws_endpoint" && "$aws_endpoint" != "http://minio:9000" ]]; then
            echo -e "\nAWS_ENDPOINT is '$aws_endpoint'; skipped MinIO bucket creation."
            return 0
        fi
        if [[ -z "$aws_endpoint" && -n "$aws_url" && "$aws_url" != "http://minio:9000/$bucket_name" && "$aws_url" != "https://minio:9000/$bucket_name" ]]; then
            echo -e "\nAWS_URL is '$aws_url'; skipped MinIO bucket creation."
            return 0
        fi
    fi

    if [[ -z "$(dockerCompose ps -q minio)" ]]; then
        echo -e "\nMinIO container is not running; skipped bucket creation."
        return 0
    fi

    if ! dockerCompose exec -T minio-client mc alias set local http://minio:9000 minioadmin minioadmin >/dev/null 2>&1; then
        echo -e "\nError: Failed to configure MinIO client."
        return 1
    fi
    dockerCompose exec -T minio-client mc mb -p local/"$bucket_name" >/dev/null 2>&1 || true
    if ! dockerCompose exec -T minio-client mc anonymous set public local/"$bucket_name" >/dev/null 2>&1; then
        echo -e "\nError: Failed to set MinIO bucket '$bucket_name' public."
        return 1
    fi

    echo -e "\nEnsured MinIO bucket '$bucket_name' exists and is public."
}
