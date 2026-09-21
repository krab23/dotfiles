# dotfiles

Personal dotfiles and a **post-install** bootstrap for Git, zsh + Oh My Zsh,
Starship, Neovim, Docker, and OpenCode. Running without module flags installs the full setup.

Primary targets:
- Native Arch Linux x86-64
- Arch Linux x86-64 on WSL2
- Debian 13 x86-64, including a GCP VM

The Ubuntu adapter is retained on a best-effort basis; it is outside the primary
verification target set. Distro-family detection is not a guarantee of support
for every derivative, release, or architecture.

## Quick start

Start with a bootable OS, networking, Git, and a normal user with working sudo
access. Run from that user's login session, **without `sudo` in front of the
bootstrap**. The script elevates individual system commands. It does not install
the OS, create users, or change the existing system locale.
The target username comes from the logged-in account (for example, `krab`), not
a hardcoded default.

If Git is missing, install it first:

```sh
# Arch
sudo pacman -Syu --needed git
# Debian 13
sudo apt-get update
sudo apt-get install -y git
```

Clone this repository into a permanent user-owned location, such as
`~/repos/dotfiles`, and run from its root:

```sh
./bootstrap/install.sh --dry-run
./bootstrap/install.sh
```

**Arch performs a full `pacman -Syu`** before installing selected packages, to
avoid partial upgrades. Debian refreshes apt metadata and installs dependencies;
Docker Engine uses Docker's upstream apt repository. Downloads also use GitHub,
nodejs.org, npm, PyPI, and the Oh My Zsh/Starship/OpenCode installers.

Full Neovim provisioning downloads plugins, builds parsers, and installs language
servers and debuggers. See [the Neovim guide](nvim/README.md) for version pins,
languages, runtime dependencies, and troubleshooting.

## Useful flags

```bash
./bootstrap/install.sh --only zsh,starship
./bootstrap/install.sh --skip docker
./bootstrap/install.sh --only git,nvim --config-only
./bootstrap/install.sh --only opencode
./bootstrap/install.sh --dry-run
./bootstrap/install.sh --config-only --dry-run
./bootstrap/install.sh --distro debian --dry-run
./bootstrap/install.sh --enable-docker-prune
```

- `--only` and `--skip` accept `git,zsh,starship,nvim,docker,opencode`; skip wins if both
  name the same module. Unknown names and malformed lists fail before changes.
- `--config-only` links the selected configs and creates the Git local-override
  file if missing. It does not install software, run Neovim, change the login
  shell, or configure Docker. Starting Neovim later can still download tools.
- `--dry-run` reads the current state and prints planned changes without creating
  files or running installers. It can preview tools that are not installed yet.
- `--distro` overrides detection; use it for previews or a compatible host, not to
  install one distro's packages on another.
- Docker prune is opt-in: `docker system prune -f` daily at 03:00 in the user's
  crontab. It requires an installed, running cron service and a usable local
  Docker engine; if `crontab` is absent, the script reports that setup was skipped.

## Configs, local settings, and recovery

| Repository path | Installed link |
| --- | --- |
| `git/gitconfig` | `~/.gitconfig` |
| `zsh/zshrc` | `~/.zshrc` |
| `starship/starship.toml` | `${XDG_CONFIG_HOME:-~/.config}/starship.toml` |
| `nvim/` | `${XDG_CONFIG_HOME:-~/.config}/nvim` |
| `opencode/opencode.json` | `${XDG_CONFIG_HOME:-~/.config}/opencode/opencode.json` |

Keep the checkout in place: the links point into it. Existing files, directories,
and incorrect symlinks are moved beside their original path as
`<target>.backup.<timestamp>` (with numbered suffixes if needed). Correct links
are reused. Run only one bootstrap instance at a time.

To restore a previous config, remove **the installed symlink**, then move the
desired backup back to the original path. This does not uninstall packages or
undo shell/group/service changes. Before retrying a failed run, read the failure
message; completed steps are generally reused.

- Put your Git identity and machine-specific settings in `~/.gitconfig.local`:

  ```ini
  [user]
    name = Your Name
    email = you@example.com
  ```

  An existing `.gitconfig` is backed up, not merged automatically. Copy any
  identity, signing, or credential configuration you need into the local file.
- Put machine-specific shell settings and aliases in `~/.zshrc.local`, which is
  loaded last. Optional Starship, Oh My Zsh, and Google Cloud SDK integrations are
  guarded. Existing `LANG` and `LC_*` settings are preserved. If `LANG` is unset or
  empty, zsh defaults to `C.UTF-8`. This is a shell-only
  fallback: no locale generation or system config edits occur.
- `~/.local/bin` is added by the zsh config. Debian's Neovim/Tree-sitter and, when
  needed, Node binaries live under `~/.local/opt` with links in this directory.
- OpenCode's global config sets `"permission": "allow"`. Project and agent-specific
  permissions can override this default, as can an existing global `opencode.jsonc`.
  Existing `opencode.json` files are backed up, not merged; copy any provider/model
  settings you need from the backup. Quit and restart OpenCode after config changes.
  The repository-root `opencode.json` is the separate project configuration.
- Arch installs the `opencode` package. Debian/Ubuntu use the official installer
  under `~/.opencode/bin`, reusing an existing installation. The zsh config already
  adds that directory to PATH; with another shell, add it yourself or launch
  `~/.opencode/bin/opencode`. The installer runs with `--no-modify-path`.

Both `C.UTF-8` and `en_US.UTF-8` support Unicode. `en_US.UTF-8` supplies US English regional
conventions; `C.UTF-8` uses the simpler C conventions with UTF-8 support. `LANG`
provides the default, individual `LC_*` variables override specific categories
(such as `LC_TIME` for dates), and `LC_ALL` overrides every category. A setting
in `~/.zshrc.local` still takes precedence over the shell's default.

## After installation

1. Log out and back in for the zsh login-shell and Docker group changes to apply.
2. On systemd hosts, the local Docker service is enabled and started. On WSL2
   without systemd, enable systemd and restart WSL or use Docker Desktop
   integration. Detected remote, rootless, and Desktop engines are left managed
   by their existing setup. The local `docker` group grants root-equivalent access.
3. Run `:Copilot setup` in Neovim to authenticate; on an SSH VM use
   `:Copilot! setup` and open the displayed URL locally.
4. Use a Nerd Font in your local terminal for prompt/editor icons. On native
   Linux, install `wl-clipboard` (Wayland) or `xclip`/`xsel` (X11) if needed.
   WSL uses Windows clipboard tools when available; SSH can use OSC52 copying.

## Updates and checks

Rerunning bootstrap ensures packages/configs and restores the checked-in Neovim
plugin lock. Compatible existing Neovim/Node/Tree-sitter binaries and installed
Mason tools are reused. It is not a universal updater: Oh My Zsh and an existing
Debian Starship/OpenCode installations use their own update mechanisms. Update archive
version/checksum pins together in `bootstrap/lib/nvim.sh`; use `:Lazy update`
deliberately and review `nvim/lazy-lock.json` afterward.

```sh
bash tests/bootstrap.sh
bash tests/zsh.sh
bash tests/nvim.sh
# Optional: downloads binaries, plugins, parsers and tools into a disposable HOME.
bash tests/nvim.sh --integration
git diff --check
```

Offline checks use isolated homes and mocked system/network commands. Neovim
integration verifies real tool installation, LSP attachment, and debugger
runtimes on the test host. Neither substitutes for a fresh Debian VM or WSL2
installation test. CI runs the offline checks; network integration is optional.

## Layout

```text
bootstrap/
  install.sh
  lib/
  distros/
  modules/
git/
nvim/
opencode/
starship/
zsh/
tests/
docs/
```

See [architecture](docs/architecture.md) for extension points and [AGENTS.md](AGENTS.md)
for coding-agent ownership, delegation budgets, and verification rules.
