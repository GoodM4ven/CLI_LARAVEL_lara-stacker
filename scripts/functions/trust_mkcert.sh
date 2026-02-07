trustMkcert() {
    local repo_dir="${lara_stacker_dir:-$PWD}"
    local cert_dir="$repo_dir/certs"
    local cert_file="$cert_dir/localhost.pem"
    local key_file="$cert_dir/localhost-key.pem"
    local mkcert_user="${USERNAME:-$USER}"

    if ! command -v mkcert >/dev/null 2>&1; then
        return 1
    fi

    mkdir -p "$cert_dir" 2>/dev/null || true

    if [[ "$EUID" -eq 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            return 1
        fi
        if [[ -n "$mkcert_user" ]]; then
            chown "$mkcert_user":"$mkcert_user" "$cert_dir" 2>/dev/null || true
            sudo -u "$mkcert_user" mkcert -install >/dev/null 2>&1 || return 1
            sudo -u "$mkcert_user" mkcert -cert-file "$cert_file" -key-file "$key_file" "localhost" "*.localhost" >/dev/null 2>&1 || return 1
        else
            return 1
        fi
    else
        mkcert -install >/dev/null 2>&1 || return 1
        mkcert -cert-file "$cert_file" -key-file "$key_file" "localhost" "*.localhost" >/dev/null 2>&1 || return 1
    fi

    chmod 644 "$cert_file" 2>/dev/null || true
    chmod 600 "$key_file" 2>/dev/null || true

    return 0
}
