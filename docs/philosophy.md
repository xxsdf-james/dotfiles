# Dotfiles philosophy

_Decided 2026-10-30 (B0). This is the reference for every decision about the dotfiles repo. When a change doesn't fit, change this document first, or don't make the change._

## 1. The goal
A setup that is **portable, maintainable and reversible**, across:
- this laptop
- a future work laptop
- Ubuntu VMs
- Ubuntu live sessions
- whatever distro comes next

## 2. Decoupled from the distro
- I chose Bluefin for its immutable model, not because I'm tied to it. In 2026 the immutable landscape is still moving (Fedora Atomic, Universal Blue, GNOME OS, KDE Linux, Ubuntu Core Desktop, NixOS), so **the repo assumes no distro.**
- It assumes a **common user layer** that runs on all of them:
  - bash
  - Homebrew for CLI tools
  - Flatpak for GUI apps
  - podman/distrobox for anything else
  - GNOME as the desktop (for now)
- The OS only provides a kernel, drivers, a desktop and a package manager I never touch from the repo. Choosing a distro is a separate decision, and switching should cost only the bootstrap step.

## 3. Layers, by concern
| Layer | Contents | Varies by |
|---|---|---|
| Shell and CLI configs | bash, `.bashrc.d/`, git, nvim, starship, fzf | nothing |
| CLI packages | Brewfile | nothing (role may add extras) |
| GUI apps | Flatpak list | nothing (role may add extras) |
| Desktop settings | dconf (GNOME, Ptyxis) | the desktop |
| System layer | `install.sh`: kill switch, udev, SELinux | OS and role, personal only |
| Containers | `distrobox.ini` | nothing |

Most of the repo **never branches**. Real differences are allowed in only two places: the system layer and the bootstrap.

**What earns a place in the package lists:**
- "I chose it" isn't enough: OpenRGB was a deliberate install, opened once, and passed two reviews.
- An app stays if I've **used it in the last 12 months**, or it's marked `# occasional: <reason>` in the Brewfile.
- Evidence of use: the newest file in `~/.var/app/<id>` for Flatpaks, and bash history for CLI tools.
- The update routine (plan Task D) flags listed apps with no use in 12 months.
- Re-installing an occasional tool when I need it costs one command. Carrying an unused one costs updates, attention and drift.

## 4. The data model (the only "profiles")
- **Detected, never asked, never stored:** the OS. Templates read chezmoi's built-in `.chezmoi.os` / `.chezmoi.osRelease`, and scripts read `/etc/os-release` when they run. Match on the family (`ID_LIKE`), not `ID`: Bluefin reports `ID=bluefin` with `ID_LIKE=fedora`.
- **Asked once per machine:**
  - `role`: personal | work (git identity, kill switch, extra apps)
  - `install`: full | dotfiles-only (dotfiles-only is for live sessions: no brew, no Flatpak, no system layer)
  - `email`: the git email, asked on every machine and never stored in the repo (personal machines use the GitHub no-reply address)

## 4a. Identities, separate from machines
- An **identity** is a named bundle: git name and email, a GitHub account, an SSH key, a KeePassXC database, a browser profile.
- A **machine** is a role plus an install level, plus the identities it carries. A work laptop will likely carry two: personal (for this repo) and work.
- **Identities live in KeePassXC, not in the repo.** The repo only references them: chezmoi can read values from KeePassXC while rendering templates, and git can switch identity per folder (`includeIf "gitdir:..."`). Identities attach to folders, not machines.
- Today there is one identity, so the repo stays minimal: it asks for the email on each machine. The full design (SSH keys, KeePassXC layout, several GitHub accounts) belongs in the secrets discussion in Task D.

## 4b. Repo layout
`.chezmoiroot` points chezmoi at `home/`, so only `home/` maps onto the home folder. `README.md`, `docs/` and `system/` sit beside it and are never copied into `$HOME`.

Nothing else is a profile. A new axis needs a written reason in this file.

## 5. Rules against profile rot
1. **Detect facts, ask intent.**
2. **Guards over branches.** A plain file with `command -v` checks beats a template with OS conditionals. Use templates only for values (an email address) and for skipping whole files (`.chezmoiignore`).
3. **One git branch.** Differences are data, never per-OS branches.
4. **No apt or dnf in the repo**, except in the system layer. Brew and Flatpak names are the same everywhere.
5. **Never run a default twice.** When the image already provides something (Bluefin starts Starship and sets brew's PATH), my copy runs only if it hasn't run yet. This is the lesson from bling.
6. **Missing tools fail silently.** A live session without brew still gets a working shell.
7. **Test the branches I don't use daily:** `chezmoi apply` in an Ubuntu distrobox (dotfiles-only) after changes, and a full VM restore now and then.
8. **Config goes in `~/.config` (XDG) wherever the program supports it natively, and in the home folder only where the program requires it.** No environment-variable redirection (`HISTFILE`, `DOCKER_CONFIG`, ...) just for tidiness. Stick to defaults where we can: `~/.bashrc.d` (Fedora's convention) and chezmoi's source in `~/.local/share/chezmoi` (XDG data) stay as they are.

## 6. Tool: chezmoi
**Why:**
- It copies real files instead of creating links (Flatpak sandboxes and apps that rewrite their configs both break links).
- It's a single binary that also works on a live session.
- It has templates for the few real differences.
- `run_onchange_` scripts handle packages and dconf.
- It integrates with KeePassXC for secrets.
- The diff-then-apply workflow makes every change reviewable and reversible.

**Accepted costs:**
- You edit the source, not the target.
- File names are encoded (`private_dot_config/...`).
- Go templates are clunky, which is one more reason to template rarely.

**Not chosen:**
- **Stow:** links, and no templates, scripts or secrets.
- **Bare git / yadm:** too little structure, and yadm's encrypted-archive habit is what leaked the SSH/GPG archive.
- **Home Manager:** needs `/nix`, competes with brew, and isn't a boring core. Reconsider only if NixOS becomes the distro.

**Tools and bootstrap** (framework rule 5, scope set 2026-10-31): the rule is about *tools*. Tools come from brew or Flatpak, never `curl | sh` or `pip --user`, and no installer edits rc files (use its `--no-modify-path` or equivalent). Bootstrapping a package manager or chezmoi itself is different: a script may do it when I know what it does (download it, read it, then run it; never pipe it into a shell) and it comes from the project's own source. Today that's brew's `install.sh` from github.com/Homebrew on Ubuntu, and chezmoi's from get.chezmoi.io on a live session (it checks the download's checksum).

## 7. The workflow, and the principle behind it
**Edit the source → review the diff → apply.** Nothing on a machine is changed by hand and left there. A change I like goes into the repo (`chezmoi edit` / `chezmoi re-add`), and `chezmoi diff` should be empty on every machine.

This is the ideal for **everything** I keep, not only dotfiles: one canonical source, changes made deliberately, and every copy derived from it.
- **Config** (this repo): git is the source, chezmoi applies it.
- **Data** (Obsidian vaults, the KeePassXC database, Syncthing folders): data never goes in git (framework rule 4). The same principle still applies: **one canonical store**, sync as distribution, backups as history. Their *settings* (e.g. `keepassxc.ini`, chosen `.obsidian/` settings) can go through the repo. Their *contents* and secrets (Syncthing device keys, vault files) cannot.

### Ownership modes: who owns each config file
Apps change files too: through their GUI, or by rewriting them on their own. Every config picks exactly one mode:

| Mode | chezmoi feature | Use for |
|---|---|---|
| **Managed** | plain file / `.tmpl` | text I edit by hand: bash, git, nvim |
| **Create-once** | `create_` prefix | good starting defaults; after that the app owns the file |
| **Selected keys** | `modify_` script, or `dconf load` of chosen keys | files the app rewrites, where only a few settings matter (`keepassxc.ini`, GNOME/Ptyxis dconf) |
| **Unmanaged, app's own sync** | not in the repo | profiles and databases: Brave (Brave Sync), Obsidian vault contents, the KeePassXC database |

**Drift:** chezmoi doesn't watch files, it compares when asked. When a managed file changes outside the repo, `chezmoi status` / `chezmoi diff` show it, and I decide:
- keep it: `chezmoi re-add <file>`, review, commit
- discard it: `chezmoi apply`, which asks before overwriting a file changed since it last wrote it
- both sides changed: `chezmoi merge <file>`

Selected keys don't show up as file diffs (dconf lives in a database), so they need their own check: compare my chosen keys with the values in effect. Drift checks run as part of the update routine (plan Task D).

## 8. The framework this sits inside
From the 2026 cleanup plan (`~/Developer/claude-test/config-cleanup-plan.md`, "The framework"):
- keep my layer small
- boring core, separate experiments
- one tool per job
- track intentions, not state
- installers never edit rc files; tools only through brew or Flatpak (bootstrap scripts excepted, see §6)
- upstream default / upstream optional / mine
