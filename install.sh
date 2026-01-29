#!/usr/bin/env bash
set -euo pipefail

DOTS_DIR="${DOTS_DIR:-$(cd "$(dirname "$0")/dots" && pwd)}"
TARGET_DIR="${TARGET_DIR:-$HOME}"

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

find "$DOTS_DIR" -type f | while read -r src; do
    rel="${src#$DOTS_DIR/}"
    dest="$TARGET_DIR/.$rel"
    
    # Create parent directory if needed
    mkdir -p "$(dirname "$dest")"
    
    # Skip if already correctly linked
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        echo "OK: $dest"
        continue
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
done
