runAsHostUser() {
    local target_user="${USERNAME:-$USER}"
    local -a cmd=("$@")
    local extra_path_prefix=""
    local effective_path="${PATH:-/usr/bin:/bin}"

    if [[ "${#cmd[@]}" -gt 0 ]]; then
        if [[ "${cmd[0]}" == "node" && -n "${HOST_NODE_CMD:-}" ]]; then
            cmd[0]="$HOST_NODE_CMD"
        elif [[ "${cmd[0]}" == "npm" && -n "${HOST_NPM_CMD:-}" ]]; then
            cmd[0]="$HOST_NPM_CMD"
        fi

        if [[ ("${cmd[0]}" == "$HOST_NODE_CMD" || "${cmd[0]}" == "$HOST_NPM_CMD") && -n "${HOST_NODE_CMD:-}" ]]; then
            extra_path_prefix=$(dirname "$HOST_NODE_CMD")
            if [[ -n "$extra_path_prefix" && ":$effective_path:" != *":$extra_path_prefix:"* ]]; then
                effective_path="$extra_path_prefix:$effective_path"
            fi
        fi
    fi

    if [[ "$EUID" -eq 0 && -n "$target_user" && "$target_user" != "root" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            if [[ -n "$extra_path_prefix" ]]; then
                sudo -u "$target_user" env "PATH=$effective_path" "${cmd[@]}"
            else
                sudo -u "$target_user" "${cmd[@]}"
            fi
            return $?
        fi
    fi

    if [[ -n "$extra_path_prefix" ]]; then
        env "PATH=$effective_path" "${cmd[@]}"
    else
        "${cmd[@]}"
    fi
}

resolveHostCommandPath() {
    local cmd="$1"
    local target_user="${USERNAME:-$USER}"
    local resolved=""

    if resolved=$(command -v "$cmd" 2>/dev/null); then
        echo "$resolved"
        return 0
    fi

    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$target_user")
    fi

    local nvm_dir="${user_home%/}/.nvm"
    if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
        return 1
    fi

    local probe="export NVM_DIR='$nvm_dir'; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" >/dev/null 2>&1; command -v '$cmd' 2>/dev/null || true"
    if [[ "$EUID" -eq 0 && -n "$target_user" && "$target_user" != "root" && "$(command -v sudo 2>/dev/null)" ]]; then
        resolved=$(sudo -u "$target_user" bash -lc "$probe" 2>/dev/null || true)
    else
        resolved=$(bash -lc "$probe" 2>/dev/null || true)
    fi

    if [[ -n "$resolved" ]]; then
        echo "$resolved"
        return 0
    fi

    return 1
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
    local node_cmd
    local npm_cmd

    node_cmd=$(resolveHostCommandPath "node" || true)
    npm_cmd=$(resolveHostCommandPath "npm" || true)

    if [[ -z "$node_cmd" ]]; then
        prompt "Missing host tool: node." "Install Node.js on the host and retry." false
    fi
    if [[ -z "$npm_cmd" ]]; then
        prompt "Missing host tool: npm." "Install npm on the host and retry." false
    fi

    export HOST_NODE_CMD="$node_cmd"
    export HOST_NPM_CMD="$npm_cmd"

    if ! runAsHostUser "$HOST_NODE_CMD" --version >/dev/null 2>&1; then
        prompt "Node.js is not runnable on the host." "Reinstall Node.js and retry." false
    fi
    if ! runAsHostUser "$HOST_NPM_CMD" --version >/dev/null 2>&1; then
        prompt "npm is not runnable on the host." "Reinstall npm and retry." false
    fi
}

requireHostComposerExtensionsForApp() {
    local app_path="$1"
    local composer_file="$app_path/composer.json"

    if [[ -z "$app_path" || ! -f "$composer_file" ]]; then
        return 0
    fi

    local missing
    missing=$(runAsHostUser php -r '
        $file = $argv[1] ?? "";
        if (!is_file($file)) { exit(0); }

        $json = json_decode((string) file_get_contents($file), true);
        if (!is_array($json)) { exit(0); }

        $required = [];
        foreach (["require", "require-dev"] as $section) {
            if (!isset($json[$section]) || !is_array($json[$section])) {
                continue;
            }
            foreach ($json[$section] as $package => $constraint) {
                if (strncmp($package, "ext-", 4) === 0) {
                    $required[substr($package, 4)] = true;
                }
            }
        }

        ksort($required);

        $missing = [];
        foreach (array_keys($required) as $extension) {
            $loaded = extension_loaded($extension);
            if (!$loaded && $extension === "opcache") {
                $loaded = extension_loaded("Zend OPcache");
            }
            if (!$loaded) {
                $missing[] = $extension;
            }
        }

        if (!empty($missing)) {
            echo implode("\n", $missing);
        }
    ' "$composer_file" 2>/dev/null || true)

    if [[ -n "$missing" ]]; then
        local missing_list
        missing_list=$(echo "$missing" | tr '\n' ',' | sed 's/,$//; s/,/, /g')
        prompt "Missing host PHP extension(s): $missing_list." "Enable required host PHP extensions declared in composer.json (ext-*) and retry." false
    fi
}

installHostNpmDependencies() {
    local application_path="$1"

    if [[ -z "$application_path" || ! -f "$application_path/package.json" ]]; then
        return 0
    fi

    if runAsHostUser npm install --prefix "$application_path"; then
        return 0
    fi

    echo -e "\nWarning: npm install failed. Retrying with --legacy-peer-deps for broader app compatibility...\n"
    runAsHostUser npm install --legacy-peer-deps --prefix "$application_path"
}
