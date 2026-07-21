#!/bin/bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Lara-Stacker v6 supports macOS only."
    exit 1
fi

repo_dir=$(cd "$(dirname "$0")/.." && pwd -P)
user_home="${HOME}"

echo "-=|[ Lara-Stacker |> SETUP ]|=-"

if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

echo "Installing Lara-Stacker's native macOS dependencies..."
brew install imagemagick mkcert nss
if [[ -d /Applications/OrbStack.app || -d "$user_home/Applications/OrbStack.app" ]]; then
    echo "OrbStack is already installed."
else
    brew install --cask orbstack
fi

dev_editor="zed"
if [[ -f "$repo_dir/.env" ]]; then
    dev_editor=$(sed -n 's/^DEV_EDITOR=//p' "$repo_dir/.env" | tail -n 1)
fi
if [[ "$dev_editor" == "zed" ]]; then
    if [[ -d /Applications/Zed.app || -d "$user_home/Applications/Zed.app" ]]; then
        echo "Zed is already installed."
    else
        brew install --cask zed
    fi
fi

mise_bin="$user_home/.local/bin/mise"
if [[ ! -x "$mise_bin" ]]; then
    echo "Installing mise..."
    curl https://mise.run | sh
fi
if [[ ! -x "$mise_bin" ]]; then
    echo "mise was not installed at $mise_bin."
    exit 1
fi

profile_file="$user_home/.zprofile"
touch "$profile_file"
if ! grep -Fq '.local/bin/mise" activate zsh' "$profile_file" "$user_home/.zshrc" "$user_home/.zsh_env" 2>/dev/null; then
    printf '\n# mise (installed by Lara-Stacker)\neval "$("$HOME/.local/bin/mise" activate zsh)"\n' >>"$profile_file"
fi
if ! grep -Fq '$HOME/.composer/vendor/bin' "$profile_file" "$user_home/.zshrc" "$user_home/.zsh_env" 2>/dev/null; then
    printf '\n# Composer global binaries (Laravel installer)\nexport PATH="$PATH:$HOME/.composer/vendor/bin"\n' >>"$profile_file"
fi

export PATH="$user_home/.composer/vendor/bin:$user_home/.local/bin:$PATH"

echo "Installing the repository's mise-managed PHP, Composer, Node, npm, and pnpm..."
cd "$repo_dir"
"$mise_bin" trust --yes "$repo_dir/mise.toml" >/dev/null 2>&1 || true
"$mise_bin" install

php_cmd=$("$mise_bin" which php)
composer_cmd=$("$mise_bin" which composer)

echo "Installing the Laravel installer globally for this macOS user..."
"$php_cmd" "$composer_cmd" global require laravel/installer --with-all-dependencies --no-interaction

echo "Installing and trusting the local HTTPS authority..."
mkcert -install

open -a OrbStack

echo
echo "Setup complete. Open a new shell to use 'laravel' globally, or run Lara-Stacker now."
