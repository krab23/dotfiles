# Background llama.cpp launcher

This is a launcher/config layer, **not yet a llama.cpp installer**. It requires
Linux with pidfd support, Python 3.11+, and an existing `llama-server`. Normal
full bootstrap already provisions Python through Neovim; a zsh-only installation
does not install Python or llama.cpp on behalf of this optional workflow.

The zsh module links `launcher.py` as `~/.local/bin/llama-background` and defines
`ornith-start`, `ornith-stop`, `ornith-logs`, and `ornith-status`. No foreground
`ornith` alias is supplied, and shell startup/bootstrap never invokes the launcher.
You can also use `python3 /path/to/dotfiles/llama/launcher.py ...` without linking it.

## Explicit use

After installing config links and switching any old local aliases (see below):

```zsh
# Use an already-downloaded GGUF. No weight download is requested.
ornith-start --model /path/to/ornith.gguf
# Alternatively, explicitly allow llama-server's HF download/cache workflow:
ornith-start --download
ornith-status
ornith-logs
ornith-stop
```

Direct command equivalents are `llama-background start`, `status`, `logs --follow`,
and `stop`. Logs without `--follow` show the last 40 lines. `status` returns 0 for a
live managed process and 3 when stopped. Neither process status nor a successful
start confirms model/API readiness; inspect logs and `/v1/models` separately.

By default the model is served as `ornith` at `127.0.0.1:8080`. The preset in
`ornith.json` captures the current 32K-context, quantized-cache setup, with an 8192
generation limit matching the OpenCode example. It is not a universally suitable
CPU/low-memory preset. For example:

```zsh
ornith-start --model /path/to/ornith.gguf --context 4096 --predict 512
```

The existing server build chooses available backends. `--gpu-layers N` can request
an offload setting but `0` alone does not guarantee that every GPU operation is
disabled. To force CPU execution on a compatible build, use `--device none` in
the profile's `extra_args`. Runtime/backend provisioning remains a separate step;
this launcher never installs drivers/toolkits or chooses a build backend.

## Local overrides

- `LLAMA_SERVER_BIN`: executable path (including paths with spaces), otherwise
  `llama-server` on PATH. Never interpreted as a shell command.
- `LLAMA_MODEL`: local GGUF path instead of repeating `--model`. Unset it before
  using `--download`; the two choices are deliberately mutually exclusive.
- `${XDG_CONFIG_HOME:-~/.config}/llama-background/ornith.json`: optional partial
  JSON override of the checked-in profile. `LLAMA_BACKGROUND_CONFIG` selects an
  explicit alternate file. Unknown keys are rejected; no shell code is sourced.
- Start options `--port`, `--context`, and `--predict` override profile values.
- `${XDG_STATE_HOME:-~/.local/state}/llama-background/ornith/`: private state/log
  directory. `LLAMA_BACKGROUND_STATE_DIR` selects another absolute directory for
  an independent instance. Use the same setting for start/stop/status/logs.

Example local profile:

```json
{
  "context": 4096,
  "predict": 512,
  "extra_args": ["--jinja", "--no-mmproj", "--device", "none"]
}
```

`extra_args` replaces the default argument array, rather than appending to it.
Profile arguments are trusted user configuration and can change server behavior;
review them before use. The default host is loopback; changing `host` can expose
an unauthenticated model server to the network. Changing port/context/alias also
requires matching OpenCode provider settings and limits.

## Process safety and migration

Start/stop are serialized with a lock. The process record contains a PID, boot ID,
and kernel start time. Stop verifies the identity, then sends SIGTERM through a
Linux pidfd so PID reuse cannot redirect the signal. There is no `pkill` or systemd
requirement. Stop never automatically force-kills; a startup failure cleans up only
its own just-spawned child. `stop --timeout 10` retains the record if the server
does not exit. Corrupt records and unsafe file permissions fail closed;
stale identities are never signalled. Logs append in the private state directory;
rotation is manual. The server executable must remain in the foreground rather
than fork its own daemon, so the recorded process remains the server.

Existing `nohup` servers and `/tmp/ornith.log` are **not adopted**. Managed `status`
does not detect unmanaged servers or another service occupying port 8080. Stop
an old server using its known PID before migration; this change does not stop it.

The old background aliases in `~/.zshrc.local` are deliberately left unchanged and
override the shared functions. When ready to switch, back up that file, remove
only its old `ornith-start`/`ornith-stop`/`ornith-logs` alias definitions, install the
zsh config links, and open a new shell. Merely sourcing the file does not remove
already-defined aliases; in an existing shell, explicitly `unalias` those names.
There is no need to edit or rebuild `~/tools/llama.cpp` for this migration.
