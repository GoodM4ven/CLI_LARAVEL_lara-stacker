mysqlDown() {
    local db_or_application_name="$1"

    db_or_application_name=$(echo "$db_or_application_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    db_or_application_name=${db_or_application_name// /}

    local db_name
    db_name=$(echo "$db_or_application_name" | sed 's/\([[:lower:]]\)\([[:upper:]]\)/\1_\2/g' | sed 's/\([[:upper:]]\)\([[:upper:]][[:lower:]]\)/\1_\2/g' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/^_//')

    if [[ -z "$(dockerCompose ps -q mysql)" ]]; then
        echo -e "\nError: MySQL container is not running; cannot delete database."
        return 1
    fi

    if ! dockerCompose exec -T mysql mysql -u root -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS $db_name;"; then
        echo -e "\nError: Failed to delete MySQL database '$db_name'."
        return 1
    fi

    echo -e "\nDeleted '$db_name' MySQL database (if existed)."
    return 0
}
