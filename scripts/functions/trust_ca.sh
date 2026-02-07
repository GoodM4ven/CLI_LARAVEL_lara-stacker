trustCa() {
    local project_name="lara-stacker"
    local volume_name
    local mount_point
    local cert_path

    volume_name=$(docker volume ls -q \
        --filter "label=com.docker.compose.project=$project_name" \
        --filter "label=com.docker.compose.volume=caddy_data" | head -n 1)

    if [[ -n "$volume_name" ]]; then
        mount_point=$(docker volume inspect -f '{{ .Mountpoint }}' "$volume_name" 2>/dev/null)
        cert_path="$mount_point/caddy/pki/authorities/local/root.crt"

        for _ in {1..10}; do
            if [[ -f "$cert_path" ]]; then
                break
            fi
            sleep 1
        done
    fi

    local temp_cert=""
    if [[ -z "$cert_path" ]] || [[ ! -f "$cert_path" ]]; then
        # Fallback: read cert from the running Caddy container
        temp_cert="$(mktemp /tmp/caddy-local-XXXXXX.crt)"
        if dockerCompose exec -T caddy sh -lc "cat /data/caddy/pki/authorities/local/root.crt" > "$temp_cert" 2>/dev/null; then
            cert_path="$temp_cert"
        else
            [[ -n "$temp_cert" ]] && rm -f "$temp_cert"
            return 1
        fi
    fi

    install_path="/usr/local/share/ca-certificates/caddy-local.crt"
    if [[ "$EUID" -ne 0 ]]; then
        if ! command -v sudo >/dev/null 2>&1; then
            [[ -n "$temp_cert" ]] && rm -f "$temp_cert"
            return 1
        fi
        sudo cp "$cert_path" "$install_path"
        sudo update-ca-certificates >/dev/null 2>&1
    else
        cp "$cert_path" "$install_path"
        update-ca-certificates >/dev/null 2>&1
    fi

    local cert_user="${USERNAME:-${SUDO_USER:-$USER}}"
    if command -v certutil >/dev/null 2>&1; then
        if [[ -n "$cert_user" ]]; then
            sudo -u "$cert_user" bash -lc "mkdir -p ~/.pki/nssdb && certutil -d sql:\$HOME/.pki/nssdb -A -t 'C,,' -n 'Caddy Local CA' -i '$install_path' >/dev/null 2>&1 || true"
            if ! sudo -u "$cert_user" bash -lc "certutil -d sql:\$HOME/.pki/nssdb -L 2>/dev/null | grep -q 'Caddy Local CA'"; then
                echo -e "\nWarning: NSS trust store did not register the Caddy CA. Chrome/Brave may still show 'Not secure'."
            fi
        else
            echo -e "\nWarning: NSS trust store did not register the Caddy CA. Chrome/Brave may still show 'Not secure'."
        fi
    else
        echo -e "\nWarning: certutil not found; NSS trust store not updated."
    fi

    [[ -n "$temp_cert" ]] && rm -f "$temp_cert"
    return 0
}
