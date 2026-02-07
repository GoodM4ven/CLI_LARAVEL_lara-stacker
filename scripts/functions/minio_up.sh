minioUp() {
    local bucket_name="$1"

    bucket_name=$(echo "$bucket_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    bucket_name=${bucket_name// /}

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
