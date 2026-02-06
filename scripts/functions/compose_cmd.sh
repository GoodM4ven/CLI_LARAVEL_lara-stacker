dockerCompose() {
    local lara_stacker_dir="$PWD"
    local compose_file="${DOCKER_COMPOSE_FILE:-$lara_stacker_dir/compose.yaml}"
    local project_name="${DOCKER_PROJECT_NAME:-lara-stacker}"
    local app_root="${APP_ROOT:-/var/www/html}"
    local php_version="${PHP_VERSION:-8.3}"
    local node_version="${NODE_VERSION:-20}"

    local host_uid
    local host_gid
    if [[ -n "$USERNAME" ]] && id -u "$USERNAME" >/dev/null 2>&1; then
        host_uid=$(id -u "$USERNAME")
        host_gid=$(id -g "$USERNAME")
    else
        host_uid=$(id -u)
        host_gid=$(id -g)
    fi

    APP_ROOT="$app_root" \
    HOST_UID="$host_uid" \
    HOST_GID="$host_gid" \
    PHP_VERSION="$php_version" \
    NODE_VERSION="$node_version" \
        docker compose -f "$compose_file" --project-name "$project_name" "$@"
}
