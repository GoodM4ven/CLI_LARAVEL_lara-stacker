dockerCompose() {
    local lara_stacker_dir="$PWD"
    local compose_file="${DOCKER_COMPOSE_FILE:-$lara_stacker_dir/configurations/compose.yaml}"
    local compose_project_name="lara-stacker"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local php_version="${PHP_VERSION:-8.3}"
    local restart_unless_stopped="${RESTART_UNLESS_STOPPED:-true}"
    local restart_policy="unless-stopped"

    if [[ -f "$lara_stacker_dir/scripts/functions/docker_host.sh" ]]; then
        # shellcheck source=/dev/null
        source "$lara_stacker_dir/scripts/functions/docker_host.sh"
        resolveDockerHost || true
        ensureDockerAccess || true
    fi

    local host_uid
    local host_gid
    if [[ -n "$USERNAME" ]] && id -u "$USERNAME" >/dev/null 2>&1; then
        host_uid=$(id -u "$USERNAME")
        host_gid=$(id -g "$USERNAME")
    else
        host_uid=$(id -u)
        host_gid=$(id -g)
    fi

    case "${restart_unless_stopped,,}" in
        1|true|yes|on)
            restart_policy="unless-stopped"
            ;;
        0|false|no|off)
            restart_policy="no"
            ;;
        *)
            restart_policy="unless-stopped"
            ;;
    esac

    APPS_ROOT="$apps_root" \
    HOST_UID="$host_uid" \
    HOST_GID="$host_gid" \
    PHP_VERSION="$php_version" \
    STACKER_RESTART_POLICY="$restart_policy" \
        docker compose \
        --env-file "$lara_stacker_dir/.env" \
        -f "$compose_file" \
        --project-name "$compose_project_name" \
        "$@"
}
