minioUp() {
    local bucket_name="$1"

    bucket_name=$(echo "$bucket_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    bucket_name=${bucket_name// /}

    if [[ -z "$(dockerCompose ps -q minio)" ]]; then
        echo -e "\nMinIO container is not running; skipped bucket creation."
        return 0
    fi

    dockerCompose exec -T minio-client mc alias set local http://minio:9000 minioadmin minioadmin >/dev/null 2>&1
    dockerCompose exec -T minio-client mc mb -p local/"$bucket_name" >/dev/null 2>&1 || true
    dockerCompose exec -T minio-client mc anonymous set public local/"$bucket_name" >/dev/null 2>&1 || true

    echo -e "\nEnsured MinIO bucket '$bucket_name' exists."
}
