viteUp() {
    local application_name="$1"

    local apps_root="${APPS_ROOT:-/var/www/html}"
    local domain_suffix="dev.localhost"

    local escaped_application_name
    escaped_application_name=$(echo "$application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    escaped_application_name=${escaped_application_name// /}

    local application_path="$apps_root/$escaped_application_name"
    local file="$application_path/vite.config.js"

    if [[ ! -f "$file" ]]; then
        return 0
    fi

    local vite_host="vite-${escaped_application_name}.${domain_suffix}"
    local https_port="${CADDY_HTTPS_PORT:-8443}"

    if grep -q "server:" "$file"; then
        if grep -q "hmr:" "$file"; then
            echo -e "\nDetected existing Vite HMR config; skipped auto-patch."
            return 0
        fi

        local insert="        host: true,\n        strictPort: true,\n        port: 5173,\n        hmr: {\n            host: '${vite_host}',\n            protocol: 'wss',\n            clientPort: ${https_port},\n        },"

        awk -v insert="$insert" '
        {
            print $0
            if ($0 ~ /server:[[:space:]]*{/) {
                print insert
            }
        }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

        echo -e "\nPatched existing Vite server config for Docker HMR."
        return 0
    fi

    sed -i "/export default defineConfig({/a \
    server: {\n\
        host: true,\n\
        strictPort: true,\n\
        port: 5173,\n\
        hmr: {\n\
            host: '$vite_host',\n\
            protocol: 'wss',\n\
            clientPort: ${https_port},\n\
        },\n\
    }," "$file"

    echo -e "\nAdded Docker-friendly Vite dev server config."
}
