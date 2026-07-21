selectRegisteredApplication() {
    local apps_root="$1"
    local application_names=()
    local application_statuses=()
    local dir name status

    for dir in "$apps_root"/*/; do
        if [[ ! -d "$dir" ]] || ! isRegisteredApplicationDir "$dir"; then
            continue
        fi

        name=$(basename "$dir")
        status="enabled"
        if isDisabledApplicationDir "$dir"; then
            status="disabled"
        fi
        application_names+=("$name")
        application_statuses+=("$status")
    done

    local application_count=${#application_names[@]}
    if [[ "$application_count" -eq 0 ]]; then
        prompt "No registered applications found." "Use Import or Create first."
    fi

    echo -e "\nAvailable applications:\n"
    local digits=${#application_count}
    if [[ "$digits" -lt 2 ]]; then
        digits=2
    fi

    local i idx
    for i in "${!application_names[@]}"; do
        idx=$((i + 1))
        printf "%0*d. %s (%s)\n" "$digits" "$idx" "${application_names[$i]}" "${application_statuses[$i]}"
    done

    echo -ne "\nEnter application number or name: "
    local application_input
    read -r application_input
    if [[ -z "$application_input" ]]; then
        prompt "Application selection cannot be empty."
    fi

    if [[ "$application_input" =~ ^[0-9]+$ ]]; then
        local selected_index=$((10#$application_input - 1))
        if [[ "$selected_index" -lt 0 || "$selected_index" -ge "$application_count" ]]; then
            prompt "Invalid application selection."
        fi
        SELECTED_APPLICATION_NAME="${application_names[$selected_index]}"
    else
        SELECTED_APPLICATION_NAME=$(printf '%s' "$application_input" \
            | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
        SELECTED_APPLICATION_NAME=${SELECTED_APPLICATION_NAME// /}
    fi

    SELECTED_APPLICATION_PATH="$apps_root/$SELECTED_APPLICATION_NAME"
    if [[ ! -d "$SELECTED_APPLICATION_PATH" ]] || ! isRegisteredApplicationDir "$SELECTED_APPLICATION_PATH"; then
        prompt "Application \"$SELECTED_APPLICATION_NAME\" is not registered."
    fi
}
