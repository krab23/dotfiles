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

The module links `opencode/opencode.json` into the XDG config directory with
global `"permission": "allow"`. It uses the standard backup behavior for an existing
JSON config and leaves other files in the OpenCode config directory in place.
Project/agent rules and an existing global JSONC config can override the default.
Arch uses its native package; Debian/Ubuntu use the official installer with
`--no-modify-path`, reusing an executable on PATH or at `~/.opencode/bin/opencode`.
The zsh configuration already includes that user-local bin directory.

## Extending and verifying

New modules should declare their own dependencies, implement all execution modes,
and be registered in the entrypoint and module-name validation. Add regression
cases under `tests/` using isolated HOME/XDG directories and mocked privileged
commands. Never run a real bootstrap on the development host as a test.

`tests/bootstrap.sh` checks selection, command plans, nonmutation, backups, and
Docker behavior; `tests/zsh.sh` checks isolated shell startup; `tests/nvim.sh`
checks provisioning and failures. Its `--integration` mode additionally downloads
and exercises the real editor/toolchain. Fresh distro/WSL testing is a separate
acceptance step, not implied by passing mocks or host integration.

Design goals:
- Idempotent: repeated runs should be safe.
- Explicit: module-level install logic is isolated.
- Conservative: config files remain in existing paths (`zsh/`, `starship/`, `nvim/`) to preserve current live symlinks.
