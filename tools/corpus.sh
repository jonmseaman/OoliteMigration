#!/usr/bin/env bash
# tools/corpus.sh - OXP corpus tiers for the Oolite ObjC->C++ migration (bead oo-het).
#
# Subcommands:
#   list          print the Tier 1 set (offline, no game launch)
#   regen         regenerate tools/oxp-corpus/tier1.json from the corpus
#   check-list    assert the committed tier1.json matches a fresh regeneration
#   selftest      offline proof that the load check's vacuity guards discriminate
#   tier1         LOAD every Tier 1 expansion on a headless build and assert that
#                 each one really loaded and produced no ERROR lines
#
# Options for tier1:
#   --app-dir DIR   the built oolite.app (default $OO_APP_DIR, then the shared build)
#   --limit N       only the first N entries (for a cheap smoke run)
#   --only SUBSTR   only entries whose name contains SUBSTR
#   --include-broken  also load the deliberately-broken red-proof fixture
#
# WORKTREES CONTAIN NO BUILD.  This script never builds; it points at the shared
# build and fails up front, naming the path, if it is not there.
set -u -o pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/.." && pwd)"
# Native programs (python.exe, oolite.exe) do NOT understand MSYS /c/... paths -
# path conversion is disabled on this host, so python.exe resolves "/c/Users/x"
# against the drive and dies with "can't open file 'C:/c/Users/x'". Convert once,
# here, and pass only native forward-slash paths to native tools below.
if command -v cygpath >/dev/null 2>&1; then
	REPO_ROOT="$(cygpath -m "$REPO_ROOT")"
fi

# THE 0xC0000135 TRAP.  oolite.exe's staged opengl32.dll loads
# libgallium_wgl.dll, which needs libLLVM-*.dll / libSPIRV-Tools.dll /
# libsystre-0.dll - all of which live ONLY in the MSYS2 UCRT64 bin directory and
# appear in NO static import table.  A shell without it gets exit 3221225781
# before the entry point and writes no log at all.  Fix it here so no caller can
# turn an environment defect into a silent pass.
if [ -d /ucrt64/bin ]; then
	export PATH="/ucrt64/bin:$PATH"
fi

PY="$(command -v python3 || command -v python || echo /ucrt64/bin/python3)"

DEFAULT_APP_DIR="C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"
APP_DIR="${OO_APP_DIR:-$DEFAULT_APP_DIR}"

TIER1_JSON="$REPO_ROOT/tools/oxp-corpus/tier1.json"
SENTINEL="$REPO_ROOT/tools/oxp-corpus/sentinel/oo-het-sentinel.oxp"
BROKEN="$REPO_ROOT/tools/oxp-corpus/broken/oo-het-broken.oxp"
DEAD_LOG="$REPO_ROOT/tools/oxp-corpus/fixtures/dead-initgl-Latest.log"

die() { printf '%s\n' "$*" >&2; exit 1; }

cmd_list() {
	"$PY" "$REPO_ROOT/tools/oxp_tier1.py" show --out "$TIER1_JSON"
}

cmd_regen() {
	"$PY" "$REPO_ROOT/tools/oxp_tier1.py" generate --out "$TIER1_JSON"
}

cmd_check_list() {
	"$PY" "$REPO_ROOT/tools/oxp_tier1.py" check --out "$TIER1_JSON"
}

# ---------------------------------------------------------------- selftest
#
# Proves OFFLINE - no game launch, so it is affordable in a stored acceptance
# block - that the load check's guards actually discriminate.  Every case runs
# the REAL judge() against a REAL captured log.
cmd_selftest() {
	local fail=0 rc

	echo "== 1. the vacuity guard REJECTS a real dead launch =="
	echo "   (exit 87, 19 lines, banner + [process.args] present, ZERO lines matching ERROR)"
	"$PY" "$REPO_ROOT/tools/oxp_load_check.py" --judge-log "$DEAD_LOG"
	rc=$?
	# rc must be exactly 1 (a REJECTION by the guard). rc=2 is a usage/harness
	# error - the script never ran - and counting that as "ok" is how a selftest
	# silently stops testing anything. This bit me: an MSYS path bug made the
	# interpreter fail to open the file, and a bare "rc != 0" check reported ok.
	if [ "$rc" -ne 1 ]; then
		echo "   FAIL: expected rc=1 (guard rejects), got rc=$rc$([ "$rc" -eq 2 ] && echo ' (harness/usage error - the check never ran)')"
		fail=1
	else
		echo "   ok (rc=1, rejected)"
	fi

	echo
	echo "== 2. a LAUNCH failure is reported as LAUNCH, not as a silent pass =="
	"$PY" "$REPO_ROOT/tools/oxp_load_check.py" \
		--app-dir "$REPO_ROOT/no-such-app-dir-oo-het" \
		--oxp "$SENTINEL"
	rc=$?
	if [ "$rc" -ne 3 ]; then
		echo "   FAIL: expected rc=3 (LAUNCH), got rc=$rc"
		fail=1
	else
		echo "   ok (rc=3, LAUNCH)"
	fi

	echo
	echo "== 3. the error detector is not a literal 'grep ERROR' =="
	"$PY" - <<-'PYEOF'
		import sys, pathlib
		sys.path.insert(0, str(pathlib.Path("tools").resolve()))
		import oxp_load_check as c
		# The two lines the broken fixture really produces. NEITHER contains the
		# word ERROR: a literal grep would pass an expansion whose ship data does
		# not parse and whose script throws.
		bad = [
		    '03:35:59.439 [plist.parse.failed]: Failed to parse '
		    'x/oo-het-broken.oxp/Config/shipdata.plist as a property list.',
		    '03:36:03.790 [script.javaScript.exception.notDefined]: ***** JavaScript '
		    'exception (oo-het-broken 1.0): ReferenceError: nope is not defined',
		]
		for line in bad:
		    assert 'ERROR' not in line, line
		    assert c.is_error_line(line), 'detector MISSED a real error: ' + line
		# The harness's own deliberate dead-port dial-out must NOT count.
		benign = ('03:28:56.036 [debugTCP.connect.failed]: Failed to connect to debug '
		          'console at address 127.0.0.1:1.')
		assert not c.is_error_line(benign), 'detector counted its own harness noise'
		# ... and the exclusion must be exactly one channel family, not a blanket.
		assert c.BENIGN_CHANNEL_PREFIX == 'debugTCP.', c.BENIGN_CHANNEL_PREFIX
		print('   ok: 2 non-"ERROR" error lines caught, 1 harness line excluded')
	PYEOF
	rc=$?
	[ "$rc" -eq 0 ] || { echo "   FAIL (rc=$rc)"; fail=1; }

	echo
	echo "== 4. the Tier 1 list is present and well formed =="
	"$PY" - <<-'PYEOF'
		import json, pathlib
		d = json.loads(pathlib.Path("tools/oxp-corpus/tier1.json").read_text("utf-8"))
		cat, tests = d["catalogue"], d["test_oxps"]
		assert len(cat) == 30, "expected 30 catalogue entries, got %d" % len(cat)
		assert len(tests) == 6, "expected 6 test-oxps, got %d" % len(tests)
		ids = [e["identifier"] for e in cat]
		assert len(set(ids)) == len(ids), "duplicate identifiers in the tier1 list"
		for e in cat:
		    assert e["sha256"], "%s has no sha256 - it is not pinned" % e["identifier"]
		    assert e["band"] in ("A-hub", "B-breadth"), e["band"]
		# The ranking must be non-increasing: a list whose order does not follow the
		# stated criterion is an assertion, not a selection.
		deg = [e["indegree"] for e in cat if e["band"] == "A-hub"]
		assert deg == sorted(deg, reverse=True), "hub band is not in in-degree order"
		assert deg[0] >= 1, "top hub has in-degree 0 - the criterion did nothing"
		print("   ok: 30 catalogue (%d hubs, top in-degree %d) + 6 test-oxps, all pinned"
		      % (len(deg), deg[0]))
	PYEOF
	rc=$?
	[ "$rc" -eq 0 ] || { echo "   FAIL (rc=$rc)"; fail=1; }

	echo
	echo "== 5. the staging loop survives CRLF from python.exe =="
	# REGRESSION PIN. python.exe writes CRLF, so the last field of each line the
	# resolver emits carries a trailing CR and names a nonexistent path. Only the
	# FINAL line (no trailing newline, hence no CR) used to survive, and a full
	# run reported "36 checked, 35 failed" with 35 bogus MISSING verdicts.
	"$PY" - <<-'PYEOF'
		import subprocess, sys
		# Three CRLF-terminated lines, exactly as python.exe emits them.
		payload = "a	path-a\r\nb	path-b\r\nc	path-c"
		script = r'''
		n=0
		while IFS="$(printf '	')" read -r name path; do
		  name="${name%$'\r'}"; path="${path%$'\r'}"
		  [ -n "$name" ] || continue
		  case "$path" in *$'\r'*) echo "CR-LEAK:$path"; exit 1;; esac
		  n=$((n+1))
		done <<< "$PAYLOAD"
		echo "n=$n"
		'''
		out = subprocess.run(["bash", "-c", script], capture_output=True, text=True,
		                     env={"PAYLOAD": payload, "PATH": "/usr/bin:/bin"})
		got = out.stdout.strip()
		assert "CR-LEAK" not in got, got
		assert got.endswith("n=3"), "expected 3 iterations, got: %r %r" % (got, out.stderr)
		print("   ok: 3/3 CRLF lines parsed, no carriage return leaked into a path")
	PYEOF
	rc=$?
	[ "$rc" -eq 0 ] || { echo "   FAIL (rc=$rc)"; fail=1; }

	echo
	if [ "$fail" -ne 0 ]; then
		echo "SELFTEST FAILED"
		return 1
	fi
	echo "SELFTEST OK"
	return 0
}

# ------------------------------------------------------------------- tier1
#
# DEPENDENCY-AWARE GROUPING (bead oo-kcrw).  Each Tier 1 expansion is loaded in
# ONE launch together with the TRANSITIVE closure of its requires_oxps, not
# solo.  Verified necessary by a two-launch experiment on this host, same build,
# differing only in whether the dependency was staged:
#
#   solo    ['oolite.oxp.Svengali.GNN']                       -> NOTLOADED
#           [oxp.requirementMissing]: OXP oolite.oxp.Svengali.GNN.oxz had unmet
#           requirements and was removed from the loading list
#   closure ['...GNN', '...Svengali.Library']                 -> PASS
#
# The closure is resolved by tools/oxp_deps.py, which builds an identifier ->
# cached-blob index from the manifests (requires_oxps names IDENTIFIERS and the
# byte cache is content-addressed, so no filename mapping exists otherwise),
# walks the graph ITERATIVELY with a visited set so a cycle cannot hang it, and
# reports a requirement that is absent from the corpus as UNSATISFIABLE rather
# than as a load failure.
cmd_tier1() {
	local limit="" only="" include_broken=0
	while [ $# -gt 0 ]; do
		case "$1" in
			--app-dir) APP_DIR="$2"; shift 2 ;;
			--limit) limit="$2"; shift 2 ;;
			--only) only="$2"; shift 2 ;;
			--include-broken) include_broken=1; shift ;;
			*) die "corpus.sh tier1: unknown option $1" ;;
		esac
	done

	[ -d "$APP_DIR" ] || die "LAUNCH: no build at $APP_DIR
  Worktrees are source-only; point --app-dir or OO_APP_DIR at the shared build.
  The game cannot be launched, so NO conclusion about ERROR lines is possible."
	[ -f "$APP_DIR/oolite.exe" ] || die "LAUNCH: no oolite.exe in $APP_DIR"
	[ -f "$TIER1_JSON" ] || die "no tier1 list at $TIER1_JSON (run: tools/corpus.sh regen)"

	local work="${TMPDIR:-${LOCALAPPDATA:-$HOME}/Temp}/oo-kcrw-tier1.$$"
	mkdir -p "$work" || die "could not create work dir $work"
	local groups="$work/groups.json"

	# Resolve the groups in ONE python call that writes a FILE. Nothing is piped
	# through a bash `while read` loop any more: python.exe emits CRLF, and the
	# resulting trailing carriage return once made a run stage 1 of 36 entries
	# and report 35 bogus MISSING verdicts. A JSON file has no such hazard, and
	# the staging itself now happens inside run_group() where every copy is
	# checked at the point of failure.
	"$PY" - "$TIER1_JSON" "$groups" "${limit:-0}" "$only" "$include_broken" <<-'PYEOF' || die "could not resolve the tier1 dependency closures"
		import json, sys, pathlib
		sys.path.insert(0, "tools")
		import oxp_deps as od

		tier1, out, limit, only, include_broken = sys.argv[1:6]
		groups = od.tier1_groups(pathlib.Path(tier1))
		if only:
		    groups = [g for g in groups if only.lower() in g["name"].lower()]
		if int(limit):
		    groups = groups[:int(limit)]
		if include_broken == "1":
		    p = str(od.REPO_ROOT / "tools/oxp-corpus/broken/oo-het-broken.oxp").replace("\\", "/")
		    groups.append({
		        "name": "oo-het-broken.oxp", "primary": "oo-het-broken.oxp",
		        "members": [{"identifier": "oo-het-broken.oxp",
		                     "staged_as": "oo-het-broken.oxp", "path": p,
		                     "title": "oo-het-broken", "role": "primary"}],
		        "missing": [], "companions": [], "companion_reason": "",
		    })
		pathlib.Path(out).write_text(json.dumps(groups, indent=2), encoding="utf-8")
		nd = sum(1 for g in groups if len(g["members"]) > 1)
		print("tier1: %d group(s), %d with dependencies, %d member-loads total"
		      % (len(groups), nd, sum(len(g["members"]) for g in groups)))
	PYEOF

	local n
	n="$("$PY" -c "import json,sys;print(len(json.load(open(sys.argv[1]))))" "$groups")"
	[ "${n:-0}" -gt 0 ] || die "tier1 selection is EMPTY - refusing to report success on zero checks"
	echo "app-dir=$APP_DIR"
	echo

	"$PY" "$REPO_ROOT/tools/oxp_load_check.py" \
		--app-dir "$APP_DIR" --work "$work/runs" \
		--json "$work/results.json" --groups "$groups"
	local rc=$?
	echo
	echo "results: $work/results.json"
	return $rc
}

case "${1:-}" in
	list)       shift; cmd_list "$@" ;;
	regen)      shift; cmd_regen "$@" ;;
	check-list) shift; cmd_check_list "$@" ;;
	selftest)   shift; cmd_selftest "$@" ;;
	tier1)      shift; cmd_tier1 "$@" ;;
	*) die "usage: tools/corpus.sh {list|regen|check-list|selftest|tier1} [options]" ;;
esac
