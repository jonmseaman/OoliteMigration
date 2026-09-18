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

	local args
	args="$("$PY" - "$TIER1_JSON" "${limit:-0}" "$only" "$include_broken" <<-'PYEOF'
		import json, os, sys, pathlib
		sys.path.insert(0, "tools")
		import oxp_corpus as oc

		tier1, limit, only, include_broken = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
		repo = pathlib.Path(tier1).resolve().parent.parent.parent
		d = json.loads(pathlib.Path(tier1).read_text("utf-8"))

		cache = os.environ.get("OXP_CACHE_DIR")
		if not cache:
		    local = os.environ.get("LOCALAPPDATA")
		    cache = (os.path.join(local, "OoliteMigration", "oxp-cache") if local
		             else os.path.expanduser("~/.cache/oolite-migration/oxp-cache"))

		items = []
		for e in d["catalogue"]:
		    blob = oc.blob_path(cache, e["url"])
		    # The cache is content-addressed, so the blob has no .oxz name. Oolite
		    # decides what is an expansion BY EXTENSION (ResourceManager.m:290-310),
		    # so it must be staged under a real .oxz filename - the checker copies it
		    # into a private AddOns dir, and we hand it the cached path plus the name.
		    items.append((e["identifier"] + ".oxz", str(blob)))
		for t in d["test_oxps"]:
		    items.append((t["name"], str(repo / t["path"])))
		if include_broken == "1":
		    items.append(("oo-het-broken.oxp", str(repo / "tools/oxp-corpus/broken/oo-het-broken.oxp")))

		if only:
		    items = [i for i in items if only.lower() in i[0].lower()]
		if limit:
		    items = items[:limit]
		for name, path in items:
		    print(name + "\t" + path)
	PYEOF
	)" || die "could not resolve the tier1 set"

	[ -n "$args" ] || die "tier1 selection is EMPTY - refusing to report success on zero checks"

	local n
	n="$(printf '%s\n' "$args" | wc -l | tr -d ' ')"
	echo "tier1: $n expansion(s), app-dir=$APP_DIR"
	echo

	local work="${TMPDIR:-${LOCALAPPDATA:-$HOME}/Temp}/oo-het-tier1.$$"
	mkdir -p "$work"

	local oxpargs=() staged_n=0
	while IFS="$(printf '	')" read -r name path; do
		# STRIP THE CR. python.exe on Windows writes CRLF, so the last field of
		# every line read here ends with a carriage return, and "$path" then
		# names a file that does not exist. This is exactly the bug that made a
		# full run report "36 checked, 35 failed" with 35 bogus MISSING results:
		# only the FINAL line survived, because it had no trailing newline and
		# therefore no CR. A staging failure must never masquerade as a missing
		# expansion - it sends the next reader hunting the corpus cache instead
		# of the harness.
		name="${name%$'\r'}"; path="${path%$'\r'}"
		[ -n "$name" ] || continue

		# (a) NOT IN THE CORPUS: the source is not where the manifest says.
		if [ ! -e "$path" ]; then
			echo "NOTCACHED  $name" >&2
			echo "  source does not exist: $path" >&2
			echo "  the expansion is not in the cache; run tools/oxp_corpus.py fetch" >&2
			return 1
		fi

		# Stage under the correct extension: the cache is content-addressed and
		# has no filename, and Oolite dispatches on the extension.
		local staged="$work/staged/$name"
		mkdir -p "$(dirname "$staged")"
		# (b) FAILED TO STAGE must be LOUD. An unchecked cp surfaces 20 lines
		# later as a bogus "MISSING" verdict about the expansion itself.
		if [ -d "$path" ]; then
			cp -r "$path" "$staged" || { echo "STAGEFAIL  $name: cp -r failed ($path -> $staged)" >&2; return 1; }
		else
			cp "$path" "$staged" || { echo "STAGEFAIL  $name: cp failed ($path -> $staged)" >&2; return 1; }
		fi
		[ -e "$staged" ] || { echo "STAGEFAIL  $name: cp reported success but $staged does not exist" >&2; return 1; }
		staged_n=$((staged_n+1))
		oxpargs+=(--oxp "$staged")
	done <<< "$args"

	# The staged count must match what we resolved, or the run would silently
	# check fewer expansions than it claims to.
	if [ "$staged_n" -ne "$n" ]; then
		echo "STAGEFAIL  staged $staged_n of $n expansions - refusing to report on a partial set" >&2
		return 1
	fi
	echo "staged $staged_n/$n, loading..."
	echo

	"$PY" "$REPO_ROOT/tools/oxp_load_check.py" \
		--app-dir "$APP_DIR" --work "$work/runs" \
		--json "$work/results.json" "${oxpargs[@]}"
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
