#!/usr/bin/env bash
# tools/check-beads-db-merge.sh — the bead DB export never conflicts an accept again (bead oo-c4ly).
#
# The design under test: .beads/issues.jsonl is a GENERATED export of the Dolt DB. Nothing writes
# a bead's notes, status or fields into that file by hand; `bd` writes Dolt and the export is
# regenerated from Dolt. So a merge conflict in the file carries no information the base branch's
# fresh export lacks, and accept.sh resolves such a conflict by taking the base side and then
# regenerating. Two guards keep that true: export.auto is off (worktrees stop rewriting their
# copies) and the tracked copy is refreshed only on the base branch by accept.sh.
#
# This script proves, on a scratch worktree, no live bead touched:
#   1. a real two-sided conflict (each side edits a different bead's record; both append different
#      notes to the SAME bead's record) is resolved by resolve_beads_db_conflict to exactly the
#      base side, with no duplicate ids and no record lost or gained;
#   2. the resolver REFUSES when anything other than .beads/*.jsonl conflicts, so a genuine
#      conflict in bead work is still a rejection, never silently taken from one side;
#   3. the information argument holds on the live DB: for the ten most recently updated beads a
#      fresh `bd export` carries exactly the notes `bd show` reports, so anything a branch's copy
#      had (which came through bd) is in the regenerated export;
#   4. export.auto is off in .beads/config.yaml and the export is still tracked (option d of the
#      bead, untracking it, is rejected: reviewers and tools read it).
#
# Run from the repo root in the UCRT64 shell. ~10 s. Leaves no worktree behind.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=../.agents/skills/beads-worker/scripts/_lib.sh
source "$root/.agents/skills/beads-worker/scripts/_lib.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
step() { echo "== $*"; }

f=.beads/issues.jsonl
git ls-files --error-unmatch "$f" >/dev/null 2>&1 || fail "$f is not tracked; the export must stay in git (reviewers and tools/check-file-modes.sh read it)"

T="$(mktemp -d "${TMPDIR:-/tmp}/beadsmerge.XXXXXX")"
rm -rf "$T"
# Branches are repo-wide even when made from a scratch worktree: name them per run and delete them.
pfx="ctl-$$"
cleanup() {
	git worktree remove --force "$T" >/dev/null 2>&1 || rm -rf "$T"
	git worktree prune >/dev/null 2>&1 || true
	git branch --list "$pfx-*" | tr -d ' *' | xargs -r git branch -D >/dev/null 2>&1 || true
}
trap cleanup EXIT
git worktree add --detach "$T" HEAD >/dev/null 2>&1 || fail "could not create a scratch worktree"

# Three ids to play with: the first three records of the tracked export. (tr strips the CR that
# a Windows python adds to stdout; a stray CR in an id matched no record and made the control
# vacuous on its first run.)
mapfile -t ids < <(python3 -c 'import json,sys
for n,l in enumerate(open(sys.argv[1],encoding="utf-8")):
    if n==3: break
    print(json.loads(l)["id"])' "$T/$f" | tr -d '\r')
[ "${#ids[@]}" -eq 3 ] || fail "need at least three records in $f"
X="${ids[0]}"; Y="${ids[1]}"; Z="${ids[2]}"

# edit_record <file> <id> <field> <suffix>: append <suffix> to a string field of one record, in place
edit_record() {
	python3 - "$1" "$2" "$3" "$4" <<'PY'
import json, sys
path, bead, field, suffix = sys.argv[1:]
out = []
for line in open(path, encoding="utf-8"):
    if not line.strip():
        continue
    rec = json.loads(line)
    if rec["id"] == bead:
        rec[field] = (rec.get(field) or "") + suffix
    out.append(json.dumps(rec, ensure_ascii=False, separators=(",", ":")))
open(path, "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
PY
}

g() { git -C "$T" -c user.name=ctl -c user.email=ctl@local "$@"; }

step "1/4 two-sided conflict in the export alone resolves to the base side, nothing lost or duplicated"
g checkout -q -b $pfx-base
g checkout -q -b $pfx-a
edit_record "$T/$f" "$X" title " [side A]"
edit_record "$T/$f" "$Z" notes " A-note"
g commit -q -am "ctl: side A"
g checkout -q $pfx-base
g checkout -q -b $pfx-b
edit_record "$T/$f" "$Y" title " [side B]"
edit_record "$T/$f" "$Z" notes " B-note"
g commit -q -am "ctl: side B"
g checkout -q $pfx-a
if g merge --no-ff --no-edit $pfx-b >/dev/null 2>&1; then
	fail "the two sides merged cleanly; the control did not construct a conflict"
fi
[ "$(g diff --name-only --diff-filter=U)" = "$f" ] || fail "expected the conflict to be in $f alone, got: $(g diff --name-only --diff-filter=U | tr '\n' ' ')"
resolve_beads_db_conflict "$T" || fail "resolve_beads_db_conflict refused an export-only conflict"
g commit -q --no-edit
g diff --quiet $pfx-a~1 -- "$f" || fail "the resolution is not byte-identical to the base side (side A) of $f"
python3 - "$T/$f" "$(git -C "$T" show $pfx-base:"$f" | wc -l)" <<'PY'
import json, sys
path, base_count = sys.argv[1], int(sys.argv[2])
ids = [json.loads(l)["id"] for l in open(path, encoding="utf-8") if l.strip()]
dup = sorted({i for i in ids if ids.count(i) > 1})
assert not dup, "duplicate ids after resolution: %r" % dup[:5]
assert len(ids) == base_count, "record count moved: %d -> %d" % (base_count, len(ids))
print("  resolved: %d records, no duplicate ids, count unchanged" % len(ids))
PY
echo "  side B's edits to $Y and $Z are NOT in the resolved file by design: they never lived only there (step 3)"

step "2/4 the resolver refuses when a non-export file conflicts"
g checkout -q $pfx-base
g checkout -q -b $pfx-c
edit_record "$T/$f" "$Z" notes " C-note"
printf 'side C\n' > "$T/ctl-probe.txt"
g add ctl-probe.txt
g commit -q -am "ctl: side C"
g checkout -q $pfx-base
g checkout -q -b $pfx-d
edit_record "$T/$f" "$Z" notes " D-note"
printf 'side D\n' > "$T/ctl-probe.txt"
g add ctl-probe.txt
g commit -q -am "ctl: side D"
g checkout -q $pfx-c
if g merge --no-ff --no-edit $pfx-d >/dev/null 2>&1; then fail "control C/D merged cleanly"; fi
if resolve_beads_db_conflict "$T"; then fail "the resolver took a side while ctl-probe.txt was also in conflict"; fi
[ -n "$(g diff --name-only --diff-filter=U | grep -x ctl-probe.txt)" ] || fail "the refused merge lost its non-export conflict marker"
g merge --abort
echo "  refused, merge left for the worker: $(g diff --name-only --diff-filter=U | wc -l) conflicts remain after abort check"

step "3/4 a fresh export carries exactly the notes the DB reports (ten most recently updated beads)"
E="$T/fresh.jsonl"
real_bd export -o "$E" >/dev/null 2>&1 || fail "bd export failed"
# (the UCRT64 jq writes CRLF; strip the CR or every id below carries one and matches nothing)
recent="$(real_bd list -n 0 --json 2>/dev/null | jq -r 'sort_by(.updated_at) | reverse | .[:10] | .[].id' | tr -d '\r')"
[ -n "$recent" ] || fail "bd list returned nothing"
n=0
for id in $recent; do
	want="$(real_bd show "$id" --json 2>/dev/null | jq -r 'if type=="array" then .[0] else . end | .notes // ""' | tr -d '\r')"
	got="$(jq -r --arg id "$id" 'select(.id==$id) | .notes // ""' "$E" | tr -d '\r')"
	[ "$want" = "$got" ] || fail "export notes differ from bd show for $id"
	n=$((n + 1))
done
echo "  $n beads: export notes == bd show notes"

step "4/4 export.auto is off and the export stays tracked"
# The `export:` block is read into a variable and matched by the shell rather than piped into
# `grep -qE`. This file runs under `set -euo pipefail` (line 24), and `producer | grep -q` is
# the trap bead oo-mxgy audited: grep -q exits on the first match, SIGPIPEs the awk still
# writing, and pipefail turns a SUCCESSFUL match into exit 141. Measured here: the awk emits
# only 35 bytes, so it always completes inside the 64 KB pipe buffer and the site could NOT be
# made to fire (0 failures in 200 in-place runs). The shape is removed anyway - it fires the
# day the config grows, the failure mode is silent, and `|| true` would swallow real errors.
# A trailing YAML comment on the setting is LEGAL and must not fail the guard (bead oo-ehyx):
# `auto: false   # keep exports manual` is the same setting as `auto: false`. The comment is
# stripped only where YAML says one starts -- at a `#` PRECEDED BY WHITESPACE (or at the very
# start of the value) -- so `auto: falsey` and `auto: false# nospace` still do NOT match: in
# YAML both are the plain scalars "falsey" and "false# nospace", neither of which is false.
# The old `grep -qE '^\s*auto:\s*false'` matched both of those because it was unanchored at the
# end; that tightening came in with oo-mxgy and is deliberately kept.
export_block="$(awk '/^export:/{f=1;next} f&&/^[^ ]/{f=0} f' .beads/config.yaml)"
auto_off=0
while IFS= read -r cfgline; do
	# >>> BEGIN export.auto matcher (tools/test_export_auto_matcher.py runs exactly these lines) >>>
	cfgline="${cfgline%$'\r'}"
	cfgline="${cfgline#"${cfgline%%[![:space:]]*}"}"   # strip leading whitespace
	cfgline="${cfgline%"${cfgline##*[![:space:]]}"}"   # strip trailing whitespace
	case "$cfgline" in
	"auto:"*)
		val="${cfgline#auto:}"
		val="${val#"${val%%[![:space:]]*}"}"       # strip leading whitespace
		case "$val" in
		"#"*) val="" ;;                            # the value is only a comment
		*[[:space:]]"#"*) val="${val%%[[:space:]]"#"*}" ;;  # drop a trailing comment
		esac
		val="${val%"${val##*[![:space:]]}"}"       # re-trim what the comment left behind
		# An `if` rather than `[ ... ] && auto_off=1`: the `&&` list returns 1 on a
		# non-false value, so it leaves the loop body's exit status at 1 - fragile under
		# `set -e` (line 24) and dependent on subtle rules about which positions are
		# exempt. Measured on main before this change: the script did NOT die there, it
		# still printed the FAIL message and exited 1. This is defensive, not a bug fix.
		if [ "$val" = "false" ]; then auto_off=1; fi
		;;
	esac
	# <<< END export.auto matcher <<<
done <<EOF
$export_block
EOF
[ "$auto_off" = 1 ] || fail "export.auto is not false in .beads/config.yaml"
echo "PASS: export-only conflicts resolve to the base side (no loss, no duplicates), non-export conflicts are refused, a fresh export matches the DB, export.auto is off and the export is tracked"
