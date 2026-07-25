<div align="center">بسم الله الرحمن الرحيم</div>
<div align="left">

# LARA-STACKER v6

Lara-Stacker is a **macOS-only, OrbStack-backed** Laravel development environment. One shared PHP-FPM/Caddy stack serves every registered application, while this repository's mise configuration owns the matching host PHP, Composer, Node/npm, and pnpm toolchain.

It is inspired by the author's personal [macOS dot-zsh setup](https://github.com/GoodM4ven/CLI_MACOS_dot-zsh), but that repository, its Brewfile, and its shell configuration are not prerequisites. Lara-Stacker's setup command installs and configures everything it needs.

### Highlights

- One PHP-FPM, Caddy, MySQL, Redis, MinIO, Mailpit, and Reverb-capable stack for many Laravel applications.
- Clean `https://<app>.dev.localhost` URLs through OrbStack.
- A repository-level mise toolchain—generated Laravel projects do not need their own `mise.toml`.
- Creation through Laravel's official `laravel new` flow, always with SQLite, Boost, and Pest.
- Reverb, Laravel Echo, and the MinIO S3 filesystem adapter installed in every new project.
- Laravel's original welcome page extended with compact live diagnostics for MySQL, Redis, Mailpit, and MinIO.
- Trigger-only Xdebug with a manually started Zed listener and Chromium browser triggers—no rebuild or restart.
- Optional Tailscale Funnel service for temporary public application and Reverb testing.
- A synchronizer sidecar that reloads PHP-FPM after Composer changes settle.

### [Laravel Sail](https://laravel.com/docs/sail) vs Lara-Stacker

- Sail owns a container stack **per** application.
- Lara-Stacker shares its services across **every** registered application.
- Host tooling runs through this repository's mise environment; web requests run through the PHP-FPM container.


## Installation

The only starting requirement is macOS and an internet connection:

```bash
mkdir -p ~/Code/Scripts
cd ~/Code/Scripts
git clone https://github.com/GoodM4ven/CLI_MACOS_lara-stacker.git
cd CLI_MACOS_lara-stacker
cp .env.example .env
```

Fill the environment variables in `.env`, then run:

```bash
./scripts/setup.sh
./lara-stacker.sh
```

`setup.sh` installs Homebrew when absent, OrbStack, mise, the native PHP build dependencies, mobile development requirements, mkcert, and Zed when enabled. It installs this repository's mise tools, trusts the local HTTPS authority, and runs `composer global require laravel/installer`.

For NativePHP iOS development, after installing or updating Xcode, make its full developer toolchain active so `xcrun` can find Simulator utilities:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

It also makes the global Laravel installer available to ordinary shells by adding `$HOME/.composer/vendor/bin` to `PATH` when no existing shell file already does so. Open a new terminal after first-time setup.

And, again, when `DEV_EDITOR=zed`, install Zed's PHP extension once from the Extensions panel (`cmd-shift-x`). The extension supplies the `Xdebug` adapter. Choose your own Zed shortcut for `debugger: start`; Lara-Stacker does not modify your keymap.


## Usage

### Applications

- `List` — list registered applications and enabled state.
- `Create` — create and fully wire a Laravel application.
- `Import` — copy/register and wire an existing application without changing its package choices.
- `Refresh` — reinstall Composer and JavaScript dependencies, clear caches, and rewire.
- `Rewire` — refresh environment, Vite, Zed, and service wiring.
- `Delete` — delete application files and associated database/bucket data.
- `Enable` / `Disable` — control whether Caddy serves the application.

Every newly created application uses the installed Laravel CLI:

```bash
laravel new <name> --database=sqlite --pest --boost --no-node --no-interaction
```

This intentionally delegates Boost and Pest setup to Laravel's current official installer, including Pest initialization/drift and Boost's Composer update hook. Lara-Stacker then:

- preserves `database/database.sqlite`, even though the application is rewired to MySQL;
- installs Reverb through `php artisan install:broadcasting --reverb`;
- installs Laravel Echo and its Pusher client;
- installs `league/flysystem-aws-s3-v3` for MinIO;
- preserves Laravel's original `.env` line ordering while doing some required **changes**;
- preserves Laravel's Vite `server.watch.ignored` setting;
- adds `php artisan reverb:start --host=0.0.0.0 --port=8080` to the generated `composer dev` process group;
- adds the compact diagnostics panel and its Pest coverage.

### Services

- `MySQL > Browse/Create/Delete`
- `MinIO > Browse/Create/Delete`
- `Redis > Browse/Delete`
- `Tailscale > Funnel` — install/start, inspect, or stop the optional Funnel container.

The welcome-page diagnostics show all four service states. “Test all” performs MySQL and Redis round trips with temporary data, sends an email that remains visible in Mailpit, and writes a timestamped file that remains in MinIO. Mailpit and MinIO cards link to their dashboards.

When Reverb is enabled, the same panel includes **Ping open pages**. Clicking it broadcasts a small live event over the public `lara-stacker.welcome` channel; every other open welcome page for that application briefly highlights the sender and timestamp. The generated project includes the Echo client and Reverb event wiring automatically. Run `composer dev` (which starts Reverb with the other development processes), or leave `php artisan reverb:start --host=0.0.0.0 --port=8080` running from that application's directory before testing; Lara-Stacker and Caddy expose its `/app` websocket endpoint through the application's HTTPS host.

### Container

- `Start` — build/start the OrbStack services and prepare HTTPS.
- `Debug` — prepare a trigger-only Zed session and run an Artisan Xdebug request. For browser routes, use the Chromium extension described below and visit the route directly.
- `Status` — show the shared service state.
- `Stop` — stop all services.
- `Certify` — regenerate and trust local certificates.
- `Purge` — remove this stack's containers, images, volumes, network, and build cache.
- `Setup / Tools` — run the idempotent macOS dependency setup.


## Configuration

`.env` and `.env.example` intentionally have the same variables, comments, and ordering.

- `USERNAME` — macOS user that owns application files.
- `DB_PASSWORD` — MySQL root password.
- `HOST_HOME_PATH` — read-only host-home mount used by Composer path repositories.
- `APPS_ROOT` — application directory, normally `/Users/$USERNAME/Code/Laravel`.
- `OPINIONATED` — removes the legacy `MEMCACHED_HOST` entry and seeds `.prettierrc` when missing.
- `DEV_EDITOR` — `zed` to generate `.zed/debug.json`, or `none`.
- `DOCKER_COMPOSE_FILE` — Compose file path.
- `RESTART_UNLESS_STOPPED` — persistent service restart policy.
- `PHP_VERSION` — official PHP-FPM image version; keep it aligned with PHP in this repository's `mise.toml`.
- `CONTAINER_APT_MIRROR` / `CONTAINER_APT_SECURITY_MIRROR` — Debian mirrors used only while building the app image.
- Reverb server settings use `REVERB_HOST=host.docker.internal`, `REVERB_PORT=8080`, and `REVERB_SCHEME=http` for PHP inside the container; `VITE_REVERB_HOST`, `VITE_REVERB_PORT`, and `VITE_REVERB_SCHEME` retain the public HTTPS browser endpoint.
- `CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT`
- `MYSQL_PORT`, `REDIS_PORT`
- `MAILPIT_SMTP_PORT` / `MAILPIT_UI_PORT`
- `MINIO_PORT` / `MINIO_CONSOLE_PORT`

`composeUp` keeps its last successful PHP version and Dockerfile fingerprint in `~/.lara-stacker/stacker-build.env`. This is a small rebuild cache, not an application or project configuration file. If it contains an older value such as `8.3` while `.env` says `PHP_VERSION=8.4`, the next `Start` detects the mismatch, rebuilds the app image, and updates the cache. A root `.stacker-build.env` containing `STACKER_NODE_VERSION` or `STACKER_PROFILES` is a legacy v5 artifact; current code does not read it and it remains ignored.


## Trigger-only Xdebug

The app image contains Xdebug with:

```ini
xdebug.mode=debug
xdebug.start_with_request=trigger
xdebug.client_host=host.docker.internal
xdebug.client_port=9003
```

For browser requests, you do not need `Container > Debug`. Open the application in Zed, run the debugger-start shortcut you configured yourself (or use Zed's command palette and `debugger: start`), and choose **PHP: Listen to Xdebug**. Then enable [Xdebug Helper by JetBrains](https://chromewebstore.google.com/detail/xdebug-helper-by-jetbrain/aoelhdemabeimdhedkidlnbkfhnhgnhm) in Helium or another Chromium browser, right click on its icon and go to settings and set the debug trigger key to `LARA_STACKER`, and finally visit any application route normally. The extension sets the browser trigger cookie; Xdebug's trigger mode then [starts the session for that request](https://xdebug.org/docs/step_debug#browser_extension_initiation).

`Container > Debug` remains useful for preparing the generated Zed configuration and for triggered Artisan commands. It can also open a one-off URL with `XDEBUG_TRIGGER=1` as a fallback. It does not set or alter your Zed keybindings.

The command can then:

- open a route with `XDEBUG_TRIGGER=1`; or
- execute an Artisan command with the trigger environment.

The command neither changes mise/PHP configuration nor rebuilds or restarts the container. Zed requires `"adapter": "Xdebug"`; the generated task includes the correct container-to-worktree path mapping.


## Composer changes and PHP-FPM

Host Composer writes into the OrbStack bind mount, so new package files become visible to the app container immediately. OPcache validates timestamps on every request, and the `synchronizer` sidecar watches Composer's settled autoload map and then reloads PHP-FPM once. New packages do not require a manual container restart; praises to Allah.

The app container also mounts `HOST_HOME_PATH` read-only so Composer path-repository symlinks outside `APPS_ROOT` remain resolvable.

**Docker Desktop is NOT supported**; unlike OrbStack, it may require a full app-container restart after project package changes.


## Tailscale Funnel

Tailscale runs as an optional official container. Lara-Stacker can install and start that service, but authentication and exposure policy remain intentionally manual:

1. Generate an auth key in the [Tailscale admin console](https://login.tailscale.com/admin/settings/keys) and put it in `.env` as `TAILSCALE_AUTH_KEY`.
2. Set `TAILSCALE_HOSTNAME`.
3. In the admin console, enable the node/tag permissions, HTTPS certificates, and Funnel access appropriate for the tailnet.
4. Choose `Tailscale > Funnel > Install/start Funnel and expose an app`.

Funnel is public internet exposure. Treat `TAILSCALE_AUTH_KEY` as a secret; `.env` is ignored by Git.

</div>

> [!TIP]
> The command authenticates the container, points the shared `_funnel_app` symlink at the selected application, and exposes Caddy on Funnel port 443. Reverb is available under the same public hostname at `/app`.

<div align="left">


## Ports and URLs

The shipped `.env.example` avoids common host conflicts:

- Apps: `https://<app>.dev.localhost`
- Vite: `https://vite-<app>.dev.localhost:8443`
- Mailpit: `https://mailpit.dev.localhost`
- MinIO: `https://minio.dev.localhost`
- MySQL `3307`, Redis `6380`, Mailpit SMTP/UI `1026/8026`, MinIO API/UI `9100/9101`

Use host ports `80/443` when available for clean URLs. Restart the stack and Rewire applications after port changes.


## Support

</div>

>[!IMPORTANT]
> Please don’t skip this—your support helps make continued development possible!

<div align="left">

Support ongoing maintenance through [GitHub Sponsors](https://github.com/sponsors/GoodM4ven).


## Credits

- [Youssif Shaaban Alsager](https://github.com/yshalsager)
- [Laravel](https://laravel.com/), [PHP](https://www.php.net/), [Composer](https://getcomposer.org/), and the official [PHP-FPM images](https://hub.docker.com/_/php)
- [mise](https://github.com/jdx/mise), [verzly/mise-php](https://github.com/verzly/mise-php), and [PHP Installer for Extensions (PIE)](https://github.com/php/pie)
- [OrbStack](https://orbstack.dev/), [Docker Compose](https://github.com/docker/compose), and [Caddy](https://github.com/caddyserver/caddy)
- [MySQL](https://github.com/mysql/mysql-server), [Redis](https://github.com/redis/redis), [MinIO](https://github.com/minio/minio), and [Mailpit](https://github.com/axllent/mailpit)
- [Laravel Reverb](https://github.com/laravel/reverb), [Pest](https://github.com/pestphp/pest), and [Laravel Boost](https://github.com/laravel/boost)
- [Xdebug](https://github.com/xdebug/xdebug), [Zed](https://github.com/zed-industries/zed), and [mkcert](https://github.com/FiloSottile/mkcert)
- [Node.js](https://github.com/nodejs/node), [npm](https://github.com/npm/cli), and [pnpm](https://github.com/pnpm/pnpm)
- [Tailscale](https://github.com/tailscale/tailscale) and [Tailscale Funnel](https://tailscale.com/docs/features/tailscale-funnel)
- [ChatGPT](https://chatgpt.com/), [Codex CLI](https://developers.openai.com/codex/cli/), and [Claude Code](https://claude.com/claude-code)
- [Active contributors](https://github.com/GoodM4ven/CLI_MACOS_lara-stacker/graphs/contributors)

</div>
<div align="center"><br>والحمد لله رب العالمين</div>
