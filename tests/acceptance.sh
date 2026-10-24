#!/usr/bin/env bash
# Real network/package installation, exclusively inside a disposable container.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ "$#" != 1 ]; then
  printf 'Usage: bash tests/acceptance.sh <debian|arch>\n' >&2
  exit 1
fi
case "$1" in
  debian) image=debian:13 ;;
  arch) image=archlinux:base ;;
  *) printf 'Unknown acceptance target: %s\n' "$1" >&2; exit 1 ;;
esac
docker info >/dev/null
# Read-only input; the guest copies sources before bootstrap links into them.
# No host HOME, daemon socket, privileges, or system directories are mounted.
docker run --rm --init --platform linux/amd64 \
  --mount "type=bind,source=$ROOT,target=/input,readonly" \
  --env DOTFILES_DISPOSABLE_ACCEPTANCE=1 "$image" \
  bash /input/tests/acceptance/container.sh
