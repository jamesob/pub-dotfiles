#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOTS_DIR="${DOTS_DIR:-$SCRIPT_DIR/dots}"
HOSTS_DIR="${HOSTS_DIR:-$SCRIPT_DIR/hosts}"
TARGET_DIR="${TARGET_DIR:-$HOME}"
CURRENT_HOST="$(hostname)"

if [[ ! -d "$DOTS_DIR" ]]; then
    echo "Error: dots directory not found: $DOTS_DIR" >&2
    exit 1
fi

if ! command -v fzf &>/dev/null; then
    echo "Installing fzf..."
    if [[ "$OSTYPE" == darwin* ]]; then
        brew install fzf
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm fzf
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y fzf
    else
        echo "Unknown OS, install fzf manually" >&2
        exit 1
    fi
fi

laank() {
    local src=$1
    local base_dir=$2
    local rel="${src#$base_dir/}"
    local dest="$TARGET_DIR/.$rel"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"
    
    # Skip if already correctly linked
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        echo "OK: $dest"
        return
    fi
    
    # Backup existing file if it's not a symlink
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        echo "Backing up: $dest -> $dest.bak"
        mv "$dest" "$dest.bak"
    fi
    
    # Remove existing symlink if pointing elsewhere
    [[ -L "$dest" ]] && rm "$dest"
    
    ln -s "$src" "$dest"
    echo "Linked: $dest -> $src"
}

# Process shared dotfiles
find "$DOTS_DIR" -type f | while read -r src; do
    laank "$src" "$DOTS_DIR"
done

# Process host-specific dotfiles
HOST_DIR="$HOSTS_DIR/$CURRENT_HOST"
if [[ -d "$HOST_DIR" ]]; then
    echo "Processing host-specific files for: $CURRENT_HOST"
    find "$HOST_DIR" -type f | while read -r src; do
        laank "$src" "$HOST_DIR"
    done
fi

# Mark all local/bin files as executable
find "$DOTS_DIR" -path "*/local/bin/*" -type f -exec chmod +x {} \;
if [[ -d "$HOST_DIR" ]]; then
    find "$HOST_DIR" -path "*/local/bin/*" -type f -exec chmod +x {} \;
fi

# Enable systemd user services and timers
enable_systemd_units() {
    local base_dir=$1
    local systemd_dir="$base_dir/config/systemd/user"

    [[ -d "$systemd_dir" ]] || return 0

    systemctl --user daemon-reload

    find "$systemd_dir" -type f \( -name "*.timer" -o -name "*.service" \) | while read -r unit; do
        local unit_name
        unit_name=$(basename "$unit")

        # Only auto-enable timers and services with [Install] section
        if grep -q '^\[Install\]' "$unit"; then
            if ! systemctl --user is-enabled "$unit_name" &>/dev/null; then
                echo "Enabling: $unit_name"
                systemctl --user enable "$unit_name"
            fi

            # Start timers automatically
            if [[ "$unit_name" == *.timer ]]; then
                systemctl --user start "$unit_name"
            fi
        fi
    done
}

enable_systemd_units "$DOTS_DIR"
[[ -d "$HOST_DIR" ]] && enable_systemd_units "$HOST_DIR"
