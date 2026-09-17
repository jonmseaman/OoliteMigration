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
#   * the start of a line (optionally indented), or a YAML list `- ` or `run:`, or a crontab
#     schedule;
#   * a shell operator that opens a command: `;`  `&`  `&&`  `|`  `||`  `(`  `$(`;
#   * a RUN PREFIX that executes its argument rather than reading it: `exec`, `nohup`,
#     `command`, `time`, `watch`, `timeout <n>`, `env FOO=1`, `xargs -n1`, a scheduling
#     wrapper with its options (`sudo -u bob`, `nice -n 5`, `ionice`, `stdbuf`, `setsid`,
#     `chrt`), or a shell keyword that is followed by a command (`then`, `do`, `else`, `if`,
#     `elif`, `while`, `until`, `!`);
#
# and where the program token ENDS at whitespace, a quote, `;`, `)`, `&`, `|`, or end of line.
# The terminator set matters: `if tools/foo.sh; then`, `while tools/foo.sh; do`, and
# `out=$(tools/foo.sh)` are all real bare-program calls, and a terminator set of only
# whitespace/quote/EOL silently missed every one of them.
#
# A USAGE COMMENT (`#     tools/foo.sh --list`) is also a call site, but a bare `#` opener
# cannot be trusted on its own: `# tools/foo.sh is prose in a comment` would otherwise force
# an unnecessary chmod. After a `#` opener the path must therefore be followed by end of line
# or by an ARGUMENT-SHAPED token -- one starting with `-`, `<`, `[`, `(`, `{`, a quote, `$`, a
# digit, `*` or `#` -- never by an English word.
#
# The path may appear either literally or as a SIBLING/VARIABLE DISPATCH -- a `$` expansion
# followed by the basename, e.g. `"$here/harvest.sh"` or
# `"$(dirname "${BASH_SOURCE[0]}")/gc.sh"`. Those are bare-program calls with no interpreter,
# so the exec bit is load-bearing on Linux even though the directory part is computed; the
# whole fleet toolchain under .agents/skills/beads-worker/scripts/ is dispatched that way.
# The dispatch rule keys on the basename alone, so it is only applied where the basename
# identifies exactly one tracked file -- and when it is suppressed for an ambiguous basename
# the suppression is ANNOUNCED (`note: ... dispatch rule suppressed`), never silent: silently
# disabling it re-opens the exact hole this guard exists to close.
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
#
# Sourcing: `CHECK_FILE_MODES_SOURCE_ONLY=1 . tools/check-file-modes.sh` defines the grammar
# and `build_re` and returns without scanning, so a probe can test the REAL regexes instead of
# a hand-copied paraphrase of them.
set -u

cd "$(dirname "$0")/.." || exit 1

note() { echo "check-file-modes: $*" >&2; }

# --- command-position grammar -------------------------------------------------------------
# Anything that may sit between the start of a command and the program name. Wrappers that
# take options (`sudo -u bob`, `nice -n 5`) must swallow those options too, or the call site
# after them is missed.
RUNPRE='((exec|nohup|command|time|watch)[[:space:]]+'
RUNPRE="$RUNPRE"'|(sudo|nice|ionice|stdbuf|setsid|chrt)([[:space:]]+-[^[:space:]]+([[:space:]]+[^-[:space:]][^[:space:]]*)?)*[[:space:]]+'
RUNPRE="$RUNPRE"'|timeout[[:space:]]+[0-9]+[smhd]?[[:space:]]+'
RUNPRE="$RUNPRE"'|env([[:space:]]+[A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*)+[[:space:]]+'
RUNPRE="$RUNPRE"'|xargs([[:space:]]+-[^[:space:]]+)*[[:space:]]+'
RUNPRE="$RUNPRE"'|(then|do|else|if|elif|while|until|!)[[:space:]]+)*'

# Positions that open a command (everything except a comment). A line whose first non-blank
# character is `#` is EXCLUDED here and handled only by the stricter usage-comment grammar
# below: otherwise the `(` / `;` openers turn ordinary prose such as
# `# run artifacts (tests/golden/run.sh); one dir per run` into a bogus call site.
NOTCMT='(^[^#[:space:]]|^[[:space:]]*[^#[:space:]])[^#]*'
BASE="(^[[:space:]]*(-[[:space:]]+|[-0-9*/,]+([[:space:]]+[-0-9*/,]+){4}[[:space:]]+)?|$NOTCMT[;&|(][[:space:]]*|$NOTCMT"'\$\([[:space:]]*|run:[[:space:]]*)'
# A usage-comment opener, which carries a stricter trailing requirement.
CMTBASE='^[[:space:]]*#[[:space:]]*'
# The program token must end at whitespace, a quote, `;`, `)`, `&`, `|`, or end of line.
TRAIL="([[:space:]\";')&|]|\$)"
# English function words. After a `#` opener the token following the path decides whether the
# line is a USAGE line or PROSE: `#   tools/gui-lock acquire [--timeout N]` is a call site,
# `# tools/gui-lock is the desktop mutex` is not. A real usage line is followed by end of line,
# by an argument-shaped token (`-x`, `<scenario>`, `[opts]`, `001`, `"s"`, `$X`, `#`), or by a
# SUBCOMMAND word (`acquire`, `release`, `status`) -- never by an English function word or a
# conjugated verb, which is what prose puts there. Matching on this word list rather than on
# indentation is deliberate: genuine usage headers in this tree use one space
# (`# tests/golden/run.sh <scenario>`) as well as three or five, so indent carries no signal.
PROSEWORD='(is|was|are|were|be|been|being|has|have|had|does|do|did|can|could|will|would|should'
PROSEWORD="$PROSEWORD"'|shall|must|may|might|the|a|an|and|or|but|so|then|than|that|which|who'
PROSEWORD="$PROSEWORD"'|whose|this|these|those|it|its|they|them|their|there|here|to|for|in|on'
PROSEWORD="$PROSEWORD"'|at|by|with|from|as|of|into|onto|about|above|below|over|under|only|also'
PROSEWORD="$PROSEWORD"'|still|now|never|always|often|just|instead|because|when|while|where|if'
PROSEWORD="$PROSEWORD"'|unless|until|since|after|before|during|via|per|not|no|we|you|our|your'
PROSEWORD="$PROSEWORD"'|my|runs|ran|lives|exists|contains|explains|handles|takes|gives|returns'
PROSEWORD="$PROSEWORD"'|reads|writes|needs|wants|uses|used|using|calls|called|invokes|invoked'
PROSEWORD="$PROSEWORD"'|creates|created|ships|shipped|passes|passed|fails|failed|adds|added'
PROSEWORD="$PROSEWORD"'|removes|removed|renames|renamed|replaces|replaced|moves|moved|expects'
PROSEWORD="$PROSEWORD"'|prints|printed|sets|gets|makes|made|becomes|became|would|wrote|stages)'
# After a `#` opener: end of line, an argument-shaped token, or a bare word. Bare words are
# admitted here and the PROSE ones are subtracted afterwards by build_reject_re -- POSIX ERE
# has no negative lookahead, so "word but not a prose word" cannot be one pattern.
TRAIL_USAGE="([[:space:]]*\$|[[:space:]]+[-<[({\"'\$0-9*#][^[:space:]]*|[[:space:]]+[A-Za-z][^[:space:]]*)"

ere_escape() { printf '%s' "$1" | sed 's/[].[*^$\\+?(){}|/]/\\&/g'; }

# build_form <path> [allow_dispatch] -- the program-token alternation for <path>.
build_form() {
	local path="$1" allow_dispatch="${2:-1}" base pe be form
	base=$(printf '%s' "$path" | sed 's|.*/||')
	pe=$(ere_escape "$path")
	be=$(ere_escape "$base")

	# Literal path in command position, optionally quoted and optionally ./-prefixed.
	form="[\"']?(\\./)?$pe"
	# Basename-anchored dispatch, with any directory part: covers sibling/variable dispatch
	# (`"$here/harvest.sh"`, `"$(dirname "${BASH_SOURCE[0]}")/gc.sh"`) and relative-prefix
	# invocation from a subdirectory (`scripts/accept.sh` for a path under .agents/...).
	if [ "$path" != "$base" ] && [ "$allow_dispatch" = 1 ]; then
		form="$form|[\"']?([^[:space:]\"';&|]*|\\\$\\([^)]*\\)[^[:space:]\"';&|]*)/$be"
	fi
	printf '%s' "$form"
}

# build_re <path> [allow_dispatch]  -- the exact ERE used to find candidate call sites.
build_re() {
	local path="$1" allow_dispatch="${2:-1}" form
	form=$(build_form "$path" "$allow_dispatch")
	printf '%s' "($BASE$RUNPRE($form)$TRAIL)|($CMTBASE$RUNPRE($form)$TRAIL_USAGE)"
}

# build_reject_re <path> [allow_dispatch] -- lines that the positive pattern matched but that
# are PROSE, not call sites: a `#` comment whose path is followed by an English word. Applied
# as a subtraction because POSIX ERE cannot express "a word that is not one of these".
build_reject_re() {
	local path="$1" allow_dispatch="${2:-1}" form
	form=$(build_form "$path" "$allow_dispatch")
	printf '%s' "$CMTBASE$RUNPRE($form)[[:space:]]+$PROSEWORD([^A-Za-z0-9_-]|\$)"
}

# line_is_call_site <path> <allow_dispatch> <line>  -- the single source of truth for the
# grammar, used by the scan below AND by tools/check-file-modes-probe.sh, so a probe cannot
# test a paraphrase of the rule instead of the rule.
line_is_call_site() {
	local path="$1" allow="$2" line="$3"
	printf '%s\n' "$line" | grep -qE "$(build_re "$path" "$allow")" || return 1
	printf '%s\n' "$line" | grep -qE "$(build_reject_re "$path" "$allow")" && return 1
	return 0
}

if [ "${CHECK_FILE_MODES_SOURCE_ONLY:-0}" = 1 ]; then
	return 0 2>/dev/null || exit 0
fi

LIST_ONLY=0
[ "${1:-}" = "--list" ] && LIST_ONLY=1

fail=0

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

# Basenames that are ambiguous across the tree: the variable-dispatch rule keys on the
# basename alone, so only apply it where the basename identifies exactly one tracked file.
dup_basenames=$(printf '%s\n' "$blobs" | cut -f2 | sed 's|.*/||' | sort | uniq -d)

is_dup_basename() {
	printf '%s\n' "$dup_basenames" | grep -qxF "$1"
}

# Does any tracked line, or any bead acceptance line, call PATH in command position?
# $2 is 1 to allow the sibling/variable-dispatch form, 0 to suppress it. The suppression
# decision is made by the CALLER, not here: this runs inside a command substitution, so any
# variable it set would die with the subshell and the suppression would go unannounced.
bare_call_sites() {
	local path="$1" allow="${2:-1}" re rej
	re=$(build_re "$path" "$allow")
	rej=$(build_reject_re "$path" "$allow")

	{
		git grep --cached -n -I -E "$re" -- ':!upstream/' ':!.beads/' 2>/dev/null
		grep -n -E "$re" "$ACC_FILE" 2>/dev/null | sed 's|^|.beads/acceptance:|'
	} | grep -v '^tools/check-file-modes\.sh:' | grep -v '^tools/check-file-modes-probe\.sh:' \
	  | grep -vE "$rej"
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

	# The dispatch rule keys on the basename alone, so it is only sound where the basename
	# identifies exactly one tracked file. Decide that HERE (not inside the command
	# substitution below, whose subshell cannot report back).
	base=$(printf '%s' "$path" | sed 's|.*/||')
	allow_dispatch=1
	if [ "$path" != "$base" ] && is_dup_basename "$base"; then
		allow_dispatch=0
	fi

	sites=$(bare_call_sites "$path" "$allow_dispatch")
	if [ -n "$sites" ]; then kind=bare-program; else kind=interpreted; fi

	# Never let the ambiguous-basename guard hide a possible bare-program script in silence:
	# a duplicated basename disables the dispatch rule, which is exactly how a 100644
	# fleet script slipped through before this guard existed.
	if [ "$allow_dispatch" = 0 ] && [ "$kind" = interpreted ] && [ "$mode" != 100755 ]; then
		if [ "$LIST_ONLY" = 1 ]; then
			echo "$mode $kind $path (dispatch rule suppressed: duplicate basename)"
		else
			note "note: $path has a duplicate basename ($base); the sibling/variable-dispatch rule is SUPPRESSED for it, so a \"\$dir/$base\" call site cannot be detected -- verify its mode by hand"
		fi
		continue
	fi

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
