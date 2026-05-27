# Bootstrap architecture

`bootstrap/install.sh` is the single entrypoint.

It composes four modules:
- `zsh`
- `starship`
- `nvim`
- `docker`

Flow:
1. Detect distro family (`debian`, `ubuntu`, or `arch`)
2. Load distro-specific installers from `bootstrap/distros/<family>.sh`
3. Run selected modules from `bootstrap/modules/*.sh`

Common helpers:
- `bootstrap/lib/common.sh`: logging, dry-run execution, symlink + backup helpers
- `bootstrap/lib/packages.sh`: package install abstraction
- `bootstrap/lib/distro_detect.sh`: distro detection/validation

Design goals:
- Idempotent: repeated runs should be safe.
- Explicit: module-level install logic is isolated.
- Conservative: config files remain in existing paths (`zsh/`, `starship/`, `nvim/`) to preserve current live symlinks.
