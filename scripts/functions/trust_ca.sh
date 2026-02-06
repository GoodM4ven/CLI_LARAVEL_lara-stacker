trustCa() {
    local project_name="${DOCKER_PROJECT_NAME:-lara-stacker}"
    local volume_name
    local mount_point
    local cert_path

    volume_name=$(docker volume ls -q \
        --filter "label=com.docker.compose.project=$project_name" \
        --filter "label=com.docker.compose.volume=caddy_data" | head -n 1)

    if [[ -z "$volume_name" ]]; then
        return 1
    fi

    mount_point=$(docker volume inspect -f '{{ .Mountpoint }}' "$volume_name" 2>/dev/null)
    cert_path="$mount_point/caddy/pki/authorities/local/root.crt"

    for _ in {1..10}; do
        if [[ -f "$cert_path" ]]; then
            break
        fi
        sleep 1
    done

    if [[ ! -f "$cert_path" ]]; then
        return 1
    fi

    install_path="/usr/local/share/ca-certificates/caddy-local.crt"
    cp "$cert_path" "$install_path"
    update-ca-certificates >/dev/null 2>&1

    if command -v certutil >/dev/null 2>&1; then
        sudo -u "$USERNAME" bash -lc "mkdir -p ~/.pki/nssdb && certutil -d sql:\$HOME/.pki/nssdb -A -t 'C,,' -n 'Caddy Local CA' -i '$install_path' >/dev/null 2>&1 || true"
    fi

    return 0
}
