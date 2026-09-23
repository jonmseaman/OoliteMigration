#!/usr/bin/env bash
# Probe the REAL regexes: source check-file-modes.sh and call its own build_re().
# Nothing here re-implements the grammar; that is how the last two probe tables were wrong.
set -u
cd "$(dirname "$0")/.." || exit 1
CHECK_FILE_MODES_SOURCE_ONLY=1 . tools/check-file-modes.sh

pass=0; failn=0
probe() { # probe <expect hit|miss> <path> <line>
	local want="$1" path="$2" line="$3" got
	if line_is_call_site "$path" 1 "$line"; then got=hit; else got=miss; fi
	if [ "$got" = "$want" ]; then pass=$((pass+1)); printf 'ok   %-4s %s\n' "$got" "$line"
	else failn=$((failn+1)); printf 'FAIL want=%s got=%s  %s\n' "$want" "$got" "$line"; fi
}

# qprobe <expect open|closed> <label> <file-text-with-\n> <1-based line to test>
# Multi-line quote state is NOT a property of one line, so it is probed against the real
# open_quote_lines() with a whole synthetic file rather than against line_is_call_site.
qprobe() {
	local want="$1" label="$2" text="$3" n="$4" got
	if printf '%b' "$text" | open_quote_lines | grep -qx "$n"; then got=open; else got=closed; fi
	if [ "$got" = "$want" ]; then pass=$((pass+1)); printf 'ok   %-6s %s\n' "$got" "$label"
	else failn=$((failn+1)); printf 'FAIL want=%s got=%s  %s\n' "$want" "$got" "$label"; fi
}

echo "== terminator set (defect 1: ; ) & | must terminate a program token) =="
probe hit  tools/foo.sh 'if tools/foo.sh; then'
probe hit  tools/foo.sh 'while tools/foo.sh; do :; done'
probe hit  tools/foo.sh 'until tools/foo.sh; do :; done'
probe hit  tools/foo.sh 'out=$(tools/foo.sh)'
probe hit  tools/foo.sh 'tools/foo.sh && echo ok'
probe hit  tools/foo.sh 'tools/foo.sh | head'
probe hit  tools/foo.sh 'tools/foo.sh'
probe hit  tools/foo.sh '    tools/foo.sh --flag'
probe hit  tools/foo.sh 'cd /x && tools/foo.sh'

echo "== usage comments vs prose (defect 2) =="
probe miss tools/foo.sh '# tools/foo.sh is prose in a comment'
probe miss tools/foo.sh '# tools/foo.sh was renamed last week'
probe hit  tools/foo.sh '#     tools/foo.sh --list     # report every fact'
probe hit  tools/foo.sh '# tools/foo.sh <scenario> [options] - run one scenario'
probe hit  tools/foo.sh '# tools/foo.sh'
probe hit  tools/foo.sh '# tools/foo.sh 001'
probe miss tools/foo.sh '# Golden harness run artifacts (tools/foo.sh); one directory per run'
probe miss tools/foo.sh '# see the note in tools/foo.sh; it explains why'
probe miss tools/foo.sh '#  x = $(tools/foo.sh) is what the old version did'
probe hit  tools/foo.sh 'x=1; tools/foo.sh'

echo "== real usage headers from this tree must stay hits (regression) =="
probe hit  tools/gui-lock '#   tools/gui-lock acquire [--timeout N]   block until held'
probe hit  tools/gui-lock '#   tools/gui-lock release [--force]       drop a lock THIS owner holds'
probe hit  tools/gui-lock '#   tools/gui-lock status                  exit 0 if held, 1 if free'
probe hit  tools/gui-lock '#   tools/gui-lock path                    print the lock directory'
probe hit  tools/gui-lock '#   tools/gui-lock owner                   print this owner identity'
probe hit  tools/gui-lock '#   tools/gui-lock run [--timeout N] -- cmd...   acquire, run, release'
probe hit  tests/golden/run.sh '# tests/golden/run.sh <scenario> [options] - run ONE golden scenario'
probe hit  tools/check-file-modes.sh '#     tools/check-file-modes.sh            # enforce; exit 1 on any violation'
probe hit  tools/check-file-modes.sh '#     tools/check-file-modes.sh --list     # report every fact, exit 0'

echo "== real prose from this tree must stay misses (regression) =="
probe miss tools/gui-lock '# tools/gui-lock shipped 100644 with a `test -x` acceptance that passed'
probe miss tools/gui-lock '# conftest.py::_lock_path() shells out to `tools/gui-lock path` and'
probe miss tools/foo.sh '# tools/foo.sh is the desktop mutex'
probe miss tools/foo.sh '# tools/foo.sh was renamed in the last sweep'
probe miss tools/foo.sh '# tools/foo.sh runs on every commit'
probe miss tools/foo.sh '# tools/foo.sh and tools/bar.sh both exist'

echo "== run prefixes (defect 4) =="
probe hit  tools/foo.sh 'sudo -u bob tools/foo.sh'
probe hit  tools/foo.sh 'sudo tools/foo.sh'
probe hit  tools/foo.sh 'nice -n 5 tools/foo.sh'
probe hit  tools/foo.sh 'ionice -c 3 nice -n 10 tools/foo.sh'
probe hit  tools/foo.sh 'exec tools/foo.sh'
probe hit  tools/foo.sh 'timeout 30 tools/foo.sh a b'
probe hit  tools/foo.sh 'env FOO=1 tools/foo.sh'
probe hit  tools/foo.sh 'xargs -n1 tools/foo.sh'
probe hit  tools/foo.sh 'setsid tools/foo.sh'

echo "== must NOT fire: interpreter / argument / prose =="
probe miss tools/foo.sh 'bash tools/foo.sh'
probe miss tools/foo.sh 'sh tools/foo.sh arg'
probe miss tools/foo.py 'python3 tools/foo.py'
probe miss tools/foo.sh 'git ls-files -s tools/foo.sh'
probe miss tools/foo.sh 'grep pat tools/foo.sh'
probe miss tools/foo.sh 'See `tools/foo.sh` for details'
probe miss tools/foo.sh 'COMPDB_READER="$REPO/tools/foo.sh"'
probe miss tools/foo.sh 'the tools/foo.sh script'

echo "== sibling / variable dispatch still caught =="
probe hit  .agents/skills/beads-worker/scripts/harvest.sh '"$here/harvest.sh" "$id"'
probe hit  .agents/skills/beads-worker/scripts/gc.sh '"$(dirname "${BASH_SOURCE[0]}")/gc.sh"'

# --- the four defects measured against attempt 3 -------------------------------------------
# Every case below FAILED before "judge command position by shell grammar, not by prefix".
# They are grouped by defect so a regression names itself.

echo "== defect A: a data-list element is data, not command position (was a false positive) =="
# The live hit: a tuple element in a Python file was reported as a bare-program call site.
probe miss tools/launcher_scan.py '    "tools/launcher_scan.py",'
probe miss tools/foo.sh '    "tools/foo.sh",'
probe miss tools/foo.sh "    'tools/foo.sh',"
probe miss tools/foo.sh '    "tools/foo.sh"'
probe miss tools/foo.sh '        "./tools/foo.sh",'
probe miss tools/foo.sh '["tools/foo.sh"]'
probe miss tools/foo.sh '    ["tools/foo.sh"],'
probe miss tools/foo.sh '    ("tools/foo.sh",)'
probe miss tools/foo.sh '    - "tools/foo.sh"'
probe miss tools/foo.sh '    "tools/foo.sh": 1,'
probe miss tools/foo.sh '"tools/foo.sh": {'
probe miss tools/foo.sh '    "tools/foo.sh",   '
# ...but a quoted path WITH ARGUMENTS is a command, and a dispatch is never data.
probe hit  tools/foo.sh '"tools/foo.sh" --list'
probe hit  tools/foo.sh '    "tools/foo.sh" arg'
probe hit  tools/foo.sh '"tools/foo.sh" && echo ok'
probe hit  .agents/skills/beads-worker/scripts/gc.sh '    "$here/gc.sh",'
probe hit  .agents/skills/beads-worker/scripts/gc.sh '    "$here/gc.sh"'

echo "== defect B: an assignment is not command position (was a false positive) =="
# The guard's own header has claimed since attempt 1 that assignments are excluded. Before
# this commit only the QUOTED form was excluded, and only by accident ($-expansion).
probe miss tools/foo.sh 'FOO=tools/foo.sh'
probe miss tools/foo.sh 'FOO=./tools/foo.sh'
probe miss tools/foo.sh 'X=tools/foo.sh; echo'
probe miss tools/foo.sh 'COMPDB_READER=tools/foo.sh'
probe miss tools/foo.sh '    COMPDB_READER=tools/foo.sh'
probe miss tools/foo.sh 'FOO=tools/foo.sh BAR=1'
probe miss tools/foo.sh 'export FOO=tools/foo.sh'
probe miss tools/foo.sh 'local f=tools/foo.sh'
probe miss tools/foo.sh 'readonly F=tools/foo.sh'
probe miss tools/foo.sh 'FOO="tools/foo.sh"'
probe miss tools/foo.sh "FOO='tools/foo.sh'"
probe miss tools/foo.sh 'FOO=$REPO/tools/foo.sh'
# `env FOO=1 tools/foo.sh` is still a RUN PREFIX, not an assignment; and a `;`-separated
# assignment followed by a real call is still a call.
probe hit  tools/foo.sh 'FOO=1 tools/foo.sh'
probe hit  tools/foo.sh 'F=tools/foo.sh; tools/foo.sh'

echo "== defect E: a quoted assignment VALUE must not open a command (regression, attempt 4) =="
# The env-assignment RUN PREFIX added for `FOO=1 tools/foo.sh` swallowed the UNTERMINATED
# OPENING QUOTE of a quoted value, so the token after it looked like a command. Storing an
# interpreter invocation in a variable is the commonest shape of the class this guard exists
# to EXCLUDE, and it went unprobed because the 109-case table had no assignment-with-a-quoted
# -value case at all. All six of these are HITs on attempt 4 and MISSes on attempt 3.
probe miss tools/foo.py 'cmd="python3 tools/foo.py"'
probe miss tools/foo.sh 'CMD="bash tools/foo.sh"'
probe miss tools/foo.sh 'msg="edit tools/foo.sh now"'
probe miss tools/foo.sh 'x="a tools/foo.sh"'
probe miss tools/foo.py "cmd='python3 tools/foo.py'"
probe miss tools/foo.sh 'args="--x tools/foo.sh"'
probe miss tools/foo.sh 'RUN="sh tools/foo.sh --flag"'
probe miss tools/foo.sh 'CMD=`bash tools/foo.sh`'
probe miss tools/foo.sh '    LOCAL_CMD="bash tools/foo.sh"'
# The same swallow via a command substitution. This one is LIVE: tools/check-desktop-lock.sh
# captures `$(python3 tools/launcher_scan.py ...)`, an interpreter invocation, and the guard
# demanded a chmod for it.
probe miss tools/launcher_scan.py 'spawners=$(python3 tools/launcher_scan.py tools tests upstream/oolite/tests) || fail=1'
probe miss tools/foo.py 'out=$(python3 tools/foo.py)'
probe miss tools/foo.sh 'v=$(bash tools/foo.sh --list)'
# ...but capturing a BARE program is still a call site.
probe hit  tools/foo.sh 'out=$(tools/foo.sh)'
# ...while the genuine env-assignment prefix and a genuine multi-assignment prefix still fire.
probe hit  tools/foo.sh 'FOO=1 BAR=2 tools/foo.sh'
probe hit  tools/foo.sh 'FOO=x/y tools/foo.sh'

echo "== defect F: a case arm and a bracketed list both open a command (was a false negative) =="
# `)` closes a `case` arm PATTERN and opens its command list; `[` opens a bracketed list whose
# element may be a dispatch. Neither was in BASE's operator class, so the header's opener list
# was untrue and `["$here/gc.sh"]` was the one hole in the "a dispatch is never data" rule.
probe hit  tools/foo.sh '  a) tools/foo.sh ;;'
probe hit  tools/foo.sh '  *) exec tools/foo.sh ;;'
probe hit  tools/foo.sh 'case $x in a) tools/foo.sh ;; esac'
probe hit  tools/foo.sh '    run) tools/foo.sh "$@" ;;'
probe hit  .agents/skills/beads-worker/scripts/gc.sh '  ["$here/gc.sh"]'
probe hit  .agents/skills/beads-worker/scripts/gc.sh '  ["$here/gc.sh", "x"]'
# The new openers must not resurrect the DATA or PROSE false positives.
probe miss tools/foo.sh '["tools/foo.sh"]'
probe miss tools/foo.sh '    ["tools/foo.sh"],'
probe miss tools/foo.sh '# a) tools/foo.sh is what the old version did'
probe miss tools/foo.sh 'grep pat tools/foo.sh) | head'

echo "== defect C: subshell / brace group DOES open a command (was a false negative) =="
probe hit  tools/foo.sh '( tools/foo.sh )'
probe hit  tools/foo.sh '(tools/foo.sh)'
probe hit  tools/foo.sh '( tools/foo.sh; echo done )'
probe hit  tools/foo.sh '    ( tools/foo.sh )'
probe hit  tools/foo.sh '{ tools/foo.sh; }'
probe hit  tools/foo.sh '{ tools/foo.sh; } >log'
probe hit  tools/foo.sh '    { tools/foo.sh; }'
probe hit  tools/foo.sh 'x() { tools/foo.sh; }'
probe hit  tools/foo.sh 'run_it() { tools/foo.sh "$@"; }'
probe hit  tools/foo.sh 'cd /x && ( tools/foo.sh )'
probe hit  tools/foo.sh 'if x; then ( tools/foo.sh ); fi'
# The group opener must not resurrect the prose false positive it was excluded for.
probe miss tools/foo.sh '# run artifacts (tools/foo.sh); one dir per run'
probe miss tools/foo.sh '# ( tools/foo.sh ) is what the old version did'

echo "== defect D: a line inside an open quoted string is string data =="
# Line-oriented scanning has no quoting state, so a bare path on its own line inside a
# multi-line VAR="..." literal looked like a command. The live hit demanded a chmod for a
# file that is only ever invoked as `python3 tools/check-splash-off.py`.
qprobe open   'line 3 inside LOCKED_LAUNCHERS="' 'LOCKED_LAUNCHERS="\ntools/a.py\ntools/check-splash-off.py\ntools/b.py\n"\n' 3
qprobe open   'line 2 inside an open quote'      'V="\ntools/foo.sh\n"\n' 2
qprobe closed 'the opening line itself'          'V="\ntools/foo.sh\n"\n' 1
qprobe closed 'line after the string closes'     'V="\ntools/foo.sh\n"\ntools/foo.sh\n' 4
qprobe closed 'single-line assignment'           'V="tools/foo.sh"\ntools/foo.sh\n' 2
qprobe closed 'escaped quote does not open'      'echo \\"\ntools/foo.sh\n' 2
qprobe closed 'quote inside single quotes'       "echo '\"'\ntools/foo.sh\n" 2
qprobe closed 'quote inside a # comment'         '# a " in prose\ntools/foo.sh\n' 2
qprobe closed 'balanced pair on one line'        'echo "a" "b"\ntools/foo.sh\n' 2
qprobe closed 'python triple-quoted docstring'   '"""\ntools/foo.sh --list\n"""\n' 2
qprobe closed 'heredoc body is not a quote'      'cat <<EOF\ntools/foo.sh\nEOF\ntools/foo.sh\n' 4
qprobe open   'still open after a blank line'    'V="\n\ntools/foo.sh\n"\n' 3

echo "== defect G: the scan's hit/reject/open-quote set logic across a digit-count boundary =="
# bead oo-3rb.169: the scan subtracted rejected line numbers with `comm -23` over `sort -n`
# output. comm needs LEXICAL order, so once line numbers crossed 9 -> 10 it KEPT rejected
# lines and could DROP real hits. These run the scan's REAL match_candidates and join_sites on
# a synthetic candidate table whose line numbers span 1, 2 and 3 digits. Under the old
# sort -n | comm logic, x.sh:10 and x.sh:100 (both rejected as prose) came back as call sites.
sprobe() { # sprobe <label> <want: space-separated file:line list> <candidates> <open-quote keys>
	local label="$1" want="$2" cands="$3" openq="$4" got
	got=$(join_sites <(printf '%b' "$openq") \
	          <(match_candidates <(pattern_line tools/foo.sh 1) <(printf '%b' "$cands")) \
	      | cut -f2 | cut -d: -f1-2 | tr '\n' ' ')
	got=${got% }
	if [ "$got" = "$want" ]; then pass=$((pass+1)); printf 'ok   %s -> [%s]\n' "$label" "$got"
	else failn=$((failn+1)); printf 'FAIL %s want=[%s] got=[%s]\n' "$label" "$want" "$got"; fi
}
G='x.sh:9\ttools/foo.sh\nx.sh:10\t# tools/foo.sh is prose\nx.sh:11\ttools/foo.sh --x\n'
G="$G"'x.sh:12\ttools/foo.sh a\nx.sh:99\ttools/foo.sh b\nx.sh:100\t# tools/foo.sh was prose\n'
G="$G"'x.sh:101\ttools/foo.sh c\ny.sh:2\tpython3 tools/foo.sh\n'
sprobe 'rejects dropped, hits kept, 1-3 digit lines' 'x.sh:9 x.sh:11 x.sh:12 x.sh:99 x.sh:101' "$G" ''
sprobe 'open-quote keys drop exactly their line'     'x.sh:9 x.sh:12 x.sh:101' "$G" 'x.sh:11\nx.sh:99\nx.sh:1\nx.sh:10\n'
sprobe 'a key is file-qualified, not a bare number'  'x.sh:9 x.sh:11 x.sh:12 x.sh:99 x.sh:101' "$G" 'y.sh:9\ny.sh:11\n'
sprobe 'no candidates at all'                         '' '' ''
# The multi-file tracker the scan uses resets its state per file: a quote left open at the end
# of one file must not swallow the next file's lines.
okeys=$(printf 'a.sh:1:V="\na.sh:2:tools/foo.sh\nb.sh:1:tools/foo.sh\nb.sh:2:W="\nb.sh:3:x\n' \
        | open_quote_keys | tr '\n' ' ')
if [ "$okeys" = "a.sh:2 b.sh:3 " ]; then pass=$((pass+1)); echo "ok   open_quote_keys resets per file -> [$okeys]"
else failn=$((failn+1)); echo "FAIL open_quote_keys resets per file: got [$okeys]"; fi

echo
echo "probes: pass=$pass fail=$failn"
[ "$failn" -eq 0 ]
