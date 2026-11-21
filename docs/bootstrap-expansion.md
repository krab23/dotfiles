# AI tooling: inventory and bootstrap expansion

Inventory recorded 2026-11-21 on Arch Linux under WSL2. This is a scoped snapshot
and implementation plan, not a claim of fresh-install or inference validation.
Paths below use `~` instead of a specific username. During the initial inventory,
no live configuration was changed, no bootstrap was run, and no model was
downloaded or started. Implementation follow-ups are recorded separately below.

## Agreed scope

- Antigravity and llama.cpp are **optional**, excluded from the default install.
- llama.cpp supports a CPU build and an explicitly selected GPU backend.
  Recommend CPU and CUDA first because this host provides CUDA build evidence;
  Vulkan/HIP remain future extensions, not promised support.
- Inventory existing aliases before deciding what to promote into shared config.
- Preserve local overrides, existing installations, and unrelated repository work.

## Observed installation and configuration

### OpenCode

- `~/.opencode/bin/opencode` reports `v2.2.5`.
- The repository already has an installer module. Its managed global config,
  `opencode/opencode.json`, contains only the schema and legacy
  `"permission": "allow"` setting.
- This host instead has a regular `~/.config/opencode/opencode.jsonc`; no sibling
  `opencode.json` was present. Its additional `providers.llamacpp` definition uses
  `@opencode/ai/providers/openai-compatible` at `http://127.0.0.1:8080/v1`.
- Two text/tool-capable models are declared:

  | Config ID | Upstream model ID | Context / output limit |
  | --- | --- | --- |
  | `qwen35-9b` | `unsloth/Qwen3.5-9B-GGUF:Q4_K_M` | 8192 / 2048 |
  | `ornith15-9b` | `ornith-ai/Ornith-1.5-9B-GGUF:Q4_K_M` | 32768 / 8192 |

- A separate, unmanaged `cli.json` selects the `opencode` theme, global tabs in
  automatic mode, and `session.permissions: "autoaccept"`.
- `package.json` declares `@opencode-ai/plugin`; generated dependencies and a
  lockfile are also present. Presence alone does not establish a custom plugin
  requirement. `service.json` and runtime data are not portable preferences.
- The repository-root `opencode.json` and `.opencode/agents/` are project-specific;
  do not automatically promote their delegation policy into global settings.

Portable candidates: reviewed CLI preferences and a local-provider example.
Automatic permission acceptance and the existing global allow policy require
explicit review; recording current behavior is not approval to broaden it.
Keep the local endpoint, model selection, and host resource limits overridable.

Before linking more files, resolve the existing JSON/JSONC arrangement explicitly
and preserve the local provider settings. Do not assume writing `opencode.json`
will replace the active JSONC configuration or safely merge its contents.

### Antigravity CLI

- `~/.local/bin/agy` is a regular ELF executable reporting version `1.5.14`, with
  no pacman ownership reported. The original download/install source and artifact
  verification procedure have not yet been established.
- `agy --help` confirms session model/mode/effort flags, session-only `--settings`,
  and `install`/`update` subcommands. No install, update, login, or model call was run.
- Preferences live in `~/.gemini/antigravity-cli/settings.json`. Observed top-level
  fields are `model`, `orchestrator`, and `trustedWorkspaces`. The model is
  `Gemini 4 Neon (Medium)` and the orchestrator contains a `planner` field.
- `keybindings.json` is a JSON object with 42 entries; bindings have not yet been
  reviewed for portability or default-generated values.
- The same directory contains OAuth state, conversations, histories, databases,
  logs, caches, and installation state. Authentication-related files also exist
  under `~/.config/antigravity/` and elsewhere under `~/.gemini/`.
- Related shared integration metadata exists in `~/.gemini/config/`, and separate
  IDE/server installations are present. Their configuration is not part of the
  initial CLI scope and must not be copied wholesale.
- The existing uncommitted change in `zsh/zshrc` is an installer-added, hardcoded
  `~/.local/bin` PATH export. The shared zsh config already adds `$HOME/.local/bin`.
  Leave this user-owned change untouched during inventory.

Portable candidates: reviewed preferences and intentional keybindings only.
Exclude trusted workspace paths and all authentication/runtime data. Confirm the
supported settings location and update behavior before managing individual files;
do not symlink the whole application directory.

### llama.cpp

- Source checkout: `~/tools/llama.cpp`, from upstream `ggml-org/llama.cpp`.
- Checkout reports tag `b12021`, commit `7bd180830821`, and a clean Git working tree.
  These identify the observed source, not an independently verified binary build.
- `~/.local/bin/llama-server` links to that checkout's `build/bin/llama-server`.
  `llama-cli` is also built but is not on PATH. `llama-bench` is not on PATH.
- CMake cache: Release build, `GGML_CUDA=ON`, `GGML_NATIVE=ON`, CUDA architecture
  `120`, server enabled; BLAS, HIP, and Vulkan disabled.
- CUDA compiler and WSL NVIDIA utility are available on PATH. No GPU runtime or
  inference test was performed. Architecture `120` is a host-specific build choice,
  not a portable default.
- No llama/OpenCode/Antigravity-named unit was found among top-level user service
  filenames. This does not rule out differently named or system-level services.
- `~/models` exists and was empty. Actual downloaded model/cache locations and
  available disk/RAM/VRAM were not established; model weights were not inspected.

Preserve the existing checkout and symlink. A future installer should use its own
managed, versioned location unless the user explicitly chooses migration.

## Complete local zsh alias inventory

`~/.zshrc.local` contains four aliases and one descriptive comment; there were no
additional aliases or functions in that file. It was read as text, not sourced.

| Alias | Current behavior | Portability / safety follow-up |
| --- | --- | --- |
| `ornith` | Run the local Ornith server in the foreground | Use an overridable executable and model profile instead of a hardcoded build path |
| `ornith-start` | Run the same command via `nohup`, logging to `/tmp/ornith.log` | Track the specific process; use a user-owned state/log directory |
| `ornith-stop` | `pkill -f "llama-server.*Ornith-1.5-9B"` | Replace broad command-pattern matching with instance-specific stopping |
| `ornith-logs` | `tail -f /tmp/ornith.log` | Share the launcher's configurable log path |

Both launch aliases use the same options:

```text
-hf ornith-ai/Ornith-1.5-9B-GGUF:Q4_K_M
--alias ornith --jinja --no-mmproj
--host 127.0.0.1 --port 8080
-c 32768 -n 16384 -np 1 -fa on -ctk q8_0 -ctv q8_0
```

The `-hf` launch path can download weights when invoked: preserve this distinction
between installing a runtime and fetching/running a model. Context, output, flash
attention, and cache settings are observed tuning, not universal CPU defaults.
The server alias `ornith` differs from OpenCode's upstream model ID; check actual
`/v1/models` and request behavior before deciding whether mapping changes are needed.

Follow-up applied locally: removed only the foreground `ornith` alias, retaining
the three background-management aliases (`ornith-start`, `ornith-stop`,
`ornith-logs`) byte-for-byte. A timestamped `~/.zshrc.local.backup.*` preserves the
original. Already-open shells can remove the old alias with `unalias ornith`.
Shared background functions now wrap the managed launcher, with local overrides
loaded last. The three local aliases still take precedence until explicitly
migrated; no existing server is adopted or stopped. See `llama/README.md`.

## Proposed implementation order

The optional-selection and portable-config/launcher steps are implemented below.
The Antigravity/llama.cpp installer modules remain future work, not options
available today.

1. **Optional module selection — implemented.** The current six modules remain in
   `BOOTSTRAP_DEFAULT_MODULES`; `BOOTSTRAP_OPTIONAL_MODULES` is empty until the new
   installers land. Their concatenation forms the complete registry. Optional
   modules require `--only`, and `--skip` wins. Fixture-based tests exercise future
   `antigravity`/`llamacpp` entries without registering unfinished installers or
   performing real installations. These proposed module names are not yet accepted
   by the production CLI.
2. **Portable shell and OpenCode configuration — implemented.** The zsh module
   links a background-only launcher and defines start/stop/logs/status functions,
   preserving `~/.zshrc.local` precedence. The shared Ornith profile is locally
   overridable; local weights or explicit `--download` consent are required.
   OpenCode seeds only missing JSON/CLI files, preserves JSONC and all existing
   settings, and provides an opt-in provider merge example. Missing CLI config gets
   the theme/global-tab preferences without automatic request acceptance; existing
   server permission policy and local autoaccept choices are not changed. The
   redundant hardcoded Antigravity PATH addition was removed with user approval.
3. **llama.cpp runtime module.** Use a pinned source revision or verified release
   artifact, with CPU as the default within this optional module and explicit CUDA
   selection. Keep backend dependencies in distro adapters and download/build logic
   in shared helpers. Backend changes must not accidentally reuse incompatible
   CMake state or binaries. Validate toolkits without silently selecting a backend
   or installing/replacing GPU drivers; document WSL's host-driver prerequisite.
4. **Antigravity module.** Establish the official installation source, release
   policy, verification mechanism, supported platforms, and whether its installer
   can avoid shell-file edits. Reuse compatible installations conservatively.
   Provision only reviewed preference files, preserving trust/authentication state;
   login remains a manual post-install step.
5. **Separate optional model and server workflows.** Runtime bootstrap must not
   download weights, start inference, or enable a service. Provide explicit model
   fetch/run instructions, configurable storage and resource limits, and loopback
   binding by default. Service enablement, if added, is a separate opt-in and must
   not require systemd for manual use.

## Verification and completion criteria

- Test default exclusion, explicit selection, skip precedence, and malformed
  backend/module arguments before any mutation.
- Use isolated HOME/XDG directories and mocks for installs, downloads, builds,
  process control, backups, JSON/JSONC coexistence, and local override precedence.
- Dry-run creates nothing and runs no installers/builds/model requests. Config-only
  links selected configs without installing tools, downloading weights, changing
  system settings, or starting services.
- Verify repeated runs reuse compatible installs and preserve unmanaged files,
  trust decisions, credentials, and the existing llama.cpp checkout.
- Run relevant bootstrap/zsh regressions and `git diff --check` for implementation.
  Use disposable environments for real CPU installation and optional model smoke
  tests. Record GPU/WSL acceptance separately; host CMake metadata is not GPU support
  validation.
- Version/help commands and static metadata inspection establish the inventory
  observations above, not application interoperability.

## Optional-selection implementation verification (2026-11-21)

- `TMPDIR=/tmp/opencode bash tests/check.sh` passed shell syntax, ShellCheck,
  config parsing, whitespace checks, and the complete bootstrap regression suite,
  including the new optional-module fixture cases. It then stopped at the zsh
  startup test: the pre-existing hardcoded PATH addition in `zsh/zshrc` leaks the
  host path into the isolated shell. That user-owned change was not altered.
- The zsh suite passed in a disposable copy using the committed `zsh/zshrc`,
  confirming the baseline without modifying the working-tree file.
- `TMPDIR=/tmp/opencode bash tests/nvim.sh` passed offline checks separately;
  injected failure-case diagnostics are expected. No network integration was run.
- `zsh -n ~/.zshrc.local` passed. Comparison against the local backup verified that
  only the foreground alias line was removed and the background aliases survived
  unchanged. No real bootstrap, model launch, or service change was performed.

## Portable-config/launcher verification (2026-11-21)

- `TMPDIR=/tmp/opencode bash tests/check.sh` passed the complete offline suite:
  syntax/ShellCheck, JSON/TOML parsing, bootstrap regressions, nine fake-server
  launcher tests, isolated zsh startup/override checks, and Neovim offline tests.
  The previous PATH-related shell failure is resolved by the approved removal.
- Launcher checks cover explicit download consent, local paths with spaces,
  lifecycle/idempotence, private state permissions, stale identity rejection,
  corrupt records, symlink rejection, early exit, stop timeout, locking, and logs.
  Only fake servers ran; no real model, GPU, API, or inference request was used.
- Bootstrap tests cover JSON/JSONC coexistence, missing-only CLI defaults, existing
  autoaccept preservation, dangling links, XDG paths, config-only nonmutation of
  runtime state, and new launcher links. Shell tests verify delegation/quoting,
  no startup launch, local alias precedence, and absence of a foreground helper.
- The acceptance runner's source-copy list includes `llama/`; real container,
  fresh VM/WSL, GPU, and OpenCode provider interoperability runs were not performed.
- Focused launcher tests passed again after final file-safety/kernel-support
  hardening. The acceptance script passed ShellCheck, and a read-only archive check
  verified that its actual source list includes the executable launcher, profile,
  and OpenCode files. Python syntax and new-file whitespace checks also passed.
- Live OpenCode files and local background aliases were not rewritten. The runtime
  launcher symlink has not been installed into this host as a test; migration is
  explicit and documented in `llama/README.md` and `opencode/README.md`.

References checked: [OpenCode V2 config](https://opencode.ai/v2/docs/config),
[CLI settings](https://opencode.ai/v2/docs/cli/config), and
[llama.cpp build guide](https://github.com/ggml-org/llama.cpp/blob/master/docs/build.md).
Recheck upstream instructions against the selected versions during implementation.
