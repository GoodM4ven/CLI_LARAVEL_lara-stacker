<div align="center">بسم الله الرحمن الرحيم</div>
<div align="left">


# LARA-STACKER v5

Now **Docker-backed**! A single containerized stack provides runtime and services (PHP-FPM, MySQL, Redis, MinIO, Mailpit) exposed to the host, while the CLI manages apps, services, and HTTPS certs.

### Highlights

- One Docker container, many applications.
- `https://<app>.dev.localhost` for every application (no more `/etc/hosts`).
- Xdebug is **trigger-only** (no idling slow cost).
- Enable/disable applications without deleting them.

### Laravel Sail vs Lara-Stacker

- **Sail is per-application**: each app ships its own `compose.yaml` and containers. That means duplicated services and **rebuild time per application**.
- **Shared container here**: one runtime container group serves **all apps**, so no duplicate services per application.
- **Sail CLI depends on containers**: if an application’s container fail, Sail commands for that application is blocked, since the devEnvironment is inaccessible.
- **Host tools here**: Composer, PHP, and NPM run on the host. The container only provides runtime and services.
- Net: **faster iteration, fewer moving parts**, and no per-application Docker overhead.

https://github.com/user-attachments/assets/137f6d92-e1d6-4047-b73b-f5ce1da5e69f


## Setup

### Prerequisites

- <details>
  <summary>Docker Desktop (which contains <a href="https://docs.docker.com/engine/install">Engine</a> and <a href="https://docs.docker.com/compose/install">Compose</a> for containerization)</summary>

  - Linux (Ubuntu tested)
    ```bash
    set -e
    uname -m | grep -Eq 'x86_64|amd64'
    grep -Eq '(vmx|svm)' /proc/cpuinfo

    sudo apt update
    sudo apt install -y ca-certificates curl gnupg qemu-kvm qemu-utils libvirt-daemon-system libvirt-clients pass gnome-terminal || true

    lsmod | grep -q '^kvm' || sudo modprobe kvm
    if grep -qi intel /proc/cpuinfo; then
        lsmod | grep -q '^kvm_intel' || sudo modprobe kvm_intel
    fi
    if grep -qi amd /proc/cpuinfo; then
        lsmod | grep -q '^kvm_amd' || sudo modprobe kvm_amd
    fi
    getent group kvm | grep -q "$USER" || sudo usermod -aG kvm "$USER"

    sudo install -m 0755 -d /etc/apt/keyrings
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi

    sudo apt update
    cd ~/Downloads
    [ -f docker-desktop-amd64.deb ] || wget https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb
    sudo apt install ./docker-desktop-amd64.deb

    systemctl --user start docker-desktop
    systemctl --user enable docker-desktop
    ```
  </details>

- <details>
  <summary>Building tools</summary>

  - Linux (Ubuntu tested)
    - <a href="https://getcomposer.org">Composer</a>, <a href="https://php.net">PHP</a>, and some of its extensions:
      ```bash
      sudo apt update
      sudo apt install -y php-cli unzip php-xml php-bcmath php-sqlite3 php8.3-mysql php-redis php-gd composer
      ```
    - <a href="https://nodejs.org">Node.js</a> via <a href="https://github.com/nvm-sh/nvm">NVM</a> preferably:
      ```bash
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
      ```
  </details>

- <details>
  <summary>Certification Tools</summary>

  - Linux (Ubuntu tested)
    ```bash
    sudo apt update
    sudo apt install ca-certificates certutil libnss3-tools
    git clone https://github.com/FiloSottile/mkcert && cd mkcert
    go build -ldflags "-X main.Version=$(git describe --tags)"
    ```
  </details>

- <details>
  <summary>Android Tools (for NativePHP Android apps)</summary>

  - Linux (Ubuntu tested)
    ```bash
    sudo apt update
    sudo apt install openjdk-17-jdk
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
    echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc
    sudo snap install android-studio --classic
    ```
  </details>

### Installation

1. Clone this repo, from the new main `docker` branch, and navigate to it.
2. Create `.env` from `.env.example` and fill the values.
   ```bash
   cp .env.example .env
   ```
3. Run the CLI:
   ```bash
   chmod +x ./lara-stacker.sh && ./lara-stacker.sh
   ```


## Usage

### Available Commands

Applications:
- `List` — lists folders under `APPS_ROOT` and whether they’re enabled
- `Create` — new Laravel app under `APPS_ROOT`, wired to Docker services
- `Import` — copy an existing app into `APPS_ROOT` and wire it
- `Refresh` — reinstall deps, clear caches, rewire env (full consistency pass)
- `Rewire` — updates an application’s `.env` and the Vite configuration file
- `Delete` — removes application files and its database, bucket, etc.
- `Enable` — removes `.disabled` marker and serves the app
- `Disable` — adds `.disabled` marker and returns 503 blocked response

</div>

> [!TIP]
> The **rewire** command updates config only (writes host-exposed service addresses and ports). Whereas the **refresh** command does a full dependency reinstall on the host, clears caches, and then *rewires* too.

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
  - `APPS_ROOT` (default `/var/www/html`) — host directory where applications live and coded from, locally!
    - The CLI will create `APPS_ROOT` if missing and make it owned by `USERNAME`.
  - `OPINIONATED` — copy opinionated application files (Prettier config)
  - `USE_VSC` — the CLI copies `stubs/.vscode/launch.json` into each application, that runs [xdebug](https://xdebug.org) in the proper way for [VSCodium](https://vscodium.com).
    - Xdebug is run in "trigger-only" mode.
    - Use the [browser extension](https://chromewebstore.google.com/detail/xdebug-chrome-extension/oiofkammbajfehgpleginfomeppgnglk?hl=en&pli=1) and make sure it's on **only when needed**.
  - `VSC_WORKSPACES_DIR` — auto-create `.code-workspace` files (leave empty to disable)

- Container
  - `DOCKER_COMPOSE_FILE` — override the compose file path
  - `PHP_VERSION` — changing this triggers a rebuild on next `Start Container`
  - `APT_MIRROR` — Debian main mirror (HTTPS)
  - `APT_SECURITY_MIRROR` — Debian security mirror (HTTPS)
  - `CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT` — host ports for Caddy (**it's recommended to use `80/443` if free**)
  - `MYSQL_PORT` — host port for MySQL (container `3306`)
  - `REDIS_PORT` — host port for Redis (container `6379`)
  - `MAILPIT_SMTP_PORT` / `MAILPIT_UI_PORT` — host ports for Mailpit SMTP/UI (container `1025/8025`)
  - `MINIO_PORT` / `MINIO_CONSOLE_PORT` — host ports for MinIO API/Console (container `9000/9001`)

- The **rewire** command writes these host port values into each application’s `.env` (with `DB_HOST=127.0.0.1`, `REDIS_HOST=127.0.0.1`, etc.).
- After changing any host port variables, restart the container and run the **rewire** command to refresh each app’s `.env`.

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
> It's extremely recommended to use `80/443` ports with Caddy. I only made them different by default in order not to conflict with lara-stacker v4. Check the [.env](./.env) file.

<div align="left">


## Responsibilities

- The container does install and expose the main services (Caddy, MySQL, Redis, MinIO, etc.) ports for you, does runtime stuff in place (PHP, PHP Extensions, PHP-FPM, etc.) too, and finally includes whatever extra packages the local server may need, such as the media's (ImageMagick, Ghostscript, FFmpeg, etc.).
- Application `.env` files are **host-wired** (`127.0.0.1` + host ports) because all dev tooling (Composer/PHP/Artisan/NPM) runs on the host.
- The app container is injected with internal service hosts so runtime still connects to MySQL/Redis/MinIO when serving requests.
- **The container does NOT contain the [development tools](#prerequisites) themselves that need to exist locally.** This includes Java and Android tooling, etc.

TLDR: **Docker provides the runtime container group**, but there are **essential [prerequisites](#prerequisites) that must be installed on the host** for ever so many reasons really... All in all, the CLI will DISFUNCTION if those tools are missing.

- Inside the container, applications are always mounted at `/var/www/html` (Caddy/PHP-FPM depend on this).
- Applications can be **disabled** via the CLI. This creates a `.disabled` file, and Caddy responds with **503** while keeping files intact.
- **You can access an application using: `https://<app>.dev.localhost:8443` (or `https://<app>.dev.localhost` if `CADDY_HTTPS_PORT=443`)**
- Vite HMR is exposed via `https://vite-<app>.dev.localhost:8443`. Run on host: `cd <app> && npm run dev`
- mkcert installs the "trust" into the system store, so make sure it's installed back in [prerequisites](#prerequisites) section, of course.
- Certs are generated into `./.certs` (which isn't version controlled) and Caddy is restarted to use them from there. **DO NOT REMOVE THEM.**

</div>

> [!IMPORTANT]
> This stack uses PHP-FPM (with OPcache), which is fast but **can sometimes make changes appear “stuck” due to caching** configs, routes, views, or bytecode. If something behaves oddly after a change, this Artisan command should fix it: `php artisan optimize:clear`.

<div align="left">


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
