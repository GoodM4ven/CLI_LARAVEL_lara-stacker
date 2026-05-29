composeUp() {
    local state_dir="${HOME:-/tmp}/.lara-stacker"
    local state_file="$state_dir/stacker-build.env"
    local last_php_version=""
    local last_build_hash=""

    if [[ -f "$state_file" ]]; then
        # shellcheck source=/dev/null
        source "$state_file"
        last_php_version="${STACKER_PHP_VERSION:-}"
        last_build_hash="${STACKER_BUILD_HASH:-}"
    fi

    local current_php="${PHP_VERSION:-8.3}"
    local current_build_hash=""

    if command -v sha256sum >/dev/null 2>&1; then
        local repo_dir="$PWD"
        if [[ -f "$repo_dir/configurations/Dockerfile" ]]; then
            current_build_hash=$(
                sha256sum \
                    "$repo_dir/configurations/Dockerfile" \
                    "$repo_dir/configurations/xdebug.ini" \
                    "$repo_dir/configurations/opcache.ini" \
                    2>/dev/null | sha256sum | awk '{print $1}'
            )
        fi
    fi

    normalizePhpMajorMinor() {
        local version="$1"
        local major_minor
        major_minor=$(printf '%s' "$version" | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
        printf '%s' "$major_minor"
    }

    local need_rebuild="false"
    if [[ "$current_php" != "$last_php_version" ]]; then
        need_rebuild="true"
    fi
    if [[ -n "$current_build_hash" ]] && [[ "$current_build_hash" != "$last_build_hash" ]]; then
        need_rebuild="true"
    fi

    local faulty="false"
    local ps_output
    ps_output=$(dockerCompose ps -a --format '{{.Name}}|{{.State}}|{{.Status}}' 2>/dev/null || true)
    if [[ -n "$ps_output" ]]; then
        while IFS='|' read -r name state status; do
            [[ -z "$name" ]] && continue
            if [[ "$state" != "running" ]] || [[ "$status" =~ (unhealthy|Exited|exited|dead|restarting) ]]; then
                faulty="true"
                break
            fi
        done <<< "$ps_output"
    fi

    if [[ "$faulty" == "true" ]]; then
        dockerCompose down
    fi

    local expected_php
    local running_php=""
    expected_php=$(normalizePhpMajorMinor "$current_php")

    if [[ "$need_rebuild" != "true" ]]; then
        running_php=$(dockerCompose exec -T app php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || true)
        if [[ -n "$running_php" ]] && [[ "$running_php" != "$expected_php" ]]; then
            need_rebuild="true"
        fi
    fi

    local up_status=0
    # Ensure the external default network exists
    if ! docker network inspect lara-stacker_default >/dev/null 2>&1; then
        docker network create \
            --label com.docker.compose.project=lara-stacker \
            --label com.docker.compose.network=default \
            lara-stacker_default >/dev/null 2>&1 || true
    fi

    if [[ "$need_rebuild" == "true" ]]; then
        dockerCompose up -d --remove-orphans --build || up_status=$?
    else
        dockerCompose up -d --remove-orphans || up_status=$?
    fi

    if [[ "$up_status" -ne 0 ]]; then
        local err_out
        err_out=$(dockerCompose up -d --remove-orphans 2>&1 || true)
        if echo "$err_out" | grep -qi "network .* not found"; then
            dockerCompose down --remove-orphans >/dev/null 2>&1 || true
            if [[ "$need_rebuild" == "true" ]]; then
                dockerCompose up -d --remove-orphans --build || up_status=$?
            else
                dockerCompose up -d --remove-orphans || up_status=$?
            fi
        fi
    fi

    if [[ "$up_status" -ne 0 ]]; then
        return "$up_status"
    fi

    mkdir -p "$state_dir" 2>/dev/null || true
    cat > "$state_file" <<EOF
STACKER_PHP_VERSION="$current_php"
STACKER_BUILD_HASH="$current_build_hash"
EOF
}
