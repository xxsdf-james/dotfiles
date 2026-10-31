# dotfiles

My Linux config, managed with [chezmoi](https://chezmoi.io). It isn't tied to a distro; why and how is in [docs/philosophy.md](docs/philosophy.md).

## Layout
- `home/`: what chezmoi copies into `$HOME` (`.chezmoiroot` points here)
- `docs/`: the philosophy behind the setup
- `system/`: files for `/etc`, one folder per component, installed by `system/install.sh` (usage in its header)

## Daily use
- `chezmoi edit <file>` → `chezmoi diff` → `chezmoi apply`
- Changed a file in place? `chezmoi re-add <file>`, then review with `chezmoi cd && git diff`.
- `chezmoi diff` should be empty on every machine.

## Restore on a new machine
To be written in B1 (bootstrap per OS, `chezmoi init --apply`, `system/install.sh`, manual steps).
