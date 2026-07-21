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
            pnpm) [[ -n "${HOST_PNPM_CMD:-}" ]] && cmd[0]="$HOST_PNPM_CMD" ;;
            laravel) [[ -n "${HOST_LARAVEL_CMD:-}" ]] && cmd[0]="$HOST_LARAVEL_CMD" ;;
        esac
    fi

    # Prefix resolved tool directories so cross-tool lookups work (Composer's
    # shebang resolves `php` from PATH, npm scripts resolve `node`, etc.)
    local tool_cmd tool_dir
    for tool_cmd in "${HOST_PHP_CMD:-}" "${HOST_COMPOSER_CMD:-}" "${HOST_NODE_CMD:-}" "${HOST_NPM_CMD:-}" "${HOST_PNPM_CMD:-}" "${HOST_LARAVEL_CMD:-}"; do
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

    # Resolve from Lara-Stacker's repository-level mise environment first.
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

    local user_home="${HOME:-}"
    if declare -F resolveUserHomePath >/dev/null 2>&1; then
        user_home=$(resolveUserHomePath "$target_user")
    fi
    if [[ -n "$user_home" && -x "$user_home/.composer/vendor/bin/$cmd" ]]; then
        echo "$user_home/.composer/vendor/bin/$cmd"
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
        prompt "Missing host tool: mise." "Run [./scripts/setup.sh] to install Lara-Stacker's complete macOS toolchain." false
    fi
}

requireHostLaravelInstaller() {
    requireHostComposer

    local laravel_cmd
    laravel_cmd=$(resolveHostCommandPath "laravel" || true)

    if [[ -z "$laravel_cmd" ]]; then
        echo -e "\nInstalling the Laravel installer globally..."
        if ! runAsHostUser composer global require laravel/installer --with-all-dependencies --no-interaction; then
            prompt "Failed to install laravel/installer globally." "Run [./scripts/setup.sh], then retry." false
        fi
        laravel_cmd=$(resolveHostCommandPath "laravel" || true)
    fi

    if [[ -z "$laravel_cmd" ]]; then
        prompt "Laravel's global installer is unavailable." "Ensure [$HOME/.composer/vendor/bin] is in PATH, then retry." false
    fi

    export HOST_LARAVEL_CMD="$laravel_cmd"
}

runInApplicationAsHostUser() {
    local application_path="$1"
    shift

    if [[ -z "$application_path" || ! -d "$application_path" ]]; then
        return 1
    fi

    (
        cd "$application_path"
        runAsHostUser "$@"
    )
}

requireHostComposer() {
    local php_cmd
    local composer_cmd

    php_cmd=$(resolveHostCommandPath "php" || true)
    composer_cmd=$(resolveHostCommandPath "composer" || true)

    if [[ -z "$php_cmd" ]]; then
        prompt "Missing host tool: php." "Run [./scripts/setup.sh] to install this repository's mise toolchain." false
    fi
    if [[ -z "$composer_cmd" ]]; then
        prompt "Missing host tool: composer." "Run [./scripts/setup.sh]; the repository's mise PHP installation bundles Composer." false
    fi

    export HOST_PHP_CMD="$php_cmd"
    export HOST_COMPOSER_CMD="$composer_cmd"

    if ! runAsHostUser composer --version >/dev/null 2>&1; then
        prompt "Composer is not runnable on the host." "Check [mise doctor] and reinstall PHP via mise if needed." false
    fi

    # Warn (not abort) when the host PHP diverges from the container's version
    if [[ -n "${PHP_VERSION:-}" ]]; then
        local host_php_version
        host_php_version=$(runAsHostUser php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;' 2>/dev/null || true)
        if [[ -n "$host_php_version" && "$host_php_version" != "$PHP_VERSION" ]]; then
            echo -e "\nWarning: Host PHP is $host_php_version while the container's PHP_VERSION is $PHP_VERSION. Consider aligning them (mise + [.env])."
        fi
    fi
}

requireHostNode() {
    local node_cmd
    local npm_cmd

    node_cmd=$(resolveHostCommandPath "node" || true)
    npm_cmd=$(resolveHostCommandPath "npm" || true)

    if [[ -z "$node_cmd" ]]; then
        prompt "Missing host tool: node." "Run [./scripts/setup.sh] to install this repository's mise toolchain." false
    fi
    if [[ -z "$npm_cmd" ]]; then
        prompt "Missing host tool: npm." "Run [./scripts/setup.sh]; the repository's mise Node.js installation bundles npm." false
    fi

    export HOST_NODE_CMD="$node_cmd"
    export HOST_NPM_CMD="$npm_cmd"

    # pnpm is optional at this point; it's only required for pnpm-lock.yaml apps
    local pnpm_cmd
    pnpm_cmd=$(resolveHostCommandPath "pnpm" || true)
    if [[ -n "$pnpm_cmd" ]]; then
        export HOST_PNPM_CMD="$pnpm_cmd"
    fi

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
        prompt "Missing host PHP extension(s): $missing_list." "Add the PIE package to this repository's [mise.toml], then rerun [./scripts/setup.sh]." false
    fi
}

installHostNpmDependencies() {
    local application_path="$1"

    if [[ -z "$application_path" || ! -f "$application_path/package.json" ]]; then
        return 0
    fi

    # Respect the app's package manager: pnpm-lock.yaml means pnpm, otherwise npm
    if [[ -f "$application_path/pnpm-lock.yaml" ]]; then
        if [[ -z "${HOST_PNPM_CMD:-}" ]]; then
            HOST_PNPM_CMD=$(resolveHostCommandPath "pnpm" || true)
            export HOST_PNPM_CMD
        fi
        if [[ -z "${HOST_PNPM_CMD:-}" ]]; then
            prompt "Missing host tool: pnpm (the app has a pnpm-lock.yaml)." "Run [./scripts/setup.sh] to install this repository's mise toolchain." false
        fi
        runAsHostUser pnpm install --dir "$application_path"
        return $?
    fi

    if runAsHostUser npm install --prefix "$application_path"; then
        return 0
    fi

    echo -e "\nWarning: npm install failed. Retrying with --legacy-peer-deps for broader app compatibility...\n"
    runAsHostUser npm install --legacy-peer-deps --prefix "$application_path"
}
