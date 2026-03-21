resolveDockerHost() {
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi

    if [[ -n "$DOCKER_HOST" ]]; then
        if [[ "$DOCKER_HOST" == unix://* ]]; then
            local sock_path="${DOCKER_HOST#unix://}"
            if [[ -S "$sock_path" ]]; then
                return 0
            fi
            unset DOCKER_HOST
        else
            return 0
        fi
    fi

    local sock="/var/run/docker.sock"
    if [[ -S "$sock" ]]; then
        export DOCKER_HOST="unix://$sock"
        return 0
    fi

    local uid="${SUDO_UID:-$(id -u)}"
    local user="${SUDO_USER:-$(id -un)}"
    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$user")
    fi

    local user_sock="/run/user/$uid/docker.sock"
    if [[ -S "$user_sock" ]]; then
        export DOCKER_HOST="unix://$user_sock"
        return 0
    fi

    local desktop_cli_sock="$user_home/.docker/desktop/docker-cli.sock"
    if [[ -S "$desktop_cli_sock" ]]; then
        export DOCKER_HOST="unix://$desktop_cli_sock"
        return 0
    fi

    local desktop_sock="$user_home/.docker/desktop/docker.sock"
    if [[ -S "$desktop_sock" ]]; then
        export DOCKER_HOST="unix://$desktop_sock"
        return 0
    fi

    local desktop_run_sock="$user_home/.docker/run/docker.sock"
    if [[ -S "$desktop_run_sock" ]]; then
        export DOCKER_HOST="unix://$desktop_run_sock"
        return 0
    fi

    if command -v docker >/dev/null 2>&1; then
        local context_name
        context_name="${DOCKER_CONTEXT:-$(docker context show 2>/dev/null || true)}"
        if [[ -n "$context_name" ]]; then
            local context_host
            context_host=$(docker context inspect "$context_name" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)
            if [[ "$context_host" == unix://* ]]; then
                local context_sock="${context_host#unix://}"
                if [[ -S "$context_sock" ]]; then
                    export DOCKER_HOST="unix://$context_sock"
                    return 0
                fi
            fi
        fi
    fi

    return 1
}

ensureDockerAccess() {
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi

    if docker info >/dev/null 2>&1; then
        return 0
    fi

    local uid="${SUDO_UID:-$(id -u)}"
    local user="${SUDO_USER:-$(id -un)}"
    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$user")
    fi
    local sockets=(
        "$user_home/.docker/desktop/docker-cli.sock"
        "$user_home/.docker/desktop/docker.sock"
        "$user_home/.docker/run/docker.sock"
        "/run/user/$uid/docker.sock"
        "/var/run/docker.sock"
    )

    if command -v docker >/dev/null 2>&1; then
        local context_name
        context_name="${DOCKER_CONTEXT:-$(docker context show 2>/dev/null || true)}"
        if [[ -n "$context_name" ]]; then
            local context_host
            context_host=$(docker context inspect "$context_name" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)
            if [[ "$context_host" == unix://* ]]; then
                sockets+=("${context_host#unix://}")
            fi
        fi
    fi

    local sock
    for sock in "${sockets[@]}"; do
        if [[ -S "$sock" ]]; then
            if DOCKER_HOST="unix://$sock" docker info >/dev/null 2>&1; then
                export DOCKER_HOST="unix://$sock"
                return 0
            fi
        fi
    done

    return 1
}
