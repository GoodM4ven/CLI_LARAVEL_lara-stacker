resolveDockerHost() {
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

    local user_sock="/run/user/$uid/docker.sock"
    if [[ -S "$user_sock" ]]; then
        export DOCKER_HOST="unix://$user_sock"
        return 0
    fi

    local desktop_cli_sock="/home/$user/.docker/desktop/docker-cli.sock"
    if [[ -S "$desktop_cli_sock" ]]; then
        export DOCKER_HOST="unix://$desktop_cli_sock"
        return 0
    fi

    local desktop_sock="/home/$user/.docker/desktop/docker.sock"
    if [[ -S "$desktop_sock" ]]; then
        export DOCKER_HOST="unix://$desktop_sock"
        return 0
    fi

    return 1
}
