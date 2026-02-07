<div align="center">بسم الله الرحمن الرحيم</div>
<div align="left">


# Lara-Stacker v5

Now **Docker-only**! It runs a single containerized stack that serves **all** Laravel projects from one root directory, with automatic HTTPS and per-project wiring.

### Highlights

- One Docker stack, many projects.
- `https://<app>.dev.localhost` for every project (no `/etc/hosts`).
- Includes Redis, Mailpit, and MinIO out of the box.
- Xdebug is **trigger-only** (no idle cost).
- Enable/disable projects without deleting them.

### Sail vs Lara-Stacker (Short + Critical)

- **Sail is per-project**: each app ships its own `compose.yaml` and containers. That means duplicated services and **rebuild time per project**.
- **Shared stack here**: one runtime stack serves **all apps**, so no duplicate MySQL/Redis/Mailpit/MinIO per project.
- **Sail CLI depends on containers**: if a project’s containers fail, Sail commands for that project are blocked.
- **Host tools here**: Composer + Node/npm run on the host (tools most devs install anyway). The container is only for runtime PHP + services.
- Net: **faster iteration, fewer moving parts**, and no per-project Docker overhead.


## Setup

### Requirements

- <details>
  <summary>Docker Desktop (which contains <a href="https://docs.docker.com/engine/install">Engine</a> and <a href="https://docs.docker.com/compose/install">Compose</a>)</summary>

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
    - <a href="https://php.net">PHP</a> and <a href="https://getcomposer.org">Composer</a>:
      ```bash
      sudo apt update
      sudo apt install -y php-cli unzip
      php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
      php composer-setup.php --install-dir=/usr/local/bin --filename=composer
      rm composer-setup.php
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

### CLI Installation

1. Clone this repo, from the new main `docker` branch, and navigate to it.
2. Create `.env` from `.env.example` and fill the values.
   ```bash
   cp .env.example .env
   ```
3. Run the CLI:
   ```bash
   chmod +x ./lara-stacker.sh && ./lara-stacker.sh
   ```

### Available Commands

Applications:
- `List` — lists folders under `APPS_ROOT` and whether they’re enabled
- `Create` — new Laravel app under `APPS_ROOT`, wired to Docker services
- `Import` — copy an existing app into `APPS_ROOT` and wire it
- `Refresh` — reinstall deps, clear caches, rewire env (full consistency pass)
- `Rewire` — updates a project’s `.env` + Vite config to match the stack (no reinstall)
- `Delete` — removes project files and its DB/bucket
- `Enable` — removes `.disabled` marker and serves it
- `Disable` — adds `.disabled` marker and returns 503

</div>

> [!NOTE]
> Rewire updates config only. Refresh does a full dependency reinstall on the host, clears caches, and then *rewires* too.

<div align="left">

Services:
- `MySQL > Browse` — shows all databases in the stack MySQL
- `MySQL > Create` — creates a new database by name
- `MySQL > Delete` — deletes a database by name (with confirmation)
- `MinIO > Browse` — lists MinIO buckets
- `MinIO > Create` — creates a MinIO bucket
- `MinIO > Delete` — deletes a MinIO bucket
- `Redis > Browse` — lists Redis keys
- `Redis > Delete` — deletes Redis keys by pattern

Container:
- `Start` — boots the Docker stack and prepares HTTPS (auto-trusts if enabled)
- `Check` — shows running containers in the stack
- `Stop` — shuts down all stack services
- `Certify` — installs local HTTPS certs/trust (mkcert)
  - Requires `sudo` access once, in order to write to the system trust store
  - Requires restarting the browser, in order to pick up the new trust
- `Purge` — removes all stack containers, images, volumes, networks, and build cache

### Responsibilities

What the container does for you (main services + runtime stack):
- Runs the **main services** and exposes them on ports (Caddy + PHP-FPM, MySQL, Redis, Mailpit, MinIO).
- Installs the **runtime stack** needed to serve apps **inside the container** (PHP + extensions).
- Includes **media tooling** (ImageMagick/Ghostscript/FFmpeg) for local dev needs.

**What the container does NOT do for you (and you must install it yourself):**
- The **building tools** in order to run them locally (Composer, Node.js + npm).
- Java and Android tooling, pywatchman, etc (for NativePHP development).

In short: **Docker provides the runtime stack**, but there are **essential tools that must be installed on the host** for ever so many reasons really. All and all, the CLI will DISFUNCTION if these tools are missing.

### Configuration

Edit `.env` (same order as the file):

Host
- `USERNAME` — system user that owns project files
- `DB_PASSWORD` — root password for the MySQL container image
- `APPS_ROOT` (default `/var/www/html`) — host directory where projects live
- `OPINIONATED` — copy opinionated project files (Prettier config)
- `USE_VSC` — generate Xdebug `launch.json` files
- `VSC_WORKSPACES_DIR` — auto-create `.code-workspace` files (leave empty to disable)

Container
- `DOCKER_COMPOSE_FILE` — override the compose file path
- `PHP_VERSION` — changing triggers a rebuild on next `Start Stack`
- `APT_MIRROR` — Debian main mirror (HTTPS)
- `APT_SECURITY_MIRROR` — Debian security mirror (HTTPS)
- `CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT` — host ports for Caddy (use `80/443` if free)

Notes:
- When `USE_VSC=true`, the CLI also copies `files/.vscode/launch.json` into each project.
- The CLI will create `APPS_ROOT` if missing and make it owned by `USERNAME`.
- The base domain is fixed to `dev.localhost`.
- HTTPS trust via `mkcert` is always attempted when bringing the stack up or preparing projects.

### Xdebug (On-Demand)

- Configured for **trigger-only** debugging.
- Use the [VSCodium](https://vscodium.com) config in `.vscode/launch.json` (auto-copied per project).
- Trigger with a [browser extension](https://chromewebstore.google.com/detail/xdebug-chrome-extension/oiofkammbajfehgpleginfomeppgnglk?hl=en&pli=1) or `XDEBUG_TRIGGER=1`.

### Notes

- Inside the container, projects are always mounted at `/var/www/html` (Caddy/PHP-FPM depend on this).
- Projects can be **disabled** via the CLI. This creates a `.disabled` file, and Caddy responds with 503 while keeping files intact.
- You can access an application using: `https://<app>.dev.localhost:8443` (or `https://<app>.dev.localhost` if `CADDY_HTTPS_PORT=443`)
- Vite HMR is exposed via `https://vite-<app>.dev.localhost:8443`. Run on host: `cd <app> && npm run dev`
- Service UIs: `https://mailpit.dev.localhost:8443` and `https://minio.dev.localhost:8443` (or use the host ports below)
- mkcert installs trust into the system store (and NSS if `certutil` is available).
- Certs are generated into `./.certs` and Caddy is restarted to use them.
- After changing `CADDY_HTTPS_PORT`, run **Rewire Project** (or **Refresh Project**) to update each project's `APP_URL` and Vite HMR URL.

### Ports

This stack is isolated from host installs (v4-style). It only conflicts if a host service already uses these same ports:

- [Caddy](https://caddyserver.com/): `8080/8443` (use `80/443` if free to remove port from URLs)
- [MySQL](https://www.mysql.com/): `3307` (container `3306`) [Required]
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
