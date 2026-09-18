#!/usr/bin/env bash
# Replay the STORED acceptance block for oo-l7u, line by line, from the bytes
# bd actually holds - not from a scratch copy that may have drifted.
#
# Asserts RAN == the number of stored lines (a replay that runs zero lines
# reports no failures and looks clean), and reports per-line rc AND wall time.
set -u
export PATH=/ucrt64/bin:$PATH
cd "$(dirname "$0")/../.." || exit 2
BLOCK="${LOCALAPPDATA:-$HOME}/Temp/l7u_stored.txt"
bd show oo-l7u --json 2>/dev/null | python3 -c "
import sys,json
a=json.load(sys.stdin)[0]['acceptance_criteria']
open(sys.argv[1],'w',encoding='utf8',newline='').write(a)
print('stored bytes:',len(a),'CR:',a.count(chr(13)))
" "$(cygpath -m "$BLOCK" 2>/dev/null || echo "$BLOCK")"

WANT=$(python3 -c "
import sys
s=open(sys.argv[1],encoding='utf8').read()
print(len([l for l in s.split(chr(10)) if l.strip()]))
" "$(cygpath -m "$BLOCK" 2>/dev/null || echo "$BLOCK")")
echo "STORED LINES = $WANT"
echo

RAN=0; BAD=0
# herestring appends a trailing newline, so the final line is never dropped
while IFS= read -r line; do
  [ -z "${line// }" ] && continue
  RAN=$((RAN+1))
  t0=$(date +%s)
  out="$(bash -c "$line" 2>&1)"; rc=$?
  t1=$(date +%s)
  echo "===== LINE $RAN  rc=$rc  wall=$((t1-t0))s"
  echo "$line" | cut -c1-140 | sed 's/^/   cmd: /'
  echo "$out" | tail -6 | sed 's/^/   /'
  [ $rc -ne 0 ] && { BAD=$((BAD+1)); echo "   *** NONZERO ***"; }
  echo
done <<< "$(cat "$BLOCK")"

echo "RAN=$RAN lines (stored $WANT), nonzero=$BAD"
[ "$RAN" -eq "$WANT" ] || { echo "*** REPLAY INVALID: ran $RAN of $WANT stored lines ***"; exit 1; }
[ "$BAD" -eq 0 ] || exit 1
echo "REPLAY OK: all $RAN stored lines exit 0"
