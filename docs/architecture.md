# Bootstrap architecture

`bootstrap/install.sh` is the single entrypoint.

It composes six modules in dependency-independent order:
- `git`
- `zsh`
- `starship`
- `nvim`
- `docker`
- `opencode`

Flow:
1. Parse and validate options/module lists.
2. Detect the distro family (`debian`, `ubuntu`, or `arch`) and resolve the normal
   login user. The invoking account and HOME must match; root execution is rejected.
3. Load distro hooks and modules; preflight sudo for real installation only.
4. Run selected modules. Each module ensures its own dependencies, so `--only`
   does not rely on another module having run first.

Common helpers:
- `bootstrap/lib/common.sh`: logging, dry-run execution, symlink + backup helpers
- `bootstrap/lib/packages.sh`: package install abstraction
- `bootstrap/lib/distro_detect.sh`: distro detection/validation
- `bootstrap/lib/nvim.sh`: pinned archive downloads with SHA256 verification,
  executable selection, version checks, and headless provisioning entry points
- `bootstrap/lib/opencode.sh`: user-local upstream installation for Debian/Ubuntu;
  distro hooks own dependencies and Arch's native package installation

## Execution modes

- Normal: ensure packages, link configs, and apply the selected module's setup.
- Config-only: link configs (and ensure Git's local-override file), without
  package installation, downloads, Neovim execution, or system changes.
- Dry-run: inspect installed state and print planned operations without mutation.
  It must work before the planned dependencies exist and must not allocate temps.

Use `run_cmd` for mutations and `run_sudo` for privileged operations. Guard direct
writes/downloads and external installers explicitly. `make_temp` registers files
for cleanup on exit, including errors/signals. Archive installation uses an
isolated staging directory on the destination filesystem.

Arch package refresh performs a full upgrade once per invocation. Debian/Ubuntu
refresh apt once, with an additional refresh after adding the Docker repository.
The distro hooks own package names and repository setup. Locale settings are
outside the bootstrap's scope.

Debian and Ubuntu wrappers provide distro-specific values and codename policy to
`bootstrap/distros/apt-family.sh`; shared apt-family installation lives there.
`BOOTSTRAP_DEFAULT_MODULES` and `BOOTSTRAP_OPTIONAL_MODULES` in
`bootstrap/lib/common.sh` declare each module once, in its selection group.
`BOOTSTRAP_MODULES` combines them into the ordered registry used by help,
validation, loading, preflight, and dispatch. Without `--only`, only defaults run;
optional modules require explicit `--only` selection. `--skip` always wins and
never enables an optional module. The optional group is empty until its installers
are implemented; defaults retain their current order and run before optionals.

## Neovim provisioning

The module ensures a compatible Neovim, Tree-sitter CLI, Node/npm/npx, compiler,
and Python toolchain, then links the configuration. Debian-family installs can
use verified archives under `~/.local/opt`; Arch uses distro packages.

Two headless processes separate plugin restoration from tool setup, so the
second process loads the restored code. `nvim/lua/provision.lua` waits for parser
and Mason installations and propagates failures. `nvim/lua/tooling.lua` declares
the languages and tools; `nvim/lazy-lock.json` pins plugins. Provisioning uses a
copy of the lockfile so it cannot rewrite the checked-in source of truth. Mason
tool releases follow the live registry; already installed tools are retained.

## OpenCode provisioning

The module seeds missing `opencode/opencode.json` and `opencode/cli.json` links in
the XDG config directory. Existing JSON/JSONC and CLI files, including unmanaged or
dangling symlinks, are preserved. A JSONC file suppresses creation of a competing
JSON file. The existing server default remains global `"permission": "allow"`;
the CLI default does not autoaccept requests but cannot override server allow rules.
Provider examples are opt-in manual merges. See `opencode/README.md`.
Project/agent rules and an existing global JSONC config can override the default.
Arch uses its native package; Debian/Ubuntu use `https://opencode.ai/v2/install` with
`--no-modify-path`, reusing an executable on PATH or at `~/.opencode/bin/opencode`.
The zsh configuration already includes that user-local bin directory.
Existing V1 binaries are reported and retained; migration is a separate explicit
operation, following upstream guidance for package-managed installations.

## Background model launcher

The zsh module also links `llama/launcher.py` as `~/.local/bin/llama-background`.
Shell functions delegate to its start/stop/logs/status commands; local aliases
retain precedence. Linking it never invokes Python, downloads weights, starts a
server, or installs llama.cpp/Python on behalf of zsh-only installs. The launcher
requires Linux/Python 3.11+, uses a private XDG state directory and advisory lock,
and validates boot/start-time identity before signalling via pidfd. Local model
paths and explicit download consent are mutually exclusive. `tests/llama.py` uses
only fake servers; see `llama/README.md` for migration and runtime overrides.

## Extending and verifying

New modules should declare their own dependencies, implement all execution modes,
and be registered in exactly one of the default/optional module lists. Add regression
cases under `tests/` using isolated HOME/XDG directories and mocked privileged
commands. Never run a real bootstrap on the development host as a test.

`tests/bootstrap.sh` checks selection, command plans, nonmutation, backups, and
Docker behavior; `tests/zsh.sh` checks isolated shell startup; `tests/nvim.sh`
checks provisioning and failures. Its `--integration` mode additionally downloads
and exercises the real editor/toolchain. Fresh distro/WSL testing is a separate
acceptance step, not implied by passing mocks or host integration.

`bash tests/check.sh` is the shared offline entrypoint for local development and
CI. See [verification](verification.md) for prerequisites and opt-in Debian/Arch
container acceptance, VM/WSL checks, and startup measurements.

Design goals:
- Idempotent: repeated runs should be safe.
- Explicit: module-level install logic is isolated.
- Conservative: config files remain in existing paths (`zsh/`, `starship/`, `nvim/`) to preserve current live symlinks.
