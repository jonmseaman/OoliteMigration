"""Golden scenario 018-expansion-closure-and-manifestless.

WHAT THIS SCENARIO MEASURES, AND WHY IT IS A *DIFFERENTIAL*
----------------------------------------------------------
Two launches of the SAME build, differing only in WHAT IS STAGED:

  CLOSURE run   staged: primary + the transitive closure of its `requires_oxps`
                        + one manifest-less in-tree fixture
                -> the primary is NAMED in the `[searchPaths.dumpAll]` block

  CONTROL run   staged: the primary ALONE (closure deliberately withheld)
                        + the same manifest-less fixture
                -> the primary is ABSENT from `[searchPaths.dumpAll]` and the
                   engine logs `[oxp.requirementMissing]` naming it

Bead oo-kcrw measured exactly this causally (oolite.oxp.Svengali.GNN solo =
NOTLOADED, GNN + oolite.oxp.Svengali.Library = PASS). Nothing in goldens 001-017
pins it: 007-012 each load exactly ONE in-tree test-oxp solo, 001-006 stage no
expansion at all, 013-017 load saves. The resource-path COMPOSITION layer -
ResourceManager's search-path assembly, manifest parsing, requirement resolution
(`filterSearchPathsForRequirements`, ResourceManager.m:949-975) and the standards
diagnostic channel - is unobserved by any golden.

WHY A DIFFERENTIAL AND NOT AN ABSENCE
-------------------------------------
Bead oo-het captured a REAL corpse: exit 87, a 1476-byte Latest.log carrying the
version banner and `[process.args]`, ZERO lines matching ERROR, and nothing
loaded. So "no errors in the log" and "exit code 0" are satisfiable by a run that
did nothing, and this scenario may not rest on either. It rests on a pair of runs
that must DISAGREE in a specific, named way:

  * the primary present in one search-path block and absent from the other;
  * `[oxp.requirementMissing]` present in the control run and absent from the
    closure run;
  * `[startup.complete]` in BOTH runs (a marker emitted after expansion parsing,
    which oo-het's corpse lacks).

A harness that skipped a launch produces neither block. A harness that staged the
same thing twice produces two IDENTICAL blocks and fails the differential.

THE MANIFEST-LESS ARM
---------------------
`upstream/oolite-tests/test-oxps/RetroMissions/RetroMissions.oxp` ships no
manifest.plist. ResourceManager.m:634-664 branches on the file EXTENSION: an
`.oxz` with no manifest is logged on `oxp.noManifest` and RETURNS at :640 (never
loaded); an `.oxp` emits `OOStandardsError` at :646 and, in relaxed mode, falls
through to :654 where a basic manifest is synthesised and the path IS added to
the search paths. So the fixture LOADS and emits EXACTLY 2
`[oxp-standards.error]: OXP ... has no manifest.plist` lines (bead oo-kcrw's
NOMANIF class; measured identically for five unrelated fixtures, which is the
tell that it is a fixture property and not five defects).

That count is pinned EXACTLY, in BOTH runs, and the lines are attributed
per-expansion with `tools/oxp_deps.attribute_errors` so a standards complaint
belonging to the primary or to its dependency cannot be absorbed into the
fixture's allowance. A third line, or a different message, fails the run.
Widening the number to make a run pass is forbidden.

DETERMINISM AND ISOLATION
-------------------------
Identical to scenarios 001/012 and for the same measured reasons: a reserved
console port plus a debugConfig.plist written into a private
OO_ADDITIONALADDONSDIRS root (the game DIALS OUT to the port named there,
OODebugSupport.m:67-80 - a run on the shared 8563 can be captured and quit by a
sibling worker's console while still exiting rc=0, bead oo-het); a private staged
app so N runs do not race on one Defaults/oolite.plist; the populator switched off
at the source before anything is measured; the world asserted at rest under a
CHECKED pauseGame(); the tick budget measured on the GAME clock.

The staging directory is called `oxp-stage`, NOT `addons`: the game also searches
`<app dir>/../AddOns` and the staged app lives at `<artifact>/app`, so
`<artifact>/addons` IS `<artifact>/../AddOns` on a case-insensitive filesystem and
every expansion would be found at TWO roots, doubling the standards-error count
(scenario 012 measured 4 lines instead of 2 that way).

This scenario never launches the player: it stays docked, so the populator and the
thrust-velocity problem are out of scope by construction.

NO EXPANSION CONTENT IS READ. The corpus blobs are staged BY PATH and never
opened by this file; only manifest METADATA (identifier, version, requires_oxps)
is consulted, through `tools/oxp_deps.py`, and only the game's own log output is
judged.
"""

import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DUMP_DIR = os.path.join(HERE, "dump")

sys.path.insert(0, HERE)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import frame_hash  # noqa: E402
import golden_run  # noqa: E402
import oxp_deps  # noqa: E402
import oxp_load_check  # noqa: E402
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "018-expansion-closure-and-manifestless"

# The spec, golden, provenance and frame live under the guarded goldens/ tree once Jon has
# approved the protected-path addition (tools/rebless-approvals.txt); until then they are staged
# under tests/golden/pending/. BOTH locations are searched, in that order, so landing them is a
# pure `git mv` with no code change. See tests/golden/pending/018-*/LANDING.md.
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)
FRAME_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "frame.grid"),
    os.path.join(HERE, "pending", SCENARIO, "frame.grid"),
)
PROVENANCE_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
    os.path.join(HERE, "pending", SCENARIO, "provenance.json"),
)

TICK_WALL_BUDGET_SECONDS = 300

OXP_STANDARDS_RE = re.compile(r"\[oxp-standards\.error\]:\s*(.*)")
REQUIREMENT_MISSING_RE = re.compile(r"\[oxp\.requirementMissing\]:\s*(.*)")
STARTUP_COMPLETE_RE = re.compile(r"\[startup\.complete\]")

#: The floor a frame grid must clear, in frame_hash distance units from an all-black grid, to
#: count as RENDERED. Inherited from scenario 015's measurement (all-black vs a real frame
#: 0.031..0.037; largest same-scene noise 0.011), and re-measured for this scenario in
#: provenance.json's frame_liveness block. LIVENESS is the only frame property asserted here:
#: llvmpipe is not bit-reproducible, so byte-gating a frame would flake forever.
FRAME_LIVENESS_FLOOR = 0.02


class ScenarioError(RuntimeError):
    pass


def _first_existing(candidates, what):
    for path in candidates:
        if os.path.isfile(path):
            return path
    raise ScenarioError("no %s found; looked in: %s" % (what, ", ".join(candidates)))


def spec_path():
    return _first_existing(SPEC_CANDIDATES, "spec.json for scenario %s" % SCENARIO)


def golden_path():
    return _first_existing(GOLDEN_CANDIDATES, "stored golden for scenario %s" % SCENARIO)


def frame_path():
    return _first_existing(FRAME_CANDIDATES, "stored frame grid for scenario %s" % SCENARIO)


def provenance_path():
    return _first_existing(PROVENANCE_CANDIDATES, "provenance for scenario %s" % SCENARIO)


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


# --------------------------------------------------------------------- staging


def manifestless_source(spec):
    src = os.path.join(REPO_ROOT, *spec["manifestless_oxp"].split("/"))
    if not os.path.isdir(src):
        raise ScenarioError(
            "the manifest-less in-tree fixture is not in the tree at %s; a run staging nothing "
            "would still launch the game and would emit no standards error at all, which is "
            "indistinguishable from the standards channel having died" % src)
    return src


def resolve_closure(spec):
    """(order, missing, index) for the primary, computed FRESH from the corpus index.

    Recomputed rather than read from the spec on purpose: the stored golden carries the closure
    it was blessed with, and comparing a FRESH walk against it is what makes a changed identifier
    index or a changed dependency walk a RED result instead of an invisible one.
    """
    index = oxp_deps.build_index()
    order, missing = oxp_deps.closure(index, spec["primary_identifier"],
                                      oxp_deps.load_companions())
    if missing:
        raise ScenarioError(
            "the closure of %s names %r, which is not in the local corpus cache, so the CLOSURE "
            "arm cannot be staged and the differential this scenario is would compare two "
            "identically-broken runs. Populate the cache (python3 tools/oxp_corpus.py fetch) "
            "before blessing." % (spec["primary_identifier"], missing))
    if len(order) < 2:
        raise ScenarioError(
            "the closure of %s is %r - fewer than two members, so there is no DEPENDENCY to "
            "withhold and the control arm would be identical to the closure arm. This scenario "
            "requires a primary with a non-empty requires_oxps." % (spec["primary_identifier"],
                                                                    order))
    return order, missing, index


def stage_members(index, identifiers, addons_dir):
    """Copy each corpus blob into the private staging root as `<identifier>.oxz`.

    The cache is CONTENT-ADDRESSED, so the file on disk has no name; Oolite dispatches on the
    EXTENSION (ResourceManager.m:290-310), which is why the staged name carries `.oxz`.

    Every copy's result is checked at the point of failure. An unchecked cp in a staging loop
    surfaces twenty lines later as a bogus "not loaded" verdict about the engine (bead oo-het
    measured 35 of 36 members silently never copied and reported as MISSING).
    """
    os.makedirs(addons_dir, exist_ok=True)
    staged = []
    for ident in identifiers:
        blob = oxp_deps.blob_for(index, ident)
        if not os.path.isfile(blob):
            raise ScenarioError(
                "corpus blob for %s is not cached at %s; staging would silently skip it and the "
                "run would report a load failure that is really a missing file" % (ident, blob))
        target = os.path.join(addons_dir, ident + ".oxz")
        shutil.copyfile(blob, target)
        if not os.path.isfile(target) or os.path.getsize(target) != os.path.getsize(blob):
            raise ScenarioError("staging %s -> %s did not produce a complete copy" % (blob, target))
        staged.append(ident + ".oxz")
    return staged


def stage_manifestless(spec, addons_dir):
    src = manifestless_source(spec)
    os.makedirs(addons_dir, exist_ok=True)
    target = os.path.join(addons_dir, os.path.basename(src))
    shutil.copytree(src, target)
    if not os.path.isdir(target):
        raise ScenarioError("staging %s -> %s produced nothing" % (src, target))
    return os.path.basename(src)


# ------------------------------------------------------------------ log reading


def read_log(artifact_dir):
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log, so nothing can be said about which "
            "expansions reached the search paths" % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        return handle.read()


def normalise_standards_error(message, tokens):
    """Replace the volatile staged path with the bare staged name.

    The staging root carries a timestamp, a port and a pid, so the raw message differs on every
    run by construction. ONLY the path is rewritten; the rest of the message is compared
    VERBATIM, so a different complaint about the same path does not match the allow-list.
    """
    out = message.strip()
    for tok in sorted(tokens, key=len, reverse=True):
        out = re.sub(r"\S*%s" % re.escape(tok), tok, out)
    return out.strip()


def examine(text, closure_names, manifestless_name, index, label):
    """Everything this scenario reads out of ONE run's log.

    `attribute_errors` (tools/oxp_deps.py) assigns each standards line to the expansion that owns
    it, longest-token-wins, so a complaint belonging to the primary or to a dependency cannot be
    counted against the manifest-less fixture's allowance - which is the only way an EXACT count
    of 2 means anything in a run that stages three expansions.
    """
    entries = oxp_load_check.searchpath_entries(text)
    if entries is None:
        raise ScenarioError(
            "the %s run's log has no [searchPaths.dumpAll] block at all, so which expansions the "
            "engine accepted cannot be read. Either the run died before ResourceManager logged "
            "its paths, or the searchPaths.dumpAll channel was switched off." % label)

    owners = []
    for name in list(closure_names) + [manifestless_name]:
        ident = name[:-4] if name.endswith(".oxz") else name
        owners.append({"label": name, "tokens": oxp_deps.owner_tokens(index.get(ident), name)})

    standards = [m.group(1).strip() for m in OXP_STANDARDS_RE.finditer(text)]
    attributed = oxp_deps.attribute_errors(standards, owners)
    tokens = [t for o in owners for t in o["tokens"]]

    return {
        "searchpath_names": sorted(oxp_load_check.entry_names(entries)),
        "loaded": sorted(n for n in list(closure_names) + [manifestless_name]
                         if oxp_load_check.is_loaded(entries, n)),
        "startup_complete": bool(STARTUP_COMPLETE_RE.search(text)),
        "requirement_missing": sorted(m.group(1).strip()
                                      for m in REQUIREMENT_MISSING_RE.finditer(text)),
        "standards_total": len(standards),
        "standards_by_owner": {k: [normalise_standards_error(v, tokens) for v in vs]
                               for k, vs in attributed.items()},
        "log_bytes": len(text),
    }


# ------------------------------------------------------------------- game steps


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def suppress_populators(console):
    """Switch the system populator off at the source (copied from scenarios 001 and 012).

    `system.setPopulator(key, null)` deletes a populator setting (OOJSSystem.m:1311). The
    populator keeps adding traffic while the run proceeds and every ship it adds consumes RANROT
    draws, so a fixed seed fixes the SEQUENCE but not how far a wall-clock-timed run has got
    through it (bead oo-jor).
    """
    keys = console.evaluate(
        "(function(){ var s = system.populatorSettings, out = [];"
        " for (var k in s) out.push(k);"
        " for (var i = 0; i < out.length; i++) system.setPopulator(out[i], null);"
        " return out.join(','); })()").strip()
    remaining = console.evaluate(
        "(function(){ var n = 0; for (var k in system.populatorSettings) n++;"
        " return String(n); })()").strip()
    if remaining not in ("0", ""):
        raise ScenarioError(
            "%s populator setting(s) survived suppression; the system will keep adding traffic "
            "during the run, consuming a per-run-variable number of RANROT draws" % remaining)
    return [k for k in keys.split(",") if k]


def clear_system(console):
    """Remove every non-player, non-station ship (copied from scenario 001)."""
    console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
        " return n; })()")
    if remaining:
        raise ScenarioError("%d non-station ship(s) remain after clearing; the dump would measure "
                            "the ambient population instead of the scenario" % remaining)
    return remaining


def run_ticks(console, ticks, tick_seconds):
    budget = ticks * tick_seconds
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + TICK_WALL_BUDGET_SECONDS
    while time.time() < deadline:
        elapsed = float(console.evaluate("clock.absoluteSeconds")) - start
        if elapsed >= budget:
            return elapsed
        time.sleep(0.1)
    raise ScenarioError("game time did not advance %ss within %ss of wall time"
                        % (budget, TICK_WALL_BUDGET_SECONDS))


def freeze_and_check(console):
    """Pause, CHECK the pause took, and assert nothing is still integrating."""
    if console.evaluate("pauseGame()").strip().lower() != "true":
        raise ScenarioError(
            "pauseGame() returned false: the game is NOT paused (guiScreen=%s). The simulation "
            "would keep integrating through the dump and no two runs could agree."
            % console.evaluate("guiScreen").strip())
    before = float(console.evaluate("clock.absoluteSeconds"))
    clear_system(console)
    after = float(console.evaluate("clock.absoluteSeconds"))
    if after != before:
        raise ScenarioError(
            "the game clock advanced %.4fs (%.4f -> %.4f) after pauseGame() returned true; the "
            "world is NOT frozen, so the dump is a stopwatch reading and no two runs can agree"
            % (after - before, before, after))
    # `magnitude` IS A FUNCTION, NOT A PROPERTY - calling it is what makes this guard able to
    # fail at all (bead oo-jor measured a version comparing a function object with a number,
    # which passed on every run).
    moving = console.evaluate(
        "(function(){ var s = system.allShips, bad = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()").strip()
    if moving:
        raise ScenarioError(
            "the game clock is stopped but entity/entities still report motion: %s. ShipEntity "
            "-velocity is [super velocity] + [self thrustVector] (ShipEntity.m:12830-12833), so a "
            "ship under thrust reads a non-zero velocity no JS write can clear; its value depends "
            "on the frame count and no two runs can reproduce it." % moving)
    return True


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED: golden_run._await_png waits for the NAME, which on
    Windows shows up while the game still holds the handle open for writing. Reading it then
    fails with PermissionError or, worse, reads a truncated image (scenario 010's finding). A
    frame that never becomes readable is a REFUSAL, never a hash of half a file.
    """
    before = set(f for f in os.listdir(artifact_dir) if f.endswith(".png"))
    console.perform("takeSnapShot();")
    png = golden_run._await_png(artifact_dir, before)
    last = None
    for _ in range(attempts):
        try:
            return png, frame_hash.frame_grid(png)
        except (PermissionError, OSError, ValueError) as exc:
            last = exc
            time.sleep(0.25)
    raise ScenarioError(
        "the snapshot at %s never became readable (%s: %s); hashing a partial image would be "
        "worse than no frame at all." % (png, type(last).__name__, last))


def frame_liveness(grid):
    return frame_hash.distance(list(grid), [0] * frame_hash.GRID_CELLS)


# --------------------------------------------------------------------- one arm


def launch_arm(app_dir, spec, run_root, index, stage_identifiers, label,
               want_dump=False, want_frame=False, keep=False):
    """One game process with a named staging set. Returns (observations, state, png, grid)."""
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-%s-p%d-%d" % (label, time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged_app = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))
    addons_dir = golden_run._slashes(os.path.join(artifact_dir, "oxp-stage"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged_app)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)
    staged_names = stage_members(index, stage_identifiers, addons_dir)
    manifestless_name = (stage_manifestless(spec, addons_dir)
                         if spec.get("_stage_manifestless", True) else None)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    roots = [config_dir, addons_dir]
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots + ([previous] if previous else []))
    started = time.time()
    state = png = grid = None
    elapsed = 0.0
    suppressed = []
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged_app, port, seed=int(spec["seed"]), output_dir=artifact_dir,
            host="127.0.0.1", load_save=spec["load_save"]))
        with console:
            assert_system(console, spec)
            suppressed = suppress_populators(console)
            clear_system(console)
            elapsed = run_ticks(console, int(spec["ticks"]), float(spec["tick_seconds"]))
            freeze_and_check(console)
            if want_frame:
                png, grid = capture_frame(console, artifact_dir)
            if want_dump:
                state = json.loads(dump_state(console))
        # AFTER the game has exited, so the log is complete and flushed.
        obs = examine(read_log(artifact_dir), staged_names,
                      manifestless_name or "(none)", index, label)
        obs.update({
            "label": label,
            "staged": sorted(staged_names + ([manifestless_name] if manifestless_name else [])),
            "staged_identifiers": list(stage_identifiers),
            "manifestless_staged_as": manifestless_name,
            "tick_budget_met": bool(elapsed >= int(spec["ticks"]) * float(spec["tick_seconds"])),
            "populators_suppressed": len(suppressed),
            "wall_seconds": round(time.time() - started, 1),
            "port": port,
        })
        return obs, state, png, grid
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged_app)
            shutil.rmtree(addons_dir, ignore_errors=True)
        golden_run.release_all()


# ------------------------------------------------------------- the evidence gate


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied BEFORE anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    primary = evidence["primary_staged_as"]
    dependency = evidence["dependency_staged_as"]

    if not evidence["startup_complete_both_runs"]:
        raise ScenarioError(
            "[startup.complete] is missing from at least one run (closure=%r control=%r). That "
            "marker is emitted AFTER expansion parsing; bead oo-het's exit-87 corpse carries the "
            "version banner and [process.args] and still never reaches it. Without it in BOTH "
            "runs, every other signal in this differential is void."
            % (evidence["closure_startup_complete"], evidence["control_startup_complete"]))

    if not evidence["primary_in_search_paths"]:
        raise ScenarioError(
            "the CLOSURE run staged %s together with its whole requires_oxps closure %r, yet %s "
            "is ABSENT from [searchPaths.dumpAll] (block listed: %r). An expansion reaches that "
            "block only through checkPotentialPath (ResourceManager.m:613-664), i.e. only after "
            "its manifest was read and validated, so this run did not load the expansion the "
            "scenario is about and the differential has no positive arm."
            % (primary, evidence["staged_identifiers"], primary,
               evidence["closure_search_path_names"]))

    if not evidence["dependency_in_search_paths"]:
        raise ScenarioError(
            "the CLOSURE run's dependency %s is absent from [searchPaths.dumpAll]; the primary "
            "may be loaded for some other reason, but the CLOSURE was not actually composed and "
            "this run does not measure dependency resolution." % dependency)

    if evidence["control_primary_in_search_paths"]:
        raise ScenarioError(
            "THE NEGATIVE CONTROL FAILED: the CONTROL run staged %s WITHOUT its declared "
            "requirement %s, and the engine loaded it anyway (search paths: %r). Requirement "
            "resolution (ResourceManager.m:949-975) has stopped enforcing requires_oxps, which "
            "is how an OXP breaks silently for every user. This is a FINDING about the engine, "
            "not a number to adjust."
            % (primary, dependency, evidence["control_search_path_names"]))

    if not evidence["control_requirement_missing"]:
        raise ScenarioError(
            "the CONTROL run did not log [oxp.requirementMissing] naming %s (lines seen: %r). "
            "Either the diagnostic channel died or the refusal moved earlier; in both cases the "
            "corpus tooling's verdicts become unattributable, and 'the expansion is absent from "
            "the search paths' alone cannot distinguish a refusal from a staging bug."
            % (primary, evidence["control_requirement_missing_lines"]))

    if evidence["closure_requirement_missing_lines"]:
        raise ScenarioError(
            "the CLOSURE run ALSO logged [oxp.requirementMissing]: %r. The two arms must differ "
            "in this line; if both emit it, the control proves nothing about the closure."
            % (evidence["closure_requirement_missing_lines"],))

    allowed = int(spec["allowed_manifestless_standards_errors"])
    for arm in ("closure", "control"):
        got = evidence["%s_nomanif_standards_errors" % arm]
        if got != allowed:
            raise ScenarioError(
                "the %s run attributed %d [oxp-standards.error] line(s) to the manifest-less "
                "fixture %s, but exactly %d is the pinned count (bead oo-kcrw's NOMANIF class: "
                "ResourceManager.m:646 emits OOStandardsError once per scan of an .oxp with no "
                "manifest.plist, and five unrelated in-tree fixtures each produce exactly %d). "
                "Above %d means new complaints; below means complaints were lost; and staging "
                "the fixture under a directory the game reaches by two roots doubles it. "
                "Widening this number to make the run pass is forbidden. Lines: %r"
                % (arm, got, evidence["manifestless_staged_as"], allowed, allowed, allowed,
                   evidence["%s_nomanif_standards_error_signatures" % arm]))
        sigs = evidence["%s_nomanif_standards_error_signatures" % arm]
        if not sigs:
            raise ScenarioError(
                "the %s run recorded no standards-error signature for the manifest-less fixture; "
                "a count with no message behind it cannot be audited" % arm)
        bad = [s for s in sigs if s not in spec["allowed_manifestless_standards_error_signatures"]]
        if bad:
            raise ScenarioError(
                "the %s run emitted an [oxp-standards.error] line that is NOT the known "
                "missing-manifest message: %r. The allow-list is %r and it is deliberately exact "
                "- a different complaint is a finding, not noise."
                % (arm, bad, spec["allowed_manifestless_standards_error_signatures"]))
        unowned = evidence["%s_unattributed_standards_errors" % arm]
        if unowned:
            raise ScenarioError(
                "the %s run emitted %d [oxp-standards.error] line(s) no staged expansion claims: "
                "%r. An error nobody owns is a finding about the harness or the engine and must "
                "never be folded into the fixture's allowance."
                % (arm, len(unowned), unowned))

    if not evidence["manifestless_in_search_paths_both_runs"]:
        raise ScenarioError(
            "the manifest-less fixture %s is not in the search paths of both runs. "
            "ResourceManager.m:642-664 SYNTHESISES a manifest for an .oxp in relaxed mode and "
            "adds the path, so its absence means the standards complaint stopped being "
            "informational and became a rejection - a change in load behaviour, not in logging."
            % evidence["manifestless_staged_as"])

    if evidence["staged_identifiers"] != evidence["recomputed_closure"]:
        raise ScenarioError(
            "the closure staged by this run %r differs from the closure recomputed from the "
            "corpus index %r: the identifier index or the dependency walk changed between "
            "staging and checking, so the run measured a different composition than it reports."
            % (evidence["staged_identifiers"], evidence["recomputed_closure"]))

    if evidence["closure_search_path_names"] == evidence["control_search_path_names"]:
        raise ScenarioError(
            "the two runs produced IDENTICAL [searchPaths.dumpAll] blocks (%r). This scenario is "
            "a DIFFERENTIAL between two differently-staged launches; two identical blocks mean "
            "the staging difference never reached the engine and both arms measure the same "
            "thing." % (evidence["closure_search_path_names"],))

    for arm in ("closure", "control"):
        if not evidence["%s_tick_budget_met" % arm]:
            raise ScenarioError(
                "evidence.%s_tick_budget_met is false: the game clock advanced less than the "
                "scenario's budget of %.3f game seconds (%d ticks), so that run's simulation did "
                "not run" % (arm, evidence["game_seconds_budget"], evidence["ticks"]))

    if evidence["frame_liveness"] is not None and evidence["frame_liveness"] < FRAME_LIVENESS_FLOOR:
        raise ScenarioError(
            "the captured frame is %.6f from an all-black grid, below the liveness floor %.6f: "
            "nothing was rendered, so the run drew into a lost context or died before drawing. "
            "Do NOT lower the floor to make this pass."
            % (evidence["frame_liveness"], FRAME_LIVENESS_FLOOR))


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


# --------------------------------------------------------------------- the run


def run(app_dir, out_path, spec, run_root, keep=False, frame_out=None,
        break_closure=False, no_manifestless=False):
    """Two launches, one canonical dump, one frame grid.

    `break_closure` is the NON-VACUITY MUTANT: the CLOSURE arm is staged WITHOUT the dependency,
    so it becomes a second control. The run must then fail on `primary_in_search_paths`. It is
    deliberately narrower than "stage nothing": the run still stages an expansion, still
    launches, still reaches the assertion under test, so the mutant exercises the assertion
    rather than short-circuiting it (bead oo-vwd).

    `no_manifestless` withholds the manifest-less fixture: the standards-error count becomes 0
    and the NOMANIF arm must go red. That mutant proves the count is a PREDICATE and not a field
    that is merely printed (bead oo-3ya's seed survivor).
    """
    order, _missing, index = resolve_closure(spec)
    primary = order[0]
    dependency = order[1]
    spec = dict(spec)
    spec["_stage_manifestless"] = not no_manifestless

    started = time.time()
    closure_stage = [primary] if break_closure else list(order)
    closure_obs, state, png, grid = launch_arm(
        app_dir, spec, run_root, index, closure_stage, "closure",
        want_dump=True, want_frame=True, keep=keep)

    # The dump and the frame belong to the CLOSURE arm; evaluate its half of the differential
    # before spending a second launch, so a mutant run costs one launch instead of two.
    closure_loaded = closure_obs["loaded"]
    if primary + ".oxz" not in closure_loaded:
        raise ScenarioError(
            "the CLOSURE run staged %r yet %s.oxz is ABSENT from [searchPaths.dumpAll] (block "
            "listed: %r). An expansion reaches that block only through checkPotentialPath "
            "(ResourceManager.m:613-664), so this run did not load the expansion the scenario is "
            "about and the differential has no positive arm."
            % (closure_stage, primary, closure_obs["searchpath_names"]))

    control_obs, _s, _p, _g = launch_arm(
        app_dir, spec, run_root, index, [primary], "control",
        want_dump=False, want_frame=False, keep=keep)

    recomputed, _m = oxp_deps.closure(oxp_deps.build_index(), primary,
                                      oxp_deps.load_companions())

    def nomanif(obs):
        name = obs["manifestless_staged_as"]
        return obs["standards_by_owner"].get(name, []) if name else []

    manifestless_name = closure_obs["manifestless_staged_as"] or "(none)"
    evidence = {
        "scenario": SCENARIO,
        "primary_identifier": primary,
        "primary_staged_as": primary + ".oxz",
        "dependency_identifier": dependency,
        "dependency_staged_as": dependency + ".oxz",
        "manifestless_staged_as": manifestless_name,
        "staged_identifiers": list(closure_obs["staged_identifiers"]),
        "recomputed_closure": list(recomputed),
        "control_staged_identifiers": list(control_obs["staged_identifiers"]),

        "primary_in_search_paths": primary + ".oxz" in closure_obs["loaded"],
        "dependency_in_search_paths": dependency + ".oxz" in closure_obs["loaded"],
        "control_primary_in_search_paths": primary + ".oxz" in control_obs["loaded"],
        "closure_search_path_names": closure_obs["searchpath_names"],
        "control_search_path_names": control_obs["searchpath_names"],
        "manifestless_in_search_paths_both_runs": (
            manifestless_name in closure_obs["loaded"]
            and manifestless_name in control_obs["loaded"]),

        "control_requirement_missing": any(primary in ln
                                           for ln in control_obs["requirement_missing"]),
        "control_requirement_missing_lines": control_obs["requirement_missing"],
        "closure_requirement_missing_lines": closure_obs["requirement_missing"],

        "closure_startup_complete": closure_obs["startup_complete"],
        "control_startup_complete": control_obs["startup_complete"],
        "startup_complete_both_runs": bool(closure_obs["startup_complete"]
                                           and control_obs["startup_complete"]),

        "closure_nomanif_standards_errors": len(nomanif(closure_obs)),
        "control_nomanif_standards_errors": len(nomanif(control_obs)),
        "closure_nomanif_standards_error_signatures": sorted(set(nomanif(closure_obs))),
        "control_nomanif_standards_error_signatures": sorted(set(nomanif(control_obs))),
        "closure_unattributed_standards_errors": sorted(set(
            closure_obs["standards_by_owner"].get(oxp_deps.UNATTRIBUTED, []))),
        "control_unattributed_standards_errors": sorted(set(
            control_obs["standards_by_owner"].get(oxp_deps.UNATTRIBUTED, []))),
        "closure_standards_errors_total": closure_obs["standards_total"],
        "control_standards_errors_total": control_obs["standards_total"],

        "closure_tick_budget_met": closure_obs["tick_budget_met"],
        "control_tick_budget_met": control_obs["tick_budget_met"],
        "game_seconds_budget": round(int(spec["ticks"]) * float(spec["tick_seconds"]), 3),
        "ticks": int(spec["ticks"]),
        "seed": int(spec["seed"]),
        "system_id": int(spec["system_id"]),
        "populators_suppressed": closure_obs["populators_suppressed"],
        # The frame's LIVENESS is stored (quantised) because it is the one frame property the
        # measurements support; the frame DIGEST is never a gate predicate - llvmpipe is not
        # bit-reproducible. Quantised to 3 decimals so the dump stays byte-reproducible.
        "frame_liveness": (round(frame_liveness(grid), 3) if grid is not None else None),
    }
    assert_ran(evidence, spec)

    state["evidence"] = evidence
    text = canonical(state)
    if out_path:
        parent = os.path.dirname(os.path.abspath(out_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    if frame_out and grid is not None:
        parent = os.path.dirname(os.path.abspath(frame_out))
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(frame_out, "wb") as handle:
            handle.write(bytes(grid))
    return {"ok": True, "out": out_path, "frame_out": frame_out, "bytes": len(text),
            "png": golden_run._slashes(png) if png else None,
            "frame_hash": frame_hash.hex_digest(grid) if grid is not None else None,
            "closure_wall_seconds": closure_obs["wall_seconds"],
            "control_wall_seconds": control_obs["wall_seconds"],
            "wall_seconds": round(time.time() - started, 1),
            "evidence": evidence}


# ------------------------------------------------------------------ offline CLI


def check_evidence(path, spec, label):
    with open(path, "r", encoding="utf-8") as handle:
        state = json.load(handle)
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        raise ScenarioError("%s carries no evidence block at all" % label)
    assert_ran(evidence, spec)
    print("PASS: %s proves the differential - %s loaded WITH its closure %r and was REFUSED "
          "without it ([oxp.requirementMissing]), both runs reached [startup.complete], and the "
          "manifest-less fixture %s emitted exactly %d standards error(s) in each run"
          % (label, evidence["primary_staged_as"], evidence["staged_identifiers"],
             evidence["manifestless_staged_as"], evidence["closure_nomanif_standards_errors"]))
    return 0


def check_frame(grid_path, label):
    with open(grid_path, "rb") as handle:
        blob = handle.read()
    if len(blob) != frame_hash.GRID_CELLS:
        print("REFUSED: %s is %d bytes, not the %d-byte 64x64 luminance grid; a wrong-sized grid "
              "is refused for its SIZE and would prove nothing about liveness"
              % (label, len(blob), frame_hash.GRID_CELLS))
        return 2
    distance = frame_hash.distance(list(blob), [0] * frame_hash.GRID_CELLS)
    if distance < FRAME_LIVENESS_FLOOR:
        print("FAIL: %s has luminance distance %.6f from an all-black grid, below the liveness "
              "floor %.6f - nothing was rendered" % (label, distance, FRAME_LIVENESS_FLOOR))
        return 1
    print("PASS: %s is LIVE - luminance distance %.6f from all-black, %.2fx the floor %.6f"
          % (label, distance, distance / FRAME_LIVENESS_FLOOR, FRAME_LIVENESS_FLOOR))
    return 0


def check_provenance(scenario_dir, label):
    """Assert provenance.json WITNESSES this golden, from outside it.

    A golden cannot witness itself. A one-quantised-unit edit to a float in state.json moves BOTH
    sides of any golden-vs-copy comparison and is invisible to golden_diff; only a digest recorded
    in a SEPARATE file can see it (bead oo-gxp). This also refuses a provenance that has lost its
    stability record or that has quietly started asserting the frame BYTES, which llvmpipe makes
    unreproducible - the dump gets a digest because it is quantised and deterministic; the frame
    gets a measured liveness floor. The asymmetry is the whole point and is checked here.
    """
    prov_path = os.path.join(scenario_dir, "provenance.json")
    dump_path = os.path.join(scenario_dir, "state.json")
    for path in (prov_path, dump_path):
        if not os.path.isfile(path):
            print("REFUSED: %s is missing; there is nothing to witness" % path)
            return 2
    with open(prov_path, "r", encoding="utf-8") as handle:
        prov = json.load(handle)
    with open(dump_path, "rb") as handle:
        blob = handle.read()

    problems = []
    record = (prov.get("artifacts") or {}).get("state.json")
    if not isinstance(record, dict):
        problems.append("provenance records no artifacts.state.json digest at all, so nothing "
                        "outside the golden witnesses it")
    else:
        digest = hashlib.sha256(blob).hexdigest()
        if record.get("bytes") != len(blob):
            problems.append("state.json is %d bytes but provenance witnesses %s"
                            % (len(blob), record.get("bytes")))
        if record.get("sha256") != digest:
            problems.append("state.json hashes to %s but provenance witnesses %s; ONE quantised "
                            "unit on ONE float does this, and a golden-vs-copy comparison cannot "
                            "see it" % (digest, record.get("sha256")))

    stability = prov.get("stability") or {}
    if stability.get("runs", 0) < 10:
        problems.append("provenance records %r runs; the stability claim for a golden is 10 "
                        "consecutive runs, and fewer cannot support it" % (stability.get("runs"),))
    if stability.get("stable") is not True:
        problems.append("provenance.stability.stable is %r, not True" % (stability.get("stable"),))
    digests = stability.get("distinct_dump_digests")
    if not isinstance(digests, list) or len(digests) != 1:
        problems.append("provenance.stability.distinct_dump_digests is %r; a stable golden has "
                        "EXACTLY one" % (digests,))
    elif record and digests[0] != record.get("sha256"):
        problems.append("the sweep's one dump digest %s is not the digest of the blessed "
                        "state.json %s: the golden was not taken from the sweep it cites"
                        % (digests[0], record.get("sha256")))

    if (prov.get("frame_liveness") or {}).get("asserted") is not True:
        problems.append("provenance.frame_liveness.asserted is not True; the one frame property "
                        "this scenario's measurements support would be unclaimed")
    if prov.get("frame_digest_asserted") is not False:
        problems.append("provenance.frame_digest_asserted is %r, must be False: llvmpipe is not "
                        "bit-reproducible and this scenario's own sweep produced %r distinct grid "
                        "digests over one dump digest"
                        % (prov.get("frame_digest_asserted"),
                           stability.get("distinct_frame_grid_digests")))

    if problems:
        print("\n[!] %s does NOT witness its golden:" % label)
        for problem in problems:
            print("  - %s" % problem)
        return 1
    print("PASS: %s witnesses state.json byte-for-byte (%d bytes, sha256 %s), records %d stable "
          "runs with one dump digest, asserts frame LIVENESS and does not assert frame bytes"
          % (label, len(blob), hashlib.sha256(blob).hexdigest()[:16], stability.get("runs")))
    return 0


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/expansion_closure.py", description=__doc__)
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 4096-byte frame grid here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--check-evidence", default=None,
                        help="offline: re-apply this scenario's OWN assertions to a stored dump")
    parser.add_argument("--check-frame", default=None,
                        help="offline: assert a stored frame grid is LIVE (not an empty render)")
    parser.add_argument("--check-provenance", default=None,
                        help="assert provenance.json in this scenario directory witnesses "
                             "state.json byte-for-byte and records the stability sweep")
    parser.add_argument("--print-closure", action="store_true",
                        help="offline: print the recomputed closure of the spec's primary")
    parser.add_argument("--label", default=None)
    parser.add_argument("--break-closure", action="store_true",
                        help="MUTANT: stage the CLOSURE arm without the dependency. The run must "
                             "then FAIL, proving the search-path assertion is load-bearing.")
    parser.add_argument("--no-manifestless", action="store_true",
                        help="MUTANT: stage no manifest-less fixture. The standards-error count "
                             "becomes 0 and the NOMANIF assertion must go red.")
    args = parser.parse_args(argv)

    spec = load_spec()

    if args.print_closure:
        order, missing, _ = resolve_closure(spec)
        json.dump({"primary": spec["primary_identifier"], "closure": order, "missing": missing},
                  sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0
    if args.check_evidence:
        try:
            return check_evidence(args.check_evidence, spec,
                                  args.label or args.check_evidence)
        except ScenarioError as exc:
            print("[!] %s" % exc, file=sys.stderr)
            return 1
    if args.check_frame:
        return check_frame(args.check_frame, args.label or args.check_frame)

    if args.check_provenance:
        return check_provenance(args.check_provenance,
                                args.label or (args.check_provenance + "/provenance.json"))

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_1bf5_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     frame_out=args.frame_out, break_closure=args.break_closure,
                     no_manifestless=args.no_manifestless)
    except ScenarioError as exc:
        print("[!] SCENARIO FAILED: %s" % exc, file=sys.stderr)
        return 1
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 3
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
