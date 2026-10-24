# Verification and acceptance

## Fast offline checks

```sh
bash tests/check.sh
```

Requires Git, Bash, zsh, Neovim, ShellCheck, and Python 3.11+ (`tomllib`).
On Debian 13 install check prerequisites with
`sudo apt-get install git zsh neovim shellcheck python3`; on Arch use
`sudo pacman -Syu --needed git zsh neovim shellcheck python`.
The check script does not install anything. It runs Bash/zsh syntax checks,
ShellCheck warnings/errors for Bash, JSON/TOML parsing, whitespace checks, and
all three isolated regression suites. It includes new, nonignored source files.
JSON/TOML parsing checks syntax, not application schemas or OpenCode compatibility.

Individual suites remain available as `bash tests/bootstrap.sh`,
`bash tests/zsh.sh`, and `bash tests/nvim.sh`. CI uses the same check entrypoint
and additionally checks committed whitespace.

## Real Neovim integration

```sh
bash tests/nvim.sh --integration
```

This downloads binaries/plugins/tools and compiles parsers in a disposable HOME.
See [Neovim prerequisites](../nvim/README.md). It tests actual LSP attachment and
debugger runtimes and prints runtime versions and Mason receipt source IDs.
The smoke test gives LSPs time to shut down gracefully, then force-stops remaining
test clients so upstream shutdown behavior does not prevent later samples.

For a failed run that needs investigation, set `NVIM_TEST_KEEP=1` to retain the
isolated directory printed at exit. Its `home/` contains the config, plugins,
Mason receipts/logs, and binaries. Remove that directory after investigation.
When reusing it, set HOME and all XDG directories to that environment, prepend
its `.local/bin` to PATH, and unset `NVIM_APPNAME`, `VIMINIT`, and `EXINIT`.
Never point a diagnostic rerun at your real HOME accidentally.

## Debian 13 and Arch container acceptance

With a running local Docker engine:

```sh
bash tests/acceptance.sh debian
bash tests/acceptance.sh arch
```

These are opt-in network tests. They use `debian:13` and `archlinux:base` on
linux/amd64, mount the repository read-only, and copy sources into a disposable
container. The host HOME and Docker socket are not mounted in the guest, and
the container is not privileged. A normal guest user with sudo runs the real
bootstrap twice with `--skip docker`.

Each run records the distro/kernel and tool versions and checks:

- First installation and rerun complete successfully.
- Existing shell config is backed up once and the link is reused.
- Git local identity and the checked-in Neovim lock survive unchanged.
- zsh, Git, Starship, OpenCode, Neovim, LSPs, and debugger runtimes start.
- OpenCode reports a V2 version (a working V1 executable is not sufficient).

Use the **Dotfiles checks** manual workflow's `distro_acceptance` input for the
same Debian/Arch matrix in CI. Logs are uploaded even on failure. Images and
repositories are live, so archive the logs with the commit under test.
The guest scripts are internal to this runner, not host setup commands.

Containers do not validate Docker Engine installation/services, login sessions,
or Windows integration. Complete those in disposable VMs/WSL below.

## Fresh VM / WSL2 acceptance record

Create a fresh Debian 13 VM, native Arch VM, or Arch WSL2 instance with networking
and a normal sudo-capable account. Clone the commit under test into a permanent
user-owned path. Record the commit, `/etc/os-release`, `uname -srmo`, terminal,
and (on Windows) `wsl --version` before beginning.

1. Seed an existing `.zshrc` and `.gitconfig.local`; save copies. Run
   `bash bootstrap/install.sh --dry-run` and verify no config files changed.
2. Run `bash bootstrap/install.sh` as the normal account. Save output and tool
   versions. Verify configs point into the checkout and the original `.zshrc`
   exists in exactly one backup. Verify Git identity is preserved.
3. Log out/in. Check the login shell, `EDITOR`, PATH, prompt, `git var GIT_EDITOR`,
   and a local override in `.zshrc.local`.
4. On a systemd/local-engine machine, check `systemctl is-active docker` and
   `docker info` without sudo after relogin. Rerun bootstrap and verify no extra
   backups, duplicate groups/jobs, or lockfile changes. Leave prune disabled
   unless specifically testing its opt-in behavior on disposable Docker data.
5. On WSL2 with Docker Desktop integration, check the selected context/socket,
   run the Docker module, and confirm it skips local service/group/prune setup.
   Separately test WSL2 without systemd for the documented startup guidance.
6. Open Lua, TypeScript, Python, and C++ projects in Neovim; check LSP attachment,
   a Python launch and a compiled C++ debug launch. Authenticate Copilot manually
   only if testing that optional integration.
7. WSL: copy/paste Unicode and multiline text through Windows clipboard tools.
   In a separate disposable WSL instance with interop disabled, confirm the
   graphical-provider/OSC52 fallback and absence of startup errors.
8. SSH: use a real SSH connection and terminal with OSC52 support. Confirm copying
   works and paste remains the terminal shortcut/local register behavior.

Record pass/fail/untested per step, first-install/rerun logs, exact tool versions,
and any recovery steps. Passing container or host integration tests does not
complete this record.

## Startup measurements

For an already provisioned environment:

```sh
python3 tests/startup.py --label 'arch-wsl2; OMZ+Starship; Windows interop' \
  --output /tmp/startup-wsl.json
```

Use a new output path. This starts the current user's configured interactive
zsh and headless Neovim five times, reports wall-clock samples/medians, and saves
a Neovim `--startuptime` trace. Ordinary startup files/plugins can perform their
normal work, including downloads if the environment has not been provisioned.
It does not change configs or install prerequisites itself.

For an isolated baseline, set `NVIM_STARTUP_REPORT` to an absolute output file
when running `tests/nvim.sh --integration`. That measures the disposable Neovim
toolchain and zsh fallback; it does not include an installed OMZ/Starship setup
unless those are actually available there. Reports record provisioning mode.

Collect real native Linux, SSH, and WSL2 runs with the same terminal/tool versions
and integrations before choosing an optimization. The first run may be colder
than subsequent runs, so retain all samples. Headless Neovim timing is not an
interactive UI responsiveness benchmark. WSL clipboard probes remain synchronous
until measured evidence justifies changing their behavior.
