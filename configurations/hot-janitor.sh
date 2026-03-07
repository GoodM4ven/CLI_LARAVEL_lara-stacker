#!/bin/sh
set -eu

APPS_ROOT="${APPS_ROOT:-/var/www/html}"
POLL_SECONDS="${HOT_JANITOR_INTERVAL_SECONDS:-2}"
STALE_SECONDS="${HOT_JANITOR_STALE_SECONDS:-6}"
TIMEOUT_SECONDS="${HOT_JANITOR_TIMEOUT_SECONDS:-1}"
VERBOSE="${HOT_JANITOR_VERBOSE:-false}"

log() {
    if [ "$VERBOSE" = "true" ]; then
        echo "[hot-janitor] $*"
    fi
}

hot_file_age_seconds() {
    hot_file="$1"

    now="$(date +%s)"
    modified="$(stat -c %Y "$hot_file" 2>/dev/null || printf '')"

    if [ -z "$modified" ]; then
        return 1
    fi

    echo "$((now - modified))"
}

extract_host_header() {
    hot_url="$1"
    printf '%s' "$hot_url" | sed -E 's#^[a-zA-Z]+://([^/]+).*$#\1#'
}

probe_vite() {
    host_header="$1"

    wget \
        -q \
        --spider \
        --no-check-certificate \
        --timeout="$TIMEOUT_SECONDS" \
        --header="Host: ${host_header}" \
        "https://caddy/@vite/client" >/dev/null 2>&1
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

    age="$(hot_file_age_seconds "$hot_file" || echo 0)"

    if [ "$age" -lt "$STALE_SECONDS" ]; then
        return 0
    fi

    host_header="$(extract_host_header "$hot_url")"

    if [ -z "$host_header" ]; then
        return 0
    fi

    if probe_vite "$host_header"; then
        log "healthy hot file for ${app_name}: ${host_header}"
        return 0
    fi

    # Retry once to avoid deleting during transient network/container restarts.
    sleep 1

    if probe_vite "$host_header"; then
        log "healthy hot file after retry for ${app_name}: ${host_header}"
        return 0
    fi

    rm -f "$hot_file"
    echo "[hot-janitor] removed stale hot file for ${app_name}: ${hot_url}"
}

while true; do
    if [ ! -d "$APPS_ROOT" ]; then
        sleep "$POLL_SECONDS"
        continue
    fi

    for app_dir in "$APPS_ROOT"/*; do
        if [ ! -d "$app_dir" ]; then
            continue
        fi

        app_name="$(basename "$app_dir")"
        check_hot_file "$app_name" "$app_dir/public/hot"
    done

    sleep "$POLL_SECONDS"
done
