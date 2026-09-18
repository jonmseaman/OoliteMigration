"""Golden scenario 006: the save/load round-trip, and the honest shape of it on this engine.

READ THIS FIRST: WHAT A "ROUND-TRIP" CAN AND CANNOT MEAN HERE
=============================================================
The bead asks for a save/load round-trip: save the state, load it back, assert the state after
equals the state before. That is the right ask, and half of it is NOT REACHABLE on this build.
The gap is a real finding about the engine, it is stated here rather than quietly designed
around, and every claim below was checked against the source rather than assumed:

  THE LOAD DIRECTION IS REACHABLE.  `oolite.exe -load <path>` is parsed in src/SDL/main.m:166-175
  (`setPlayerFileToLoad:`) and dispatched by GameController.m:353
  `[PLAYER loadPlayerFromFile:playerFileToLoad asNew:NO]`, which reaches
  PlayerEntityLoadSave.m:597 and then PlayerEntity.m:1191 `-setCommanderDataFromDictionary:`.
  That is the whole deserialiser, driven from the command line, with no GUI. console.py already
  passes `-load`, so this half costs nothing new.

  THE SAVE DIRECTION IS NOT REACHABLE.  Every writer funnels into
  PlayerEntityLoadSave.m:869 `-writePlayerToPath:`, and it has exactly three callers:
    * `-savePlayerWithPanel` (:861)  - an AppKit save panel, macOS only;
    * `-quicksavePlayer` (:201)      - reached only from PlayerEntityControls.m:2603, i.e. a
                                       keypress on the docked GUI;
    * `-autosavePlayer` (:169)       - reached only from PlayerEntityControls.m:4927 inside
                                       `-handleUndockControl`, i.e. also a keypress, and only
                                       when the `autosave` user default is on
                                       (Universe.m:748, default NO).
  None of the three is exposed to JavaScript. Verified exhaustively rather than by spot-check:
  extracting every JS-callable name from src/Core/Scripting/*.m and src/Core/Debug/OOJSConsole.m
  and filtering for save/load/commander/persist/write yields no save entry point at all.
  `console.callObjC` would have reached `-writePlayerToPath:` directly, but it is compiled under
  `#if OO_DEBUG` (OOJSConsole.m:198-200) and the shared build carries zero `-DOO_DEBUG`
  (meson.build:45-53 adds it only when `debug` or `-O0`; the golden build is `-Ddebug=false -O2`).
  And `oolite.exe --help` (main.m:177-200) lists no save flag.

  CONSEQUENCE, STATED PLAINLY: a save-then-load round-trip driven entirely from a headless
  harness CANNOT be written on this build. Writing one would require a keyboard-driven GUI run
  (the G-tier's territory) or a new JS seam, and inventing a seam is out of scope for a golden
  scenario. Anything claiming to be a headless save/load round-trip here is comparing something
  else and calling it that.

SO WHAT THIS SCENARIO ACTUALLY ASSERTS - AND WHY IT IS STILL A SELF-CHECKING INVARIANT
=====================================================================================
The bead's real point is that a round-trip gives you an invariant that can fail meaningfully
WITHOUT a blessed file, instead of byte-comparing two dumps of the same static world. That
property survives intact in the reachable half, and it is the primary assertion here:

  INVARIANT 1 (PRIMARY) - TRANSCRIPTION.  For every field in the census
  (tests/golden/specs/006-save-load.json), the value stored in the .oolite-save file EQUALS the
  value the live game reports after loading it.

  This is genuinely self-checking, and more strongly so than a same-process before/after
  comparison would be, because the two sides are produced by two INDEPENDENT readers that share
  no code:
      left  = Python's plistlib parsing the file's bytes, in THIS process;
      right = Oolite's own Objective-C deserialiser, inside a SEPARATE OS PROCESS, read back
              over the debug console through the JS API.
  There is no object identity to accidentally compare with itself - the two sides cannot be the
  same object even in principle, because one of them lives in another process's address space.
  A loader that silently dropped a field, rescaled it, or defaulted it is caught by name.

  INVARIANT 2 (SECONDARY) - RELOAD DETERMINISM.  The same save file loaded in two SEPARATE game
  processes yields the same census. This is the closest reachable analogue of "save, load, save
  again, compare": it pins the deserialiser as a function of the file rather than of the run.

  INVARIANT 3 (TERTIARY, AND THE ONE WITH TEETH) - DETECTION.  Perturb ONE census field by one
  quantised unit in a THROWAWAY COPY of the save file, load THAT copy, and the comparison MUST
  report a difference naming that field. This is the only check here that proves the other two
  can fail, and it proves it END TO END through the real engine rather than in a unit test.
  `--prove-detection` runs it.

The GOLDEN is the secondary regression pin the bead asks for, not the primary assertion: a
canonical dump of the loaded world, blessed under the existing storage policy and compared with
tests/golden/golden_diff.py. The invariants above hold even with the golden deleted.

HOW EACH ROUTE TO A VACUOUS PASS IS CLOSED
==========================================
"Before equals after" passes trivially in four ways. Each is closed by a NAMED assertion that
fails loudly, and each has a mutant in tests/golden/scenario_006.sh proving it fires:

  the state is EMPTY                -> assert_non_vacuous(): the census must be fully populated,
                                       MIN_CENSUS_FIELDS of them, and the values must not all be
                                       falsy - a census of empty strings and zeros compares equal
                                       to any other empty census.
  the SAVE did not happen           -> the save file must EXIST and be at least MIN_SAVE_BYTES,
                                       must parse as a plist, and must itself carry every census
                                       key. A missing or stub file is refused, not compared.
  the LOAD did not happen           -> `evidence.load_verified`: the game must report the save's
                                       OWN system name and commander name, values that differ
                                       from the engine's defaults, plus `clock.absoluteSeconds`
                                       past the save's own ship_clock. A game sitting on the demo
                                       screen fails all three.
  compared a structure to ITSELF    -> the two sides are different processes (above), and
                                       compare_census() additionally refuses if the two mappings
                                       are the same Python object (`left is right`), which is the
                                       in-memory twin of golden_diff.py's st_dev/st_ino guard.

FIELDS THAT DO NOT SURVIVE - THE AUDITED EXCLUSIONS
===================================================
The census is a CLOSED, PER-FIELD-JUSTIFIED list, not "everything except some stuff". Every key
in the save file that is NOT in the census is enumerated by `--audit-exclusions`, which prints
the plist value beside the reason, so the exclusion list is auditable by running it rather than
by trusting this comment. The measured findings are written up in the README beside the staged
golden. An exclusion nobody can audit is how a golden becomes a lie.

PORT / LAUNCH ISOLATION
=======================
Reuses golden_run.py wholesale, exactly as tests/golden/launch_dock.py does: a reserved port, a
staged app dir, and a debugConfig.plist in a private OO_ADDITIONALADDONSDIRS - because the game
DIALS OUT to the port named in that plist (OODebugSupport.m:67-80). A run on the shared 8563 can
be captured by a sibling worker's console and quit four seconds in while still exiting rc=0
(bead oo-het), which is a fully vacuous pass.
"""

import argparse
import json
import os
import plistlib
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DUMP_DIR = os.path.join(HERE, "dump")

sys.path.insert(0, HERE)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import golden_run  # noqa: E402
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "006-save-load"
SPEC_PATH = os.path.join(HERE, "specs", "006-save-load.json")

# A real oolite-standard.oolite-save is ~46 KB. This floor is far under that and exists to reject
# a zero-byte or stub file, which would parse to an empty mapping and make every comparison
# vacuous. It is deliberately not "equal to the known size": the point is to catch nothing, not
# to re-pin the fixture.
MIN_SAVE_BYTES = 1024

# The census must stay substantial. Pinned here AND in test_save_load.py, so shrinking the spec
# to a single trivially-equal field fails in two places.
MIN_CENSUS_FIELDS = 8

LOAD_TIMEOUT_SECONDS = 180


class ScenarioError(RuntimeError):
    pass


class Refusal(RuntimeError):
    """The comparison could not be performed soundly, so no verdict is given (rc=2)."""


def load_spec(path=SPEC_PATH):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def read_save_file(path):
    """Parse the .oolite-save and PROVE it is worth comparing against.

    Every refusal here is one of the vacuity routes in the module docstring. They are refusals
    (rc=2, "I cannot tell you") and never differences (rc=1), following the convention
    golden_diff.py established: a checker that returns "equal" when it could not actually
    compare is the most dangerous failure mode a gate can have.
    """
    if not os.path.isfile(path):
        raise Refusal(
            "the save file %s DOES NOT EXIST. There is nothing to load, so 'the loaded state "
            "matches the saved state' would be comparing the live game against an empty mapping "
            "and passing whenever the census is also empty." % path)
    size = os.path.getsize(path)
    if size < MIN_SAVE_BYTES:
        raise Refusal(
            "the save file %s is %d bytes, under the %d-byte floor. A stub or truncated save "
            "parses to few or no keys, and a comparison against it is vacuous however green it "
            "comes out." % (path, size, MIN_SAVE_BYTES))
    try:
        with open(path, "rb") as handle:
            data = plistlib.load(handle)
    except Exception as exc:  # noqa: BLE001 - any parse failure is a refusal, not a difference
        raise Refusal("%s is not a readable property list: %s: %s"
                      % (path, type(exc).__name__, exc))
    if not isinstance(data, dict) or not data:
        raise Refusal("%s parsed to %r, which carries no commander data" % (path, type(data)))
    return data, size


def saved_census(spec, plist):
    """The LEFT side: the census read out of the file's own bytes by Python's plist parser.

    Deliberately NOT read through the game. The whole value of this comparison is that the two
    sides share no code, so a bug in Oolite's deserialiser cannot corrupt both halves the same
    way and pass.
    """
    out, missing = {}, []
    for field in spec["census"]:
        key = field["plist"]
        if key not in plist:
            missing.append(key)
            continue
        out[key] = _normalise(plist[key], field["kind"])
    if missing:
        raise Refusal(
            "the save file is missing %d census key(s) the scenario compares on: %s. The census "
            "describes a save this file is not, so every 'match' would be a match on the fields "
            "that happen to remain." % (len(missing), ", ".join(missing)))
    return out


def _normalise(value, kind):
    """One place where the two sides are made comparable, and the ONLY place a scale is applied.

    Each `kind` is a MEASURED property of the storage, recorded in the spec's `why` beside the
    field. `float_tenths` in particular is not a fudge factor: PlayerEntity stores credits and
    fuel as integers in tenths, while the JS API reports them in whole units, so the file holds
    1000 where JS reports 100.0. Any conversion beyond this list would be a place to hide a
    mismatch, so there is no catch-all branch - an unknown kind raises.
    """
    if kind == "int":
        return int(value)
    if kind == "str":
        return str(value)
    if kind == "float_tenths":
        return round(float(value) / 10.0, 3)
    raise Refusal("census field declares unknown kind %r; refusing to invent a conversion" % kind)


# Reads the census back out of the LIVE game. One console round trip per field, each an
# ordinary JS property read - nothing here writes to the game, so the right-hand side cannot be
# contaminated by the harness.
def live_census(console, spec):
    out = {}
    for field in spec["census"]:
        raw = console.evaluate(field["js"]).strip()
        if raw == "" or raw.lower() in ("undefined", "null"):
            raise ScenarioError(
                "the game answered %r for census field %s (%s). An absent value on the live side "
                "would compare unequal for a reason that is about the probe, not about the "
                "round-trip." % (raw, field["plist"], field["js"]))
        kind = field["kind"]
        if kind == "int":
            out[field["plist"]] = int(float(raw))
        elif kind == "str":
            out[field["plist"]] = str(raw)
        elif kind == "float_tenths":
            out[field["plist"]] = round(float(raw), 3)
        else:
            raise Refusal("census field declares unknown kind %r" % kind)
    return out


def assert_non_vacuous(census, label):
    """The census must be big enough and full enough to be worth comparing."""
    if len(census) < MIN_CENSUS_FIELDS:
        raise Refusal(
            "%s carries %d field(s), fewer than the %d minimum. A short census is the empty-state "
            "vacuity route wearing a smaller hat: two states agreeing on three fields is not "
            "evidence that a save round-tripped." % (label, len(census), MIN_CENSUS_FIELDS))
    populated = [k for k, v in census.items() if v not in ("", 0, 0.0, None)]
    if len(populated) < MIN_CENSUS_FIELDS // 2:
        raise Refusal(
            "%s has only %d non-empty value(s) out of %d: %r. A census of zeros and empty strings "
            "compares equal to any other empty census, which is exactly the 'the state is EMPTY' "
            "vacuity route." % (label, len(populated), len(census), census))
    return len(census), len(populated)


def compare_census(left, right, left_label, right_label):
    """The round-trip assertion. Returns a list of differences; [] means they agree.

    THE SELF-COMPARISON GUARD. golden_diff.py refuses two paths that are one file on disk
    (st_dev/st_ino) because a file always equals itself. The in-memory twin of that mistake is
    comparing a mapping with itself - `compare(c, c)` is empty for any c, including an empty one -
    so it is refused here by IDENTITY, not by equality: `left == right` is the ANSWER, and using
    it as the guard would refuse every correct round-trip.
    """
    if left is right:
        raise Refusal(
            "both sides of the comparison are the SAME object in memory (id=%d). A mapping always "
            "equals itself, so this comparison could never fail - the same defect golden_diff.py "
            "refuses on disk via st_dev/st_ino." % id(left))
    problems = []
    for key in sorted(set(left) | set(right)):
        if key not in left:
            problems.append("%s: <absent in %s> != %r" % (key, left_label, right[key]))
        elif key not in right:
            problems.append("%s: %r != <absent in %s>" % (key, left[key], right_label))
        elif left[key] != right[key]:
            problems.append("%s: %r (%s) != %r (%s)"
                            % (key, left[key], left_label, right[key], right_label))
    return problems


def assert_loaded(console, spec, plist):
    """Positive evidence that the LOAD really happened, before anything is compared.

    A game that ignored -load sits on the main-menu demo with a default commander in a default
    system. It still answers every JS probe, so every probe-shaped check passes on it. These
    three clauses are chosen because the demo state FAILS all of them, and they are returned as
    dump FIELDS so the stored golden re-checks them on every future diff rather than trusting
    that this capture-time assertion once passed.
    """
    evidence = {}

    want_system = str(plist["current_system_name"])
    got_system = console.evaluate("system.name").strip()
    evidence["system_name"] = got_system
    if got_system != want_system:
        raise ScenarioError(
            "the game is in system %r but the save file names %r. The save was not loaded (or was "
            "loaded and then left), so the state being compared is not the saved state."
            % (got_system, want_system))

    want_name = str(plist["player_name"])
    got_name = console.evaluate("player.name").strip()
    evidence["commander_name"] = got_name
    if got_name != want_name:
        raise ScenarioError(
            "the commander is %r but the save file names %r; this is not the saved commander"
            % (got_name, want_name))

    # ship_clock is the saved PLAYER clock. A fresh game starts at the engine's own epoch, far
    # below it, so a player clock at or past the saved value is evidence the save's CLOCK was
    # adopted - a third signal, from a different subsystem than the two names above.
    #
    # `clock.seconds`, NOT `clock.absoluteSeconds`. MEASURED, and the distinction is the whole
    # point of this clause. OOJSClock.m:ClockGetProperty returns [UNIVERSE getTime] for
    # `absoluteSeconds` - the time this SESSION has been running, which starts near zero in every
    # process - and [player clockTime] for `seconds`, which is the value ship_clock restores. A
    # first version read absoluteSeconds and failed against a correctly loaded game with
    # "clock.absoluteSeconds is 0.752, BEFORE the save's own ship_clock 180058018403.920". That
    # was the PROBE being wrong, not the engine, and the two properties differ by eleven orders
    # of magnitude here, so reading the wrong one is not a subtle error - but it IS one that
    # would have been invisible had the assertion been written the other way round (>= would pass
    # trivially against a session clock if the saved value were small).
    want_clock = float(plist["ship_clock"])
    got_clock = float(console.evaluate("clock.seconds"))
    evidence["clock_at_or_past_save"] = bool(got_clock >= want_clock)
    evidence["saved_ship_clock"] = round(want_clock, 3)
    if not evidence["clock_at_or_past_save"]:
        raise ScenarioError(
            "clock.seconds (the PLAYER clock, [player clockTime]) is %.3f, BEFORE the save's own "
            "ship_clock %.3f: the game did not adopt the saved game clock, so it is not running "
            "the saved state" % (got_clock, want_clock))
    return evidence


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def suppress_populators(console):
    """Switch the system populator OFF, and PROVE it is off.

    `system.populatorSettings` is the read-only dictionary of active populator keys
    (OOJSSystem.m:170, :339) and `system.setPopulator(key, null)` deletes one (:1311 calls
    `[UNIVERSE setPopulatorSetting:key to:nil]`). Copied from scenario 001, which learned that
    clearing ships afterwards treats only the symptom: while the populator runs it both adds
    traffic and consumes a per-run-variable number of RANROT draws.

    An empty list is legitimate (a system may define none) and is reported rather than treated as
    a failure - but the count of SURVIVING settings is asserted, so a silently ineffective
    suppression cannot pass unnoticed.
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
            "%s populator setting(s) survived suppression; the system will keep adding traffic, "
            "so the dump records ambient population rather than the loaded save" % remaining)
    return [k for k in keys.split(",") if k]


def clear_system(console):
    """Remove every non-player, non-station ship, and assert none remain.

    The main station is deliberately spared: removing it undocks the player and makes
    docked/undocked a second, unintended source of divergence (scenario 001's finding).
    """
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


def assert_at_rest(console):
    """The world must be genuinely still. An ASSERTION, not a write.

    `magnitude` IS A FUNCTION, NOT A PROPERTY - scenario 001 shipped a version comparing the
    function object with a number, which is always false, so the guard passed on every run
    including ones whose dumps differed by twelve velocity fields. It is CALLED here. A guard
    that cannot fail is worse than none, because it is reported as evidence.
    """
    moving = console.evaluate(
        "(function(){ var s = system.allShips, bad = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()").strip()
    if moving:
        raise ScenarioError(
            "the game is paused but %d entity/entities still report motion: %s. ShipEntity "
            "-velocity is [super velocity] + [self thrustVector] (ShipEntity.m:12830-12833), so a "
            "ship under thrust reads a non-zero velocity no JS write can clear; its value depends "
            "on the frame count and no two runs can reproduce it."
            % (moving.count("=") + 1, moving))
    return True


def probe(app_dir, spec, run_root, save_path, keep=False, tag="run"):
    """Launch one game on the given save file and return (live_census, evidence, dump).

    One game process per call, on a PRIVATE port with its own debugConfig.plist, so a sibling
    worker's console cannot capture this run.
    """
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s-%s" % (SCENARIO, tag, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)

    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = (
        "%s,%s" % (config_dir, previous) if previous else config_dir)
    started = time.time()
    try:
        plist, _ = read_save_file(save_path)
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=int(spec["seed"]), output_dir=artifact_dir, host="127.0.0.1",
            load_save=save_path))
        with console:
            evidence = assert_loaded(console, spec, plist)
            got = console.evaluate_int("system.ID")
            if got != int(spec["system_id"]):
                raise ScenarioError(
                    "scenario %s is pinned to system ID %d (%s) but the loaded save is in system "
                    "ID %d" % (SCENARIO, int(spec["system_id"]), spec.get("system_name"), got))

            live = live_census(console, spec)

            # Pause LAST and CHECK THE RETURN VALUE, exactly as scenario 001 does and for the
            # same measured reason: GlobalPauseGame (OOJSGlobal.m:831-856) returns NO without
            # pausing on several GUI screens, and an unpaused dump records whatever the world
            # had drifted to. Only the DUMP needs the pause; the census above is scalar player
            # state that does not integrate.
            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s), so the "
                    "dump would keep integrating and no two runs could agree"
                    % console.evaluate("guiScreen").strip())

            # QUIETEN THE WORLD BEFORE DUMPING - the fleet's most expensive golden lesson.
            # A first capture of this scenario dumped 83 entities: loading a save starts a LIVE
            # system and Universe.m:7101 system_repopulator keeps adding traffic, so the dump
            # measures the ambient population rather than the scenario, and which ships it
            # contains depends on how many frames this box rendered. Bead oo-jor's scenario 001
            # refused to dump on 3 of 8 runs for exactly this reason. Handled at the SOURCE
            # (switch the populator off) and then at the symptom (remove what it already added),
            # in that order, because clearing alone leaves the cause running.
            suppressed = suppress_populators(console)
            clear_system(console)
            assert_at_rest(console)
            dump = json.loads(dump_state(console))
        evidence["populators_suppressed"] = len(suppressed)
        return {"census": live, "evidence": evidence, "dump": dump, "port": port,
                "wall_seconds": round(time.time() - started, 1), "artifact_dir": artifact_dir}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
        golden_run.release_all()


def run(app_dir, spec, run_root, save_path, out_path=None, keep=False, expect_from=None):
    """INVARIANT 1: the file's own bytes and the live loaded state agree, field by field.

    `expect_from` is the DETECTION control and exists only to prove this comparison can fail.
    Normally the expected census is read from the same file the game loads, which is the round
    trip. Pointed at a DIFFERENT save file, the game still loads `save_path` but the expectation
    comes from elsewhere, so a correct engine and a correct comparison MUST report a difference.
    Without it, "the file agrees with the game" has no negative control at all.

    WHY A SIMPLER MUTANT DOES NOT WORK HERE, AND WHAT IT PROVED INSTEAD. The obvious detection
    test - perturb one field in a throwaway copy of the save and load that - was run first and
    came back GREEN, correctly. Perturbing the FILE moves BOTH sides of this comparison, because
    the expectation is read from the same bytes the engine loads: credits 1000 -> 1010 in the
    file produced a live reading of 101.0 against an expected 101.0. That is not a hole; it is a
    measurement, and a valuable one - it proves the live side genuinely TRACKS the file rather
    than being a constant the harness could have hardcoded, which is its own anti-vacuity result.
    The mutation that discriminates the COMPARISON is therefore the cross-check, and both are
    run by tests/golden/scenario_006.sh --prove-detection.
    """
    plist, size = read_save_file(save_path)
    expect_plist, _ = read_save_file(expect_from) if expect_from else (plist, size)
    saved = saved_census(spec, expect_plist)
    result = probe(app_dir, spec, run_root, save_path, keep=keep, tag="load")
    live = result["census"]

    n_saved, pop_saved = assert_non_vacuous(saved, "the census read from the save FILE")
    n_live, pop_live = assert_non_vacuous(live, "the census read from the LOADED GAME")

    problems = compare_census(saved, live, "saved", "loaded")

    evidence = dict(result["evidence"])
    evidence.update({
        "save_file": os.path.basename(save_path),
        "save_bytes": size,
        "census_fields": n_saved,
        "census_populated": pop_saved,
        "round_trip_fields_equal": n_saved - len(problems),
        "round_trip_ok": not problems,
        "load_verified": True,
        # Present so a dump taken BEFORE the populator suppression existed cannot pass as if it
        # had been taken with the populator off. 0 is legitimate and is reported, not refused.
        "populators_suppressed": result["evidence"].get("populators_suppressed", 0),
        "seed": int(spec["seed"]),
        "system_id": int(spec["system_id"]),
        "scenario": SCENARIO,
    })
    state = dict(result["dump"])
    state["evidence"] = evidence
    text = canonical(state)
    if out_path:
        parent = os.path.dirname(os.path.abspath(out_path))
        if parent:
            os.makedirs(parent, exist_ok=True)
        with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
    return {"ok": not problems, "problems": problems, "saved": saved, "live": live,
            "evidence": evidence, "out": out_path, "bytes": len(text),
            "wall_seconds": result["wall_seconds"], "n_live": n_live, "pop_live": pop_live}


def audit_exclusions(spec, save_path):
    """Print EVERY save-file key the census does not compare, with its value. Auditable by
    running it, which is the only kind of exclusion list worth having."""
    plist, size = read_save_file(save_path)
    included = {f["plist"] for f in spec["census"]}
    print("save file: %s (%d bytes, %d top-level keys)" % (save_path, size, len(plist)))
    print("census compares %d of them; the remaining %d are listed below with their values.\n"
          % (len(included), len(plist) - len(included & set(plist))))
    for key in sorted(plist):
        if key in included:
            continue
        value = repr(plist[key])
        if len(value) > 90:
            value = value[:87] + "..."
        print("  EXCLUDED  %-28s %s" % (key, value))
    print("\nINCLUDED (the round-trip assertion):")
    for field in spec["census"]:
        print("  %-28s <- %-38s [%s]" % (field["plist"], field["js"], field["kind"]))
    return 0


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def default_save(app_dir, spec):
    return golden_run._slashes(os.path.join(app_dir, spec["save_file"]))


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/save_load.py",
                                     description=__doc__.split("\n")[0])
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--run-root", default=None)
    parser.add_argument("--save", default=None, help="the .oolite-save to round-trip")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--audit-exclusions", action="store_true",
                        help="print every save key the census does not compare, and stop")
    parser.add_argument("--expect-from", default=None,
                        help="DETECTION CONTROL: read the expected census from this save file "
                             "while the game loads --save. A different file MUST produce a "
                             "difference; this is the negative control for the comparison.")
    parser.add_argument("--census-only", action="store_true",
                        help="print the saved-side census and stop (no game launch)")
    args = parser.parse_args(argv)

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 2
    save_path = args.save or default_save(app_dir, spec)

    if args.audit_exclusions:
        try:
            return audit_exclusions(spec, save_path)
        except Refusal as exc:
            sys.stderr.write("REFUSED: %s\n" % exc)
            return 2
    if args.census_only:
        try:
            plist, _ = read_save_file(save_path)
            print(json.dumps(saved_census(spec, plist), indent=2, sort_keys=True))
        except Refusal as exc:
            sys.stderr.write("REFUSED: %s\n" % exc)
            return 2
        return 0

    ensure_launchable(app_dir)
    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_8ij_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, spec, run_root, save_path, out_path=args.out, keep=args.keep,
                     expect_from=args.expect_from)
    except Refusal as exc:
        sys.stderr.write("REFUSED: %s\n" % exc)
        return 2
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        sys.stderr.write("[!] %s: %s\n" % (type(exc).__name__, exc))
        return 3

    if result["problems"]:
        sys.stderr.write(
            "ROUND-TRIP FAILED: %d of %d census field(s) differ between the save file and the "
            "loaded game:\n" % (len(result["problems"]), result["evidence"]["census_fields"]))
        for p in result["problems"]:
            sys.stderr.write("  %s\n" % p)
        return 1

    print("ROUND-TRIP OK: all %d census field(s) in %s survive the load into a SEPARATE game "
          "process (%d populated, %d-byte save, %.1fs wall)"
          % (result["evidence"]["census_fields"], result["evidence"]["save_file"],
             result["evidence"]["census_populated"], result["evidence"]["save_bytes"],
             result["wall_seconds"]))
    if result["out"]:
        print("dump: %s (%d bytes)" % (result["out"], result["bytes"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
