resolveDockerHost() {
    if [[ -n "$DOCKER_HOST" ]]; then
        return 0
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

    local desktop_sock="/home/$user/.docker/desktop/docker.sock"
    if [[ -S "$desktop_sock" ]]; then
        export DOCKER_HOST="unix://$desktop_sock"
        return 0
    fi

    return 1
}
