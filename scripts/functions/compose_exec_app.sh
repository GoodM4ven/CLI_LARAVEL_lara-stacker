composeExecApp() {
    dockerCompose exec -T app "$@"
}
