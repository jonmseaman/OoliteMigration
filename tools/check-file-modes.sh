#!/usr/bin/env bash
#
# Guardrail: git index file modes match the repo's shebang/exec-bit convention.
#
#     tools/check-file-modes.sh            # enforce; exit 1 on any violation
#     tools/check-file-modes.sh --list     # report every shebang/mode fact, exit 0
#
# THE RULE (CLAUDE.md "Repo conventions"):
#
#   * A file invoked as a BARE PROGRAM (`tools/foo`, `./foo`) MUST be mode 100755 in the
#     git index and MUST start with a `#!` shebang.
#   * A file always invoked through an interpreter (`python3 tools/foo.py`, `bash tools/foo.sh`)
#     MAY be 100644; a shebang on it is documentation, not a promise.
#   * Nothing is 100755 without a shebang.
#
# Why a check and not a habit: MSYS on NTFS reports rwx for every file, so `test -x` is
# always true on the Windows fleet machine and cannot see the defect. `git ls-files -s` is
# what the index actually records and what a Linux checkout or CI will see, so that is what
# this checks. tools/gui-lock shipped 100644 with a `test -x` acceptance that passed on this
# machine and would have failed anywhere else (bead oo-tqmx); this exists so that cannot recur.
#
# "Invoked as a bare program" is decided from the tree, not from a hand-kept list. A call site
# is a tracked line where the path stands in COMMAND POSITION. Command position means the path
# token is preceded by nothing but:
#
#   * the start of a line (optionally indented), or a usage-comment `#`, or a YAML list `- `
#     or `run:`, or a crontab schedule;
#   * a shell operator that opens a command: `;`  `&`  `&&`  `|`  `||`  `(`  `$(`;
#   * a RUN PREFIX that executes its argument rather than reading it: `exec`, `nohup`,
#     `command`, `sudo`, `time`, `timeout <n>`, `env FOO=1`, `xargs -n1`, `then`, `do`, `else`.
#
# and where the path appears either literally or as a SIBLING/VARIABLE DISPATCH -- a `$`
# expansion followed by the basename, e.g. `"$here/harvest.sh"` or
# `"$(dirname "${BASH_SOURCE[0]}")/gc.sh"`. Those are bare-program calls with no interpreter,
# so the exec bit is load-bearing on Linux even though the directory part is computed; the
# whole fleet toolchain under .agents/skills/beads-worker/scripts/ is dispatched that way.
# A variable-held path in an ASSIGNMENT (`COMPDB_READER="$REPO/tools/x.py"`) is not command
# position and is not a call site -- what matters is how the variable is later used.
#
# A path that only ever appears after an interpreter (`python3 tools/x.py`), as an argument to
# a command that reads it (`git ls-files -s tools/x.py`, `grep pat tools/x.py`), or quoted in
# prose (`` `tools/x.sh` ``) is not a call site: none of those need the exec bit.
#
# BEAD ACCEPTANCE LINES COUNT. accept.sh runs a bead's acceptance_criteria verbatim in a clean
# checkout, so `timeout 30 tools/tier-a.sh <file>` in a bead is a real bare-program call site on
# a Linux runner. .beads/issues.jsonl is a single-line-per-issue JSONL database whose prose
# fields would otherwise swamp the search, so this extracts just the acceptance_criteria field
# of every issue and scans that, rather than excluding the directory wholesale.
#
# upstream/ is a third-party subtree and is excluded: its modes come from upstream.
set -u

cd "$(dirname "$0")/.." || exit 1

LIST_ONLY=0
[ "${1:-}" = "--list" ] && LIST_ONLY=1

fail=0
note() { echo "check-file-modes: $*" >&2; }

# Tracked, non-upstream, non-submodule blobs, as "<mode><TAB><path>".
# Honours GIT_INDEX_FILE, so a scratch index can be probed without touching the real one.
blobs=$(git ls-files -s | grep -v '^160000' | sed 's/^\([0-7]*\) [0-9a-f]* [0-3]\t/\1\t/' \
        | grep -v $'\t''upstream/')

# The shebang must be read from the same place the mode comes from -- the INDEX, not the
# working tree. They can disagree (staged chmod, staged content, a file deleted from disk but
# still in the index), and reading the worktree made a staged-only file look shebang-less and
# get silently skipped instead of reported.
has_shebang() { [ "$(git cat-file blob ":$1" 2>/dev/null | head -c 2)" = '#!' ]; }

# Bead acceptance criteria, one command per line: executed verbatim by accept.sh.
ACC_FILE=$(mktemp) || exit 1
trap 'rm -f "$ACC_FILE"' EXIT
if git cat-file -e :.beads/issues.jsonl 2>/dev/null; then
	git cat-file blob :.beads/issues.jsonl 2>/dev/null | python3 -c '
import json, sys
for raw in sys.stdin:
    raw = raw.strip()
    if not raw:
        continue
    try:
        rec = json.loads(raw)
    except ValueError:
        continue
    acc = rec.get("acceptance_criteria") or ""
    for line in acc.splitlines():
        if line.strip():
            print("%s\t%s" % (rec.get("id", "?"), line))
' >"$ACC_FILE" 2>/dev/null || : >"$ACC_FILE"
fi
[ -s "$ACC_FILE" ] || note "note: no bead acceptance lines extracted; acceptance call sites not scanned"

# --- command-position grammar -------------------------------------------------------------
# Anything that may sit between the start of a command and the program name.
RUNPRE="((exec|nohup|command|sudo|time|watch)[[:space:]]+|timeout[[:space:]]+[0-9]+[smhd]?[[:space:]]+|env([[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)+[[:space:]]+|xargs([[:space:]]+-[^[:space:]]+)*[[:space:]]+|(then|do|else|if|elif|while|until|!)[[:space:]]+)*"
# Positions that open a command.
BASE="(^[[:space:]]*(#[[:space:]]*|-[[:space:]]+|[-0-9*/,]+([[:space:]]+[-0-9*/,]+){4}[[:space:]]+)?|[;&|(][[:space:]]*|\\\$\\([[:space:]]*|run:[[:space:]]*)"
# The program token must end at whitespace, a closing quote, or end of line.
TRAIL="([[:space:]\"']|\$)"

ere_escape() { printf '%s' "$1" | sed 's/[].[*^$\\+?(){}|/]/\\&/g'; }

# Basenames that are ambiguous across the tree: the variable-dispatch rule keys on the
# basename alone, so only apply it where the basename identifies exactly one tracked file.
dup_basenames=$(printf '%s\n' "$blobs" | cut -f2 | sed 's|.*/||' | sort | uniq -d)

is_dup_basename() {
	printf '%s\n' "$dup_basenames" | grep -qxF "$1"
}

# Does any tracked line, or any bead acceptance line, call PATH in command position?
bare_call_sites() {
	local path="$1" base
	base=$(printf '%s' "$path" | sed 's|.*/||')
	local pe be re
	pe=$(ere_escape "$path")
	be=$(ere_escape "$base")

	# Literal path in command position, optionally quoted and optionally ./-prefixed.
	local form="[\"']?(\\./)?$pe"
	# Basename-anchored dispatch, with any directory part: covers sibling/variable dispatch
	# (`"$here/harvest.sh"`, `"$(dirname "${BASH_SOURCE[0]}")/gc.sh"`) and relative-prefix
	# invocation from a subdirectory (`scripts/accept.sh` for a path under .agents/...).
	# Only safe when the basename identifies exactly one tracked file.
	if [ "$path" != "$base" ] && ! is_dup_basename "$base"; then
		form="$form|[\"']?([^[:space:]\"';&|]*|\\\$\\([^)]*\\)[^[:space:]\"';&|]*)/$be"
	fi
	re="$BASE$RUNPRE($form)$TRAIL"

	{
		git grep --cached -n -I -E "$re" -- ':!upstream/' ':!.beads/' 2>/dev/null
		grep -n -E "$re" "$ACC_FILE" 2>/dev/null | sed 's|^|.beads/acceptance:|'
	} | grep -v '^tools/check-file-modes\.sh:'
}

while IFS=$'\t' read -r mode path; do
	[ -n "${path:-}" ] || continue
	if has_shebang "$path"; then sb=yes; else sb=no; fi

	if [ "$sb" = no ] && [ "$mode" = 100755 ]; then
		if [ "$LIST_ONLY" = 1 ]; then
			echo "100755 no-shebang   $path"
		else
			note "$path is 100755 but has no '#!' shebang; use 100644 (git update-index --chmod=-x $path)"
			fail=1
		fi
		continue
	fi

	[ "$sb" = yes ] || continue

	sites=$(bare_call_sites "$path")
	if [ -n "$sites" ]; then kind=bare-program; else kind=interpreted; fi

	if [ "$LIST_ONLY" = 1 ]; then
		echo "$mode $kind $path"
		continue
	fi

	if [ "$kind" = bare-program ] && [ "$mode" != 100755 ]; then
		note "$path is invoked as a bare program but is committed $mode; run: git update-index --chmod=+x $path"
		printf '%s\n' "$sites" | head -5 | sed 's/^/    call site: /' >&2
		fail=1
	fi
done <<EOF
$blobs
EOF

if [ "$LIST_ONLY" = 1 ]; then
	exit 0
fi

if [ "$fail" -ne 0 ]; then
	note "FAILED - see docs/decisions or CLAUDE.md 'Repo conventions' for the shebang/mode rule"
	exit 1
fi
echo "check-file-modes: OK - every bare-program script is 100755, nothing is 100755 without a shebang"
