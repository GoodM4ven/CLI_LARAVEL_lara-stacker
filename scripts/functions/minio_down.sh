minioDown() {
    local bucket_name="$1"

    bucket_name=$(echo "$bucket_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    bucket_name=${bucket_name// /}

    if [[ -z "$(dockerCompose ps -q minio)" ]] || [[ -z "$(dockerCompose ps -q minio-client)" ]]; then
        echo -e "\nError: MinIO containers are not running; cannot delete bucket."
        return 1
    fi

    if ! dockerCompose exec -T minio-client mc alias set local http://minio:9000 minioadmin minioadmin >/dev/null 2>&1; then
        echo -e "\nError: Failed to configure MinIO client."
        return 1
    fi

    if ! dockerCompose exec -T minio-client mc ls local/"$bucket_name" >/dev/null 2>&1; then
        echo -e "\nMinIO bucket '$bucket_name' not found; nothing to delete."
        return 0
    fi

    if ! dockerCompose exec -T minio-client mc rb -r --force local/"$bucket_name" >/dev/null 2>&1; then
        echo -e "\nError: Failed to delete MinIO bucket '$bucket_name'."
        return 1
    fi

    echo -e "\nDeleted MinIO bucket '$bucket_name'."
    return 0
}
