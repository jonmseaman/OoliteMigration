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
# "Invoked as a bare program" is decided from the tree, not from a hand-kept list. The question
# this file answers for every line is ONE question of shell grammar: is the path token in
# COMMAND POSITION? Everything below is that question, and nothing below is a per-file
# special case. Command position means the path token is preceded by nothing but:
#
#   * the start of a line (optionally indented), or a YAML list `- ` or `run:`, or a crontab
#     schedule;
#   * a shell operator that opens a command: `;`  `&`  `&&`  `|`  `||`  `(`  `{`  `$(`  `[`,
#     or the `)` that terminates a `case` arm pattern -- at the start of a line as well as
#     mid-line, so `( tools/foo.sh )`, `{ tools/foo.sh; }`, `x() { tools/foo.sh; }`,
#     `  a) tools/foo.sh ;;` and `["$here/gc.sh"]` are call sites exactly as
#     `cd /x && tools/foo.sh` is. The case-arm `)` and the list `[` were added last: without
#     them a `case` branch and a dispatch inside a bracketed list both went unseen, and the
#     bracketed one was the single hole in the "a dispatch is never data" invariant below,
#     since the DATA rule correctly declines to reject a non-literal `$dir/base` token;
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
#
# THREE THINGS THAT LOOK LIKE COMMAND POSITION AND ARE NOT. Each of these fired as a false
# positive before it was named here, so each is enforced, not merely documented:
#
#   1. AN ASSIGNMENT. `FOO=tools/foo.sh`, `X=tools/foo.sh; echo`, `COMPDB_READER="$REPO/x.sh"`
#      are not command position -- what matters is how the variable is later USED. The
#      unquoted form used to match, because the dispatch rule's directory part happily
#      swallowed the `FOO=` prefix; `=` (and `,`, and a backtick) are therefore excluded from
#      the directory part of a dispatch, so no assignment prefix can be mistaken for a
#      directory. The env-assignment RUN PREFIX (`FOO=1 tools/foo.sh`) that exists alongside
#      it must NOT swallow an opening quote: `CMD="bash tools/foo.sh"` is an assignment of an
#      interpreter invocation, not a prefixed command, so the prefix's value part excludes
#      quotes and backticks.
#   2. A DATA LIST ELEMENT. A quoted path that is a list element or a mapping key --
#      `    "tools/launcher_scan.py",` in a Python tuple, `["tools/foo.sh"]`,
#      `"tools/foo.sh": 1` in JSON -- is data being named, not a program being run. Rejected
#      when the quoted token is the LITERAL path and the whole line is that token plus list
#      punctuation. A dispatch such as `"$here/gc.sh"` is not rejected: it is not the literal
#      path, so it is never data.
#   3. A LINE INSIDE AN OPEN QUOTED STRING. The scan is line-oriented, so a bare path on its
#      own line inside a multi-line `VAR="..."` literal looked like a command. open_quote_lines
#      tracks double-quote state across a file (honouring backslash escapes, single-quoted
#      segments, `#` comments, heredocs and Python triple quotes) and every line that BEGINS
#      inside an open double-quoted string is skipped. That is what stopped
#      tools/check-splash-off.py -- listed on its own line inside a `LOCKED_LAUNCHERS="..."`
#      block and only ever invoked through python3 -- from being ordered to become 100755.
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
# Cost: the tree is walked ONCE, with a fixed-string search for every shebang-bearing
# basename, and the per-path regexes then run over that small candidate set. Walking the whole
# tree once per script instead took ~84s here.
#
# Sourcing: `CHECK_FILE_MODES_SOURCE_ONLY=1 . tools/check-file-modes.sh` defines the grammar,
# `build_re`, `line_is_call_site` and `open_quote_lines` and returns without scanning, so a
# probe can test the REAL regexes instead of a hand-copied paraphrase of them.
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
# A bare env-assignment PREFIX (`FOO=1 tools/foo.sh`) is command position: the command
# follows it. It requires trailing whitespace and a command after it, which is exactly what
# distinguishes it from a plain assignment (`FOO=tools/foo.sh`, nothing after).
# The assigned value must not contain a QUOTE, a BACKTICK or a `(`. Without that exclusion the
# UNTERMINATED OPENING QUOTE of a quoted value, or the `$(` of a command substitution, was
# swallowed as the value itself, so the next token looked like a command:
# `CMD="bash tools/foo.sh"` parsed as prefix `CMD="` plus command `bash ...`, and
# `spawners=$(python3 tools/launcher_scan.py tools)` -- a LIVE line in
# tools/check-desktop-lock.sh -- parsed as prefix `spawners=$(python3 ` plus a bare-program
# call. Storing or capturing an interpreter invocation is the commonest shape of exactly the
# class this guard exists to EXCLUDE.
RUNPRE="$RUNPRE"'|[A-Za-z_][A-Za-z0-9_]*=[^[:space:]"'"'"'`(]*[[:space:]]+'
RUNPRE="$RUNPRE"'|(then|do|else|if|elif|while|until|!)[[:space:]]+)*'

# Positions that open a command (everything except a comment). A line whose first non-blank
# character is `#` is EXCLUDED here and handled only by the stricter usage-comment grammar
# below: otherwise the `(` / `;` openers turn ordinary prose such as
# `# run artifacts (tests/golden/run.sh); one dir per run` into a bogus call site.
NOTCMT='(^[^#[:space:]]|^[[:space:]]*[^#[:space:]])[^#]*'
# `( cmd )`, `{ cmd; }` and `x() { cmd; }` open a command too. The mid-line case is covered by
# NOTCMT plus the operator class; a line that STARTS with the group opener has no preceding
# token at all, so it needs its own leading alternative.
GRP='[({[][[:space:]]*'
BASE="(^[[:space:]]*($GRP)?(-[[:space:]]+|[-0-9*/,]+([[:space:]]+[-0-9*/,]+){4}[[:space:]]+)?|$NOTCMT[;&|({[)][[:space:]]*|$NOTCMT"'\$\([[:space:]]*|run:[[:space:]]*)'
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
	# The directory part excludes `=`, `,` and a backtick: without that exclusion the
	# assignment `FOO=tools/foo.sh` parsed as directory `FOO=tools`, and an assignment is
	# not command position.
	if [ "$path" != "$base" ] && [ "$allow_dispatch" = 1 ]; then
		form="$form|[\"']?([^[:space:]\"';&|=,\`]*|\\\$\\([^)]*\\)[^[:space:]\"';&|=,\`]*)/$be"
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
# are NOT call sites. Applied as a subtraction because POSIX ERE cannot express "a word that
# is not one of these". Two classes:
#   * PROSE: a `#` comment whose path is followed by an English word.
#   * DATA: a quoted LITERAL path that is a list element or a mapping key. The whole line must
#     be that quoted token plus list punctuation -- a leading `[`/`(`/`,`/`-` or a trailing
#     `,`/`]`/`}`/`)`/`:` -- so a variable dispatch (`"$here/gc.sh"`) is never data.
build_reject_re() {
	local path="$1" allow_dispatch="${2:-1}" form pe prose data
	form=$(build_form "$path" "$allow_dispatch")
	pe=$(ere_escape "$path")
	prose="$CMTBASE$RUNPRE($form)[[:space:]]+$PROSEWORD([^A-Za-z0-9_-]|\$)"
	data="^[[:space:]]*([][({,-][[:space:]]*)*[\"'](\\./)?$pe[\"'][[:space:]]*[]},:)]*[[:space:]]*\$"
	data="$data|^[[:space:]]*[\"'](\\./)?$pe[\"'][[:space:]]*:"
	printf '%s' "($prose)|($data)"
}

# line_is_call_site <path> <allow_dispatch> <line>  -- the single source of truth for the
# grammar, used by the scan below AND by tools/check-file-modes-probe.sh, so a probe cannot
# test a paraphrase of the rule instead of the rule. NOTE: this judges ONE line in isolation;
# the multi-line quoted-string rule lives in open_quote_lines and is applied by the scan.
line_is_call_site() {
	local path="$1" allow="$2" line="$3"
	printf '%s\n' "$line" | grep -qE "$(build_re "$path" "$allow")" || return 1
	printf '%s\n' "$line" | grep -qE "$(build_reject_re "$path" "$allow")" && return 1
	return 0
}

# open_quote_lines -- read a file on stdin, print the 1-based numbers of the lines that BEGIN
# inside an unterminated double-quoted string. Those lines are string DATA, not commands: a
# bare path on its own line inside `LOCKED_LAUNCHERS="..."` is not a call site.
#
# This is a deliberately crude tracker, not a shell parser. It honours backslash escapes,
# single-quoted segments (literal, no interpolation), `#` comments outside quotes, heredoc
# bodies (skipped wholesale), and Python/TOML triple quotes (tracked so the three quotes
# cannot corrupt the double-quote counter, but their bodies are NOT suppressed -- a module
# docstring may legitimately carry a usage line). It errs toward reporting nothing: an
# unrecognised construct leaves the state closed, which keeps the old behaviour rather than
# silently hiding a call site.
open_quote_lines() {
	awk '
	function scan(s,   i, c, n) {
		n = length(s)
		for (i = 1; i <= n; i++) {
			c = substr(s, i, 1)
			if (intq) {
				if (substr(s, i, 3) == "\"\"\"") { intq = 0; i += 2 }
				continue
			}
			if (inq) {
				if (c == "\\") { i++; continue }
				if (c == "\"") inq = 0
				continue
			}
			if (c == "\\") { i++; continue }
			if (c == "'"'"'") {
				i++
				while (i <= n && substr(s, i, 1) != "'"'"'") i++
				continue
			}
			if (c == "#") return
			if (substr(s, i, 3) == "\"\"\"") { intq = 1; i += 2; continue }
			if (c == "\"") inq = 1
		}
	}
	BEGIN { inq = 0; intq = 0; inhd = 0 }
	{
		if (inq) print NR
		if (inhd) { if ($0 ~ hdre) inhd = 0; next }
		scan($0)
		if (!inq && !intq && match($0, /<<-?["'"'"']?[A-Za-z_][A-Za-z0-9_]*/)) {
			tag = substr($0, RSTART, RLENGTH)
			sub(/^<<-?["'"'"']?/, "", tag)
			hdre = "^[[:space:]]*" tag "[[:space:]]*$"
			inhd = 1
		}
	}'
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

ACC_FILE=$(mktemp) || exit 1
CLASS=$(mktemp) || exit 1
PATFILE=$(mktemp) || exit 1
CANDALL=$(mktemp) || exit 1
CANDMETA=$(mktemp) || exit 1
CANDTEXT=$(mktemp) || exit 1
trap 'rm -f "$ACC_FILE" "$CLASS" "$PATFILE" "$CANDALL" "$CANDMETA" "$CANDTEXT"' EXIT

# Bead acceptance criteria, one command per line: executed verbatim by accept.sh.
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

# --- pass 1: mode + shebang for every tracked blob -----------------------------------------
# ONE `git cat-file --batch` for the whole tree rather than one process per file: on Windows
# the per-process cost dominates everything else this script does. `--batch` emits a header
# line and then raw bytes, so the stream is split by SIZE (not by newlines, which arbitrary
# blob content contains) and only the first two bytes of each blob are inspected.
shebangs=$(printf '%s\n' "$blobs" | cut -f2 | sed 's|^|:|' | git cat-file --batch 2>/dev/null | python3 -c '
import sys
buf = sys.stdin.buffer
out = []
while True:
    hdr = buf.readline()
    if not hdr:
        break
    parts = hdr.split()
    if len(parts) < 3:
        break
    size = int(parts[2])
    body = buf.read(size)
    buf.read(1)
    out.append("yes" if body[:2] == b"#!" else "no")
sys.stdout.buffer.write(("\n".join(out) + ("\n" if out else "")).encode())
')
paste <(printf '%s\n' "$blobs") <(printf '%s' "$shebangs") >"$CLASS"
# If the batch read desynchronised for any reason, fall back to the per-file probe rather
# than mis-classify: a wrong `no` here would silently skip a script.
if [ "$(wc -l <"$CLASS")" != "$(printf '%s\n' "$blobs" | wc -l)" ] \
   || grep -qvE $'	(yes|no)$' "$CLASS"; then
	note "note: batched shebang read desynchronised; falling back to one read per file"
	: >"$CLASS"
	while IFS=$'	' read -r mode path; do
		[ -n "${path:-}" ] || continue
		if has_shebang "$path"; then sb=yes; else sb=no; fi
		printf '%s	%s	%s\n' "$mode" "$path" "$sb" >>"$CLASS"
	done <<EOF
$blobs
EOF
fi

# --- pass 2: ONE walk of the tree for every candidate line ---------------------------------
# Every form the grammar can match -- literal path, `./` prefix, quoted, or a `$dir/` dispatch
# -- contains the file's BASENAME verbatim, so a single fixed-string search for the basenames
# of all shebang-bearing files is a sound superset of the candidates. The expensive per-path
# regexes then run over that superset instead of over the whole tree, once per script.
awk -F'\t' '$3 == "yes" { n = $2; sub(/.*\//, "", n); print n }' "$CLASS" | sort -u >"$PATFILE"

if [ -s "$PATFILE" ]; then
	{
		git grep --cached -n -I -F -f "$PATFILE" -- ':!upstream/' ':!.beads/' 2>/dev/null
		grep -n -F -f "$PATFILE" "$ACC_FILE" 2>/dev/null | sed 's|^|.beads/acceptance:|'
	} | awk '
	{
		sub(/\r$/, "")
		i = index($0, ":");            if (i == 0) next
		f = substr($0, 1, i - 1)
		r = substr($0, i + 1)
		j = index(r, ":");             if (j == 0) next
		if (f == "tools/check-file-modes.sh") next
		if (f == "tools/check-file-modes-probe.sh") next
		print f ":" substr(r, 1, j - 1) "	" substr(r, j + 1)
	}' >"$CANDALL"
	# Split into two line-aligned files. The split is done here, by the SHELL, rather than by
	# handing temp paths to a helper: MSYS `mktemp` yields a /tmp path that a native Windows
	# python resolves to a different directory, so a helper opening argv paths silently wrote
	# its output where nothing would read it and every file looked interpreted.
	cut -f1 <"$CANDALL" >"$CANDMETA"
	cut -f2- <"$CANDALL" >"$CANDTEXT"
fi

# Memoised open-double-quote line sets, so each candidate file is parsed at most once.
OPENQ_DONE=" "
OPENQ_SET=" "
in_open_quote() {
	local f="$1" ln="$2" nums n
	case "$OPENQ_DONE" in
	*" $f "*) ;;
	*)
		OPENQ_DONE="$OPENQ_DONE$f "
		nums=$(git cat-file blob ":$f" 2>/dev/null | open_quote_lines)
		for n in $nums; do OPENQ_SET="$OPENQ_SET$f:$n "; done
		;;
	esac
	case "$OPENQ_SET" in
	*" $f:$ln "*) return 0 ;;
	esac
	return 1
}

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
# The rejection is a second grep over the SAME candidate file rather than a per-line grep, so
# the cost is a fixed handful of processes per script instead of two per matching line.
bare_call_sites() {
	local path="$1" allow="${2:-1}" re rej hits rejs keep line f ln out=''
	[ -s "$CANDTEXT" ] || return 0
	re=$(build_re "$path" "$allow")
	rej=$(build_reject_re "$path" "$allow")

	hits=$(grep -nE "$re" "$CANDTEXT" 2>/dev/null | cut -d: -f1)
	[ -n "$hits" ] || return 0
	rejs=$(grep -nE "$rej" "$CANDTEXT" 2>/dev/null | cut -d: -f1)
	if [ -n "$rejs" ]; then
		keep=$(comm -23 <(printf '%s\n' "$hits" | sort -n) \
		                <(printf '%s\n' "$rejs" | sort -n))
	else
		keep="$hits"
	fi
	[ -n "$keep" ] || return 0

	# One awk pass joins the surviving line numbers to their "<file>:<lineno>" and text.
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		f=${line%%:*}
		ln=${line#*:}
		ln=${ln%%:*}
		in_open_quote "$f" "$ln" && continue
		out="$out$line
"
	done <<EOF
$(printf '%s\n' "$keep" | awk -v mf="$CANDMETA" -v tf="$CANDTEXT" '
	NR == FNR { want[$1] = 1; next }
	{ m[FNR] = $0 }
	END {
		while ((getline t < tf) > 0) { n++; if (n in want) print m[n] ":" t }
	}' - "$CANDMETA")
EOF
	printf '%s' "$out"
}

while IFS=$'\t' read -r mode path sb; do
	[ -n "${path:-}" ] || continue

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
done <"$CLASS"

if [ "$LIST_ONLY" = 1 ]; then
	exit 0
fi

if [ "$fail" -ne 0 ]; then
	note "FAILED - see docs/decisions or CLAUDE.md 'Repo conventions' for the shebang/mode rule"
	exit 1
fi
echo "check-file-modes: OK - every bare-program script is 100755, nothing is 100755 without a shebang"
