#!/usr/bin/env bash
#
# Every blessed golden (goldens/windows-x64: 001, 001-launch-dock) run against the DEPLOYMENT
# binary, the one Jon ships and plays (bead oo-pdsng, proposed ADR-0066).
#
#     bash tools/check-deployment-goldens.sh              # build deployment, then run the goldens
#     bash tools/check-deployment-goldens.sh --no-build   # use build/meson_deployment as it is
#
# The goldens were only ever run against build/meson_test. The deployment flavour (NDEBUG, LTO,
# stripped) could not launch at all (OOCAssert compiled out PlayerEntity::deferredInit's ship
# set-up) and 001-launch-dock fails on exactly that: "player.ship.docked never became false".
# The blessed goldens are flavour-independent state dumps (the same world, the same ledger), so the
# deployment binary must reproduce them byte-for-byte after quantisation, as the test binary does.
#
# This is tools/tier-c.sh's goldens stage (discovery, floor, golden_diff, launch/dock evidence)
# with OO_APP_DIR pointed at the deployment build; nothing is re-implemented here. The golden
# harness is the desktop-lock rule's deliberate exemption (CLAUDE.md), as it is under tier-c.

set -euo pipefail

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OO_DEPLOY_GOLDENS_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OO_DEPLOY_GOLDENS_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
APP="$REPO_ROOT/oolite-dev/build/meson_deployment/oolite.app"

die() { printf 'check-deployment-goldens: %s\n' "$*" >&2; exit 1; }

build=true
case "${1:-}" in
  --no-build) build=false ;;
  '') ;;
  *) die "unknown argument '$1' (expected --no-build or nothing)" ;;
esac

if $build; then
  bash "$HERE/build-windows.sh" deployment || die "the deployment build failed"
fi
[ -f "$APP/oolite.exe" ] || die "no deployment binary at $APP/oolite.exe; run tools/build-windows.sh deployment"

# It must really be the deployment configuration, not a test build that happens to sit there.
grep -q -- '-DNDEBUG' "$REPO_ROOT/oolite-dev/build/meson_deployment/build.ninja" \
  || die "build/meson_deployment does not compile with -DNDEBUG; not the deployment flavour"

if [ -d /ucrt64/bin ]; then export PATH="/ucrt64/bin:$PATH"; fi
OO_APP_DIR="$(cygpath -m "$APP")" bash "$HERE/tier-c.sh" --only goldens \
  || die "the blessed goldens do not reproduce on the deployment binary"
echo "check-deployment-goldens: every blessed golden reproduces on the deployment binary"
