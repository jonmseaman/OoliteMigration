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

echo
echo "probes: pass=$pass fail=$failn"
[ "$failn" -eq 0 ]
