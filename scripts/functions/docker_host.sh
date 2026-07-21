resolveDockerHost() {
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi

    local user="${SUDO_USER:-$(id -un)}"
    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$user")
    fi

    local orbstack_sock="$user_home/.orbstack/run/docker.sock"
    if [[ -S "$orbstack_sock" ]]; then
        export DOCKER_HOST="unix://$orbstack_sock"
        return 0
    fi

    unset DOCKER_HOST
    return 1
}

ensureDockerAccess() {
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi

    local user="${SUDO_USER:-$(id -un)}"
    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$user")
    fi
    local orbstack_sock="$user_home/.orbstack/run/docker.sock"
    if [[ -S "$orbstack_sock" ]] && DOCKER_HOST="unix://$orbstack_sock" docker info >/dev/null 2>&1; then
        export DOCKER_HOST="unix://$orbstack_sock"
        return 0
    fi

    return 1
}
