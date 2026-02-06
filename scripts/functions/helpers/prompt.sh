prompt() {
    # ? Take in the arguments
    local first_sentence="$1"
    local second_sentence="${2:-}"
    local should_exit="${4:-true}"
    local without_warning="${5:-false}"

    # ? Display the error or warning
    error_or_warning="Error: "
    if [ "$should_exit" == "false" ]; then
        error_or_warning="Warning: "
    fi
    if [ "$without_warning" == true ]; then
        echo -e "\n$first_sentence\n"
    else
        echo -e "\n$error_or_warning $first_sentence\n"
    fi

    # ? Display a tip if available
    if [[ -n $second_sentence ]]; then
        echo -e "Tip: $second_sentence\n"
    fi

    # ? Exit the script or not
    exit_or_continue="exit"
    if [ "$should_exit" == "false" ]; then
        exit_or_continue="continue"
    fi
    echo -ne "Press any key to $exit_or_continue..."
    read -r whatever </dev/tty

    clear

    if [ "$should_exit" == "true" ]; then
        exit 1
    fi
}
