#!/usr/bin/env bash
# tools/run-nightly-checks.sh — run every slow proof in tests/nightly/checks.txt (ADR-0021).
#
# The merge gate is a bead's acceptance block with a five-minute budget. Anything slower that a
# bead still wants proven (a 10-run stability sweep, a mutant sweep, a repeated launch) goes into
# tests/nightly/checks.txt, one shell command per line, and this script runs them all from the
# repository root: every night (tools/nightly.sh, bead oo-1bf.11) and at phase end. It runs every
# line even after a failure, so one red proof does not hide the others, and exits nonzero if any
# line failed. `#` lines and blank lines are ignored; a line may start with `[bead-id]` so a red
# proof can be traced to the bead that owns it.
#
#   tools/run-nightly-checks.sh            run everything, summary at the end
#   tools/run-nightly-checks.sh --list     print the executable lines and their count, run nothing
#
# Per-line timeout: OO_NIGHTLY_LINE_TIMEOUT seconds (default 1800). Log: build/nightly/checks-<date>.log
set -u

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
checks="tests/nightly/checks.txt"
[ -f "$checks" ] || { echo "run-nightly-checks: $checks is missing" >&2; exit 2; }

lines=()
while IFS= read -r raw; do
	line="${raw%$'\r'}"
	case "$line" in ''|'#'*) continue;; esac
	lines+=("$line")
done < "$checks"

if [ "${1:-}" = "--list" ]; then
	printf '%s\n' "${lines[@]}"
	echo "run-nightly-checks: ${#lines[@]} executable line(s) in $checks"
	exit 0
fi

if [ "${#lines[@]}" -eq 0 ]; then
	echo "run-nightly-checks: no executable lines in $checks; nothing to run (this is fine until a bead moves a slow proof here)"
	exit 0
fi

mkdir -p build/nightly
log="build/nightly/checks-$(date +%Y%m%d-%H%M%S).log"
per_line="${OO_NIGHTLY_LINE_TIMEOUT:-1800}"
if command -v timeout >/dev/null 2>&1; then tmo=(timeout "$per_line"); else tmo=(); fi
pass=0; fail=0; n=0; failed=()
for line in "${lines[@]}"; do
	n=$((n + 1))
	owner=""
	cmd="$line"
	if [[ "$line" =~ ^\[([^]]+)\][[:space:]]*(.*)$ ]]; then owner="${BASH_REMATCH[1]}"; cmd="${BASH_REMATCH[2]}"; fi
	t0=$SECONDS
	printf '\n== [%d/%d]%s $ %s\n' "$n" "${#lines[@]}" "${owner:+ ($owner)}" "$cmd" | tee -a "$log"
	rc=0
	"${tmo[@]}" bash -o pipefail -c "$cmd" >>"$log" 2>&1 || rc=$?
	if [ "$rc" -eq 0 ]; then
		pass=$((pass + 1)); echo "   ok in $(( SECONDS - t0 ))s" | tee -a "$log"
	else
		fail=$((fail + 1)); failed+=("${owner:-?}: $cmd (rc=$rc)")
		echo "   FAIL rc=$rc in $(( SECONDS - t0 ))s$( [ "$rc" -eq 124 ] && echo " (timed out at ${per_line}s)")" | tee -a "$log"
		tail -n 15 "$log" | sed 's/^/   | /'
	fi
done
echo
echo "run-nightly-checks: $pass passed, $fail failed of ${#lines[@]}; log $log"
for f in "${failed[@]:-}"; do [ -n "$f" ] && echo "  failed: $f"; done
[ "$fail" -eq 0 ]
