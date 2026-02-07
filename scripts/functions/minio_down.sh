minioDown() {
    local bucket_name="$1"

    bucket_name=$(echo "$bucket_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    bucket_name=${bucket_name// /}

    if [[ -z "$(dockerCompose ps -q minio)" ]]; then
        echo -e "\nError: MinIO container is not running; cannot delete bucket."
        return 1
    fi

    if ! dockerCompose exec -T minio-client mc alias set local http://minio:9000 minioadmin minioadmin >/dev/null 2>&1; then
        echo -e "\nError: Failed to configure MinIO client."
        return 1
    fi
    dockerCompose exec -T minio-client mc rb -r --force local/"$bucket_name" >/dev/null 2>&1 || true

    echo -e "\nDeleted MinIO bucket '$bucket_name' (if existed)."
    return 0
}
