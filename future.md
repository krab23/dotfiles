# Future improvements

Repository review: 2026-09-27. Follow-ups are proposed unless marked completed.
Priorities reflect practical benefit; effort is relative (S/M/L).
Evidence below records the original review; status notes describe implementation.

## Overall impression

The current structure is worth keeping. Bootstrap separates shared helpers,
distro hooks, and module orchestration well. Config backups, nonmutating previews,
isolated tests, and Neovim's verified archive installation are strong foundations.
The best next steps are a few correctness fixes and focused reductions in
duplication.

## First: correctness and compatibility

### 1. Fix the OpenCode V2 depth setting — completed 2026-09-27

- **Evidence:** `opencode.json` previously set top-level `subagent_depth: 1`. The current
  [V2 migration guide](https://opencode.ai/v2/docs/migrate-v1) explicitly lists
  that field as ignored, with `experimental.subagent_depth` as its replacement.
- **Implemented:** Moved the setting to `experimental.subagent_depth: 1`.
- **Verified:** OpenCode v2.0.18 `debug config` loads the setting without a
  warning and preserves the project worker allowlist. `debug agents` confirms
  all four worker models, variants, reasoning effort, and final nested-delegation
  deny rules. JSON assertions confirm the setting move is the only config change.
  No model calls were used for verification.
- **Activation:** Quit and restart OpenCode before relying on the setting in
  an existing session. Runtime delegation was not exercised by spawning workers.
- **Optional later:** Convert legacy `permission` and agent frontmatter to native
  V2 forms for consistency. Supported legacy forms remain compatible; this is a
  separate cleanup, not a prerequisite for fixing depth.

### 2. Preserve crontab contents when reading fails — completed 2026-09-27

- **Implemented:** Locale-stable absence detection, fail-closed reads, exact
  active-entry matching, and preservation of existing bytes/newline boundaries.
  Regression cases cover absent/commented/active jobs, unrelated entries, and
  read/write errors; the parent-run bootstrap suite passes.

- **Evidence:** `setup_docker_prune_cron` in `bootstrap/modules/docker.sh` treats
  every `crontab -l` failure as an empty crontab via `|| true`, then may install
  a new one. It also detects an existing job with a substring match, so a
  commented-out command can count as configured.
- **Idea:** Distinguish a genuinely absent crontab from other read failures;
  stop on unexpected errors and recognize an active managed entry explicitly.
- **Done when:** Mocked cases cover no crontab, unrelated existing jobs,
  commented entries, duplicate prevention, and read failure. Read failure must
  never invoke the crontab writer. Preserve opt-in behavior.
- **Confidence:** Source-level failure-path concern; no host crontab was changed.

### 3. Make Git-only installs usable without Neovim — completed 2026-09-27

- **Implemented:** Removed the shared forced editor. Isolated Git checks verify
  environment selection and local override precedence; README documents the policy.

- **Evidence:** `git/gitconfig` forces `core.editor = nvim`, while `--only git`
  installs only Git. The fallback in `zsh/zshrc` sets `EDITOR=vi`, but Git's
  explicit `core.editor` takes precedence over `EDITOR`.
- **Idea:** Choose a consistent editor policy: let the shell supply the default,
  with an explicit Git editor in `~/.gitconfig.local` when desired.
- **Done when:** An isolated Git-only setup can open an editor without Neovim,
  and existing local Git editor overrides still take precedence.

## Next: focused refactors

### 4. Share Debian-family adapter implementation — completed 2026-09-27

- **Implemented:** `bootstrap/distros/apt-family.sh` owns shared installation
  behavior. Explicit wrappers retain distro URLs, labels, and codename policy.
  Native/fallback/cross-distro codename cases and all distro execution modes pass.

- **Evidence:** `bootstrap/distros/debian.sh` and `ubuntu.sh` are nearly identical:
  OpenCode dependencies, Neovim dependencies, Docker key/repository setup, and
  package architecture lookup are repeated. Docker URL and codename handling
  carry the meaningful differences.
- **Idea:** Extract shared apt-family implementation under `bootstrap/distros/`
  with small explicit distro wrappers. Preserve Ubuntu's `UBUNTU_CODENAME`
  fallback and cross-distro dry-run placeholders.
- **Done when:** Each wrapper owns its distro-specific values, shared behavior
  has one implementation, and all three distro preview/config-only tests pass.
  Add focused cases for the distinct codename behavior before extraction.

### 5. Declare bootstrap modules once — completed 2026-09-27

- **Implemented:** `BOOTSTRAP_MODULES` in `bootstrap/lib/common.sh` drives help,
  validation, sourcing, sudo preflight, and dispatch. Regression checks confirm
  invalid-name rejection and skip precedence.

- **Evidence:** The module list appears in option help, validation in
  `bootstrap/lib/common.sh`, source statements, sudo preflight, and dispatch
  in `bootstrap/install.sh`.
- **Idea:** Use one ordered Bash array for validation, loading, preflight, and
  dispatch. Generate the CLI list from it where practical.
- **Done when:** Registering a module requires one authoritative list change;
  invalid names still fail before mutation and `--skip` still wins.
  Keep module selection independent of execution and avoid a plugin framework.

### 6. Consolidate Neovim language metadata — completed 2026-09-27

- **Implemented:** Language records generate parser, filetype, LSP, Mason, DAP,
  and smoke-sample lists. Independent coverage assertions protect the supported
  feature set. Real provisioning, LSP attachment, and debugger checks pass.

- **Evidence:** `nvim/lua/tooling.lua` already collects parsers, LSP names, and
  Mason packages, but FileType activation is separate in `nvim/init.lua`, DAP
  installation names are in `nvim/lua/plugins.lua`, and LSP sample mappings are
  in `nvim/tests/smoke.lua`.
- **Idea:** Extend the small tooling table with explicit filetypes and DAP
  identifiers. Keep distinctions such as `python` versus `debugpy`, and parser
  names versus filetypes, visible rather than inferred from string conventions.
- **Done when:** Adding a supported language has one clear declaration path;
  tests still independently assert expected language coverage.
- **Optional follow-up:** Split `plugins.lua` into UI, LSP, and DAP specs when
  editing those areas becomes cumbersome. At 272 lines, splitting alone is a
  lower-value change than consolidating duplicated metadata.

## Verification and maintenance

### 7. Add target-environment acceptance coverage — both container targets passed

- **Implemented:** `tests/acceptance.sh` launches disposable Debian 13 or Arch
  install/rerun tests with read-only source input. Manual CI runs a two-distro
  matrix and archives logs. `docs/verification.md` includes VM/WSL acceptance.
- **Verified (2026-09-27):** After Docker became available, both Arch and Debian 13
  containers passed real first installation, rerun, config preservation, tool
  startup, LSP attachment, and debugger runtime checks.
  Arch used Neovim 0.12.5, Node 26.10.0, npm 12.1.0, and OpenCode 2.0.18.
  Debian used Neovim 0.12.5, Node 24.21.0, npm 11.19.0, and OpenCode 1.18.32.
  Logs: `/tmp/opencode/acceptance-arch.log` and
  `/tmp/opencode/acceptance-debian.log` on the review host.
- **Finding:** Debian's upstream OpenCode installer delivered V1, whereas Arch's
  package delivered V2. The current acceptance check verifies executable startup,
  not the OpenCode major version. See follow-up 11 before claiming V2 provisioning
  parity across distros.
- **Remaining:** Execute the fresh VM/WSL procedure.
  Container checks and WSL-host Neovim integration do not validate fresh VM/WSL
  login sessions, Docker services, or Windows interop.

- **Evidence:** `.github/workflows/checks.yml` runs on `ubuntu-latest`. The
  primary targets are Arch, Arch/WSL2, and Debian 13; existing tests deliberately
  mock privileged commands, and Neovim network integration is manual-only.
- **Idea:** Start with a disposable Debian 13 install/rerun test, then Arch.
  Record a separate WSL2 acceptance procedure for systemd, Docker Desktop,
  Windows clipboard interop, and login-shell behavior.
- **Done when:** Results record distro/tool versions, first install, rerun,
  config preservation, and tool startup. Container package checks and actual
  VM/WSL service checks are reported distinctly.

### 8. Add lightweight static checks and a common check entrypoint — completed 2026-09-27

- **Implemented:** `bash tests/check.sh` runs syntax, ShellCheck warnings/errors,
  tracked/new JSON/TOML parsing, whitespace, and offline regressions. CI invokes
  the same entrypoint. Dependencies and narrow lint annotations are documented.
  The parent-run combined check passes with ShellCheck 0.11.0.

- **Evidence:** CI checks shell syntax and behavior but has no ShellCheck or
  general JSON/TOML parsing step. Check commands are repeated in CI and docs.
- **Idea:** Add a small offline check script used by CI and contributors;
  include ShellCheck for Bash plus parsing of tracked JSON/TOML configs.
  Keep zsh on its own syntax/behavior checks and network integration opt-in.
- **Done when:** One documented command runs the fast suite, missing check
  dependencies are clearly reported, and any lint suppressions are narrow and
  explained. Syntax parsing must not be presented as application compatibility
  validation, particularly for OpenCode V2.

### 9. Make tool-version maintenance more repeatable — completed 2026-09-27

- **Implemented:** Compatibility floors are centralized separately from archive
  pins. Provisioning/smoke reports show runtime versions and installed Mason
  source IDs; `nvim/README.md` documents the update/verification procedure.
  Integration exercised the pinned toolchain; offline newer-version reuse cases pass.

- **Evidence:** Archive versions/checksums are centralized in
  `bootstrap/lib/nvim.sh`, but minimum versions repeat across its selection and
  validation functions. Plugin commits are locked, while Mason tool releases
  follow the live registry and installed tools are reused.
- **Idea:** Centralize minimum-version constants and document a short update
  procedure covering archives, checksums, plugin lock changes, and a disposable
  integration run. Record installed Mason versions in failure reports before
  deciding whether maintaining tool pins is worth the effort.
- **Done when:** An update has a reproducible verification record and failures
  identify actual runtime/tool versions. Preserve reuse of newer compatible
  installations.

### 10. Measure startup costs before tuning — WSL baseline recorded; comparison pending

- **Implemented:** `tests/startup.py` records repeated startup timings, tool and
  environment versions, and a Neovim trace. Integration can produce an isolated
  report using `NVIM_STARTUP_REPORT`.
- **Measured:** WSL2, kernel `6.18.26.1-microsoft-standard-WSL2`, Neovim 0.12.5,
  zsh 5.9.2: five-run medians **65.86 ms zsh**, **200.03 ms headless Neovim**.
  This was a disposable provisioned editor with zsh fallback and host-available
  Starship, without Oh My Zsh; provisioning mode was enabled. It is not a full
  interactive-session benchmark. Raw report: `/tmp/opencode/dotfiles-startup-wsl.json`
  on the review host (temporary, not a repository artifact).
- **Remaining:** Measure real native Linux and SSH setups and a fully installed
  WSL shell before choosing an optimization. Clipboard behavior is unchanged.

- **Evidence:** WSL clipboard selection in `nvim/lua/clipboard/init.lua` waits
  synchronously for PowerShell, with a two-second timeout. Shell startup loads
  Oh My Zsh, Starship, and optional Cloud SDK scripts.
- **Idea:** Capture Neovim and zsh startup timings on native Linux, SSH, and
  WSL2. If the interop probe is significant, investigate deferred clipboard
  setup while retaining the broken-interop fallback.
- **Done when:** Any optimization includes before/after measurements and keeps
  clipboard selection and local shell overrides working. Current latency has
  not been measured; this is an investigation, not a confirmed performance bug.

### 11. Align upstream OpenCode installation with V2 — P1 / M

- **Evidence:** The successful Debian 13 acceptance run installed OpenCode
  `1.18.32` through `https://opencode.ai/install`; Arch installed `2.0.18`.
- **Idea:** Verify the current official V2 installation procedure, update the
  Debian/Ubuntu helper accordingly, and define how existing V1 installations
  should be reported or upgraded. Add a major-version assertion to acceptance.
- **Done when:** A fresh Debian container receives V2, reruns preserve the
  installation, and existing-install behavior is explicit and tested. Recheck
  the project depth setting using V2 configuration inspection in that environment.

## Suggested order

1. Align Debian/Ubuntu OpenCode provisioning with V2, then record the fresh VM/WSL checklist.
2. Collect native Linux, SSH, and full-shell WSL startup comparisons.
3. Consider the optional native-V2 config cleanup or plugin-spec split only when
   they simplify actual maintenance.

## Implementation verification (2026-09-27)

- Parent reviewed the worker's actual bootstrap diff and all integrated changes.
- `bash tests/check.sh`: passed (syntax, ShellCheck, config parsing, all offline suites).
- Acceptance launcher command/guard checks passed with a mocked Docker executable;
  workflow YAML parses. These checks do not establish real container installation.
- `bash tests/nvim.sh --integration`: passed on the WSL2 host. The initial run
  exposed an upstream-client shutdown timeout; the smoke test now gracefully
  stops clients, then force-cleans any remaining test clients before continuing.
- OpenCode depth/configuration was verified after reload earlier in this session.
- Arch and Debian 13 container acceptance passed. Fresh VM/WSL acceptance
  and native/SSH startup measurements remain pending as above.

## Review baseline

Passed locally on 2026-09-27:

- Bash syntax for bootstrap and test scripts; `zsh -n zsh/zshrc`.
- `bash tests/bootstrap.sh`.
- `bash tests/zsh.sh`.
- `bash tests/nvim.sh` (offline, including Lua and clipboard checks).

The Neovim suite intentionally emits errors for injected failure cases and
completed successfully. Network integration, fresh distro/WSL installs, and
OpenCode effective-configuration validation were not run in this review.
