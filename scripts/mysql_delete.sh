#!/bin/bash

clear

echo -e "-=|[ Lara-Stacker |> Service Control |> MySQL |> DELETE ]|=-"

functions=(
    "./scripts/functions/helpers/prompt.sh"
    "./scripts/functions/helpers/sourcer.sh"
)
for script in "${functions[@]}"; do
    if [[ ! -f "$script" ]]; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
    chmod +x "$script" 2>/dev/null || true
    if ! source "$script"; then
        echo -e "Error: The essential script '$script' was not found. Exiting..."
        exit 1
    fi
done

if [[ -z "$RAN_MAIN_SCRIPT" ]]; then
    prompt "Aborted for direct execution flow." "Please use the main [lara-stacker.sh] script."
fi

lara_stacker_dir=$PWD
source $lara_stacker_dir/.env

sourcer "dockerHost"
sourcer "composeCmd"
sourcer "composeUp"

resolveDockerHost || true
if ! ensureDockerAccess; then
    prompt "Docker daemon is not reachable." "Start Docker and retry." false
fi

if ! docker compose version >/dev/null 2>&1; then
    prompt "Docker Compose was not found." "Install Docker Compose (v2) first and try again." false
fi

if [[ -z "$(dockerCompose ps -q mysql)" ]]; then
    if ! composeUp; then
        prompt "Failed to start the Docker stack." "Start the stack and retry." false
    fi
fi

echo -ne "\nEnter database name to delete: "
read db_input

db_name=$(echo "$db_input" | tr ' ' '_' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_')
if [[ -z "$db_name" ]]; then
    prompt "Invalid database name." "Use letters, numbers, dashes, or underscores." false
fi

echo -ne "Type the database name again to confirm: "
read db_confirm
db_confirm=$(echo "$db_confirm" | tr ' ' '_' | tr '-' '_' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_')
if [[ "$db_confirm" != "$db_name" ]]; then
    prompt "Confirmation mismatch." "Deletion cancelled." false
fi

if ! dockerCompose exec -T mysql mysql -u root -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS \`$db_name\`;"; then
    prompt "Failed to delete database." "Check MySQL container status and retry." false
fi

echo -e "\nDatabase '$db_name' deleted (if it existed)."

echo
echo -n "Press any key to continue..."
read whatever

clear
