composeDown() {
    local status=0
    dockerCompose down --remove-orphans || status=$?

    # Fallback: force-stop any remaining container services
    local remaining
    remaining=$(docker ps -q --filter label=com.docker.compose.project=lara-stacker)
    if [[ -n "$remaining" ]]; then
        docker stop $remaining >/dev/null 2>&1 || true
    fi

    remaining=$(docker ps -q --filter label=com.docker.compose.project=lara-stacker)
    if [[ -n "$remaining" ]]; then
        return 1
    fi

    return 0
}
