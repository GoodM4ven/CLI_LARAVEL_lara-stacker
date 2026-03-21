trustMkcert() {
    local repo_dir="${lara_stacker_dir:-$PWD}"
    local cert_dir="$repo_dir/.certs"
    local cert_file="$cert_dir/dev.localhost.pem"
    local key_file="$cert_dir/dev.localhost-key.pem"
    local mkcert_user="${USERNAME:-$USER}"
    local domain_suffix="dev.localhost"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local -a hosts

    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi
    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    sourcer "helpers.applicationRegistry"

    if ! command -v mkcert >/dev/null 2>&1; then
        return 1
    fi

    mkdir -p "$cert_dir" 2>/dev/null || true

    add_host() {
        local host="$1"
        [[ -z "$host" ]] && return 0
        local existing
        for existing in "${hosts[@]}"; do
            if [[ "$existing" == "$host" ]]; then
                return 0
            fi
        done
        hosts+=("$host")
    }

    add_host "localhost"
    add_host "mailpit.${domain_suffix}"
    add_host "minio.${domain_suffix}"
    add_host "minio-api.${domain_suffix}"

    if [[ -d "$apps_root" ]]; then
        while IFS= read -r -d '' dir; do
            local application
            if ! isRegisteredApplicationDir "$dir"; then
                continue
            fi
            application="$(basename "$dir")"
            [[ "$application" == .* ]] && continue
            add_host "${application}.${domain_suffix}"
            add_host "vite-${application}.${domain_suffix}"
        done < <(find "$apps_root" -mindepth 1 -maxdepth 1 -type d -print0)
    fi

    if [[ "$domain_suffix" != "localhost" ]]; then
        add_host "$domain_suffix"
        add_host "*.${domain_suffix}"
    fi

    if [[ "$EUID" -eq 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            return 1
        fi
        if [[ -n "$mkcert_user" ]]; then
            local owner_group="$mkcert_user"
            if declare -F resolveUserGroup >/dev/null 2>&1; then
                owner_group=$(resolveUserGroup "$mkcert_user")
            fi
            chown "$mkcert_user":"$owner_group" "$cert_dir" 2>/dev/null || true
            sudo -u "$mkcert_user" mkcert -install >/dev/null 2>&1 || return 1
            sudo -u "$mkcert_user" mkcert -cert-file "$cert_file" -key-file "$key_file" "${hosts[@]}" >/dev/null 2>&1 || return 1
        else
            return 1
        fi
    else
        mkcert -install >/dev/null 2>&1 || return 1
        mkcert -cert-file "$cert_file" -key-file "$key_file" "${hosts[@]}" >/dev/null 2>&1 || return 1
    fi

    chmod 644 "$cert_file" 2>/dev/null || true
    chmod 600 "$key_file" 2>/dev/null || true

    return 0
}
