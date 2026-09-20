# Neovim

Portable setup for **Linux x86_64**: native Arch, Arch on WSL2, and Debian 13
(including a headless GCP VM). Run bootstrap as your normal login user with sudo
access, from the repository root:

```sh
bash bootstrap/install.sh --only nvim
# Link config only: no packages, binary downloads, or headless Neovim execution.
bash bootstrap/install.sh --only nvim --config-only
```

The config is linked to `${XDG_CONFIG_HOME:-$HOME/.config}/nvim`, backing up an
existing target. Plugins, parsers and Mason tools use Neovim's XDG data directory.
The provisioning commands target the default `nvim` app, even if `NVIM_APPNAME`
is set. Config-only defers plugin/tool installation until you actually start
Neovim; it does not turn this into an offline editor configuration.

## Versions and system dependencies

The retained `lazy-lock.json` requires **Neovim 0.12.0+**, not merely 0.11:

- [Locked nvim-treesitter requirements](https://github.com/nvim-treesitter/nvim-treesitter/blob/4916d6592ede8c07973490d9322f187e07dfefac/README.md):
  Neovim 0.12+, tree-sitter CLI **0.26.1+**, C compiler, curl and tar.
- The locked nvim-lspconfig uses the `vim.lsp.config`/`vim.lsp.enable` APIs;
  its own minimum is 0.11.3. The Tree-sitter requirement takes precedence.
- Provisioning baseline: **Neovim 0.12.5**, **tree-sitter CLI 0.26.9**,
  **Node.js 22+ with working npm/npx 10+**, Python 3 with pip/venv and pynvim.
  Debian-family fallback: official **Node.js 24.21.0 LTS** (bundled npm/npx 11.19.0).
  Release versions, URLs and SHA256 pins for all three archives are centralized
  in `bootstrap/lib/nvim.sh`, also used by the integration tests.

Arch uses distro packages, including `base-devel`, `tree-sitter-cli`, Node/npm,
Python/pip/pynvim, Git, curl, CA certificates, ripgrep, tar, gzip, unzip and xz.
Arch Python includes `venv`. Keep Arch updated; the package helper performs a
full upgrade before installing packages.

Debian installs equivalent dependencies (`build-essential`, `python3-venv`,
etc.) and debugger runtime libraries via apt. The Neovim archive is unpacked to
`~/.local/opt/nvim-0.12.5`, with a stable `~/.local/bin/nvim` symlink. The CLI
uses `~/.local/opt/tree-sitter-0.26.9` and `~/.local/bin/tree-sitter`. Downloads
use HTTPS with HTTP failure checking and pinned SHA256 digests from the upstream
release assets. No AppImage, FUSE, or repository-local executable is involved.
Debian 13's packaged **Node 20.19.2 is insufficient**. If the existing/distro
Node/npm/npx toolchain fails the checks, the official Node LTS archive from
`nodejs.org` is verified against its pinned `SHASUMS256.txt` digest and unpacked
to `~/.local/opt/node-24.21.0`. The complete archive layout is retained, with
working `node`, `npm` and `npx` links in `~/.local/bin`. A completed bundle can
repair missing links without another download.

Compatible existing binaries/toolchains on PATH are reused, including newer
releases. Before prepending `~/.local/bin`, the installer records those selections
and backs up/relinks conflicting local executables so that provisioning and
future shells use the same selection. It then checks the final PATH directly.
Arch continues using distro packages and does not install the Node archive.
Unsupported architectures fail before package installation/downloads.

For subsequent shells, ensure the user binary directory precedes an older system
Neovim (bootstrap sets PATH for its own provisioning process):

```sh
export PATH="$HOME/.local/bin:$PATH"
nvim --version
tree-sitter --version
node --version
```

If migrating from the former AppImage installer, an old `/usr/local/bin/nvim`
may still exist. Check `command -v nvim` and PATH order. The Ubuntu distro hook
shares the archive installer and Node fallback. Debian 13 is the supported
Debian-family target for package selection; older Ubuntu systems must also meet
the official archives' runtime/glibc requirements.

## What full provisioning does

1. Installs prerequisites and checks executable versions.
2. Links this configuration and bootstraps lazy.nvim at its locked commit.
3. Restores all plugin commits from the lockfile, checking the resulting Git
   revisions. A working lockfile copy protects the repository lock during this step.
4. Starts a fresh headless process, installs/updates the configured parsers and
   verifies that they load, then waits for Mason registry/tool installation.
   Failures/timeouts return a failing bootstrap status and can be retried. Both
   phases reject incomplete initialization, startup errors, and plugin config
   errors reported through Neovim's notification API; an init.lua error cannot
   silently leave provisioning running against a partially initialized config.

Plugins and parser revisions are pinned by the lockfile/plugin. **Mason tool
releases are resolved from its current registry**, not frozen by lazy-lock.json;
already installed tools are retained. This is an awaited, verified installation,
not a fully offline or byte-for-byte reproducible package snapshot. GitHub,
nodejs.org, npm and PyPI access is needed. Use `:MasonLog` to investigate tool
installation errors.

To repeat just the user-level provisioning after dependencies are ready:

```sh
DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE '+lua require("provision").plugins()'
DOTFILES_NVIM_PROVISION=1 nvim --headless -i NONE '+lua require("provision").tools()'
```

Without full provisioning, first launch installs missing plugins; parsers and
Mason tools install asynchronously. Wait for completion and reopen files/restart
Neovim before expecting highlighting, language servers or debugging. `:Lazy
restore` restores plugin pins; `:Lazy update` intentionally changes them and can
raise version requirements. Run `:checkhealth`, `:checkhealth vim.lsp` and `:Mason`
for diagnostics.

## Languages and debugging

| Language | Explicit LSP | Debugger |
| --- | --- | --- |
| Lua | `lua_ls` / lua-language-server, with Neovim globals/runtime | — |
| JavaScript / JSX / TypeScript / TSX | `ts_ls` / typescript-language-server | — |
| Python | `pyright` | debugpy |
| C / C++ | `clangd` | CodeLLDB (launch or attach) |

Tree-sitter also includes Markdown and inline Markdown. The server/parser/package
lists live in `lua/tooling.lua`. Servers are explicitly enabled after Mason and
lspconfig setup, without discovering an arbitrary list of previously installed
servers. DAP paths use Mason v2's configured installation root.

Open Neovim in the project directory with appropriate project/root markers (e.g.
`.git`, `package.json`, `pyproject.toml`). Install your project's dependencies
separately. C/C++ projects should provide `compile_commands.json` for clangd and
be compiled with debug symbols (`-g`) for debugging. Attach permissions depend on
the host's ptrace policy. Python debugging uses `$VIRTUAL_ENV/bin/python`, then
the current directory's `.venv/bin/python`, then Python on PATH; the debugpy
adapter itself runs in its separate Mason-managed venv.

Mappings: Space is leader; `<leader>e` opens the tree, `<leader>ff` finds files,
`<leader>fg` uses ripgrep, `<leader>fb` selects buffers. Debug with F5 (continue),
F10/F11/F12 (step over/in/out), and `<leader>db` (breakpoint). LSP completion is
Neovim's built-in completion, available via `<C-x><C-o>`.

## Copilot, clipboard and terminal

- Copilot loads on insert or `:Copilot`. Run **`:Copilot setup`** and authenticate
  with a GitHub account that has Copilot access. On an SSH VM use **`:Copilot!
  setup`** and open the displayed URL on your local machine. Authentication is
  interactive and is not performed by bootstrap. The locked plugin uses npx to
  acquire its language server on first use; that download is also deferred.
  Check `:Copilot status` / `:Copilot log` if suggestions do not appear.
- WSL uses `clip.exe` and `powershell.exe` only if both are executable and the
  environment is actually WSL. Enable Windows interop/PATH integration to use it.
- Native Linux uses Neovim's provider detection. Install `wl-clipboard` for
  Wayland or `xclip`/`xsel` for X11 if your desktop does not already provide one.
- SSH without an available graphical provider uses OSC52 copying. Your local
  terminal (and tmux, if used) must permit OSC52. Pasting reads Neovim's register
  cache; use the terminal's paste shortcut for the local system clipboard.
- A Nerd Font in the **local terminal** is recommended for file/statusline icons;
  it is optional and does not need installation on a headless VM.

## Verification

```sh
bash tests/nvim.sh                # offline regressions, failure checks + Lua syntax
bash tests/nvim.sh --integration  # downloads pinned Neovim, CLI and Node archives;
                                 # npm/npx + current Copilot server, plugins/parsers/tools,
                                 # real LSP attachment and debugger runtimes
```

Integration checks use a disposable HOME and all XDG directories, including a
copy of this config, so they do not touch installed user plugins or credentials.
Offline regressions model Debian Node 20, incomplete npm/npx, preservation of a
newer toolchain, conflicting local Neovim binaries, and failed initialization.
Integration tests require network access and the system compiler/Python
prerequisites; they use the downloaded Node even when the host has a newer one.
