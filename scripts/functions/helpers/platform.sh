isNullLike() {
    local value="${1:-}"
    local lowered
    lowered=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')

    [[ -z "$value" || "$lowered" == "null" || "$lowered" == "none" || "$lowered" == "false" ]]
}

resolveUserHomePath() {
    local target_user="${1:-}"
    local resolved=""

    if [[ -n "$target_user" ]]; then
        resolved=$(eval echo "~$target_user" 2>/dev/null || true)
        if [[ "$resolved" == "~$target_user" ]]; then
            resolved=""
        fi
    fi

    if [[ -z "$resolved" ]]; then
        resolved="${HOME:-}"
    fi

    echo "$resolved"
}

normalizePathForHost() {
    local input_path="$1"
    local target_user="${2:-${USERNAME:-$(id -un 2>/dev/null)}}"

    if isNullLike "$input_path"; then
        echo ""
        return 0
    fi

    local normalized="$input_path"
    if [[ "$normalized" == "~"* ]]; then
        normalized=$(eval echo "$normalized" 2>/dev/null || echo "$normalized")
    fi

    echo "$normalized"
}

resolveUserGroup() {
    local target_user="${1:-${USERNAME:-$(id -un 2>/dev/null)}}"
    local group

    group=$(id -gn "$target_user" 2>/dev/null || true)
    if [[ -z "$group" ]]; then
        group="$target_user"
    fi

    echo "$group"
}

sedi() {
    sed -i '' "$@"
}

# Normalizes DEV_EDITOR into "zed" or "" (disabled).
resolveDevEditor() {
    local editor
    editor=$(printf '%s' "${DEV_EDITOR:-}" | tr '[:upper:]' '[:lower:]')

    if [[ "$editor" == "zed" ]]; then
        echo "zed"
        return 0
    fi

    echo ""
}
