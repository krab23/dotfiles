#!/usr/bin/env bash
# Isolated regression checks: privileged/network commands are mocks only.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf -- "$SANDBOX"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$SANDBOX/bin" "$SANDBOX/home" "$SANDBOX/tmp"
export HOME="$SANDBOX/home" TMPDIR="$SANDBOX/tmp"
export XDG_CONFIG_HOME="$HOME/.config"
unset DOCKER_HOST DOCKER_CONTEXT
export MOCK_LOG="$SANDBOX/commands" MOCK_UID=1000
export PATH="$SANDBOX/bin:$PATH"
cat > "$SANDBOX/bin/mock" <<'EOF'
#!/usr/bin/env bash
set -eu
name="${0##*/}"
case "$name" in
  id)
    case "$1" in
      -u) printf '%s\n' "${MOCK_UID:-1000}" ;;
      -un) printf 'tester\n' ;;
      -nG) printf 'tester\n' ;;
      *) exit 99 ;;
    esac ;;
  getent) printf 'tester:x:1000:1000:Test:%s:/bin/bash\n' "${MOCK_HOME:-$HOME}" ;;
  sudo) printf 'sudo %s\n' "$*" >> "$MOCK_LOG" ;;
  nvim|node|npm|npx|tree-sitter)
    # Simulate missing tools; dry-run may only inspect versions.
    [ "$*" = --version ] || { printf 'UNEXPECTED %s %s\n' "$name" "$*" >> "$MOCK_LOG"; }
    exit 1 ;;
  docker)
    printf 'docker %s\n' "$*" >> "$MOCK_LOG"
    case "$*" in
      'context show') printf 'default\n' ;;
      'context inspect default --format {{.Endpoints.docker.Host}}') printf 'unix:///var/run/docker.sock\n' ;;
      *) exit 99 ;;
    esac ;;
  *) printf 'UNEXPECTED %s %s\n' "$name" "$*" >> "$MOCK_LOG"; exit 99 ;;
esac
EOF
chmod +x "$SANDBOX/bin/mock"
for cmd in id getent sudo docker curl crontab pacman apt-get chsh usermod systemctl locale-gen nvim node npm npx tree-sitter; do
  ln -s mock "$SANDBOX/bin/$cmd"
done
: > "$MOCK_LOG"
OUT="$SANDBOX/output"
trap 'cat "$OUT" >&2' ERR
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq -- "$1" "$OUT" || fail "missing output: $1"; }
no_commands() { [ ! -s "$MOCK_LOG" ] || fail 'unexpected command execution'; }
install() { bash "$ROOT/bootstrap/install.sh" "$@" > "$OUT" 2>&1; }

for args in '--only gti' '--only git,' '--skip git,,zsh' '--distro unknown' '--only' '--wat'; do
  # Intentional word splitting for this fixed argument table.
  if install $args; then fail "accepted $args"; fi
  no_commands
done
if install --only $'git\nzsh'; then fail 'accepted multiline CSV'; fi
if MOCK_UID=0 install --only git; then fail 'accepted root'; fi
contains 'normal login user'
if MOCK_HOME=/other install --only git; then fail 'accepted mismatched home'; fi
contains 'HOME must match'
no_commands
printf 'ok: arguments and account validation precede mutation\n'

for distro in arch debian ubuntu; do
  install --distro "$distro" --dry-run --enable-docker-prune
  contains 'Running module: git'
  contains 'Running module: zsh'
  contains 'Running module: starship'
  contains 'Running module: nvim'
  contains 'Running module: docker'
  contains 'Running module: opencode'
  contains 'ensure user crontab contains'
  contains 'DOTFILES_NVIM_PROVISION=1'
  if grep -Eq 'locale-gen|LANG=' "$OUT"; then fail 'bootstrap alters locale'; fi
  if [ "$distro" = arch ]; then
    contains 'pacman -Syu --noconfirm'
    contains 'docker docker-compose docker-buildx'
    contains 'pacman -S --noconfirm --needed opencode'
  else
    contains 'docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
    contains 'build-essential nodejs npm python3 python3-pip python3-venv python3-pynvim'
  fi
  # Only read-only Docker context queries may run during dry-run.
  if grep -Ev '^docker context (show|inspect )' "$MOCK_LOG"; then fail 'dry-run executed a mutating command'; fi
  : > "$MOCK_LOG"
  [ -z "$(ls -A "$HOME")" ] || fail 'dry-run changed HOME'
  [ -z "$(ls -A "$TMPDIR")" ] || fail 'dry-run created a temporary file'
done
printf 'ok: three distro dry-runs, package plans, no files or mutations\n'

install --distro arch --config-only --enable-docker-prune
no_commands
[ "$(readlink "$HOME/.gitconfig")" = "$ROOT/git/gitconfig" ] || fail 'git link'
[ "$(readlink "$HOME/.zshrc")" = "$ROOT/zsh/zshrc" ] || fail 'zsh link'
[ "$(readlink "$HOME/.config/starship.toml")" = "$ROOT/starship/starship.toml" ] || fail 'starship link'
[ "$(readlink "$HOME/.config/nvim")" = "$ROOT/nvim" ] || fail 'nvim link'
[ "$(readlink "$HOME/.config/opencode/opencode.json")" = "$ROOT/opencode/opencode.json" ] || fail 'opencode link'
[ ! -e "$HOME/.opencode" ] || fail 'config-only installed OpenCode'
[ ! -e "$HOME/.oh-my-zsh" ] || fail 'config-only installed Oh My Zsh'
install --distro arch --config-only
no_commands
contains 'Symlink already correct'
printf 'ok: config-only links and idempotence without sudo\n'

XDG_CONFIG_HOME="$HOME/custom config" install --distro debian --only nvim,starship,opencode --config-only
no_commands
[ "$(readlink "$HOME/custom config/nvim")" = "$ROOT/nvim" ] || fail 'nvim XDG link'
[ "$(readlink "$HOME/custom config/starship.toml")" = "$ROOT/starship/starship.toml" ] || fail 'starship XDG link'
[ "$(readlink "$HOME/custom config/opencode/opencode.json")" = "$ROOT/opencode/opencode.json" ] || fail 'opencode XDG link'
printf 'ok: config links respect XDG_CONFIG_HOME with spaces\n'

mkdir -p "$HOME/existing config/opencode"
printf '{"model":"provider/model"}\n' > "$HOME/existing config/opencode/opencode.json"
printf 'retain\n' > "$HOME/existing config/opencode/other"
XDG_CONFIG_HOME="$HOME/existing config" install --distro debian --only opencode --config-only
no_commands
contains 'Backing up existing target'
backups=("$HOME/existing config/opencode/opencode.json.backup."*)
[ "${#backups[@]}" = 1 ] && [ "$(<"${backups[0]}")" = '{"model":"provider/model"}' ] || fail 'OpenCode config backup'
[ "$(<"$HOME/existing config/opencode/other")" = retain ] || fail 'OpenCode sibling config changed'
printf 'ok: existing OpenCode config backed up and sibling files preserved\n'

# Repeat within a fixed timestamp: files, directories and dangling links must
# each survive, and a missing source or failed move must not publish a new link.
ROOT="$ROOT" bash -c '
  source "$ROOT/bootstrap/lib/common.sh"
  date() { printf "fixed\n"; }
  dest="$HOME/backup target"
  source_file="$ROOT/git/gitconfig"
  printf "original\n" > "$dest"
  link_with_backup "$source_file" "$dest"
  [ "$(<"$dest.backup.fixed")" = original ]
  rm "$dest"
  mkdir "$dest"
  printf "nested\n" > "$dest/keep"
  link_with_backup "$source_file" "$dest"
  [ "$(<"$dest.backup.fixed.1/keep")" = nested ]
  rm "$dest"
  ln -s /missing/old/config "$dest"
  link_with_backup "$source_file" "$dest"
  [ "$(readlink "$dest.backup.fixed.2")" = /missing/old/config ]
  if link_with_backup "$HOME/missing/source" "$dest"; then exit 1; fi
  [ "$(readlink "$dest")" = "$source_file" ]
  rm "$dest"
  printf "retain\n" > "$dest"
  mv() { return 1; }
  if link_with_backup "$source_file" "$dest"; then exit 1; fi
  [ ! -L "$dest" ] && [ "$(<"$dest")" = retain ]
' > "$OUT" 2>&1
printf 'ok: collision-safe backups, missing-source and failed-move preservation\n'

install --distro arch --only git
grep -Fxq 'sudo -v' "$MOCK_LOG" || fail 'no sudo preflight'
grep -Fxq 'sudo pacman -Syu --noconfirm' "$MOCK_LOG" || fail 'no full upgrade'
grep -Fxq 'sudo pacman -S --noconfirm --needed git' "$MOCK_LOG" || fail 'git missing own package'
: > "$MOCK_LOG"
install --distro arch --skip git,zsh,starship,nvim,docker,opencode
no_commands
printf 'ok: real install preflight and independent git package, empty selection skips sudo\n'

install --distro arch --only opencode
grep -Fxq 'sudo pacman -S --noconfirm --needed opencode' "$MOCK_LOG" || fail 'OpenCode package missing'
: > "$MOCK_LOG"
printf 'ok: standalone Arch OpenCode package installation\n'

# Exercise upstream installation without contacting the network or executing the
# real installer. The downloaded stub checks arguments and writes a fake binary.
for distro in debian ubuntu; do
  ROOT="$ROOT" DISTRO_FAMILY="$distro" bash -c '
    source "$ROOT/bootstrap/lib/common.sh"
    source "$ROOT/bootstrap/lib/packages.sh"
    source "$ROOT/bootstrap/distros/$DISTRO_FAMILY.sh"
    source "$ROOT/bootstrap/modules/opencode.sh"
    DOTFILES_ROOT="$ROOT" DRY_RUN=0 CONFIG_ONLY=0
    command_exists() { return 1; }
    curl() {
      [ "$*" = "-fsSL -o $TEMP_FILE https://opencode.ai/install" ] || return 1
      printf "%s\n" \
        "set -eu" \
        "[ \"\$*\" = --no-modify-path ]" \
        "mkdir -p \"\$HOME/.opencode/bin\"" \
        "touch \"\$HOME/.opencode/bin/opencode\"" \
        "chmod +x \"\$HOME/.opencode/bin/opencode\"" > "$TEMP_FILE"
    }
    module_opencode
    [ -x "$HOME/.opencode/bin/opencode" ]
    # A second invocation finds the binary even before a new shell updates PATH.
    pkg_install() { exit 91; }
    curl() { exit 92; }
    module_opencode
    rm "$HOME/.opencode/bin/opencode"
    # An installation elsewhere on PATH is reused too.
    command_exists() { [ "$1" = opencode ]; }
    module_opencode
  ' > "$OUT" 2>&1
  grep -Fxq 'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates tar gzip' "$MOCK_LOG" || fail 'OpenCode upstream dependencies missing'
  contains 'OpenCode already installed'
  [ -z "$(ls -A "$TMPDIR")" ] || fail 'OpenCode installer leaked temp'
  : > "$MOCK_LOG"
done
printf 'ok: Debian/Ubuntu upstream installer arguments, dependencies, reuse and cleanup\n'

DOCKER_HOST=ssh://remote install --distro arch --only docker --dry-run --enable-docker-prune
contains 'Skipping local engine, group and prune setup'
no_commands
if grep -Eq 'usermod|pacman|ensure user crontab' "$OUT"; then fail 'remote engine altered'; fi
printf 'ok: remote Docker skips local system setup\n'

install --distro arch --only docker
grep -Fxq 'sudo pacman -S --noconfirm --needed docker docker-compose docker-buildx' "$MOCK_LOG" || fail 'existing CLI skipped engine components'
grep -Fxq 'sudo usermod -aG docker tester' "$MOCK_LOG" || fail 'wrong Docker group target'
if grep -q crontab "$MOCK_LOG"; then fail 'prune was not opt-in'; fi
: > "$MOCK_LOG"
ROOT="$ROOT" bash -c '
  source "$ROOT/bootstrap/lib/common.sh"
  source "$ROOT/bootstrap/modules/docker.sh"
  distro_install_docker() { :; }
  docker_uses_local_engine() { return 0; }
  # Simulate running systemd independently of the test host.
  [() {
    if [[ "$*" == "-d /run/systemd/system ]" ]]; then return 0; fi
    builtin [ "$@"
  }
  TARGET_USER=tester DRY_RUN=1
  module_docker
' > "$OUT" 2>&1
contains 'systemctl enable --now docker.service'
contains 'Docker prune cron disabled by default'
printf 'ok: existing Docker CLI still ensures components, local group, systemd and opt-in prune\n'

# A failed network download must still clean the registered installer file.
if ROOT="$ROOT" bash -c '
  source "$ROOT/bootstrap/lib/common.sh"
  make_temp
  [ -f "$TEMP_FILE" ]
  curl --fail https://example.invalid
' > "$OUT" 2>&1; then fail 'mock network unexpectedly succeeded'; fi
[ -z "$(ls -A "$TMPDIR")" ] || fail 'failed install leaked a temporary file'
printf 'ok: EXIT cleanup after failure\n'

if ROOT="$ROOT" bash -c '
  source "$ROOT/bootstrap/lib/common.sh"
  make_temp
  kill -TERM "$$"
' > "$OUT" 2>&1; then fail 'TERM unexpectedly succeeded'; fi
[ -z "$(ls -A "$TMPDIR")" ] || fail 'TERM leaked a temporary file'
printf 'ok: cleanup after TERM\n'

# Exercise missing binaries without relying on what the test host has installed.
ROOT="$ROOT" bash -c '
  source "$ROOT/bootstrap/lib/common.sh"
  source "$ROOT/bootstrap/lib/packages.sh"
  source "$ROOT/bootstrap/modules/zsh.sh"
  source "$ROOT/bootstrap/modules/starship.sh"
  source "$ROOT/bootstrap/distros/debian.sh"
  source "$ROOT/bootstrap/modules/opencode.sh"
  command_exists() { return 1; }
  DRY_RUN=1 CONFIG_ONLY=0 DISTRO_FAMILY=debian TARGET_USER=tester TARGET_SHELL=/bin/bash
  DOTFILES_ROOT="$ROOT"
  module_zsh
  module_starship
  module_opencode
' > "$OUT" 2>&1
contains 'apt-get install -y zsh git curl ca-certificates'
contains 'apt-get install -y curl ca-certificates'
contains 'sudo sh'
contains 'https://opencode.ai/install'
contains '--no-modify-path'
[ -z "$(ls -A "$TMPDIR")" ] || fail 'missing-binary dry-run leaked temp'
printf 'ok: dry-run works with missing zsh/starship/opencode/curl binaries\n'
printf 'All bootstrap checks passed.\n'
