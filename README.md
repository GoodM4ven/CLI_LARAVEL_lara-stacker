<div align="center">بسم الله الرحمن الرحيم</div>
<div align="left">


# LARA-STACKER v6

Now **macOS-first, Docker-backed, and [mise](https://mise.jdx.dev)-managed**! A single containerized stack provides runtime and services (PHP-FPM, MySQL, Redis, MinIO, Mailpit) exposed to the host, while the CLI manages apps, services, and HTTPS certs. The host toolchain (PHP, Composer, Node) is no longer a pile of Homebrew/apt/NVM installs — it's all resolved through **mise**.

### Highlights

- One Docker container, many applications.
- `https://<app>.dev.localhost` for every application (no more `/etc/hosts`).
- **mise-managed host tools** — one runtime manager for PHP, Composer, Node, and npm; each app gets a `mise.toml` pinned to the container's PHP version.
- **Zed-first Xdebug** — generates `.zed/debug.json` per app (VS Code/VSCodium still supported via `DEV_EDITOR=vsc`).
- [OrbStack](https://orbstack.dev)-friendly on macOS (auto-detected socket; lighter and faster than Docker Desktop).
- Xdebug is **trigger-only** (no idling slow cost).
- Enable/disable applications without deleting them.

> [!TIP]
> This stack is built around [my macOS setup](https://github.com/GoodM4ven/CLI_MACOS_dot-zsh) — **dot-zsh** — which carries the mise config, the `lara` launcher alias, the `permit` helper alias, the Zed configuration, and the Brewfile that installs most prerequisites below. If you adopt that repo, most of this page's setup is already done.

### Laravel Sail vs Lara-Stacker

- **Sail is per-application**: each app ships its own `compose.yaml` and containers. That means duplicated services and **rebuild time per application**.
- **Shared container here**: one runtime container group serves **all apps**, so no duplicate services per application.
- **Sail CLI depends on containers**: if an application's container fails, Sail commands for that application are blocked, since the devEnvironment is inaccessible.
- **mise-managed host tools here**: Composer, PHP, and NPM run on the host through mise. The container only provides runtime and services.
- Net: **faster iteration, fewer moving parts**, and no per-application Docker overhead.

https://github.com/user-attachments/assets/137f6d92-e1d6-4047-b73b-f5ce1da5e69f


## Setup

### Prerequisites

- <details>
  <summary>Docker (<a href="https://orbstack.dev">OrbStack</a> recommended on macOS)</summary>

  - macOS — **OrbStack** (recommended; fast VM, native `docker` CLI, auto-detected by the CLI):
    ```bash
    brew install --cask orbstack
    open -a OrbStack
    ```

  - macOS — Docker Desktop (alternative):
    ```bash
    brew install --cask docker
    sleep 3
    open -a Docker
    ```

  - Linux — prefer the **native Docker Engine** (no VM, no virtiofs staleness; see [Troubleshooting](#stale-code-on-docker-desktop-linux-editscomposer-changes-dont-apply-until-a-container-restart)):
    ```bash
    # Debian/Ubuntu example — see https://docs.docker.com/engine/install for your distro
    curl -fsSL https://get.docker.com | sh
    sudo systemctl enable --now docker.service docker.socket
    sudo usermod -aG docker "$USER" # then log out/in, or: newgrp docker
    ```
  </details>

- <details>
  <summary>Host toolchain via <a href="https://mise.jdx.dev">mise</a> (PHP + Composer + Node + npm)</summary>

  Install mise with the standalone installer (**not** Homebrew — the CLI and [dot-zsh](https://github.com/GoodM4ven/CLI_MACOS_dot-zsh) expect `~/.local/bin/mise`):
  ```bash
  curl https://mise.run | sh
  echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
  ```

  Then configure `~/.config/mise/config.toml` with the [verzly/mise-php](https://github.com/verzly/mise-php) plugin (bundles a per-version Composer) and prebuilt static PHP binaries (fast installs, huge extension set — bcmath, gd, imagick, intl, redis, pdo_mysql, swoole, zip, and more):
  ```toml
  [plugins]
  php = "https://github.com/verzly/mise-php#latest"

  [tools]
  node = "22"
  php = "8.4"
  pnpm = "11"

  [env._.php]
  prebuilt_static = true
  prebuilt_static_flavor = "bulk"
  ```

  And install everything:
  ```bash
  mise install
  ```

  This works the same on **macOS and Linux** — no more brew/apt/pacman PHP extension surgery, and no NVM.
  </details>

- <details>
  <summary>Certification Tools</summary>

  - macOS
    ```bash
    brew install mkcert nss
    mkcert -install
    ```

  - Linux (Debian-based / Arch-based)
    ```bash
    # Debian/Ubuntu
    sudo apt update && sudo apt install -y ca-certificates libnss3-tools mkcert
    mkcert -install

    # Arch/EndeavourOS
    sudo pacman -Syu --needed ca-certificates mkcert nss
    mkcert -install
    ```
  </details>

- <details>
  <summary>Editor (Zed by default)</summary>

  - [Zed](https://zed.dev) with its **PHP extension** (which ships the Xdebug debug adapter):
    ```bash
    brew install --cask zed
    ```
    Then install the `PHP` extension from Zed's extension panel (`cmd-shift-x`).

  - Or VS Code/[VSCodium](https://vscodium.com) with the [`xdebug.php-debug` extension](https://marketplace.visualstudio.com/items?itemName=xdebug.php-debug), setting `DEV_EDITOR=vsc` in [.env](./.env.example).
  </details>

- <details>
  <summary>Android Tools (for NativePHP Android apps)</summary>

  - macOS
    ```bash
    brew install openjdk@17
    echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
    echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.zshrc
    brew install --cask android-studio
    ```

  - Linux (Debian-based / Arch-based)
    ```bash
    # Debian/Ubuntu
    sudo apt update && sudo apt install openjdk-17-jdk
    sudo snap install android-studio --classic

    # Arch/EndeavourOS
    sudo pacman -Syu --needed jdk17-openjdk android-studio
    ```
  </details>

- <details>
  <summary>iOS Tools (for NativePHP iOS apps, macOS only)</summary>

  - macOS
    ```bash
    open "macappstores://itunes.apple.com/app/id497799835"
    xcode-select --install || true
    sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
    sudo xcodebuild -runFirstLaunch
    sudo xcodebuild -license accept
    ```
  </details>

### Installation

1. Clone this repo, from the new main `docker_and_mise` branch, and navigate to it.
2. Create `.env` from `.env.example` and fill the values.
   ```bash
   cp .env.example .env
   ```
   - On macOS, keep the defaults:
     - `HOST_HOME_PATH=/Users/$USERNAME`
     - `APPS_ROOT=/Users/$USERNAME/Code/Laravel`
   - On Linux, switch them to `/home/$USERNAME` equivalents.
3. Run the CLI:
   ```bash
   chmod +x ./lara-stacker.sh && ./lara-stacker.sh
   ```
   (With [dot-zsh](https://github.com/GoodM4ven/CLI_MACOS_dot-zsh), that's just `lara`.)


## Usage

### Available Commands

Applications:
- `List` — lists folders under `APPS_ROOT` and whether they're enabled
- `Create` — new Laravel app under `APPS_ROOT`, wired to Docker services
- `Import` — copy an existing app into `APPS_ROOT` and wire it
- `Refresh` — reinstall deps, clear caches, rewire env (full consistency pass)
- `Rewire` — updates an application's `.env`, Vite config, `mise.toml`, and editor debug files
- `Delete` — removes application files and its database, bucket, etc.
- `Enable` — removes `.disabled` marker and serves the app
- `Disable` — adds `.disabled` marker and returns 503 blocked response

</div>

> [!TIP]
> The **rewire** command updates config only (writes host-exposed service addresses and ports). Whereas the **refresh** command does a full dependency reinstall on the host, clears caches, and then *rewires* too.
>
> If you manually copy or `git clone` a project folder into `APPS_ROOT` (instead of using `Create`/`Import`), run **Rewire** for that app (or **Refresh**) so lara-stacker recognizes it and syncs runtime wiring for `/var/www/html/<app>`.

<div align="left">

Services:
- `MySQL > Browse` — shows all databases in the container MySQL service
- `MySQL > Create` — creates a new database by name
- `MySQL > Delete` — deletes a database by name (with confirmation)
- `MinIO > Browse` — lists MinIO buckets
- `MinIO > Create` — creates a MinIO bucket
- `MinIO > Delete` — deletes a MinIO bucket
- `Redis > Browse` — lists Redis keys
- `Redis > Delete` — deletes Redis keys by pattern

Container:
- `Start` — boots the Docker container and prepares HTTPS certification
- `Check` — shows running containers in the container group (the stack)
- `Stop` — shuts down all container services
- `Certify` — installs local HTTPS certs/trust (via mkcert)
  - Requires `sudo` access once, in order to write to the system trust store
  - Requires restarting the browser, in order to pick up the new trust
- `Purge` — removes the container and all of its resources (containers, images, volumes, networks, build cache; everything!)

### Configuration

Edit `.env` (same order as the file):

- Host
  - `USERNAME` — system user that owns application files
  - `DB_PASSWORD` — root password for the MySQL container image
  - `HOST_HOME_PATH` — host home path mounted into the app container (read-only) to support Composer path-repository symlinks that resolve outside `APPS_ROOT` (for example local packages under `~/Code/LaravelPackages`).
    - macOS typical value: `/Users/<user>`
    - Linux typical value: `/home/<user>`
  - `APPS_ROOT` (default `/var/www/html`) — host directory where applications live and coded from, locally!
    - macOS typical value: `/Users/<user>/Code/Laravel`
    - Linux typical value: `/home/<user>/Code/Laravel`
    - The CLI will create `APPS_ROOT` if missing and make it owned by `USERNAME`.
  - `OPINIONATED` — copy opinionated application files (Prettier config)
  - `DEV_EDITOR` — which editor's [Xdebug](https://xdebug.org) integration `Create`, `Import`, `Refresh`, and `Rewire` generate per app:
    - `zed` (default) — writes `.zed/debug.json` for [Zed](https://zed.dev)'s debugger.
    - `vsc` — writes `.vscode/launch.json` for VS Code/[VSCodium](https://vscodium.com).
    - `none` — skips editor files entirely.
    - Xdebug runs in "trigger-only" mode (`xdebug.start_with_request=trigger`) either way.
    - Use the [browser extension](https://chromewebstore.google.com/detail/xdebug-chrome-extension/oiofkammbajfehgpleginfomeppgnglk?hl=en&pli=1) and keep it on **only when needed**.
  - `VSC_WORKSPACES_DIR` — VSC-only: auto-create `.code-workspace` files there (leave empty to disable; `null` is also treated as disabled; ignored for Zed, which opens app folders directly)

- Container
  - `DOCKER_COMPOSE_FILE` — override the compose file path
  - `RESTART_UNLESS_STOPPED` — whether to start the container automatically along Docker.
  - `PHP_VERSION` — changing this triggers a rebuild on next `Start Container`. **Keep it in sync with your host mise PHP** — it's also what gets pinned into each app's `mise.toml`.
  - `APT_MIRROR` — Debian main mirror (HTTPS)
  - `APT_SECURITY_MIRROR` — Debian security mirror (HTTPS)
  - `CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT` — host ports for Caddy (**it's recommended to use `80/443` if free**)
  - `MYSQL_PORT` — host port for MySQL (container `3306`)
  - `REDIS_PORT` — host port for Redis (container `6379`)
  - `MAILPIT_SMTP_PORT` / `MAILPIT_UI_PORT` — host ports for Mailpit SMTP/UI (container `1025/8025`)
  - `MINIO_PORT` / `MINIO_CONSOLE_PORT` — host ports for MinIO API/Console (container `9000/9001`)

- The **rewire** command writes these host port values into each application's `.env` (with `DB_HOST=127.0.0.1`, `REDIS_HOST=127.0.0.1`, etc.).
- After changing any host port variables, restart the container and run the **rewire** command to refresh each app's `.env`.

</div>

> [!TIP]
> `APT_MIRROR` and `APT_SECURITY_MIRROR` are used inside the Debian app container image build (`apt-get` in Docker), not on the macOS host.

<div align="left">

### mise Wiring

- The CLI resolves `php`, `composer`, `node`, and `npm` through `mise which` first (falling back to `PATH`), so whatever versions your `~/.config/mise/config.toml` — or a directory-level `mise.toml` — declares are what run. No NVM, no Homebrew PHP.
- `Create`, `Import`, `Refresh`, and `Rewire` seed a `mise.toml` into each app (if one doesn't exist) pinning `php = "<PHP_VERSION>"`, so `php artisan ...` inside the app directory uses the **same PHP version the container runs**. Existing pins are never overwritten.
- The [verzly/mise-php](https://github.com/verzly/mise-php) plugin bundles Composer per PHP version, so there's no separate Composer install.
- With `prebuilt_static = true`, the static "bulk" build ships nearly every extension a Laravel app declares (`ext-*` checks run automatically before Composer installs). Two gaps worth knowing:
  - **No `xdebug` on the host CLI** — static builds have a fixed extension set (PIE/PECL requests are skipped). Web debugging is unaffected (the *container* has Xdebug); if you need host-side CLI step-debugging, switch mise to source builds: `prebuilt_static = false` + `_.php = { pie_extensions = "xdebug/xdebug" }`.
  - **No `pdo_sqlite`** — irrelevant here since apps get wired to the container's MySQL, but Laravel's default sqlite quick-starts won't run on the host CLI.
- Host CLI `memory_limit` is `128M` on the static build. If a large migration/seed fails with `Allowed memory size exhausted`, run it once with `php -d memory_limit=512M artisan ...`.

### Ports

This container is isolated from host installs (v4-style). Conflicts only happen if a host service already uses these same ports:

- [Caddy](https://caddyserver.com/): `CADDY_HTTP_PORT/CADDY_HTTPS_PORT` (default `8080/8443`, container `80/443`)
- [MySQL](https://www.mysql.com/): `MYSQL_PORT` (default `3307`, container `3306`)
- [Redis](https://redis.io/): `REDIS_PORT` (default `6380`, container `6379`)
- [Mailpit](https://mailpit.axllent.org/) SMTP/UI: `MAILPIT_SMTP_PORT/MAILPIT_UI_PORT` (default `1026/8026`, container `1025/8025`)
- [MinIO](https://www.min.io/) API/Console: `MINIO_PORT/MINIO_CONSOLE_PORT` (default `9100/9101`, container `9000/9001`)

Service UIs include:

- `https://minio.dev.localhost:8443`
- `https://mailpit.dev.localhost:8443`

</div>

> [!NOTE]
> It's extremely recommended to use `80/443` ports with Caddy. I only made them different by default in order not to conflict with lara-stacker v4. Check the [.env](./.env.example) file.

<div align="left">

### Xdebug Flow

- The app container has Xdebug installed and configured via `configurations/xdebug.ini`:
  - `xdebug.client_host=host.docker.internal`
  - `xdebug.client_port=9003`
  - `xdebug.start_with_request=trigger`
- Container path mappings are generated as `/var/www/html/<app> -> <local app folder>` so imported/created apps map correctly during debug sessions.
- **Zed** (`DEV_EDITOR=zed`): each app gets a `.zed/debug.json` with a "Listen for Xdebug" configuration. Install Zed's `PHP` extension once, open the app folder, open the debug panel, and start "Listen for Xdebug". Then turn on the Xdebug browser trigger and hit the app URL.
- **VS Code/VSCodium** (`DEV_EDITOR=vsc`): same flow via the generated `.vscode/launch.json` and the `xdebug.php-debug` extension.
- If you switch `DEV_EDITOR` (or enable it) after apps already exist, run **Rewire** (or **Refresh**) once per app to generate/update debug files.


## Responsibilities

- The container does install and expose the main services (Caddy, MySQL, Redis, MinIO, etc.) ports for you, does runtime stuff in place (PHP, PHP Extensions, PHP-FPM, etc.) too, and finally includes whatever extra packages the local server may need, such as the media's (ImageMagick, Ghostscript, FFmpeg, etc.).
- Application `.env` files are **host-wired** (`127.0.0.1` + host ports) because all dev tooling (Composer/PHP/Artisan/NPM) runs on the host — through mise.
- The app container is injected with internal service hosts so runtime still connects to MySQL/Redis/MinIO when serving requests.
- The app container also mounts `HOST_HOME_PATH` read-only to keep local Composer path-repository symlinks resolvable at runtime (preventing missing vendor class/provider errors when a dependency points outside `APPS_ROOT`).
- **The container does NOT contain the [development tools](#prerequisites) themselves that need to exist locally.** This includes mise's toolchain as well as Java/Android tooling and Xcode/iOS tooling, etc.

TLDR: **Docker provides the runtime container group**, and **mise provides the host toolchain** — but there are still [prerequisites](#prerequisites) (Docker itself, mise, mkcert...) that must be installed on the host. The CLI will DISFUNCTION if those tools are missing.

- Inside the container, applications are always mounted at `/var/www/html` (Caddy/PHP-FPM depend on this).
- Applications can be **disabled** via the CLI. This creates a `.disabled` file, and Caddy responds with **503** while keeping files intact.
- **You can access an application using: `https://<app>.dev.localhost:8443` (or `https://<app>.dev.localhost` if `CADDY_HTTPS_PORT=443`)**
- Vite HMR is exposed via `https://vite-<app>.dev.localhost:8443`. Run on host: `cd <app> && npm run dev`
- mkcert installs the "trust" into the system store, so make sure it's installed back in [prerequisites](#prerequisites) section, of course.
- Certs are generated into `./.certs` (which isn't version controlled) and Caddy is restarted to use them from there. **DO NOT REMOVE THEM.**
- There is a small `synchronizer` sidecar that continuously corrects a few host/container drift issues. It removes stale `public/hot` files when Vite is no longer reachable, and it also reloads PHP-FPM when a Composer autoload desync starts surfacing as a `vendor/composer/autoload_static.php` parse error through Caddy.

</div>

> [!IMPORTANT]
> This stack uses PHP-FPM (with OPcache), which is fast but **can sometimes make changes appear "stuck" due to caching** configs, routes, views, or bytecode. If something behaves oddly after a change, try `php artisan optimize:clear` first.
> **But if that does NOT help** — especially on **Docker Desktop for Linux**, where edits and Composer changes only apply after a container restart — it's a filesystem-layer (virtiofs) problem, not OPcache. See [Troubleshooting → Stale code on Docker Desktop](#stale-code-on-docker-desktop-linux-editscomposer-changes-dont-apply-until-a-container-restart).

<div align="left">


## Troubleshooting

### Stale code on Docker Desktop (Linux): edits/Composer changes "don't apply" until a container restart

If you are on **Docker Desktop for Linux** and you hit any of these:

- An exception points to **a line of code that no longer exists**, or a route/method you already deleted is still being called.
- `php artisan optimize:clear` does **not** help.
- Right after `composer install`/`composer update`, requests throw a `vendor/composer/autoload_static.php` parse/autoload error **before Laravel even boots**.
- The **only** thing that reliably fixes it is restarting the app container.

...then this is **not** an OPcache problem and no OPcache/Artisan setting will fix it.

**Root cause.** Docker Desktop runs the whole engine inside a **VM** and shares your host code into containers over **virtiofs**. virtiofs serves **stale file _content_** to long-running containers (e.g. PHP-FPM) after in-place edits — the bytes the container reads are already old, so:

| Symptom | Why |
|---|---|
| Exception on a line that doesn't exist | FPM read **stale file content** from virtiofs |
| `optimize:clear` does nothing | It clears Laravel caches; this is a **filesystem-layer** problem, one level below Laravel |
| Composer autoload errors before Laravel boots | virtiofs serves a stale/half-written `vendor/composer/autoload_*.php` |
| Only a **container restart** fixes it | Restart = new mount namespace → virtiofs re-resolves the files |

OPcache's `validate_timestamps` is already `On` in `configurations/opcache.ini` (it revalidates on every request) and is **irrelevant** here — it can only act on the content virtiofs hands it.

To confirm it on your machine (host shows new code, container shows old):

```bash
# active context — "desktop-linux" means Docker Desktop (VM + virtiofs)
docker context show

# host vs container view of the SAME file — counts will differ when content is stale
grep -c someDeletedSymbol ~/path/to/app/.../File.php
docker exec lara-stacker-app-1 grep -c someDeletedSymbol /var/www/html/<app>/.../File.php
```

**Stop-gap:** `docker restart lara-stacker-app-1` forces a fresh re-read.

**Permanent fix (recommended on Linux): use the native Docker Engine instead of Docker Desktop.** Native Docker bind-mounts the host filesystem **directly** — no VM, no virtiofs, no stale content, no restarts, and the `synchronizer` sidecar's autoload workaround becomes unnecessary. Note the native daemon is **separate** from Desktop, so its images/volumes/networks start empty (you'll re-seed MySQL/MinIO, and the `lara-stacker_default` external network is recreated by the CLI on the next up):

```bash
# 1. tear the Desktop stack down first (use your normal lara-stacker down, or compose down)

# 2. enable the native daemon and your group access
sudo systemctl enable --now docker.service docker.socket
sudo usermod -aG docker "$USER"      # then log out/in, or: newgrp docker

# 3. point Docker at the native engine
docker context use default

# 4. bring the stack back up via the CLI (recreates the network, rebuilds, and ups)
./lara-stacker.sh
```

On macOS a VM is unavoidable; **OrbStack** is the recommended engine — its file sharing has proven far less prone to stale-content issues than Docker Desktop's, and the CLI auto-detects its socket. If you must use Docker Desktop on macOS, prefer its **VirtioFS** file sharing and just restart the app container when content goes stale.


## Support

Support ongoing package maintenance as well as the development of other projects through [sponsorship](https://github.com/sponsors/GoodM4ven) or one-time [donations](https://github.com/sponsors/GoodM4ven?frequency=one-time&sponsor=GoodM4ven).


## Credits

- [ChatGPT](https://chatgpt.com), [Codex CLI](https://developers.openai.com/codex/cli/), and [Claude Code](https://claude.com/claude-code)
- [Laravel](https://laravel.com/)
- [Spatie](https://spatie.be/open-source/packages)
- [mise](https://mise.jdx.dev) and [verzly/mise-php](https://github.com/verzly/mise-php)
- [OrbStack](https://orbstack.dev) and [Zed](https://zed.dev)
- [Active Contributors](https://github.com/GoodM4ven/CLI_LARAVEL_lara-stacker/graphs/contributors?from=1%2F3%2F2026)
- All the technologies used to set up this whole development environment, and eventually the apps... Perhaps the browsers too?! -Please help!


</div>
<div align="center"><br>والحمد لله رب العالمين</div>
