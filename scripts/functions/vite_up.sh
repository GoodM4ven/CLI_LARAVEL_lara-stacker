viteUp() {
    # ? Take in the arguments
    local project_name="$1"
    local escaped_project_name="$2"

    local projects_directory="/var/www/html"
    local vite_config_file="vite.config.js"

    if ! [ -d "$projects_directory/$escaped_project_name" ]; then
        return 1
    fi

    cd "$projects_directory/$escaped_project_name"

    PROJECT_NAME="$project_name"
    FILE="$vite_config_file"

    if ! grep -q "const host =" "$FILE"; then
        if ! grep -q '^import path from "path";' "$FILE"; then
            sed -i '1i import path from "path";' "$FILE"
        fi

        # ? Insert const variables right AFTER the last import statement
        awk -v project="$PROJECT_NAME" '
        {
            lines[NR] = $0
        }
        END {
            max = NR
            lastImport = 0
            # Find the index of the LAST import line:
            for (i = 1; i <= max; i++) {
                if (match(lines[i], /^import /)) {
                    lastImport = i
                }
            }

            # If no imports found, we’ll just print everything then add our const lines.
            if (lastImport == 0) {
                for (i = 1; i <= max; i++) {
                    print lines[i]
                }
                print ""
                print "const host = \"" project ".test\";"
                print "const certPath = path.resolve(__dirname, \"./.certs/" project ".test.pem\");"
                print "const keyPath = path.resolve(__dirname, \"./.certs/" project ".test-key.pem\");"
            } else {
                # Print lines up to (and including) lastImport
                for (i = 1; i <= max; i++) {
                    print lines[i]
                    # Right after printing that line, insert our const lines:
                    if (i == lastImport) {
                        print ""
                        print "const host = \"" project ".test\";"
                        print "const certPath = path.resolve(__dirname, \"./.certs/" project ".test.pem\");"
                        print "const keyPath = path.resolve(__dirname, \"./.certs/" project ".test-key.pem\");"
                    }
                }
            }
        }
        ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

        # ? Insert the server block (or remove if found)
        if grep -q 'server:' "$FILE"; then
            awk '
                BEGIN { serverBlock=0; braceCount=0 }
                /server:\s*\{/ {
                    serverBlock=1
                    braceCount=1
                    next
                }
                {
                    if (serverBlock == 0) {
                        print $0
                    } else {
                        # We are inside `server: { ... }`
                        if (index($0, "{") > 0) braceCount++
                        if (index($0, "}") > 0) braceCount--
                        if (braceCount == 0) serverBlock=0
                    }
                }
            ' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
        fi

        # ? Add your new server block right after inside the export
        sed -i '/export default defineConfig({/a \
    server: {\n\
        host,\n\
        hmr: { host },\n\
        cors: { origin: `*` },\n\
        https: {\n\
            cert: certPath,\n\
            key: keyPath,\n\
        },\n\
        watch: {\n\
            ignored: ['"'"'**/storage/framework/views/**'"'"'],\n\
        },\n\
    },' "$FILE"

        # ? Remove leftover empty lines 
        sed -i '/export default defineConfig({/,$ { /^[[:space:]]*$/d }' "$FILE"

        sudo "$lara_stacker_dir/scripts/helpers/permit.sh" "./$vite_config_file"

        echo -e "\nLinked the site URL in the project's Vite configuration file." >&3
    fi
}
