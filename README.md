<div align="center">
    بسم الله الرحمن الرحيم
</div>

# Lara-Stacker v4

Now **Docker-only**! It runs a single containerized stack that serves **all** Laravel projects from one root directory, with automatic HTTPS and per-project wiring.

### Highlights

- One Docker stack, many projects.
- `https://<app>.localhost` for every project (no `/etc/hosts`).
- Optional services via profiles: MySQL, Redis, Mailpit, MinIO.
- Xdebug is **trigger-only** (no idle cost).
- Enable/disable projects without deleting them.


## Usage

### Requirements

- Docker Engine
- Docker Compose v2

### Installation

1. Clone the repo.
2. Create `.env` from `.env.example` and fill the values.
   ```bash
   cp .env.example .env
   ```
3. Run the CLI:
   ```bash
   chmod +x ./lara-stacker.sh && sudo ./lara-stacker.sh
   ```

### Commands Available

- `Start Stack` — boots the Docker stack and prepares HTTPS (auto-trusts if enabled)
- `Stop Stack` — shuts down all stack services
- `Stack Status` — shows running containers in the stack
- `List Projects` — lists folders under `APP_ROOT` and whether they’re enabled
- `Create A Project` — new Laravel app under `APP_ROOT`, wired to Docker services
- `Import A Project` — copy an existing app into `APP_ROOT` and wire it
- `Refresh A Project` — reinstall deps, clear caches, rewire env
- `Delete A Project` — removes project files and its DB/bucket
- `Wire Project .env` — updates a project’s `.env` to match the stack
- `Enable A Project` — removes `.disabled` marker and serves it
- `Disable A Project` — adds `.disabled` marker and returns 503
- `Trust HTTPS (Caddy CA)` — installs the local CA for clean HTTPS
- `Exit` — closes the CLI

### Configuration

Edit `.env`:

- `APP_ROOT` (default `/var/www/html`): where projects live
- `APP_DOMAIN_SUFFIX` (default `localhost`)
- `DOCKER_PROFILES` (default `redis,mailpit,minio`)
- `PHP_VERSION` and `NODE_VERSION`
- `AUTO_TRUST_HTTPS=true` to install Caddy’s local CA automatically
- `USE_VSC=true` to generate Xdebug `launch.json` files
- `VSC_WORKSPACES_DIR` to auto-create `.code-workspace` files (leave empty to disable)
- `OPINIONATED=true` to copy `files/.opinionated/.prettierrc` into projects
- When `USE_VSC=true`, the CLI also copies `files/.vscode/launch.json` into each project

The CLI will create `APP_ROOT` if missing and make it owned by `USERNAME`.

### Xdebug (On-Demand)

- Configured for **trigger-only** debugging.
- Use the VS Code config in `.vscode/launch.json` (auto-copied per project).
- Trigger with a browser extension or `XDEBUG_TRIGGER=1`.

### Notes

- Projects can be **disabled** via the CLI. This creates a `.disabled` file, and Caddy responds with 503 while keeping files intact.
- Vite HMR is exposed via `https://vite-<app>.localhost`. Run: `docker compose -f ./compose.yaml --project-name lara-stacker exec app bash -lc "cd /var/www/html/<app> && npm run dev"`
- Optional UIs: Mailpit at `http://mailpit.localhost`, MinIO Console at `http://minio.localhost`
- If `certutil` is available, the CLI also adds the CA to the NSS store for browsers that use it.
