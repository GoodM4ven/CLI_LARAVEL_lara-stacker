<div align="center">بسم الله الرحمن الرحيم</div>
<div align="left">


# Lara-Stacker v5

Now **Docker-only**! It runs a single containerized stack that serves **all** Laravel projects from one root directory, with automatic HTTPS and per-project wiring.

### Highlights

- One Docker stack, many projects.
- `https://<app>.localhost` for every project (no `/etc/hosts`).
- Optional services via profiles: Redis, Mailpit, MinIO, PostgreSQL.
- Xdebug is **trigger-only** (no idle cost).
- Enable/disable projects without deleting them.


## Setup

### Requirements

- [Docker Engine](https://docs.docker.com/engine/install)
- [Docker Compose](https://docs.docker.com/compose/install)
- Host tools (required for creation/refresh workflows): Composer (requires PHP), Node.js, npm
- [mkcert](https://github.com/FiloSottile/mkcert) (optional, only for `HTTPS_TRUST_MODE=mkcert`)

### Installation

1. Clone this repo, from the new main `docker` branch of course.
2. Create `.env` from `.env.example` and fill the values.
   ```bash
   cp .env.example .env
   ```
3. Run the CLI:
   ```bash
   chmod +x ./lara-stacker.sh && ./lara-stacker.sh
   ```

### Available Commands

Projects:
- `List Projects` — lists folders under `APP_ROOT` and whether they’re enabled
- `Create A Project` — new Laravel app under `APP_ROOT`, wired to Docker services
- `Import A Project` — copy an existing app into `APP_ROOT` and wire it
- `Refresh A Project` — reinstall deps, clear caches, rewire env
- `Delete A Project` — removes project files and its DB/bucket
- `Wire Project .env` — updates a project’s `.env` to match the stack
- `Enable A Project` — removes `.disabled` marker and serves it
- `Disable A Project` — adds `.disabled` marker and returns 503

Service Control:
- `List MySQL Databases` — shows all databases in the stack MySQL
- `Create MySQL Database` — creates a new database by name
- `Delete MySQL Database` — deletes a database by name (with confirmation)

Container:
- `Start Stack` — boots the Docker stack and prepares HTTPS (auto-trusts if enabled)
- `Stop Stack` — shuts down all stack services
- `Stack Status` — shows running container in the stack
- `Trust HTTPS (Caddy/mkcert)` — installs local trust for clean HTTPS
  - Requires sudo once to write to system trust store
- `Purge Stack` — removes all stack containers, images, volumes, networks, and build cache

Access:
- Visit: `https://<app>.localhost:8443` (or `https://<app>.localhost` if `CADDY_HTTPS_PORT=443`)

### Responsibilities

**What the container does for you (main services + runtime stack):**
- Runs the **main services** and exposes them on ports (Caddy + PHP-FPM, MySQL, and optional Redis/Mailpit/MinIO/PostgreSQL via profiles).
- Installs the **runtime stack** needed to serve apps **inside the container** (PHP + extensions).
- Optionally installs **media tooling** (ImageMagick/Ghostscript/FFmpeg) when `INSTALL_MEDIA_TOOLS=true`.

**What the container does NOT do for you (and you must install it yourself):**
- The **shared build tools** in order to run them locally (Composer, Node.js + npm).
- Java, Android tooling, pywatchman, etc (for NativePHP development).

In short: **Docker provides the runtime stack**, but **shared build tools must be installed on the host** for creation/refresh workflows. The CLI will stop if these tools are missing.

### Configuration

Edit `.env` (same order as the file):

Host
- `USERNAME` — system user that owns project files
- `DB_PASSWORD` — root password for MySQL/PostgreSQL container images
- `APP_ROOT` (default `/var/www/html`) — host directory where projects live
- `OPINIONATED` — copy opinionated project files (Prettier config)
- `USE_VSC` — generate Xdebug `launch.json` files
- `VSC_WORKSPACES_DIR` — auto-create `.code-workspace` files (leave empty to disable)

Container
- `DOCKER_COMPOSE_FILE` — override the compose file path
- `DOCKER_PROFILES` (default `redis,mailpit,minio`) — available: `redis`, `mailpit`, `minio`, `postgres` (MySQL always on)
- `PHP_VERSION` — changing triggers a rebuild on next `Start Stack`
- `AUTO_TRUST_HTTPS` — auto-install HTTPS trust based on `HTTPS_TRUST_MODE`
- `HTTPS_TRUST_MODE` — `caddy` (default) or `mkcert`
- `APT_MIRROR` — Debian main mirror (HTTPS)
- `APT_SECURITY_MIRROR` — Debian security mirror (HTTPS)
- `APT_PROXY` — apt proxy (e.g., `http://host.docker.internal:3142`)
- `INSTALL_MEDIA_TOOLS` — ImageMagick/Ghostscript/FFmpeg + imagick extension
- `CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT` — host ports for Caddy (use `80/443` if free)

Notes:
- When `USE_VSC=true`, the CLI also copies `files/.vscode/launch.json` into each project.
- The CLI will create `APP_ROOT` if missing and make it owned by `USERNAME`.

### Xdebug (On-Demand)

- Configured for **trigger-only** debugging.
- Use the [VSCodium](https://vscodium.com) config in `.vscode/launch.json` (auto-copied per project).
- Trigger with a [browser extension](https://chromewebstore.google.com/detail/xdebug-chrome-extension/oiofkammbajfehgpleginfomeppgnglk?hl=en&pli=1) or `XDEBUG_TRIGGER=1`.

### Notes

- Inside the container, projects are always mounted at `/var/www/html` (Caddy/PHP-FPM depend on this).
- Projects can be **disabled** via the CLI. This creates a `.disabled` file, and Caddy responds with 503 while keeping files intact.
- Vite HMR is exposed via `https://vite-<app>.localhost:8443`. Run on host: `cd <app> && npm run dev`
- Optional UIs: `https://mailpit.localhost:8443` and `https://minio.localhost:8443` (or use the host ports below)
- If `certutil` is available, the CLI also adds the CA to the NSS store for browsers that use it.
- If `HTTPS_TRUST_MODE=mkcert`, certs are generated into `./certs` and Caddy is restarted to use them.
- If you change `DOCKER_PROFILES`, the next `Start Stack` will restart the stack to apply additions/removals.

### Ports

This stack is isolated from host installs (v4-style). It only conflicts if a host service already uses these same ports:

- [Caddy](https://caddyserver.com/): `8080/8443` (use `80/443` if free to remove port from URLs)
- [MySQL](https://www.mysql.com/): `3307` (container `3306`) [Required]
- [Redis](https://redis.io/): `6380` (container `6379`)
- [Mailpit](https://mailpit.axllent.org/) SMTP/UI: `1026` / `8026`
- [MinIO](https://www.min.io/) API/Console: `9100` / `9101`
- [PostgreSQL](https://www.postgresql.org/): `5433` (container `5432`) [Optional]


## Support

Support ongoing package maintenance as well as the development of other projects through [sponsorship](https://github.com/sponsors/GoodM4ven) or one-time [donations](https://github.com/sponsors/GoodM4ven?frequency=one-time&sponsor=GoodM4ven).


## Credits

- [ChatGPT](https://chatgpt.com) and [Codex CLI](https://developers.openai.com/codex/cli/)
- [Laravel](https://laravel.com/)
- [Spatie](https://spatie.be/open-source/packages)
- [Active Contributors](https://github.com/GoodM4ven/CLI_LARAVEL_lara-stacker/graphs/contributors?from=1%2F3%2F2026)
- All the technologies used to set up this whole development environment, and eventually the apps... Perhaps the browsers too?! -Please help!


</div>
<div align="center"><br>والحمد لله رب العالمين</div>
