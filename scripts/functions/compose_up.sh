composeUp() {
    local profiles=()

    if [[ -n "$DOCKER_PROFILES" ]]; then
        IFS=',' read -ra raw_profiles <<< "$DOCKER_PROFILES"
        for p in "${raw_profiles[@]}"; do
            p=$(echo "$p" | xargs)
            if [[ -n "$p" ]]; then
                profiles+=(--profile "$p")
            fi
        done
    fi

    dockerCompose "${profiles[@]}" up -d --remove-orphans
}
