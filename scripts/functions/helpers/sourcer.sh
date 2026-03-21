sourcer() {
    # ? Take in the arguments
    local functionNameCamel=$1
    local baseDir="./scripts/functions"
    local subDir=""
    local functionNameSnake=""
    local functionPath=""

    # ? Check if there's a dot indicating a subdirectory
    if [[ "$functionNameCamel" == *.* ]]; then
        subDir="${functionNameCamel%%.*}"            # * Everything before the dot
        functionNameCamel="${functionNameCamel##*.}" # * Everything after the dot
    fi

    # ? Convert CamelCase to snake_case (bash3/macOS-safe)
    functionNameSnake=$(printf '%s' "$functionNameCamel" | sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]')

    # ? Construct the full path to the script file
    if [[ -n "$subDir" ]]; then
        functionPath="$baseDir/$subDir/${functionNameSnake}.sh"
    else
        functionPath="$baseDir/${functionNameSnake}.sh"
    fi

    # ? Abort if the target script is not found
    if [[ ! -f $functionPath ]]; then
        prompt "The \"$functionNameCamel\" function could not be found."
    fi

    source $functionPath
}
