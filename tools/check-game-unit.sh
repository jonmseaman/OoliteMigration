#!/usr/bin/env bash
# tools/check-game-unit.sh — build and run the game-side unit tests (meson suite game-unit,
# upstream/oolite/tests/unit/game): tests of game sources that still sit on gnustep-base, such as
# the NSUserDefaults -> oo::Defaults single-store shim (bead oo-mwo0). They build with the game's
# own flags and libraries, so they need the game's build directory:
#
#     bash tools/check-game-unit.sh            # uses (and if needed makes) the 'test' flavour build
#
# Runs from the MSYS2 UCRT64 shell. Exit status is meson test's.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir/.."   # repo root

build="upstream/oolite/build/meson_test"
if [ ! -f "$build/build.ninja" ]; then
	bash tools/build-windows.sh test
fi
exec meson test -C "$build" --suite game-unit --print-errorlogs
