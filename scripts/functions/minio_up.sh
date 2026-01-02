minioUp() {
    # ? Take in the arguments
    local escaped_project_name="$1"
    local minio_alias="myminio"

    local projects_directory=/var/www/html

    # ? Ensure the MinIO alias exists (covers legacy setups) and create bucket
    sudo -i -u $USERNAME bash <<EOF
minio_alias="$minio_alias"
escaped_project_name="$escaped_project_name"

if ! minio-client alias list 2>/dev/null | awk 'NR>1 {print \$1}' | grep -qx "\$minio_alias"; then
    minio-client alias set "\$minio_alias" http://localhost:9000 minioadmin minioadmin
fi

cd /home/$USERNAME/.config/minio/data/ && minio-client mb --region=us-east-1 "\$minio_alias/\$escaped_project_name"
minio-client anonymous set public "\$minio_alias/\$escaped_project_name"
EOF

    # ? Ensure proper system permissions over the data
    sudo $lara_stacker_dir/scripts/helpers/permit.sh /home/$USERNAME/.config/minio/data/$escaped_project_name

    # ? Update the Laravel project's environment variables for MinIO storage
    cd $projects_directory/$escaped_project_name

    if ! grep -q '^AWS_ENDPOINT=' ./.env; then
        sed -i "/^AWS_BUCKET=.*/a AWS_ENDPOINT=" ./.env
    fi
    if ! grep -q '^AWS_URL=' ./.env; then
        sed -i "/^AWS_ENDPOINT=.*/a AWS_URL=" ./.env
    fi

    sed -i "/^FILESYSTEM_DISK=/c\FILESYSTEM_DISK=s3" ./.env
    sed -i "/^AWS_ACCESS_KEY_ID=/c\AWS_ACCESS_KEY_ID=minioadmin" ./.env
    sed -i "/^AWS_SECRET_ACCESS_KEY=/c\AWS_SECRET_ACCESS_KEY=minioadmin" ./.env
    sed -i "/^AWS_DEFAULT_REGION=/c\AWS_DEFAULT_REGION=us-east-1" ./.env
    sed -i "/^AWS_BUCKET=/c\AWS_BUCKET=$escaped_project_name" ./.env
    sed -i "/^AWS_ENDPOINT=/c\AWS_ENDPOINT=http://localhost:9000" ./.env
    sed -i "/^AWS_URL=/c\AWS_URL=http://localhost:9000/$escaped_project_name" ./.env
    sed -i "/^AWS_USE_PATH_STYLE_ENDPOINT=/c\AWS_USE_PATH_STYLE_ENDPOINT=true" ./.env

    echo -e "\nSet up a MinIO storage for the project." >&3
}
