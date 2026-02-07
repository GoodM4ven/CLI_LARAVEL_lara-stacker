trustHttps() {
    local mode="${HTTPS_TRUST_MODE:-caddy}"

    case "$mode" in
        mkcert)
            sourcer "trustMkcert"
            trustMkcert
            ;;
        caddy|*)
            sourcer "trustCa"
            trustCa
            ;;
    esac
}
