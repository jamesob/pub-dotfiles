# pub-dotfiles security audit — 2026-10-06

Scope: everything tracked in git (working tree + full history), all runtime
dependencies cited or installed by this repo.

## (i) Sensitive data

**No secrets in the working tree or anywhere in git history** (all 398
git blobs scanned with the repo's own cred-detect patterns plus AWS/GitHub/
Slack/Stripe/JWT/private-key signatures; 0 findings). Nothing needs history
purging.

Public-key material present (safe to publish, listed for completeness):

- `dots/gitconfig`: SSH signing key (`key::ssh-rsa ...`, YubiKey PIV) and
  card serial `7826579`; public GPG key IDs `0xC3ED8EEC97AA9D43`,
  `602FF17CFE7726E077AB497EC597111CC9A2855F`. Public keys are public by
  design; the card serial is printed on the device (only useful for
  social-engineering attempts, not an attack primitive).
- `dots/sh/aliases.sh` reads an IRC password via `pass ...` — value never
  stored in the repo.
- Docker configs (`hosts/*/docker/config.json`): `auths` empty, no tokens.

Informational disclosures (typical for personal dotfiles, not credentials):
hostnames (`fido`, `m4`, `tacoma`, `teller`/`tanoshii`/`slug`, ...), internal
service names (`stt.j.co:8201`, `api.ai.j.co`), Coinbase ticker helper.
Remove if you want a lower profile.

## (ii) Dependencies — pinning status

Now pinned (this audit, commits `ec3c5bf`, `58c6f9f`, `0426f63`, on top of
vendored-vim `3aa29a3`):

| Dependency | Pin |
|---|---|
| vim plugins fzf / fzf.vim / ack.vim | raw sources in-tree @ b1be3a8 / 023de3c / 36e40f9, sha256-verified, audited |
| 19 lazy-managed nvim plugins | `dots/config/nvim/lazy-lock.json` committed, `lockfile` opt set |
| lazy.nvim bootstrap | pinned to `85c7ff3` (was floating `--branch=stable`) |
| Go tools (gopls, golangci-lint, golangci-lint-langserver, goimports, dlv) | pinned versions; `gorename`/`godoc` dropped — removed upstream |
| z.sh, seoul256(-light), fzf-tab.zsh, tmux-navigator block, colors | provenance headers naming repo+commit; `z.sh` and seoul256 byte-match upstream commits |
| `bin/yubikey-touch-detector.go` | stdlib-only — zero external deps |

Deliberately unpinned:

- OS packages via apt/pacman/brew (fzf, vim, tmux, neovim, ...) — pinning is
  the OS package manager's job.
- lazy.nvim clones plugins on first `nvim` start (network on first run only;
  no startup network afterwards).

## Vulnerabilities

- **fzf binary is 0.60** on this machine (apt) — **CVE-2026-53432**
  (integer overflow panic in `FuzzyMatchV2`, crash/DoS with crafted input)
  and **CVE-2026-53433** (medium) affect `< 0.73.1`. Fixed in fzf 0.73.1.
  `install.sh` now warns (commit `3f5984c`). **Action: install a newer fzf
  binary** (backport/newer apt, or fetch the 0.73.1 release asset and put it
  earlier in `PATH`).
- The vendored vim plugins themselves: full code audit found zero
  startup-time execution and zero network calls; the one upstream download
  path (`fzf#install`) fails closed because `install`/`install.ps1` are not
  vendored.
- No public advisories (GHSA/NVD) exist for the pinned Lua/vim plugin
  versions at audit time. Caveat: the Lua plugin ecosystem publishes few
  advisories and the lockfile was cut ~8 months ago; periodically review +
  refresh it via `:Lazy sync` and commit the diff.
- Inherited upstream risk notes (ack.vim `:AckFromSearch` double-quotes
  search text into a shell string; fzf.vim `:Locate`/`:GFiles` append raw
  args; `preview.sh` `eval`s `$FZF_PREVIEW_COMMAND`) — all require your own
  typed input/env; standard for this toolchain.

## Housekeeping suggestions (not done automatically)

- `:Lazy clean` in nvim removes orphaned installs not in the active spec
  (Comment.nvim, gitsigns.nvim, cmp-path, cmp_luasnip, nvim-treesitter ...
  sit in `~/.local/share/nvim/lazy` and stop receiving updates).
- `dots/sh/fzf.zsh` is legacy (old modified fzf keybindings, superseded by
  `fzf-tab.zsh` sourced right after it in zshrc) — candidate for deletion.
