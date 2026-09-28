#!/usr/bin/env bash
# guard-probe.sh: drive scripts/bin/bd (the guard shim) against a stub "real" bd and check that
# every close/delete path is refused (exit 77) and ordinary commands pass through (stub exit 0).
# Offline, no database. Run: bash .agents/skills/beads-worker/scripts/guard-probe.sh
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shim_dir="$here/bin"
stub_dir="$(mktemp -d)"; trap 'rm -rf "$stub_dir"' EXIT
cat > "$stub_dir/bd" <<'EOF'
#!/usr/bin/env bash
# stub real bd: record stdin (for batch) and succeed
cat > /dev/null 2>&1 || true
echo "STUB $*"
EOF
chmod +x "$stub_dir/bd"
fail=0; pass=0
run() { # run <expected-exit> <stdin> <args...>
  local want="$1" input="$2"; shift 2
  printf '%s' "$input" | PATH="$shim_dir:$stub_dir:$PATH" BEADS_ACCEPT="${ACCEPT:-0}" bash "$shim_dir/bd" "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: bd $* (stdin: ${input:-none}) exit $got, want $want"; fi
}
# refused
for c in close done duplicate supersede delete prune purge gc flatten import; do run 77 "" "$c" oo-x; done
run 77 "" --json close oo-x
run 77 "" --actor someone close oo-x
run 77 "" -C . close oo-x
run 77 "" todo done oo-x
run 77 "" epic close-eligible
run 77 "" gate resolve oo-x
run 77 "" update oo-x --status=closed
run 77 "" update oo-x --status closed
run 77 "" update oo-x -s closed
run 77 "" update oo-x -s=closed
run 77 "" --json update oo-x -s closed
run 77 "close oo-x" batch
run 77 "  close oo-x done" batch
run 77 "update oo-x status=closed" batch
f="$stub_dir/batch.txt"; printf 'update oo-y priority=1\nclose oo-x\n' > "$f"
run 77 "" batch -f "$f"
run 77 "" batch --file="$f"
# passed through
run 0 "" show oo-x
run 0 "" --json list --status=closed
run 0 "" update oo-x --claim
run 0 "" update oo-x --status in_progress
run 0 "" update oo-x --append-notes "was closed before"
run 0 "" todo list
run 0 "" epic status
run 0 "" gate list
run 0 "update oo-x priority=1" batch
run 0 "# close oo-x is only a comment" batch
printf 'update oo-y priority=1\n' > "$f"; run 0 "" batch -f "$f"
run 0 "" reopen oo-x
# accept.sh may close
ACCEPT=1 run 0 "" close oo-x
ACCEPT=1 run 0 "close oo-x" batch
echo "guard-probe: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
