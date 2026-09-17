#!/usr/bin/env bash
# Regenerate oxp-contract/js-api-1.93.json from the live game.
#
# The game is launched and interrogated over the debug console; see tools/js_api_snapshot.py for
# why the port comes from a generated debugConfig.plist and why readiness is measured on the
# game's clock rather than ours.
#
# The launch takes tools/gui-lock (the interactive-desktop mutex) for the whole run, because on
# Windows this "headless" launch still opens a real window and can steal the foreground from a
# GUI test (bug oo-ccy9). Expect to queue behind a running GUI tier; OO_GUI_LOCK_TIMEOUT bounds
# the wait.
#
# Usage: tools/js-api-snapshot.sh [--app <oolite.app>] [--output <file>] [extra args...]
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"

# Native python on Windows cannot read an MSYS path (/c/... becomes C:/c/..., WinError 3), so every
# path handed across the boundary is converted first.
to_native() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi
}

app="${OO_APP_DIR:-$repo/upstream/oolite/build/meson_test/oolite.app}"
output="$repo/oxp-contract/js-api-1.93.json"
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --app) app="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) args+=("$1"); shift ;;
  esac
done

python3 "$(to_native "$here/js_api_snapshot.py")" \
  --app "$(to_native "$app")" \
  --output "$(to_native "$output")" \
  ${args[0]+"${args[@]}"}
