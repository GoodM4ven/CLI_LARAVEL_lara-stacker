viteUp() {
    local application_name="$1"

    local apps_root="${APPS_ROOT:-/var/www/html}"
    local domain_suffix="dev.localhost"
    local repo_dir="${lara_stacker_dir:-$PWD}"
    if [[ -f "$repo_dir/scripts/functions/helpers/platform.sh" ]]; then
        # shellcheck source=/dev/null
        source "$repo_dir/scripts/functions/helpers/platform.sh"
    fi
    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

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

    local server_block="    server: {\n        host: true,\n        strictPort: true,\n        port: 5173,\n        hmr: {\n            host: '${vite_host}',\n            protocol: 'wss',\n            clientPort: ${https_port},\n        },\n    },"

    local build_block="    build: {\n        emptyOutDir: false,\n    },"

    if grep -q "server:" "$file"; then
        if grep -q "clientPort:[[:space:]]*${https_port}" "$file" && grep -q "protocol:[[:space:]]*'wss'" "$file" && grep -q "strictPort:[[:space:]]*true" "$file"; then
            echo -e "\nDetected Docker-friendly Vite server config; skipped auto-patch."
        else
            awk -v replacement="$server_block" '
            BEGIN { in_server=0; depth=0 }
            {
                if (!in_server) {
                    if ($0 ~ /server:[[:space:]]*{/) {
                        in_server=1
                        depth=0
                        line=$0
                        open_count=gsub(/{/, "{", line)
                        close_count=gsub(/}/, "}", line)
                        depth += open_count - close_count
                        print replacement
                        if (depth <= 0) {
                            in_server=0
                        }
                        next
                    }
                    print
                    next
                }

                line=$0
                open_count=gsub(/{/, "{", line)
                close_count=gsub(/}/, "}", line)
                depth += open_count - close_count
                if (depth <= 0) {
                    in_server=0
                }
            }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

            echo -e "\nReplaced existing Vite server config with Docker HMR settings."
        fi
    else
        awk -v insert="$server_block" '
        {
            print
            if ($0 ~ /export default defineConfig\({/) {
                print insert
            }
        }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

        echo -e "\nAdded Docker-friendly Vite dev server config."
    fi

    if grep -q "emptyOutDir:[[:space:]]*false" "$file"; then
        echo -e "\nDetected Vite build.emptyOutDir=false; skipped auto-patch."
        return 0
    fi

    if grep -q "emptyOutDir:[[:space:]]*" "$file"; then
        if declare -F sedi >/dev/null 2>&1; then
            sedi -E '0,/emptyOutDir[[:space:]]*:[[:space:]]*[^,}]+/{s/emptyOutDir[[:space:]]*:[[:space:]]*[^,}]+/emptyOutDir: false/}' "$file"
        else
            sed -i -E '0,/emptyOutDir[[:space:]]*:[[:space:]]*[^,}]+/{s/emptyOutDir[[:space:]]*:[[:space:]]*[^,}]+/emptyOutDir: false/}' "$file"
        fi
        echo -e "\nUpdated Vite build.emptyOutDir to false."
        return 0
    fi

    if grep -q "build:[[:space:]]*{" "$file"; then
        awk '
        BEGIN { inserted=0 }
        {
            print
            if (!inserted && $0 ~ /build:[[:space:]]*{/) {
                print "        emptyOutDir: false,"
                inserted=1
            }
        }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

        echo -e "\nAdded build.emptyOutDir=false to existing Vite build config."
        return 0
    fi

    awk -v insert="$build_block" '
    {
        print
        if ($0 ~ /export default defineConfig\({/) {
            print insert
        }
    }' "$file" > "$file.tmp" && mv "$file.tmp" "$file"

    echo -e "\nAdded Vite build config with emptyOutDir=false."
}
