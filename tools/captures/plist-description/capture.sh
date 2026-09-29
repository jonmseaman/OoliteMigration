#!/usr/bin/env bash
# tools/captures/plist-description/capture.sh — regenerate the gnustep-base -description rows that
# pin oo::describe(const oo::PList &) (bead oo-qps.32, ADR-0055 item 1):
#
#     bash tools/captures/plist-description/capture.sh          # rewrite the .inc
#     bash tools/captures/plist-description/capture.sh --check  # exit 1 if the .inc differs
#
# Builds probe.m against gnustep-base (gnustep-config --base-libs; MSYS2 UCRT64 shell), runs it over
# cases.txt with TZ=UTC (an NSDate describes itself in the default time zone) and writes
# upstream/oolite/tests/unit/oofnd/plist_description_captured.inc. Captured on GNUstep base 1.31.1.
# The game no longer needs gnustep-base after oo-qps.18; this script still does.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
out="$repo/upstream/oolite/tests/unit/oofnd/plist_description_captured.inc"
die() { echo "capture: $*" >&2; exit 1; }
command -v clang >/dev/null 2>&1 || die "clang is not on PATH; run from the MSYS2 UCRT64 shell"
command -v gnustep-config >/dev/null 2>&1 || die "gnustep-config is not on PATH (gnustep-base is needed to capture)"

native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }
work="$repo/.agent-tmp/capture-plist-description"
rm -rf "$work"; mkdir -p "$work"
trap 'rm -rf "$work"' EXIT

flags=(-x objective-c -O1 -Wall -Wextra -Werror -fobjc-runtime=gnustep-2.2 -fblocks -fexceptions -fobjc-exceptions
       -fconstant-string-class=NSConstantString -DGNUSTEP -DGNUSTEP_BASE_LIBRARY=1 -DGNUSTEP_RUNTIME=1
       -D_NONFRAGILE_ABI=1 -DGNUSTEP_WITH_DLL -I/ucrt64/include)
read -r -a libs <<< "$(gnustep-config --base-libs)"
clang "${flags[@]}" -c "$(native "$here/probe.m")" -o "$(native "$work/probe.o")"
clang++ "$(native "$work/probe.o")" "${libs[@]}" -o "$(native "$work/probe.exe")"

{
	echo "// Captured from GNUstep base 1.31.1 by tools/captures/plist-description/capture.sh (bead oo-qps.32):"
	echo "// -[NSObject description] of each case in tools/captures/plist-description/cases.txt, TZ=UTC."
	echo "// Test data: do not edit; rerun the script. Rows: { kind, name, input text, captured description }."
	TZ=UTC "$work/probe.exe" "$(native "$here/cases.txt")" | sed 's/\r$//'	# text-mode stdout's CRLF; a CR inside a row stays
} > "$work/captured.inc"

if [ "${1:-}" = "--check" ]; then
	cmp -s "$work/captured.inc" "$out" || { diff "$out" "$work/captured.inc" || true; die "$out differs from a fresh capture"; }
	echo "capture: $out matches gnustep-base"
else
	cp "$work/captured.inc" "$out"
	echo "capture: wrote $out ($(grep -c '^	{' "$out") rows)"
fi
