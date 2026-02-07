projectRegistryMarkerPath() {
    local project_path="$1"
    echo "$project_path/.lara-stacker"
}

isRegisteredProjectDir() {
    local project_path="$1"
    local marker
    marker=$(projectRegistryMarkerPath "$project_path")
    [[ -f "$marker" ]]
}

registerProjectDir() {
    local project_path="$1"
    local marker
    marker=$(projectRegistryMarkerPath "$project_path")
    if [[ -z "$project_path" || ! -d "$project_path" ]]; then
        return 1
    fi
    touch "$marker" 2>/dev/null || return 1
    return 0
}
