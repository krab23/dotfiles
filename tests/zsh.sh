#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! ZSH_BIN="$(type -P zsh)"; then
  printf 'FAIL: zsh is required to run tests/zsh.sh; install zsh first.\n' >&2
  exit 1
fi

scratch="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-zsh-test.XXXXXXXX")"
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/empty-bin" "$scratch/zdotdir"

# These must never be read, even when the caller exports startup-file variables.
printf 'print -u2 "FAIL: unexpected startup file"; exit 99\n' > "$scratch/zdotdir/.zshrc"
cp "$scratch/zdotdir/.zshrc" "$scratch/zdotdir/.zshenv"
export ZDOTDIR="$scratch/zdotdir" ENV="$scratch/zdotdir/.zshrc"

cat > "$scratch/check.zsh" <<'ZSH'
fail() { print -u2 -- "FAIL ($CASE): $*"; exit 1; }
[[ $ZDOTDIR == "$HOME" && $ENV == /dev/null ]] || fail 'inherited startup environment'
[[ ! -o rcs ]] || fail 'zsh must run with -f'
[[ $CASE != bare ]] || unset LANG LC_ALL LC_CTYPE
source "$RC_FILE"

if [[ $CASE == bare ]]; then
  [[ $LANG == C.UTF-8 ]] || fail 'missing locale tool fallback'
  (( ! ${+LC_ALL} && ! ${+LC_CTYPE} )) || fail 'locale overrides were forced'
else
  [[ $LANG == C && $LC_ALL == C && $LC_CTYPE == POSIX ]] || fail 'locale changed'
fi
[[ $plugins == git && $ZLE_RPROMPT_INDENT == 0 ]] || fail 'useful defaults lost'
[[ $ZSH == "$HOME/.oh-my-zsh" ]] || fail 'OMZ home path'

# Compare the entire PATH, including order and duplicate removal. Host binaries
# are excluded so an installed Starship/Neovim cannot mask missing-tool bugs.
expected=("$HOME/.local/bin" "$EMPTY_BIN")
if [[ $CASE == full || $CASE == overrides ]]; then
  expected=("$HOME/.opencode/bin" $expected)
fi
[[ $PATH == "${(j.:.)expected}" ]] || fail "unexpected PATH: $PATH"

case $CASE in
  bare)
    (( ! $+commands[starship] && ! $+commands[nvim] )) || fail 'host tools leaked'
    [[ ! -e $ZSH/oh-my-zsh.sh ]] || fail 'OMZ should be absent'
    [[ $EDITOR == vi && $ZSH_THEME == robbyrussell && -n $PROMPT ]] || fail 'bare fallback'
    ;;
  omz)
    [[ $EDITOR == vi && $OMZ_THEME_SEEN == robbyrussell ]] || fail 'OMZ fallback theme'
    [[ $OMZ_PROMPT_COUNT == 1 && $PROMPT == omz-prompt ]] || fail 'OMZ prompt not loaded'
    ;;
  full|overrides)
    [[ -z $OMZ_THEME_SEEN && ${OMZ_PROMPT_COUNT:-0} == 0 ]] || fail 'OMZ initialized a second prompt'
    [[ $STARSHIP_INIT_COUNT == 1 ]] || fail 'Starship must initialize exactly once'
    [[ $SDK_PATH_LOADED == 1 && $SDK_COMPLETION_LOADED == 1 ]] || fail 'SDK integration missing'
    if [[ $CASE == full ]]; then
      [[ $EDITOR == nvim && $PROMPT == starship-prompt ]] || fail 'local tool selection'
    else
      [[ $LOCAL_SAW_DEFAULTS == yes ]] || fail 'overrides loaded before defaults/integrations'
      [[ $EDITOR == local-editor && $PROMPT == local-prompt ]] || fail 'overrides lost'
      [[ $aliases[localtest] == true ]] || fail 'local alias lost'
    fi
    ;;
esac
ZSH

for scenario in bare omz full overrides; do
  home="$scratch/$scenario home with spaces"
  mkdir -p "$home/.local/bin"
  if [[ $scenario != bare ]]; then
    mkdir -p "$home/.oh-my-zsh"
    cat > "$home/.oh-my-zsh/oh-my-zsh.sh" <<'ZSH'
OMZ_LOADED=1
OMZ_THEME_SEEN=$ZSH_THEME
if [[ -n $ZSH_THEME ]]; then
  (( OMZ_PROMPT_COUNT += 1 ))
  PROMPT=omz-prompt
fi
ZSH
  fi
  if [[ $scenario == full || $scenario == overrides ]]; then
    mkdir -p "$home/.opencode/bin" "$home/google-cloud-sdk"
    cat > "$home/.local/bin/starship" <<'SH'
#!/bin/sh
[ "$#" = 2 ] && [ "$1" = init ] && [ "$2" = zsh ] || exit 1
printf '%s\n' '(( STARSHIP_INIT_COUNT += 1 ))' 'PROMPT=starship-prompt'
SH
    printf '#!/bin/sh\nexit 0\n' > "$home/.local/bin/nvim"
    chmod +x "$home/.local/bin/starship" "$home/.local/bin/nvim"
    cat > "$home/google-cloud-sdk/path.zsh.inc" <<'ZSH'
path+=("$HOME/.local/bin")
SDK_PATH_LOADED=1
ZSH
    cat > "$home/google-cloud-sdk/completion.zsh.inc" <<'ZSH'
[[ $OMZ_LOADED == 1 ]] || { print -u2 'SDK completion loaded before OMZ'; return 1; }
SDK_COMPLETION_LOADED=1
ZSH
  fi
  if [[ $scenario == overrides ]]; then
    cat > "$home/.zshrc.local" <<'ZSH'
if [[ $EDITOR == nvim && $PROMPT == starship-prompt && $SDK_COMPLETION_LOADED == 1 ]]; then
  LOCAL_SAW_DEFAULTS=yes
fi
EDITOR=local-editor
PROMPT=local-prompt
alias localtest=true
ZSH
  fi

  # No inherited shell variables, host PATH, real user config, or network tools.
  # -f skips user startup files; explicitly source only the repository's zshrc.
  if ! env -i HOME="$home" ZDOTDIR="$home" ENV=/dev/null TERM=dumb \
    LANG=C LC_ALL=C LC_CTYPE=POSIX CASE="$scenario" \
    PATH="$home/.local/bin:$scratch/empty-bin:$home/.local/bin:$scratch/empty-bin" \
    EMPTY_BIN="$scratch/empty-bin" RC_FILE="$DOTFILES_ROOT/zsh/zshrc" \
    "$ZSH_BIN" -f -i "$scratch/check.zsh" > "$scratch/output" 2>&1; then
    cat "$scratch/output" >&2
    printf 'FAIL: %s startup\n' "$scenario" >&2
    exit 1
  fi
  if [[ -s $scratch/output ]]; then
    cat "$scratch/output" >&2
    printf 'FAIL: unexpected startup output (%s)\n' "$scenario" >&2
    exit 1
  fi
  printf 'PASS: %s startup\n' "$scenario"
done

# Locale defaults must not depend on, or query, the host's installed locales.
home="$scratch/locale home"
mkdir -p "$home/.local/bin"
cat > "$home/.local/bin/locale" <<'SH'
#!/bin/sh
printf 'unexpected locale query\n' > "$HOME/locale-called"
exit 99
SH
chmod +x "$home/.local/bin/locale"
cat > "$scratch/check-locale.zsh" <<'ZSH'
fail() { print -u2 -- "FAIL ($CASE locale): $*"; exit 1; }
case $CASE in
  unset) unset LANG ;;
  empty) export LANG='' ;;
  existing) export LANG=POSIX ;;
  overrides) unset LANG; export LC_ALL=C LC_TIME=POSIX ;;
  local) unset LANG ;;
esac
source "$RC_FILE"
[[ $LANG == "$EXPECTED_LANG" ]] || fail "unexpected LANG: $LANG"
[[ ! -e "$HOME/locale-called" ]] || fail 'queried installed locales'
if [[ $CASE == overrides ]]; then
  [[ $LC_ALL == C && $LC_TIME == POSIX ]] || fail 'LC overrides changed'
else
  (( ! ${+LC_ALL} && ! ${+LC_TIME} )) || fail 'LC overrides introduced'
fi
# LANG must also reach child processes, and sourcing again must retain it.
[[ ${parameters[LANG]} == *export* ]] || fail 'LANG is not exported'
source "$RC_FILE"
[[ $LANG == "$EXPECTED_LANG" ]] || fail 'second source changed LANG'
ZSH

for scenario in unset empty existing overrides local; do
  expected=C.UTF-8
  case "$scenario" in
    existing) expected=POSIX ;;
    local)
      printf 'export LANG=POSIX\n' > "$home/.zshrc.local"
      expected=POSIX ;;
  esac
  if ! env -i HOME="$home" ZDOTDIR="$home" ENV=/dev/null TERM=dumb \
    PATH="$home/.local/bin:$scratch/empty-bin" CASE="$scenario" \
    EXPECTED_LANG="$expected" \
    RC_FILE="$DOTFILES_ROOT/zsh/zshrc" \
    "$ZSH_BIN" -f -i "$scratch/check-locale.zsh" > "$scratch/output" 2>&1; then
    cat "$scratch/output" >&2
    exit 1
  fi
  if [[ -s $scratch/output ]]; then
    cat "$scratch/output" >&2
    printf 'FAIL: unexpected locale startup output (%s)\n' "$scenario" >&2
    exit 1
  fi
  printf 'PASS: %s locale\n' "$scenario"
done
