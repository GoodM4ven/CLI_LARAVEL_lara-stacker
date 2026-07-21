dockerCompose() {
    local lara_stacker_dir="$PWD"
    local compose_file="${DOCKER_COMPOSE_FILE:-$lara_stacker_dir/configurations/compose.yaml}"
    local compose_project_name="lara-stacker"
    local host_home_path="${HOST_HOME_PATH:-}"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local php_version="${PHP_VERSION:-8.4}"
    local restart_unless_stopped="${RESTART_UNLESS_STOPPED:-true}"
    local restart_unless_stopped_lower
    local restart_policy="unless-stopped"
    local -a compose_profile_args=()

    if [[ -f "$lara_stacker_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$lara_stacker_dir/scripts/functions/helpers/platform.sh"
    fi

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

    if [[ -z "$host_home_path" ]]; then
        host_home_path="${HOME:-/Users/${USERNAME:-$(id -un)}}"
        if [[ -n "${USERNAME:-}" ]] && declare -F resolveUserHomePath >/dev/null 2>&1; then
            local resolved_home
            resolved_home=$(resolveUserHomePath "$USERNAME")
            if [[ -n "$resolved_home" ]]; then
                host_home_path="$resolved_home"
            fi
        fi
    fi

    if declare -F normalizePathForHost >/dev/null 2>&1; then
        host_home_path=$(normalizePathForHost "$host_home_path" "${USERNAME:-}")
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    restart_unless_stopped_lower=$(printf '%s' "$restart_unless_stopped" | tr '[:upper:]' '[:lower:]')

    case "$restart_unless_stopped_lower" in
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

    if [[ -n "${TAILSCALE_AUTH_KEY:-}" && "$TAILSCALE_AUTH_KEY" != *"<your-"* ]]; then
        compose_profile_args=(--profile tailscale)
    fi

    HOST_HOME_PATH="$host_home_path" \
    APPS_ROOT="$apps_root" \
    HOST_UID="$host_uid" \
    HOST_GID="$host_gid" \
    PHP_VERSION="$php_version" \
    STACKER_RESTART_POLICY="$restart_policy" \
        docker compose \
        --env-file "$lara_stacker_dir/.env" \
        -f "$compose_file" \
        --project-name "$compose_project_name" \
        "${compose_profile_args[@]}" \
        "$@"
}
