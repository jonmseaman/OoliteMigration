#!/usr/bin/env bash
#
# Decision-4 benchmark (bead oo-lvj; method and results in docs/phases/2-string-benchmark.md):
# what does value-semantics std::string copying cost the game, measured on golden wall-clock?
#
#     bash tools/bench-string-copy.sh [--reps N]     # default 5; ~4 variants x N x (both goldens)
#
# 1. builds the tree as it is (tools/build-windows.sh test) and keeps its oolite.exe as A0;
# 2. links tools/bench/string-copy/OOBenchStringCopy.mm into a second build (copied into src/Core
#    and listed in src/meson.build for the duration only; a trap restores both) and keeps it as B;
# 3. rebuilds the untouched tree, so the build directory ends as it started;
# 4. runs tools/bench_string_copy.py: every blessed golden, per variant A0 / B-off / B-copy / B-all,
#    interleaved in a shuffled order per repetition, each run diffed against its golden;
# 5. prices each mode's measured copy traffic with the unit cost of one copy (unit_cost.cpp).
#
# Launches the game only through the golden harness scripts (exempt from tools/gui-lock:
# tools/check-desktop-lock.sh), one game at a time.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
oo="$repo/upstream/oolite"
app="$oo/build/meson_test/oolite.app"
work="$oo/build/bench-string-copy"
reps=5
while [ $# -gt 0 ]; do
  case "$1" in
    --reps) reps="${2:?--reps needs a number}"; shift ;;
    *) echo "usage: $0 [--reps N]" >&2; exit 2 ;;
  esac
  shift
done
PY=""; for c in python3 python; do command -v "$c" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "bench-string-copy: no python" >&2; exit 2; }
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

hook_dst="$oo/src/Core/OOBenchStringCopy.mm"
restore() {
  rm -f "$hook_dst"
  git -C "$repo" checkout -- upstream/oolite/src/meson.build
}
[ ! -e "$hook_dst" ] || { echo "bench-string-copy: $hook_dst exists; refusing to overwrite" >&2; exit 2; }
git -C "$repo" diff --quiet -- upstream/oolite/src/meson.build \
  || { echo "bench-string-copy: src/meson.build has local changes; refusing to patch it" >&2; exit 2; }

mkdir -p "$work"
echo "==> A0: the tree as it is"
"$repo/tools/build-windows.sh" test
cp "$app/oolite.exe" "$work/A0.exe"

echo "==> B: the tree plus the shadow-copy hook"
trap restore EXIT
cp "$repo/tools/bench/string-copy/OOBenchStringCopy.mm" "$hook_dst"
"$PY" - "$(native "$oo/src/meson.build")" <<'EOF'
import sys
p = sys.argv[1]
s = open(p, newline="").read()
anchor = "appname = 'oolite'"
assert s.count(anchor) == 1, "anchor not found once in src/meson.build"
s = s.replace(anchor, "oolite_sources += files('Core/OOBenchStringCopy.mm')   # bench-string-copy.sh, temporary\n" + anchor)
open(p, "w", newline="").write(s)
EOF
"$repo/tools/build-windows.sh" test
cp "$app/oolite.exe" "$work/B.exe"
restore
trap - EXIT

echo "==> restoring the build directory to the untouched tree"
"$repo/tools/build-windows.sh" test
cmp -s "$app/oolite.exe" "$work/A0.exe" || echo "note: the rebuilt A0 is not byte-identical to the first (timestamps); the first is used"

echo "==> running: $reps repetition(s) x 4 variants x every blessed golden"
"$PY" "$(native "$repo/tools/bench_string_copy.py")" --app-dir "$(native "$app")" \
  --a0 "$(native "$work/A0.exe")" --b "$(native "$work/B.exe")" --reps "$reps" \
  --out "$(native "$work/results.json")"
echo "results: $(native "$work/results.json")"

# 5. the noise-free half: time one std::string copy on this machine and price each mode's
#    measured traffic with it (tools/bench/string-copy/unit_cost.cpp).
echo "==> unit cost of a std::string copy, and the modelled CPU of each mode's measured traffic"
clang++ -std=c++20 -O2 -Wall -Wextra -Werror "$repo/tools/bench/string-copy/unit_cost.cpp" -o "$work/unit_cost.exe"
for mode in copy all; do
  read -r n heap bytes < <("$PY" -c "
import json, sys
s = json.load(open(sys.argv[1]))['summary'][sys.argv[2]]
print(int(s['shadow']['median']), int(s['heap']['median']), int(s['bytes']['median']))
" "$(native "$work/results.json")" "$mode")
  echo "-- $mode"; "$work/unit_cost.exe" "$n" "$heap" "$bytes"
done
