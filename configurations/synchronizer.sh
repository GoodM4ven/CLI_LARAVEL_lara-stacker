#!/bin/sh
set -eu

APPS_ROOT="${APPS_ROOT:-/var/www/html}"
POLL_SECONDS="${SYNCHRONIZER_INTERVAL_SECONDS:-${HOT_JANITOR_INTERVAL_SECONDS:-2}}"
STALE_SECONDS="${SYNCHRONIZER_HOT_STALE_SECONDS:-${HOT_JANITOR_STALE_SECONDS:-6}}"
TIMEOUT_SECONDS="${SYNCHRONIZER_TIMEOUT_SECONDS:-${HOT_JANITOR_TIMEOUT_SECONDS:-1}}"
VERBOSE="${SYNCHRONIZER_VERBOSE:-${HOT_JANITOR_VERBOSE:-false}}"
RETRY_DELAY_SECONDS="${SYNCHRONIZER_RETRY_DELAY_SECONDS:-1}"
AUTOLOAD_SETTLE_SECONDS="${SYNCHRONIZER_AUTOLOAD_SETTLE_SECONDS:-4}"
AUTOLOAD_COOLDOWN_SECONDS="${SYNCHRONIZER_AUTOLOAD_COOLDOWN_SECONDS:-20}"
APP_HOST_SUFFIX="${SYNCHRONIZER_APP_HOST_SUFFIX:-dev.localhost}"
APP_HTTPS_PORT="${SYNCHRONIZER_APP_HTTPS_PORT:-8443}"
APP_MASTER_PID="${SYNCHRONIZER_APP_MASTER_PID:-1}"
RUN_ONCE="${SYNCHRONIZER_RUN_ONCE:-false}"
STATE_DIR="${SYNCHRONIZER_STATE_DIR:-/tmp/synchronizer}"

mkdir -p "$STATE_DIR"

log() {
    if [ "$VERBOSE" = "true" ]; then
        echo "[synchronizer] $*"
    fi
}

file_age_seconds() {
    file_path="$1"

    now="$(date +%s)"
    modified="$(stat -c %Y "$file_path" 2>/dev/null || printf '')"

    if [ -z "$modified" ]; then
        return 1
    fi

    echo "$((now - modified))"
}

extract_host_header() {
    hot_url="$1"
    printf '%s' "$hot_url" | sed -E 's#^[a-zA-Z]+://([^/]+).*$#\1#'
}

probe_url() {
    url="$1"
    host_header="$2"

    wget \
        -q \
        -O - \
        --no-check-certificate \
        --timeout="$TIMEOUT_SECONDS" \
        --header="Host: ${host_header}" \
        "$url" 2>/dev/null || true
}

probe_vite() {
    host_header="$1"
    response="$(probe_url "https://caddy/@vite/client" "$host_header")"
    [ -n "$response" ]
}

app_host_header() {
    app_name="$1"

    if [ -n "$APP_HTTPS_PORT" ] && [ "$APP_HTTPS_PORT" != "443" ]; then
        printf '%s.%s:%s' "$app_name" "$APP_HOST_SUFFIX" "$APP_HTTPS_PORT"
        return 0
    fi

    printf '%s.%s' "$app_name" "$APP_HOST_SUFFIX"
}

autoload_mtime_state_file() {
    app_name="$1"
    printf '%s/%s.autoload-static.mtime' "$STATE_DIR" "$app_name"
}

autoload_cooldown_state_file() {
    app_name="$1"
    printf '%s/%s.autoload-static.cooldown' "$STATE_DIR" "$app_name"
}

autoload_parse_error_detected() {
    response="$1"

    printf '%s' "$response" | grep -F "Parse error:" >/dev/null 2>&1 \
        && printf '%s' "$response" | grep -F "/vendor/composer/autoload_static.php" >/dev/null 2>&1
}

cooldown_is_active() {
    cooldown_file="$1"

    if [ ! -f "$cooldown_file" ]; then
        return 1
    fi

    last_attempt="$(cat "$cooldown_file" 2>/dev/null || printf '')"
    if [ -z "$last_attempt" ]; then
        return 1
    fi

    now="$(date +%s)"
    elapsed="$((now - last_attempt))"

    [ "$elapsed" -lt "$AUTOLOAD_COOLDOWN_SECONDS" ]
}

record_cooldown() {
    cooldown_file="$1"
    date +%s > "$cooldown_file"
}

check_hot_file() {
    app_name="$1"
    hot_file="$2"

    if [ ! -f "$hot_file" ]; then
        return 0
    fi

    hot_url="$(tr -d '\r\n' < "$hot_file")"

    if [ -z "$hot_url" ]; then
        return 0
    fi

    age="$(file_age_seconds "$hot_file" || echo 0)"

    if [ "$age" -lt "$STALE_SECONDS" ]; then
        return 0
    fi

    host_header="$(extract_host_header "$hot_url")"

    if [ -z "$host_header" ]; then
        return 0
    fi

    if probe_vite "$host_header" >/dev/null 2>&1; then
        log "healthy hot file for ${app_name}: ${host_header}"
        return 0
    fi

    sleep "$RETRY_DELAY_SECONDS"

    if probe_vite "$host_header" >/dev/null 2>&1; then
        log "healthy hot file after retry for ${app_name}: ${host_header}"
        return 0
    fi

    rm -f "$hot_file"
    echo "[synchronizer] removed stale hot file for ${app_name}: ${hot_url}"
}

check_autoload_static_file() {
    app_name="$1"
    autoload_static_file="$2"

    mtime_state_file="$(autoload_mtime_state_file "$app_name")"
    cooldown_state_file="$(autoload_cooldown_state_file "$app_name")"

    if [ ! -f "$autoload_static_file" ]; then
        rm -f "$mtime_state_file" "$cooldown_state_file"
        return 0
    fi

    current_mtime="$(stat -c %Y "$autoload_static_file" 2>/dev/null || printf '')"
    if [ -z "$current_mtime" ]; then
        return 0
    fi

    previous_mtime=""
    if [ -f "$mtime_state_file" ]; then
        previous_mtime="$(cat "$mtime_state_file" 2>/dev/null || printf '')"
    fi

    if [ "$current_mtime" = "$previous_mtime" ] && [ ! -f "$cooldown_state_file" ]; then
        return 0
    fi

    age="$(file_age_seconds "$autoload_static_file" || echo 0)"
    if [ "$age" -lt "$AUTOLOAD_SETTLE_SECONDS" ]; then
        log "autoload_static.php still settling for ${app_name}"
        return 0
    fi

    host_header="$(app_host_header "$app_name")"
    response="$(probe_url "https://caddy/" "$host_header")"

    if ! autoload_parse_error_detected "$response"; then
        printf '%s' "$current_mtime" > "$mtime_state_file"
        rm -f "$cooldown_state_file"
        return 0
    fi

    if cooldown_is_active "$cooldown_state_file"; then
        log "autoload parse error cooldown active for ${app_name}"
        printf '%s' "$current_mtime" > "$mtime_state_file"
        return 0
    fi

    echo "[synchronizer] detected Composer autoload desync for ${app_name}; reloading PHP-FPM"
    record_cooldown "$cooldown_state_file"
    printf '%s' "$current_mtime" > "$mtime_state_file"

    if ! kill -USR2 "$APP_MASTER_PID" >/dev/null 2>&1; then
        echo "[synchronizer] failed to signal PHP-FPM master process ${APP_MASTER_PID} for ${app_name}"
        return 0
    fi

    sleep "$RETRY_DELAY_SECONDS"

    response="$(probe_url "https://caddy/" "$host_header")"
    if autoload_parse_error_detected "$response"; then
        echo "[synchronizer] Composer autoload parse error persists for ${app_name} after PHP-FPM reload"
        return 0
    fi

    rm -f "$cooldown_state_file"
    echo "[synchronizer] reloaded PHP-FPM to recover Composer autoload sync for ${app_name}"
}

run_iteration() {
    if [ ! -d "$APPS_ROOT" ]; then
        return 0
    fi

    for app_dir in "$APPS_ROOT"/*; do
        if [ ! -d "$app_dir" ]; then
            continue
        fi

        app_name="$(basename "$app_dir")"
        check_hot_file "$app_name" "$app_dir/public/hot"
        check_autoload_static_file "$app_name" "$app_dir/vendor/composer/autoload_static.php"
    done
}

while true; do
    run_iteration

    if [ "$RUN_ONCE" = "true" ]; then
        exit 0
    fi

    sleep "$POLL_SECONDS"
done
