mysqlDown() {
    local db_or_project_name="$1"

    db_or_project_name=$(echo "$db_or_project_name" | tr ' ' '-' | tr '_' '-' | tr '[:upper:]' '[:lower:]')
    db_or_project_name=${db_or_project_name// /}

    local db_name
    db_name=$(echo "$db_or_project_name" | sed 's/\([[:lower:]]\)\([[:upper:]]\)/\1_\2/g' | sed 's/\([[:upper:]]\)\([[:upper:]][[:lower:]]\)/\1_\2/g' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | sed 's/__/_/g' | sed 's/^_//')

    if [[ -z "$(dockerCompose ps -q mysql)" ]]; then
        echo -e "\nMySQL container is not running; skipped database deletion." >&3
        return 0
    fi

    dockerCompose exec -T mysql mysql -u root -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS $db_name;"

    echo -e "\nDeleted '$db_name' MySQL database (if existed)." >&3
}
