resolveMiseBin() {
    local target_user="${USERNAME:-$USER}"

    if command -v mise >/dev/null 2>&1; then
        command -v mise
        return 0
    fi

    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$target_user")
    fi

    # The standalone installer's path (curl https://mise.run | sh)
    if [[ -n "$user_home" && -x "$user_home/.local/bin/mise" ]]; then
        echo "$user_home/.local/bin/mise"
        return 0
    fi

    return 1
}

runAsHostUser() {
    local target_user="${USERNAME:-$USER}"
    local -a cmd=("$@")
    local effective_path="${PATH:-/usr/bin:/bin}"

    if [[ "${#cmd[@]}" -gt 0 ]]; then
        case "${cmd[0]}" in
            php) [[ -n "${HOST_PHP_CMD:-}" ]] && cmd[0]="$HOST_PHP_CMD" ;;
            composer) [[ -n "${HOST_COMPOSER_CMD:-}" ]] && cmd[0]="$HOST_COMPOSER_CMD" ;;
            node) [[ -n "${HOST_NODE_CMD:-}" ]] && cmd[0]="$HOST_NODE_CMD" ;;
            npm) [[ -n "${HOST_NPM_CMD:-}" ]] && cmd[0]="$HOST_NPM_CMD" ;;
        esac
    fi

    # Prefix resolved tool directories so cross-tool lookups work (Composer's
    # shebang resolves `php` from PATH, npm scripts resolve `node`, etc.)
    local tool_cmd tool_dir
    for tool_cmd in "${HOST_PHP_CMD:-}" "${HOST_COMPOSER_CMD:-}" "${HOST_NODE_CMD:-}" "${HOST_NPM_CMD:-}"; do
        if [[ -z "$tool_cmd" ]]; then
            continue
        fi
        tool_dir=$(dirname "$tool_cmd")
        if [[ -n "$tool_dir" && ":$effective_path:" != *":$tool_dir:"* ]]; then
            effective_path="$tool_dir:$effective_path"
        fi
    done

    if [[ "$EUID" -eq 0 && -n "$target_user" && "$target_user" != "root" ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo -u "$target_user" env "PATH=$effective_path" "${cmd[@]}"
            return $?
        fi
    fi

    env "PATH=$effective_path" "${cmd[@]}"
}

resolveHostCommandPath() {
    local cmd="$1"
    local target_user="${USERNAME:-$USER}"
    local resolved=""

    # mise first: respects ~/.config/mise and per-directory mise.toml files
    local mise_bin
    mise_bin=$(resolveMiseBin || true)
    if [[ -n "$mise_bin" ]]; then
        local probe="'$mise_bin' which '$cmd' 2>/dev/null || true"
        if [[ "$EUID" -eq 0 && -n "$target_user" && "$target_user" != "root" && "$(command -v sudo 2>/dev/null)" ]]; then
            resolved=$(sudo -u "$target_user" bash -c "$probe" 2>/dev/null || true)
        else
            resolved=$(bash -c "$probe" 2>/dev/null || true)
        fi
        if [[ -n "$resolved" && -x "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi
    fi

    if resolved=$(command -v "$cmd" 2>/dev/null); then
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

requireHostMise() {
    if ! resolveMiseBin >/dev/null 2>&1; then
        prompt "Missing host tool: mise." "Install it via [curl https://mise.run | sh] and activate it in your shell." false
    fi
}

requireHostComposer() {
    local php_cmd
    local composer_cmd

    php_cmd=$(resolveHostCommandPath "php" || true)
    composer_cmd=$(resolveHostCommandPath "composer" || true)

    if [[ -z "$php_cmd" ]]; then
        prompt "Missing host tool: php." "Install it via mise [mise use -g php@${PHP_VERSION:-8.4}] and retry." false
    fi
    if [[ -z "$composer_cmd" ]]; then
        prompt "Missing host tool: composer." "The mise PHP plugin bundles Composer per version [mise use -g php@${PHP_VERSION:-8.4}]." false
    fi

    export HOST_PHP_CMD="$php_cmd"
    export HOST_COMPOSER_CMD="$composer_cmd"

    if ! runAsHostUser composer --version >/dev/null 2>&1; then
        prompt "Composer is not runnable on the host." "Check [mise doctor] and reinstall PHP via mise if needed." false
    fi
}

requireHostNode() {
    local node_cmd
    local npm_cmd

    node_cmd=$(resolveHostCommandPath "node" || true)
    npm_cmd=$(resolveHostCommandPath "npm" || true)

    if [[ -z "$node_cmd" ]]; then
        prompt "Missing host tool: node." "Install it via mise [mise use -g node@22] and retry." false
    fi
    if [[ -z "$npm_cmd" ]]; then
        prompt "Missing host tool: npm." "Install Node.js via mise [mise use -g node@22] and retry." false
    fi

    export HOST_NODE_CMD="$node_cmd"
    export HOST_NPM_CMD="$npm_cmd"

    if ! runAsHostUser "$HOST_NODE_CMD" --version >/dev/null 2>&1; then
        prompt "Node.js is not runnable on the host." "Check [mise doctor] and reinstall Node.js via mise if needed." false
    fi
    if ! runAsHostUser "$HOST_NPM_CMD" --version >/dev/null 2>&1; then
        prompt "npm is not runnable on the host." "Check [mise doctor] and reinstall Node.js via mise if needed." false
    fi
}

requireHostComposerExtensionsForApp() {
    local app_path="$1"
    local composer_file="$app_path/composer.json"

    if [[ -z "$app_path" || ! -f "$composer_file" ]]; then
        return 0
    fi

    if [[ -z "${HOST_PHP_CMD:-}" ]]; then
        HOST_PHP_CMD=$(resolveHostCommandPath "php" || true)
        export HOST_PHP_CMD
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
        prompt "Missing host PHP extension(s): $missing_list." "The prebuilt static mise PHP has a fixed extension set; switch to a source build with [pie_extensions] to add more (see README)." false
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
