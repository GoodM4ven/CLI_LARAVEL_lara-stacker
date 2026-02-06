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

    local state_file="$PWD/.stacker-build.env"
    local last_php_version=""
    local last_node_version=""
    local last_profiles=""

    if [[ -f "$state_file" ]]; then
        # shellcheck source=/dev/null
        source "$state_file"
        last_php_version="${STACKER_PHP_VERSION:-}"
        last_node_version="${STACKER_NODE_VERSION:-}"
        last_profiles="${STACKER_PROFILES:-}"
    fi

    local current_php="${PHP_VERSION:-8.3}"
    local current_node="${NODE_VERSION:-20}"

    local need_rebuild="false"
    if [[ "$current_php" != "$last_php_version" ]] || [[ "$current_node" != "$last_node_version" ]]; then
        need_rebuild="true"
    fi

    local profiles_changed="false"
    if [[ "$normalized_profiles" != "$last_profiles" ]]; then
        profiles_changed="true"
    fi

    if [[ "$profiles_changed" == "true" ]]; then
        dockerCompose down
    fi

    if [[ "$need_rebuild" == "true" ]]; then
        dockerCompose "${profiles[@]}" up -d --remove-orphans --build
    else
        dockerCompose "${profiles[@]}" up -d --remove-orphans
    fi

    cat > "$state_file" <<EOF
STACKER_PHP_VERSION="$current_php"
STACKER_NODE_VERSION="$current_node"
STACKER_PROFILES="$normalized_profiles"
EOF
}
