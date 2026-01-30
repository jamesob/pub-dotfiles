# dotfiles

Everyone's got 'em, these are mine.

Zsh, Neovim, and tmux configs oriented around terminal productivity.
[zshrc](dots/zshrc) sets up a git-aware prompt, history, aliases, and SDK paths;
[nvim](dots/config/nvim/init.lua) uses lazy.nvim with treesitter, LSP, fzf, and fugitive;
[tmux.conf](dots/tmux.conf) rebinds the prefix to `Ctrl-A` with vim-style pane navigation.
An [install script](install.sh) symlinks everything into place and handles
host-specific overrides.

Much of this was written before the LLM days, but some of it wasn't.

## Scripts

- [`pypass`](dots/local/bin/pypass): Passphrase generator with BIP32 mnemonic, word-list, and symbol/number modes
- [`cred-detect`](dots/local/bin/cred-detect): Scans directories for hardcoded secrets (AWS keys, tokens, JWTs, etc.) with whitelisting support
- [`mon-ctrl`](hosts/fido/local/bin/mon-ctrl): DDC-CI monitor brightness and input control with time-of-day auto-adjust
