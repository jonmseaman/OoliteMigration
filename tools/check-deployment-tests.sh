#!/usr/bin/env bash
#
# The oofnd unit suite built under the DEPLOYMENT flavour's macros (bead oo-pdsng, proposed
# ADR-0066). The core suite joins it with bead oo-n77z0 (its test files do not build under NDEBUG yet).
#
#     bash tools/check-deployment-tests.sh                        # configure, build, run the suite
#     bash tools/check-deployment-tests.sh test_objc_assert_ndebug  # extra args go to meson test
#
# Why: the test flavour builds without NDEBUG, the shipped deployment flavour with it (and with
# OO_LOCALIZATION_TOOLS=0, DEBUG_GRAPHVIZ=0, OO_CHECK_GL_HEAVY=0, ...). OOCAssert was compiled out
# under NDEBUG, upstream's Foundation assertions never were, and PlayerEntity::deferredInit's ship set-up lived
# inside one: every test-flavour suite passed and the deployment game could not launch.
# test_objc_assert_ndebug fails on that tree (3 of 5 checks), here and in every flavour.
#
# Build directory: upstream/oolite/build/meson_deployment_tests, mk.sh's deployment options
# (-Ddeployment_release=true -Ddebug=false) with -Ddeployment_unit_tests=true and WITHOUT LTO or
# strip: the macros are what is under test, and full-LTO test links would cost far more. The
# LTO'd, stripped binary itself is covered by the goldens run against build/meson_deployment
# (tools/check-deployment-goldens.sh). Same ccache set-up as tools/build-windows.sh, so the objects
# are shared with the deployment build where the flags agree.

set -euo pipefail

MSYS2_BASH="${MSYS2_BASH:-/c/msys64/usr/bin/bash.exe}"
if [ "${MSYSTEM:-}" != "UCRT64" ] && [ -z "${OO_DEPLOY_TESTS_REEXEC:-}" ] && [ -x "$MSYS2_BASH" ]; then
  export OO_DEPLOY_TESTS_REEXEC=1
  exec env MSYSTEM=UCRT64 CHERE_INVOKING=1 "$MSYS2_BASH" -lc \
    "$(printf '%q ' "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")" "$@")"
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OOLITE="$REPO_ROOT/upstream/oolite"
BD="build/meson_deployment_tests"
NATIVE_FILE="$REPO_ROOT/tools/meson/ccache-clang.ini"

die() { printf 'check-deployment-tests: %s\n' "$*" >&2; exit 1; }

for c in meson ninja ccache cygpath; do
  command -v "$c" >/dev/null 2>&1 || die "$c is not on PATH; run this from the MSYS2 UCRT64 shell"
done
[ -f "$NATIVE_FILE" ] || die "missing native file $NATIVE_FILE"

export CCACHE_DEPEND=1
CCACHE_BASEDIR="$(cygpath -m "$REPO_ROOT")"
export CCACHE_BASEDIR
export OOLITE_VER_FULL="${OOLITE_VER_FULL:-0.0.0-fleet}"

reconf=()
[ -f "$OOLITE/$BD/build.ninja" ] && reconf=(--reconfigure)
(
  cd "$OOLITE"
  export PYTHONUTF8=1 VER_FULL="$OOLITE_VER_FULL"
  meson setup "$BD" -Ddeployment_release=true -Ddebug=false -Dstrip_bin=false -Db_lto=false \
    -Ddeployment_unit_tests=true --native-file "$(cygpath -m "$NATIVE_FILE")" ${reconf[@]+"${reconf[@]}"}
  meson compile -C "$BD"
)

# The configure must really be the deployment one: NDEBUG on the game's compile lines.
grep -q -- '-DNDEBUG' "$OOLITE/$BD/build.ninja" || die "$BD does not compile with -DNDEBUG; not the deployment macro set"

if [ "$(nice)" -gt 0 ]; then
  renice -n 0 -p $$ >/dev/null 2>&1 || true	# as tools/check-core-tests.sh (oo-9ht.136)
fi

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
rc=0
meson test -C "$OOLITE/$BD" --suite oofnd --print-errorlogs "$@" 2>&1 | tee "$log" || rc=$?
[ "$rc" -eq 0 ] || die "meson test (deployment macros) failed (exit $rc)"
ok="$(sed -n 's/^Ok:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$log" | tail -n 1)"
[ -n "$ok" ] && [ "$ok" -gt 0 ] || die "no test ran"
echo "check-deployment-tests: $ok test(s) passed under the deployment macros"
