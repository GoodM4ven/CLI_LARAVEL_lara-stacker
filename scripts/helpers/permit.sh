#!/usr/bin/env bash

# Standalone helper used by the dot-zsh `permit` alias:
#   sudo ~/Code/Scripts/CLI_LARAVEL_lara-stacker/scripts/helpers/permit.sh <path>
# Restores application files to the invoking user with sane permissions after
# container-side processes (queues, storage writes, etc.) leave root-owned files.

if [ $# -ne 1 ]; then
    echo "Usage: $0 <file_or_directory_path>"
    exit 1
fi

path=$1

if [ ! -e "$path" ]; then
    echo "Error: Path not found: $path"
    exit 1
fi

target_user="${SUDO_USER:-$(id -un)}"
target_group=$(id -gn "$target_user" 2>/dev/null || echo "$target_user")

chown -R "$target_user:$target_group" "$path"
chmod -R u+rwX,g+rwX,o+rX "$path"

echo "Permitted [$path] for [$target_user:$target_group]."
