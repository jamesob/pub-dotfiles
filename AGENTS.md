# AGENTS.md

## Git

- Commit every change immediately after making it. Do not batch multiple
  unrelated changes into one commit; each logical change gets its own commit.
- Do not wait to be asked to commit — committing is part of completing any
  change.
- Use short, lowercase, imperative commit messages matching the existing
  style (e.g. `add yubikey touch detector`, `media-touchpad: mute button`).
- If GPG signing fails, retry with `git -c commit.gpgsign=false commit`.
- Do not push unless explicitly asked.
