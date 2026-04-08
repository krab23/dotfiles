# dotfiles

Multi-distro bootstrap for a terminal-focused setup with:
- zsh + Oh My Zsh
- starship
- neovim
- docker

Supported distro families:
- Debian (including Debian-based cloud VMs like GCP images)
- Arch (including Arch on WSL)

## Quick start

```bash
./bootstrap/install.sh
```

## Useful flags

```bash
./bootstrap/install.sh --only zsh,starship
./bootstrap/install.sh --skip docker
./bootstrap/install.sh --distro arch
./bootstrap/install.sh --dry-run
./bootstrap/install.sh --enable-docker-prune
```

## Layout

```text
bootstrap/
  install.sh
  lib/
  distros/
  modules/
nvim/
starship/
zsh/
```

Current config paths are kept as-is (`zsh/`, `starship/`, `nvim/`) so existing symlinks remain compatible.
