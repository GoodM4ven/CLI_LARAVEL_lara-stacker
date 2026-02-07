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
        sudo chmod 644 "$install_path" 2>/dev/null || true
        sudo update-ca-certificates >/dev/null 2>&1
    else
        cp "$cert_path" "$install_path"
        chmod 644 "$install_path" 2>/dev/null || true
        update-ca-certificates >/dev/null 2>&1
    fi

    local cert_user="${USERNAME:-${SUDO_USER:-$USER}}"
    if command -v certutil >/dev/null 2>&1; then
        if [[ -n "$cert_user" ]]; then
            local -a cert_cmd
            if [[ "$EUID" -eq 0 ]]; then
                cert_cmd=(sudo -u "$cert_user" bash -lc)
            else
                cert_cmd=(bash -lc)
            fi

            # Ensure NSS DB exists before adding the CA (Chrome/Brave use NSS)
            "${cert_cmd[@]}" "mkdir -p ~/.pki/nssdb && if [[ ! -f ~/.pki/nssdb/cert9.db ]]; then certutil -d sql:\$HOME/.pki/nssdb -N --empty-password >/dev/null 2>&1 || true; fi"
            "${cert_cmd[@]}" "certutil -d sql:\$HOME/.pki/nssdb -A -t 'C,,' -n 'Caddy Local CA' -i '$install_path' >/dev/null 2>&1 || true"
            if ! "${cert_cmd[@]}" "certutil -d sql:\$HOME/.pki/nssdb -L 2>/dev/null | grep -q 'Caddy Local CA'"; then
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
