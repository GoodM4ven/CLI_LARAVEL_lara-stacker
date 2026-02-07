runAsHostUser() {
    local target_user="${USERNAME:-$USER}"

    if [[ "$EUID" -eq 0 && -n "$target_user" && "$target_user" != "root" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo -u "$target_user" "$@"
            return $?
        fi
    fi

    "$@"
}

requireHostCommand() {
    local cmd="$1"
    local hint="$2"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        prompt "Missing host tool: $cmd." "$hint" false
    fi
}

requireHostComposer() {
    requireHostCommand "composer" "Install Composer on the host and retry."
    if ! runAsHostUser composer --version >/dev/null 2>&1; then
        prompt "Composer is not runnable on the host." "Ensure PHP is installed for Composer to run." false
    fi
}

requireHostNode() {
    requireHostCommand "node" "Install Node.js on the host and retry."
    requireHostCommand "npm" "Install npm on the host and retry."

    if ! runAsHostUser node --version >/dev/null 2>&1; then
        prompt "Node.js is not runnable on the host." "Reinstall Node.js and retry." false
    fi
    if ! runAsHostUser npm --version >/dev/null 2>&1; then
        prompt "npm is not runnable on the host." "Reinstall npm and retry." false
    fi
}
