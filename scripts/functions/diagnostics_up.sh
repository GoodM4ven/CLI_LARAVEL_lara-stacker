diagnosticsUp() {
    local application_name="$1"
    local apps_root="${APPS_ROOT:-/var/www/html}"
    local repo_dir="${lara_stacker_dir:-$PWD}"

    if declare -F normalizePathForHost >/dev/null 2>&1; then
        apps_root=$(normalizePathForHost "$apps_root" "${USERNAME:-}")
    fi

    local application_path="$apps_root/$application_name"
    local stub_root="$repo_dir/stubs/diagnostics"

    mkdir -p \
        "$application_path/app/Http/Controllers" \
        "$application_path/app/Services" \
        "$application_path/resources/views/components" \
        "$application_path/tests/Feature"

    cp "$stub_root/app/Http/Controllers/LaraStackerDiagnosticsController.php" "$application_path/app/Http/Controllers/"
    cp "$stub_root/app/Services/LaraStackerDiagnostics.php" "$application_path/app/Services/"
    cp "$stub_root/resources/views/components/lara-stacker-diagnostics.blade.php" "$application_path/resources/views/components/"
    cp "$stub_root/tests/Feature/LaraStackerDiagnosticsTest.php" "$application_path/tests/Feature/"

    runAsHostUser php "$repo_dir/scripts/helpers/install_diagnostics.php" "$application_path" \
        || prompt "Failed to add the diagnostics section." "The generated Laravel welcome page or routes file did not match the supported skeleton." false

    echo -e "\nAdded the compact Lara-Stacker service diagnostics to Laravel's welcome page."
}
