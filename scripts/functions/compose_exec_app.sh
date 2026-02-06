composeExecApp() {
    local retries=20
    local sleep_seconds=1
    local container_id=""

    for _ in $(seq 1 "$retries"); do
        container_id=$(dockerCompose ps -q app 2>/dev/null | head -n 1)
        if [[ -n "$container_id" ]]; then
            break
        fi
        sleep "$sleep_seconds"
    done

    if [[ -z "$container_id" ]]; then
        echo -e "\nError: app container is not running."
        return 1
    fi

    dockerCompose exec -T app "$@"
}
