# Portable OpenCode settings

The bootstrap now seeds missing files only:

- `opencode.json`: existing repository server/permission defaults.
- `cli.json`: `opencode` theme, automatic/global tabs, and no automatic acceptance
  of permission requests (`session.permissions: "prompt"`).

An existing `opencode.jsonc` prevents creation of a competing `opencode.json`.
Existing JSON, JSONC, CLI files, directories, and unmanaged/dangling symlinks are
preserved, not merged, backed up, or replaced. Correct managed links are reused.
Other files, credentials, installed plugins, and service state are untouched.
This also applies to config-only and dry-run paths. To adopt a default manually,
back up and review the existing file before replacing it or merging preferences.

**Permission policy is not being migrated in this step.** The existing repository
server config still grants blanket permission via its legacy allow setting.
CLI `prompt` only avoids autoaccepting requests that do reach the client; it does
not override server-side allow rules. Existing local CLI autoaccept choices are
left intact. Changing the global permission policy is a separate explicit decision.

## Optional local provider

`examples/llamacpp.json` is a review/merge example, **not automatically installed**.
Merge the desired `providers.llamacpp` entries into your existing global JSON/JSONC
without discarding other providers, MCP servers, permissions, or model settings.
No credentials or machine-specific absolute paths belong in this example.

- `ornith15-9b` sends model ID `ornith`, matching the shared launcher's `--alias`.
- `qwen35-9b` records the previously observed HF model ID and limits for reference.
  It needs a separate matching server setup; this step provides no Qwen launcher
  or model download. Do not assume a model file/HF repository ID is the ID exposed
  by an arbitrary running server.
- Default endpoint: `http://127.0.0.1:8080/v1`. Check the running server's
  `/v1/models`, context size, and tool support before selecting a model. Capability
  declarations in this example are not a successful inference/tool-call test.
- After merging, select `llamacpp/ornith15-9b` with `/models`; this does not launch
  a server. Start it explicitly using the [background launcher](../llama/README.md).

OpenCode V2 reloads config changes automatically; `/reload` requests a full reload.
CLI preferences belong in the global `cli.json`, not project `opencode.json`.

References: [V2 configuration](https://opencode.ai/v2/docs/config),
[providers](https://opencode.ai/v2/docs/providers),
[CLI settings](https://opencode.ai/v2/docs/cli/config).
