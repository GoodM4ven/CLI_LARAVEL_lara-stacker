isMacOS() {
    [[ "$(uname -s)" == "Darwin" ]]
}

isLinux() {
    [[ "$(uname -s)" == "Linux" ]]
}

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

    local user_home
    user_home=$(resolveUserHomePath "$target_user")

    if [[ -n "$user_home" && -n "$target_user" ]]; then
        if isMacOS && [[ "$normalized" == "/home/$target_user"* ]]; then
            normalized="$user_home${normalized#/home/$target_user}"
        fi

        if isLinux && [[ "$normalized" == "/Users/$target_user"* ]]; then
            normalized="$user_home${normalized#/Users/$target_user}"
        fi
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
    if isMacOS; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Normalizes DEV_EDITOR into "zed", "vsc", or "" (disabled).
# Falls back to the legacy USE_VSC toggle when DEV_EDITOR is absent.
resolveDevEditor() {
    local editor
    editor=$(printf '%s' "${DEV_EDITOR:-}" | tr '[:upper:]' '[:lower:]')

    case "$editor" in
        zed)
            echo "zed"
            return 0
            ;;
        vsc|vscode|code|vscodium)
            echo "vsc"
            return 0
            ;;
    esac

    if isNullLike "$editor" && [[ "${USE_VSC:-}" == "true" ]]; then
        echo "vsc"
        return 0
    fi

    echo ""
}
