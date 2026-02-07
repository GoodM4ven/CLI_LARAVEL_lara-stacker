composeUp() {
    local profiles=()
    local profile_names=()
    local normalized_profiles=""

    if [[ -n "$DOCKER_PROFILES" ]]; then
        IFS=',' read -ra raw_profiles <<< "$DOCKER_PROFILES"
        for p in "${raw_profiles[@]}"; do
            p=$(echo "$p" | xargs | tr '[:upper:]' '[:lower:]')
            if [[ -n "$p" ]]; then
                profiles+=(--profile "$p")
                profile_names+=("$p")
            fi
        done
    fi

    if [[ ${#profile_names[@]} -gt 0 ]]; then
        local sorted_profiles=()
        mapfile -t sorted_profiles < <(printf '%s\n' "${profile_names[@]}" | sort -u)
        normalized_profiles=$(IFS=,; echo "${sorted_profiles[*]}")
    fi

    local state_dir="${HOME:-/tmp}/.lara-stacker"
    local state_file="$state_dir/stacker-build.env"
    local last_php_version=""
    local last_profiles=""
    local last_trust_mode=""
    local last_build_hash=""

    if [[ -f "$state_file" ]]; then
        # shellcheck source=/dev/null
        source "$state_file"
        last_php_version="${STACKER_PHP_VERSION:-}"
        last_profiles="${STACKER_PROFILES:-}"
        last_trust_mode="${STACKER_TRUST_MODE:-}"
        last_build_hash="${STACKER_BUILD_HASH:-}"
    fi

    local current_php="${PHP_VERSION:-8.3}"
    local current_trust_mode="${HTTPS_TRUST_MODE:-caddy}"
    local current_build_hash=""

    if command -v sha256sum >/dev/null 2>&1; then
        local repo_dir="$PWD"
        if [[ -f "$repo_dir/files/Dockerfile" ]]; then
            current_build_hash=$(
                sha256sum \
                    "$repo_dir/files/Dockerfile" \
                    "$repo_dir/files/xdebug.ini" \
                    "$repo_dir/files/opcache.ini" \
                    2>/dev/null | sha256sum | awk '{print $1}'
            )
        fi
    fi

    local need_rebuild="false"
    if [[ "$current_php" != "$last_php_version" ]]; then
        need_rebuild="true"
    fi
    if [[ -n "$current_build_hash" ]] && [[ "$current_build_hash" != "$last_build_hash" ]]; then
        need_rebuild="true"
    fi

    local profiles_changed="false"
    if [[ "$normalized_profiles" != "$last_profiles" ]]; then
        profiles_changed="true"
    fi

    if [[ "$current_trust_mode" != "$last_trust_mode" ]]; then
        profiles_changed="true"
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

    if [[ "$profiles_changed" == "true" ]] || [[ "$faulty" == "true" ]]; then
        dockerCompose down
    fi

    local up_status=0
    if [[ "$need_rebuild" == "true" ]]; then
        dockerCompose "${profiles[@]}" up -d --remove-orphans --build || up_status=$?
    else
        dockerCompose "${profiles[@]}" up -d --remove-orphans || up_status=$?
    fi

    if [[ "$up_status" -ne 0 ]]; then
        return "$up_status"
    fi

    mkdir -p "$state_dir" 2>/dev/null || true
    cat > "$state_file" <<EOF
STACKER_PHP_VERSION="$current_php"
STACKER_PROFILES="$normalized_profiles"
STACKER_TRUST_MODE="$current_trust_mode"
STACKER_BUILD_HASH="$current_build_hash"
EOF
}
