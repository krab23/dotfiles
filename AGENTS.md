# Working in this repository

## Intent and scope

This repository holds personal configs and bootstraps a **post-install** terminal
development environment: Git, zsh/Oh My Zsh, Starship, Neovim, and Docker.
Primary targets are native Arch x86-64, Arch on WSL2, and Debian 13 x86-64
(including a GCP VM). Assume a bootable OS, networking, and a normal user with
sudo access. OS installation, partitioning, and user creation are outside scope.

Preserve existing work and configs. Keep distro package logic in
`bootstrap/distros/`, shared helpers in `bootstrap/lib/`, and module orchestration
in `bootstrap/modules/`. Config-only and dry-run paths must not install software
or change system settings. Never run a real bootstrap against the development
host merely to test a change; use mocks or a disposable environment.

## Parent ownership

- The parent owns user communication, task decomposition, integration, **all code
  review**, and final verification. Never delegate a review, audit, second
  opinion, or final acceptance to another model, including another Astra.
- Workers may implement bounded changes and run focused checks of their own work.
  Their test reports are evidence, not a substitute for parent review.
- The parent inspects the actual diff and runs the relevant independent checks
  before reporting completion. Explain any checks that could not be performed.
- Ask at most four clarification questions at a time.

## Complexity-based delegation

Delegation is permitted under this policy, not required. Do tiny edits and quick
lookups directly when delegation would cost more context than it saves. Choose
the lowest tier that can reliably complete the task; number of files alone is
not a complexity measure.

| Work shape | Task agent | Configured model | Effort | Call ceiling |
| --- | --- | --- | --- | --- |
| Clear, low-complexity work with a known approach: targeted lookup, docs update, mechanical edit, isolated regression case | `luna` | `openai/gpt-5.6-luna` | low | 4 |
| Moderate implementation requiring local reasoning: a module fix or small refactor with defined interfaces | `sol-medium` | `openai/gpt-5.6-sol` | medium | 2 |
| More complex but bounded implementation: subtle compatibility or cross-file logic with an established objective | `sol-high` | `openai/gpt-5.6-sol` | high | 1 |
| Multi-step complex implementation requiring the worker to develop its own plan and resolve interdependent decisions | `astra-complex` | `openai/gpt-6-astra` | high | 1 |

These are ceilings, not quotas. Counts apply per user task and include resumed
worker calls, retries, and replacement workers. Do not reset the count for each
internal phase. For mixed tiers, use the highest tier's ceiling for the total
number of worker calls; do not stack allowances. If escalation would exceed the
ceiling, finish in the parent or ask the user before spending additional calls.
Keep a brief count alongside the task plan when delegating.

Parallel workers are allowed only for independent tasks with disjoint file
ownership, within the same ceiling. Prefer one worker when there is no clear
benefit to parallelism. Never give two workers different functions in the same
file: shared-file integration belongs to the parent.

Workers must not spawn workers, change their assigned model/effort, or invoke
another model through the shell/API. An Astra worker can plan its own assigned
implementation; it is not a second orchestrator or reviewer. If a task exceeds
its assignment, it returns the blocker to the parent rather than expanding scope.

## Worker handoff

Every delegation must name:

1. A concrete deliverable and acceptance criteria.
2. The selected tier and a brief reason it fits.
3. Exact writable files/directories, interfaces to preserve, and relevant context.
4. Focused checks to run, and any network/download constraints.
5. A request for a concise result: changed files, decisions, checks/results, blockers.

Send only the necessary context. Do not ask each worker to rediscover the whole
repository. Do not duplicate delegated implementation in the parent. Workers
must preserve unrelated changes and must not commit unless explicitly instructed.
Avoid speculative refactors, repeated full integration downloads, and extra
agents just to summarize results.

## Routing and enforcement

Project-local agent definitions live in `.opencode/agents/`; `opencode.json`
allows only those named workers through the Task permission rules. Each worker
has nested Task calls denied. Use these named agents, not model-inheriting
`general`/`explore` fallbacks. If the current harness does not expose the named
agents, work in the parent or ask to restart/configure the harness; do not silently
substitute a different model. Avoid `-fast`/priority variants unless requested.

Model/effort selection and Task permissions are runtime configuration. Complexity
classification, call ceilings, and parent-only review are instructions the parent
must enforce; they are not automatic credit limits. Availability and actual
billing depend on the configured provider. After changing agent configuration,
quit and restart OpenCode. Validate locally with `opencode debug agent <name>`;
do not spend model calls just to test routing.

## Verification

Choose checks for the files actually changed:

- Shell syntax: `bash -n <script>` or `zsh -n zsh/zshrc`.
- Bootstrap behavior: `bash tests/bootstrap.sh`.
- Shell startup behavior: `bash tests/zsh.sh`.
- Neovim provisioning logic: `bash tests/nvim.sh`.
- Neovim integration: `bash tests/nvim.sh --integration` only when runtime changes
  justify downloading binaries/plugins/tools into its disposable environment.
- Patch hygiene: `git diff --check`.

Run tests once at the appropriate scope. Repeat only for new changes, failures,
or unresolved concerns. A mocked test or host integration run does not establish
that a fresh Debian VM or WSL install has been tested.
