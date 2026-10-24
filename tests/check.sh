#!/usr/bin/env bash
# Fast, offline checks shared by local development and CI.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

for tool in git bash zsh nvim shellcheck python3; do
  if ! command -v "$tool" >/dev/null; then
    printf 'Missing check dependency: %s (see docs/verification.md)\n' "$tool" >&2
    exit 1
  fi
done
if ! python3 -c 'import tomllib' 2>/dev/null; then
  printf 'Python 3.11+ with tomllib is required.\n' >&2
  exit 1
fi

while IFS= read -r -d '' file; do
  [ -f "$file" ] || continue
  bash -n "$file"
  shellcheck --severity=warning "$file"
done < <(git ls-files -z --cached --others --exclude-standard -- 'bootstrap/*.sh' 'tests/*.sh')
zsh -n zsh/zshrc
python3 tests/configs.py
git diff --check
git diff --cached --check
bash tests/bootstrap.sh
bash tests/zsh.sh
bash tests/nvim.sh
printf 'All offline checks passed.\n'
