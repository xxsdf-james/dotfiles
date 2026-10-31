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
- Publish a change: `chezmoi git -- push`. The repo is public: never commit a secret, because history keeps it.

## Restore on a new machine
`chezmoi init` asks three questions once per machine:
- `role`: `personal` or `work`. Work machines skip the personal Brewfile and the kill switch.
- `install`: `full`, or `dotfiles-only` for live sessions and containers (no packages, no system layer).
- `email`: the git email. On personal machines, the GitHub no-reply address.

The repo is public, so no login is needed to restore. Read any downloaded script before running it.

### 1. Bootstrap (per OS)
**Bluefin:** brew is already installed, but it's the image's version, which can be older than the taps expect.
```sh
brew update
brew install chezmoi
```

**Ubuntu:** install Flatpak and brew's dependencies, then brew itself.
```sh
sudo apt install build-essential procps curl file git flatpak
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
curl -fsSL -o /tmp/brew-install.sh https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
less /tmp/brew-install.sh          # read it first
bash /tmp/brew-install.sh          # it only prints the shellenv line; .bashrc.d/05 already does that
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"   # for this shell only
brew install chezmoi
```
Log out and back in afterwards, so Flatpak apps show up in the app grid.

**Live session or container (`install = dotfiles-only`):** only the chezmoi binary. Its install script checks the download's checksum.
```sh
curl -fsLS -o /tmp/chezmoi-install.sh https://get.chezmoi.io
less /tmp/chezmoi-install.sh       # read it first
sh /tmp/chezmoi-install.sh -b "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"
```

### 2. Dotfiles
```sh
chezmoi init xxsdf-james           # clones github.com/xxsdf-james/dotfiles, asks the three questions
chezmoi diff                       # review what will change
chezmoi apply                      # on full installs this also runs brew bundle and loads the GNOME settings
```
Open a new terminal so the new `.bashrc` is used.

### 3. By hand
- **KeePassXC database:** bring the `.kdbx` over (Syncthing, approved from a device you already have, or a USB stick). Everything below that needs a secret comes from it.
- **SSH key and GitHub login,** only on machines where you push to this repo: the SSH key from KeePassXC, then `gh auth login`.
- **Mullvad (personal):** first rename each WireGuard config to `mv-<cc>-<city>-<NNN>.conf`: the file name becomes the profile and interface name, and the kill switch only lets `mv-*` through. Import with `nmcli connection import type wireguard file <conf>`, then set `nmcli connection modify <name> connection.autoconnect no` on all but the one boot profile.
- **Printer and Wi-Fi:** through GNOME Settings.
- **Syncthing:** pair the new device from an existing one.

### 4. System layer (full installs only)
```sh
role="$(chezmoi execute-template '{{ .role }}')"
~/.local/share/chezmoi/system/install.sh --role "$role"            # shows what would change
pkexec ~/.local/share/chezmoi/system/install.sh --role "$role" --yes
```
`sudo` works instead of `pkexec`. With `role = personal` this installs the kill switch, so **the internet is blocked until a `mv-*` WireGuard profile is connected**. Import the Mullvad profiles (step 3) before this step.

### 5. Check
- `chezmoi diff` is empty, and `chezmoi doctor` shows no errors.
- Full installs: `system/install.sh --role "$role"` says `up to date` for every component.
- Personal: with the VPN off nothing gets out (`curl -m 5 https://example.com` fails); with it on, everything works.
