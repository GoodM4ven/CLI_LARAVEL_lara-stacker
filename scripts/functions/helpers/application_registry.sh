applicationRegistryMarkerPath() {
    local application_path="$1"
    echo "$application_path/.lara-stacker"
}

isRegisteredApplicationDir() {
    local application_path="$1"
    local marker
    marker=$(applicationRegistryMarkerPath "$application_path")
    [[ -f "$marker" ]]
}

registerApplicationDir() {
    local application_path="$1"
    local marker
    marker=$(applicationRegistryMarkerPath "$application_path")
    if [[ -z "$application_path" || ! -d "$application_path" ]]; then
        return 1
    fi
    touch "$marker" 2>/dev/null || return 1
    return 0
}
