#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[compat] init_debian.sh now delegates to bootstrap/install.sh"
exec "$SCRIPT_DIR/bootstrap/install.sh" --distro debian "$@"
