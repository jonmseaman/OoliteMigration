#!/usr/bin/env bash
#
# Probe the REAL clang-tidy baseline gate of tools/tier-a.sh (bead oo-3rb.60).
#
#     bash tools/tier-a-tidy-probe.sh
#
# THE DEFECT THIS GUARDS. tools/tier-a-tidy-baseline.py judged every finding against the lines
# of the SOURCE under test, whatever file the finding named. misc-header-include-cycle reports
# inside a header even under -header-filter='$^', so on bead oo-z8zd the pre-existing finding
# "OOLogging.h:31" was looked up at line 31 of OOStringExpander.mm -- which the bead had just
# edited -- and tier-a failed a correct change. The same blindness runs the other way: a NEW
# finding on an edited header line was passed whenever the .mm's same-numbered line was old.
#
# Nothing here re-implements the gate: it sources tools/tier-a.sh with
# OOLITE_TIER_A_SOURCE_ONLY=1 and calls ITS tidy_gate (which calls the real
# tools/tier-a-tidy-baseline.py), the tools/tier-a-deny-probe.sh pattern (bead oo-2ixr). Every
# defect case is also run against LEGACY, a verbatim copy of the pre-fix verdict logic, and the
# probe ASSERTS the legacy code gets it wrong: if a later edit reverts the fix, those
# discrimination assertions stop holding and the probe goes red.
#
# The fixture is a throwaway git repo in a per-run `mktemp -d` with an EXIT trap (the fleet runs
# several workers concurrently; a fixed scratch path would let them corrupt each other).
set -u

cd "$(dirname "$0")/.." || exit 1

OOLITE_TIER_A_SOURCE_ONLY=1 . tools/tier-a.sh
set +e   # the sourced file sets -e; the probe must survive its own failing cases

pass=0
failn=0
ok()  { pass=$((pass+1));   printf 'ok   %s\n' "$*"; }
bad() { failn=$((failn+1)); printf 'FAIL %s\n' "$*"; }
check() { # check <label> <expected> <actual>
	if [ "$2" = "$3" ]; then ok "$1 ($3)"; else bad "$1: want=$2 got=$3"; fi
}

command -v tidy_gate >/dev/null 2>&1 \
	|| { printf 'FAIL tools/tier-a.sh did not define tidy_gate when sourced\n'; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/tier-a-tidy-probe.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT
native() { cygpath -m "$1"; }

# The pre-fix verdict, verbatim from tools/tier-a-tidy-baseline.py before bead oo-3rb.60: every
# finding is looked up by LINE NUMBER in the source, never by the path it names.
LEGACY="$TMP/legacy.py"
cat >"$LEGACY" <<'PY'
import re, sys
from collections import Counter
FINDING = re.compile(r"^(?P<path>.+?):(?P<line>\d+):(?P<col>\d+): (?:error|warning): (?P<msg>.*?) \[(?P<check>[^\]]+)\]\s*$")
def norm(s):
    return " ".join(s.split())
source, baseline, tidy_out = sys.argv[1:4]
lines = open(source, encoding="utf-8", errors="replace").read().splitlines()
base_lines = Counter(norm(l) for l in open(baseline, encoding="utf-8", errors="replace").read().splitlines())
findings = [m for m in map(FINDING.match, open(tidy_out, encoding="utf-8", errors="replace").read().splitlines()) if m]
if not findings:
    sys.exit(2)
new = []
for m in findings:
    n = int(m["line"])
    text = norm(lines[n - 1]) if 0 < n <= len(lines) else None
    if not (text is not None and base_lines[text] > 0):
        new.append(m.group(0))
sys.exit(1 if new else 0)
PY

# --- the fixture: a repo whose source and header BOTH have a line 3 --------------------------
R="$TMP/repo"
mkdir -p "$R/src/Core" "$TMP/sys"
git -C "$R" init -q
git -C "$R" config user.email probe@example.invalid
git -C "$R" config user.name probe
printf '%s\n' '// header' '#pragma once' '#import "Cycle.h"' 'int h_old(void);' >"$R/src/h.h"
printf '%s\n' '// source' '#import "h.h"' '#import "Old.h"' 'int f(void) { return 1; }' >"$R/src/a.mm"
# Mixed case, as the real tree is (src/Core/OOLogging.h): git paths are case-sensitive.
printf '%s\n' '// logging' '#pragma once' '#import "OOCocoa.h"' >"$R/src/Core/OOLogging.h"
git -C "$R" add -A && git -C "$R" commit -qm base
BASE="$(git -C "$R" rev-parse HEAD)"
: >"$TMP/sys/stdio.h"

# The change under test: source line 3 edited (the oo-z8zd shape: an #import swapped in place).
printf '%s\n' '// source' '#import "h.h"' '#import "New.h"' 'int f(void) { return 1; }' >"$R/src/a.mm"

OUT="$TMP/tidy.out"
finding() { # finding <native-path> <line> -- one clang-tidy error line
	printf '%s:%s:9: error: circular header file dependency [misc-header-include-cycle,-warnings-as-errors]\n' "$1" "$2"
}
gate() { # gate -- rc of the REAL tidy_gate on $OUT for src/a.mm
	tidy_gate "$R" "$BASE" "$R/src/a.mm" src/a.mm "$OUT" >/dev/null 2>&1
	printf '%s' $?
}
legacy() { # legacy -- rc of the pre-fix verdict on $OUT for src/a.mm
	git -C "$R" show "$BASE:src/a.mm" >"$TMP/a.base"
	python "$(native "$LEGACY")" "$(native "$R/src/a.mm")" "$(native "$TMP/a.base")" "$(native "$OUT")" >/dev/null 2>&1
	printf '%s' $?
}

echo "== defect: an unchanged header line vs an edited source line of the same number =="
finding "$(native "$R/src/h.h")" 3 >"$OUT"
check "pre-existing header finding (h.h:3 unchanged) passes" 0 "$(gate)"
check "LEGACY failed it against a.mm:3 (discrimination)" 1 "$(legacy)"

echo "== defect, mirrored: an edited header line vs an unchanged source line =="
printf '%s\n' '// header' '#pragma once' '#import "Cycle.h"' 'int h_new(void);' >"$R/src/h.h"
finding "$(native "$R/src/h.h")" 4 >"$OUT"
check "new header finding (h.h:4 edited) fails" 1 "$(gate)"
check "LEGACY passed it against a.mm:4 (discrimination)" 0 "$(legacy)"

echo "== a header that did not exist at the baseline =="
printf '%s\n' '// brand new' '#import "Cycle.h"' '#import "New.h"' >"$R/src/n.h"
finding "$(native "$R/src/n.h")" 3 >"$OUT"
check "finding in a header added by the change fails" 1 "$(gate)"

echo "== outside the repo =="
finding "$(native "$TMP/sys/stdio.h")" 3 >"$OUT"
check "finding in a header outside the repo is pre-existing" 0 "$(gate)"

echo "== the source itself: unchanged behaviour, under any spelling of its path =="
finding "$(native "$R/src/a.mm")" 4 >"$OUT"
check "source finding on an unchanged line passes" 0 "$(gate)"
finding "$(native "$R/src/a.mm")" 3 >"$OUT"
check "source finding on the edited line fails" 1 "$(gate)"
finding "$(cygpath -w "$R/src/a.mm")" 3 >"$OUT"
check "backslash spelling of the source path is still the source" 1 "$(gate)"
{ finding "$(native "$R/src/h.h")" 3; finding "$(native "$R/src/a.mm")" 3; } >"$OUT"
check "one new finding among pre-existing ones fails the whole run" 1 "$(gate)"

echo "== a MixedCase header path, in the main checkout and in a linked worktree =="
# The first fix normcase()d the path it handed to git ("src/core/oologging.h"), which is absent
# at every base ref, so on the real tree the oo-z8zd header finding was STILL reported as new.
finding "$(native "$R/src/Core/OOLogging.h")" 3 >"$OUT"
check "pre-existing finding in src/Core/OOLogging.h passes" 0 "$(gate)"
W="$TMP/wt"
git -C "$R" worktree add -q --detach "$W" "$BASE" 2>/dev/null
cp "$R/src/a.mm" "$W/src/a.mm"
finding "$(native "$W/src/Core/OOLogging.h")" 3 >"$OUT"
tidy_gate "$W" "$BASE" "$W/src/a.mm" src/a.mm "$OUT" >/dev/null 2>&1
check "the same finding in a linked worktree (how the fleet runs) passes" 0 "$?"

echo "== never a silent pass =="
finding "$(native "$R/src/Core/OOLogging.h")" 3 >"$OUT"
tidy_gate "$R" 0123456789abcdef0123456789abcdef01234567 "$R/src/a.mm" src/a.mm "$OUT" >/dev/null 2>&1
check "a base ref git cannot read is 'cannot evaluate', not 'new file'" 2 "$?"
printf 'Segmentation fault\n' >"$OUT"
check "tidy output with no parseable finding cannot pass" 2 "$(gate)"
finding "$(native "$R/src/h.h")" 3 >"$OUT"
python "$(native tools/tier-a-tidy-baseline.py)" "$(native "$R/src/a.mm")" "$(native "$TMP/a.base")" "$(native "$OUT")" >/dev/null 2>&1
check "the tool refuses the old 3-argument call (no path-blind fallback)" 2 "$?"

# tier-a.sh's call site must hand the tool the repo root and base ref, or every header finding
# would be judged by a tool that cannot find the header's baseline. Case 1 already fails if it
# does not; this names the cause.
if grep -qxF '    "$(cygpath -m "$root")" "$base" || rc=$?' tools/tier-a.sh; then
	ok "tidy_gate passes the repo root and base ref to tier-a-tidy-baseline.py"
else
	bad "tidy_gate does not pass the repo root and base ref to tier-a-tidy-baseline.py"
fi

printf '\ntier-a-tidy-probe: %s ok, %s failed\n' "$pass" "$failn"
[ "$failn" -eq 0 ] || exit 1
