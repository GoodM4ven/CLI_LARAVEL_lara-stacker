<div align="center">بسم الله الرحمن الرحيم</div>
<div align="left">


# Lara-Stacker v4

Now **Docker-only**! It runs a single containerized stack that serves **all** Laravel projects from one root directory, with automatic HTTPS and per-project wiring.

### Highlights

- One Docker stack, many projects.
- `https://<app>.localhost` for every project (no `/etc/hosts`).
- Optional services via profiles: MySQL, Redis, Mailpit, MinIO.
- Xdebug is **trigger-only** (no idle cost).
- Enable/disable projects without deleting them.


## Setup

### Requirements

- [Docker Engine](https://docs.docker.com/engine/install)
- [Docker Compose](https://docs.docker.com/compose/install)

### Installation

1. Clone this repo, from the new main `docker` branch of course.
2. Create `.env` from `.env.example` and fill the values.
   ```bash
   cp .env.example .env
   ```
3. Run the CLI:
   ```bash
   chmod +x ./lara-stacker.sh && sudo ./lara-stacker.sh
   ```

### Available Commands

Container:
- `Start Stack` — boots the Docker stack and prepares HTTPS (auto-trusts if enabled)
- `Stop Stack` — shuts down all stack services
- `Stack Status` — shows running containers in the stack

Projects:
- `List Projects` — lists folders under `APP_ROOT` and whether they’re enabled
- `Create A Project` — new Laravel app under `APP_ROOT`, wired to Docker services
- `Import A Project` — copy an existing app into `APP_ROOT` and wire it
- `Refresh A Project` — reinstall deps, clear caches, rewire env
- `Delete A Project` — removes project files and its DB/bucket
- `Wire Project .env` — updates a project’s `.env` to match the stack
- `Enable A Project` — removes `.disabled` marker and serves it
- `Disable A Project` — adds `.disabled` marker and returns 503

Extra:
- `Trust HTTPS (Caddy CA)` — installs the local CA for clean HTTPS

Access:
- Visit: `https://<app>.localhost:8443` (or the `CADDY_HTTPS_PORT` value)

### Configuration

Edit `.env`:

- `APP_ROOT` (default `/var/www/html`): where projects live
- `APP_DOMAIN_SUFFIX` (default `localhost`)
- `DOCKER_PROFILES` (default `redis,mailpit,minio`)
- `CADDY_HTTP_PORT` and `CADDY_HTTPS_PORT` (default `8080/8443`)
- `PHP_VERSION` and `NODE_VERSION`
- `AUTO_TRUST_HTTPS=true` to install Caddy’s local CA automatically
- `USE_VSC=true` to generate Xdebug `launch.json` files
- `VSC_WORKSPACES_DIR` to auto-create `.code-workspace` files (leave empty to disable)
- `OPINIONATED=true` to copy `files/.opinionated/.prettierrc` into projects
- When `USE_VSC=true`, the CLI also copies `files/.vscode/launch.json` into each project

The CLI will create `APP_ROOT` if missing and make it owned by `USERNAME`.

### Xdebug (On-Demand)

- Configured for **trigger-only** debugging.
- Use the [VSCodium](https://vscodium.com) config in `.vscode/launch.json` (auto-copied per project).
- Trigger with a [browser extension](https://chromewebstore.google.com/detail/xdebug-chrome-extension/oiofkammbajfehgpleginfomeppgnglk?hl=en&pli=1) or `XDEBUG_TRIGGER=1`.

### Notes

- Projects can be **disabled** via the CLI. This creates a `.disabled` file, and Caddy responds with 503 while keeping files intact.
- Vite HMR is exposed via `https://vite-<app>.localhost:8443`. Run: `docker compose -f ./compose.yaml --project-name lara-stacker exec app bash -lc "cd /var/www/html/<app> && npm run dev"`
- Optional UIs: `https://mailpit.localhost:8443` and `https://minio.localhost:8443` (or use the host ports below)
- If `certutil` is available, the CLI also adds the CA to the NSS store for browsers that use it.

### Ports

This stack is isolated from host installs (v3-style). It only conflicts if a host service already uses these same ports:

- [Caddy](https://caddyserver.com/): `8080/8443`
- [MySQL](https://www.mysql.com/): `3307` (container `3306`)
- [Redis](https://redis.io/): `6380` (container `6379`)
- [Mailpit](https://mailpit.axllent.org/) SMTP/UI: `1026` / `8026`
- [MinIO](https://www.min.io/) API/Console: `9100` / `9101`


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
