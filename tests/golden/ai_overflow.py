"""Golden scenario 011-ai-overflow: stage the in-tree 'AI overflow test' test-OXP, SPAWN its
ship, prove the engine's AI stack overflow condition was REACHED and HANDLED, then emit a
canonical dump.

THE PREMISE THIS BEAD WAS GIVEN WAS WRONG, AND THE MEASUREMENT IS RECORDED HERE
------------------------------------------------------------------------------
This scenario was briefed as probably impossible: 'AI overflow test' was reported to fail to load
on a missing manifest.plist in a way that kept it out of the loaded set entirely. MEASURED on this
box before anything else was written (bead oo-dto, probe run on the shared meson_test build), the
expansion is ACCEPTED as a resource path and appears in the game's own [searchPaths.dumpAll] block:

    [searchPaths.dumpAll]: Resource paths:
        ~/Resources
        <artifact>/console-config
        <artifact>/oxp-stage
        ~/AddOns
        <artifact>/oxp-stage/AI overflow test.oxp        <-- HERE
        ~/AddOns/Basic-debug.oxp

    [oxp-standards.error]: OXP <artifact>/oxp-stage/AI overflow test.oxp has no manifest.plist
    [oxp-standards.error]: OXP <artifact>/oxp-stage/AI overflow test.oxp has no manifest.plist
    [startup.complete]: ========== Loading complete in 5.91 seconds. ==========

Exactly TWO missing-manifest lines, and it loads: bead oo-kcrw's NOMANIF class, identical to
RetroMissions. ResourceManager.m:642-664 is why - the missing-manifest path is only FATAL for an
.oxz (:636-641, `return`) or when OOEnforceStandards() is on (:647-651). For a plain .oxp in
relaxed mode the engine emits the standards error, SYNTHESISES a basic manifest (:654) and adds
the path to searchPaths (:663). NO MANIFEST IS STAGED and none is fabricated; the missing one is
tolerated EXACTLY, exactly as scenario 012 does.

WHAT THIS SCENARIO ASSERTS, AND WHY A DEAD OR QUIET RUN CANNOT SATISFY IT
------------------------------------------------------------------------
The name says 'AI overflow', so the property under test is the engine's behaviour under AI stack
pressure, not that a game started. Four independent things must be true, in causal order:

  1. `evidence.oxp_ship_keys` - `Ship.keysForRole('ahruman-stack-overflow-test')` read from the
     RUNNING game. A key gets there only if the expansion's Config/shipdata.plist was MERGED into
     the ship registry. Being named in searchPaths proves only that a directory was accepted.

  2. `evidence.oxp_ship_ai_type` - a PROPERTY read off that registry entry
     (`Ship.shipDataForKey(key).ai_type`), measured as 'ahruman-stack-overflow-testAI.plist'.
     A key in a list could be a bare name; a property read succeeds only against real merged data,
     and this particular property is the pointer to the expansion's OWN AIs/ file.

  3. `evidence.ai_stack_overflow_events` / `_max_stack_depth` / `_signatures` - the ENGINE's own
     report that the overflow happened, read out of THIS run's Latest.log. AI.m:240-246
     raises when the preserved-state-machine stack reaches kStackLimiter, and :205-227 logs
     `[ai.error.stackOverflow]` plus one `[ai.error.stackOverflow.dump]` line per preserved frame.
     `_max_stack_depth` is (highest dump index + 1) and is a STRUCTURAL engine constant, not a
     stopwatch reading: it equals kStackLimiter. tests/golden/test_ai_overflow.py derives that
     constant from AI.m and asserts the measured depth agrees with it AND with the literal 32, so
     an upstream renumbering fails loudly instead of quietly redefining the test (bead oo-vwd).

  4. `evidence.ai_stack_overflow_squashed` and `evidence.overflow_handled` - the overflow was
     HANDLED, not merely reached. The raise at AI.m:244 is caught and logged as
     `[exception]: Squashing exception OoliteException:AI stack overflow ... in AI handler
     <ai>:<state>.<handler>`. `overflow_handled` is the RELATION events == squashed with events
     >= 1: an overflow that escaped would leave the two unequal.

  5. `evidence.tick_budget_met` - the tick budget is started only AFTER the overflow line has been
     seen in the live log (see `await_overflow`), so a met budget is proof the simulation kept
     integrating AFTER the engine reported the overflow. A run that crashed on the exception
     cannot produce it, and neither can a run that never overflowed.

A run that died in display init has no log past initGL: zero for 3, 4 and 5. A run that loaded the
OXP and dumped a quiet world never spawns the ship: zero for 3, 4, 5. A run with nothing staged
fails 1 and 2. None of those can be made to pass by re-running.

WHAT IS DELIBERATELY *NOT* ASSERTED, AND THE SEAM THAT WOULD ALLOW IT
--------------------------------------------------------------------
The interesting per-ship facts - that THIS ship's AI is the overflowing one, what its AI state is,
how deep ITS stack is - are not observable in this tier. `Ship.AIState` is permanently 'GLOBAL'
here, `AI -stackDepth` (AI.m:382) has no JS binding, and the component step library
(upstream/oolite/tests/component/steps/world_steps.py) exposes only role counts and liveness: no
per-ship identity and no generic property read. Those are the seam beads oo-kbqw / oo-bdl0. This
scenario therefore attributes the overflow to the expansion through the AI FILE NAME carried in
the engine's own log signature ('ahruman-stack-overflow-testAI.plist'), which is a name only this
expansion can put there, rather than inventing an observable that does not exist.

THE OVERFLOW SHIP IS REMOVED BEFORE THE DUMP, ON PURPOSE
--------------------------------------------------------
The evidence above lives in the evidence block, not in the entity list. The ship is removed and
the world re-asserted at rest before dumping, so the dump is the same smallest reproducible world
scenario 012 uses. Keeping a thrusting ship in the dump would make the golden a stopwatch reading:
ShipEntity -velocity is [super velocity] + [self thrustVector] (ShipEntity.m:12830-12833), which no
JS write can clear, and bead oo-jor measured that refusing to dump on exactly that basis.

DETERMINISM AND ISOLATION
-------------------------
Identical to 001 and 012: a reserved port plus a debugConfig.plist in a private
OO_ADDITIONALADDONSDIRS (the game DIALS OUT to the port named there, OODebugSupport.m:67-80 - on
the shared 8563 a sibling worker's console captures and quits the run while it still exits rc=0,
bead oo-het); the populator switched off at the source before anything is measured; the world
asserted at rest under a CHECKED pauseGame(); the tick budget measured on the game clock.
"""

import argparse
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
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import golden_run  # noqa: E402

# NO DESKTOP LOCK, deliberately: this is a golden-harness scenario driver, exempt from tools/gui-lock
# on golden_run.py's terms (see its module docstring and tools/check-desktop-lock.sh). It launches
# through golden_run's per-run isolation - a reserved port, a staged private app dir, a private
# artifact dir - which exists so that golden runs can share one machine AT ONCE (stability sweeps,
# tier-b/tier-c golden stages, and several fleet worktrees' acceptance lines side by side). The
# desktop mutex is exclusive, so taking it here would serialise all of them into a queue of one.
# The run never needs the FOREGROUND: no synthetic input, no window click, readiness over the
# console socket, and every frame is rendered game-side from the game's own framebuffer. If this
# scenario ever starts to need the foreground it stops being exempt and must take the lock.
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "011-ai-overflow"

# The spec lives under tests/golden/scenarios/<SCENARIO>/ once Jon has approved the
# protected-path addition (tools/rebless-approvals.txt). Until then it is staged under
# tests/golden/pending/, and BOTH locations are searched so landing it is a pure `git mv` with no
# code change. See tests/golden/pending/011-ai-overflow/LANDING.md.
SPEC_CANDIDATES = (
    os.path.join(HERE, "scenarios", SCENARIO, "spec.json"),
    os.path.join(HERE, "pending", SCENARIO, "spec.json"),
)
GOLDEN_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "state.json"),
    os.path.join(HERE, "pending", SCENARIO, "state.json"),
)

TICK_WALL_BUDGET_SECONDS = 300
OVERFLOW_WALL_BUDGET_SECONDS = 180

OXP_STANDARDS_RE = re.compile(r"\[oxp-standards\.error\]:\s*(.*)")
# `[ai.error.stackOverflow]: ***** ERROR: AI stack overflow for <ShipEntity 0x...>{"..."} in
#  <ai file>: <state> -- stack:`   (AI.m:212)
OVERFLOW_RE = re.compile(r"\[ai\.error\.stackOverflow\]:.*?\bin ([^:]+): (\S+)")
# `[ai.error.stackOverflow.dump]:  31: <ai file>: <state>`   (AI.m:222)
OVERFLOW_DUMP_RE = re.compile(r"\[ai\.error\.stackOverflow\.dump\]:\s*(\d+):\s*(\S+):\s*(\S+)")
# `[exception]: Squashing exception OoliteException:AI stack overflow for <ShipEntity ...> in AI
#  handler <ai file>:<state>.<handler>`
SQUASH_RE = re.compile(
    r"\[exception\]:\s*Squashing exception (\S+):AI stack overflow .*?\bin AI handler (\S+)")


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


def load_spec(path=None):
    with open(path or spec_path(), "r", encoding="utf-8") as handle:
        return json.load(handle)


def oxp_source(spec):
    src = os.path.join(REPO_ROOT, *spec["oxp_source"].split("/"))
    if not os.path.isdir(src):
        raise ScenarioError(
            "the test-OXP this scenario is about is not in the tree at %s; a run staging nothing "
            "would still load the game and would dump a world with no expansion in it" % src)
    return src


def stage_oxp(spec, addons_dir):
    """Copy the expansion into a private addons root and return its staged path.

    A COPY, not a junction: the game writes nothing here, but the staged root is deleted at the
    end of the run and unstage must never follow a link into the tracked tree.

    THE DIRECTORY IS CALLED `oxp-stage`, NOT `addons`, AND THAT IS LOAD-BEARING. The game also
    searches `<app dir>/../AddOns` by default and the staged app lives at `<artifact>/app`, so a
    staging directory named `<artifact>/addons` IS `<artifact>/../AddOns` on a case-insensitive
    filesystem: bead oo-3ya measured the expansion being found at TWO roots and FOUR
    missing-manifest errors logged instead of two. The exact-count guard in assert_ran() is what
    catches that.
    """
    src = oxp_source(spec)
    os.makedirs(addons_dir, exist_ok=True)
    target = os.path.join(addons_dir, os.path.basename(src))
    shutil.copytree(src, target)
    if not os.path.isdir(target):
        raise ScenarioError("staging %s -> %s produced nothing" % (src, target))
    return golden_run._slashes(target)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def read_ship_registry(console, spec):
    """What the RUNNING game's ship registry knows about the expansion's ship.

    Returns (keys, ai_type). `keys` proves Config/shipdata.plist was merged; `ai_type` is a
    PROPERTY read off the merged entry and is the pointer to the expansion's own AIs/ file, so it
    is the registry's own statement that this ship runs that AI.

    Returned via JSON because the console transport is an XML property list: bead oo-3ya measured
    a separator character coming back plist-escaped, which would silently collapse a list.
    """
    role = spec["overflow_ship_role"]
    raw = console.evaluate(
        "(function(){ var k = Ship.keysForRole(%s) || []; k = k.slice(); k.sort();"
        " return JSON.stringify(k); })()" % json.dumps(role)).strip()
    try:
        keys = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("Ship.keysForRole(%r) did not come back as JSON (%s): %r"
                            % (role, exc, raw[:200]))
    if not isinstance(keys, list):
        raise ScenarioError("Ship.keysForRole(%r) came back as %r, not a list" % (role, keys))

    ai_type = None
    if keys:
        ai_type = console.evaluate(
            "(function(){ var d = Ship.shipDataForKey(%s);"
            " if (!d) return 'OODTO-NO-SHIPDATA';"
            " return String(d.ai_type); })()" % json.dumps(keys[0])).strip()
        if ai_type == "OODTO-NO-SHIPDATA":
            ai_type = None
    return keys, ai_type


def suppress_populators(console):
    """Switch the system populator off at the source (copied from scenarios 001 and 012).

    `system.setPopulator(key, null)` deletes a populator setting (OOJSSystem.m:1311). The
    populator keeps adding traffic while the scenario runs and every ship it adds consumes RANROT
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


def spawn_overflow_ship(console, spec):
    """Spawn the expansion's ship. Its AI triggers a setAITo: recursion immediately.

    `Read me.txt` in the fixture gives this exact invocation. The count and distance come from the
    spec so they are knobs with predicates, not literals buried in a string.
    """
    count = int(spec["overflow_ship_count"])
    distance = int(spec["overflow_spawn_distance"])
    got = console.evaluate(
        "(function(){ var a = system.addShips(%s, %d, player.ship.position, %d);"
        " return a ? String(a.length) : '0'; })()"
        % (json.dumps(spec["overflow_ship_role"]), count, distance)).strip()
    try:
        spawned = int(got)
    except ValueError:
        raise ScenarioError("system.addShips returned %r, not a count" % got)
    if spawned != count:
        raise ScenarioError(
            "system.addShips(%r, %d, ...) spawned %d ship(s); with nothing spawned the AI stack "
            "overflow can never be reached and the run would prove only that the game started"
            % (spec["overflow_ship_role"], count, spawned))
    return spawned


def await_overflow(console, artifact_dir, budget=OVERFLOW_WALL_BUDGET_SECONDS):
    """Block until the ENGINE reports an AI stack overflow in THIS run's live log.

    This is the causal hinge of the scenario. Everything after it - the tick budget, the world
    still answering the console - happens AFTER the engine has said the overflow occurred, so
    `tick_budget_met` is evidence the simulation survived it rather than merely evidence that the
    game once ran. The log is polled rather than the console because the overflow has no JS
    observable in this tier (see the module docstring).

    Returns the game-clock reading at the moment the line appeared. That value is NOT stored: it
    is a stopwatch reading of how fast this box got there (bead oo-jor).
    """
    log = os.path.join(artifact_dir, "Latest.log")
    deadline = time.time() + budget
    while time.time() < deadline:
        if os.path.isfile(log):
            with open(log, "r", encoding="utf-8", errors="replace") as handle:
                if OVERFLOW_RE.search(handle.read()):
                    return float(console.evaluate("clock.absoluteSeconds"))
        time.sleep(0.25)
    raise ScenarioError(
        "no [ai.error.stackOverflow] line appeared in %s within %ss of wall time. The expansion's "
        "ship was spawned but the engine never reported an AI stack overflow, so this run does "
        "NOT exercise the condition the scenario is named for and must not be dumped."
        % (log, budget))


def run_ticks(console, ticks, tick_seconds):
    """Advance `ticks` AI ticks of GAME time and return the elapsed game seconds."""
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


def normalise_oxp_error(message, oxp_basename):
    """Replace the volatile staged path with the OXP's basename.

    The staged addons root carries a timestamp, a port and a pid, so the raw message differs on
    every run by construction. Only the path is replaced; the rest of the message is compared
    VERBATIM, so a different error at the same path does not match the allow-list.
    """
    return re.sub(r"\S*%s" % re.escape(oxp_basename), oxp_basename, message).strip()


def read_run_log(artifact_dir, oxp_basename):
    """Everything this run's own Latest.log says about loading and about the overflow.

    Deliberately reads the log rather than trusting the harness's memory of what it did: the
    engine's own report is the only witness to the overflow in this tier, and the ShipEntity
    POINTER and position in those messages are volatile, so only the AI-file:state pair is kept.
    """
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log, so neither the expansion's load nor the "
            "AI stack overflow can be checked at all" % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()

    standards = [normalise_oxp_error(m.group(1), oxp_basename)
                 for m in OXP_STANDARDS_RE.finditer(text)]
    overflows = ["%s:%s" % (m.group(1).strip(), m.group(2).strip())
                 for m in OVERFLOW_RE.finditer(text)]
    depths = [int(m.group(1)) for m in OVERFLOW_DUMP_RE.finditer(text)]
    squashes = ["%s in %s" % (m.group(1), m.group(2)) for m in SQUASH_RE.finditer(text)]
    return {
        "standards": standards,
        "overflows": overflows,
        # The dump is printed from the top frame down to 0, so the count of DISTINCT frames is
        # (highest index + 1). AI.m:218-223 walks `while (count--)` over the whole stack.
        "max_stack_depth": (max(depths) + 1) if depths else 0,
        "stack_dump_lines": len(depths),
        "squashes": squashes,
        "log_bytes": len(text),
    }


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied before anything is written.

    Every clause names a field the dump carries, so the same property is re-checked by every
    future diff against the stored golden rather than only at capture time.
    """
    if not evidence["oxp_staged"]:
        raise ScenarioError("evidence.oxp_staged is false: nothing was staged, so this run says "
                            "nothing about the expansion")

    expected_keys = sorted(spec["expected_ship_keys"])
    if not evidence["oxp_ship_keys"]:
        raise ScenarioError(
            "evidence.oxp_ship_keys is empty: the running game's ship registry has no key for "
            "role %r, so the expansion's Config/shipdata.plist was never merged. The OXP being on "
            "the search path is not the same as its content being live."
            % spec["overflow_ship_role"])
    if sorted(evidence["oxp_ship_keys"]) != expected_keys:
        raise ScenarioError(
            "evidence.oxp_ship_keys is %r but the spec pins %r. A golden taken against a "
            "different expansion is not comparable with the stored one."
            % (sorted(evidence["oxp_ship_keys"]), expected_keys))
    if evidence["oxp_ship_ai_type"] != spec["expected_ship_ai_type"]:
        raise ScenarioError(
            "evidence.oxp_ship_ai_type is %r but the spec pins %r. This is the PROPERTY read that "
            "proves merged ship data rather than a bare key, and it is the registry's own "
            "statement that this ship runs the expansion's AI file."
            % (evidence["oxp_ship_ai_type"], spec["expected_ship_ai_type"]))

    if evidence["overflow_ships_spawned"] != int(spec["overflow_ship_count"]):
        raise ScenarioError(
            "evidence.overflow_ships_spawned is %r, expected %r: with the ship not spawned the "
            "overflow condition is never reached"
            % (evidence["overflow_ships_spawned"], int(spec["overflow_ship_count"])))

    if evidence["ai_stack_overflow_events"] < 1:
        raise ScenarioError(
            "evidence.ai_stack_overflow_events is %r: the engine never logged "
            "[ai.error.stackOverflow], so the AI stack overflow this scenario is named for did "
            "NOT happen. A run that loads the OXP and dumps a quiet world proves nothing and "
            "would reproduce byte-for-byte forever." % evidence["ai_stack_overflow_events"])
    expected_depth = int(spec["expected_max_stack_depth"])
    if evidence["ai_stack_overflow_max_stack_depth"] != expected_depth:
        raise ScenarioError(
            "evidence.ai_stack_overflow_max_stack_depth is %r but the spec pins %r "
            "(AI.m:40 kStackLimiter). The depth the engine unwinds is a structural constant, so a "
            "different value means the limiter changed and this golden is stale."
            % (evidence["ai_stack_overflow_max_stack_depth"], expected_depth))
    expected_sigs = sorted(spec["expected_overflow_signatures"])
    if sorted(set(evidence["ai_stack_overflow_signatures"])) != expected_sigs:
        raise ScenarioError(
            "evidence.ai_stack_overflow_signatures is %r but the spec pins %r. The signature is "
            "<AI file>:<state> taken from the engine's own message, and the AI file name is what "
            "attributes the overflow to THIS expansion rather than to ambient traffic."
            % (sorted(set(evidence["ai_stack_overflow_signatures"])), expected_sigs))

    if evidence["ai_stack_overflow_squashed"] != evidence["ai_stack_overflow_events"]:
        raise ScenarioError(
            "the engine reported %d AI stack overflow(s) but only %d were squashed. An overflow "
            "that escaped its handler is not 'handled', and the difference is the finding."
            % (evidence["ai_stack_overflow_events"], evidence["ai_stack_overflow_squashed"]))
    if not evidence["overflow_handled"]:
        raise ScenarioError(
            "evidence.overflow_handled is false: the overflow was not both REACHED and HANDLED")
    expected_squash = sorted(spec["expected_squash_signatures"])
    if sorted(set(evidence["ai_stack_overflow_squash_signatures"])) != expected_squash:
        raise ScenarioError(
            "evidence.ai_stack_overflow_squash_signatures is %r but the spec pins %r. This names "
            "the exception class and the AI handler that raised, which is how 'handled' is "
            "distinguished from 'silently absent'."
            % (sorted(set(evidence["ai_stack_overflow_squash_signatures"])), expected_squash))

    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks) AFTER the overflow was observed, so the "
            "simulation did not survive it"
            % (evidence["game_seconds_budget"], evidence["ticks"]))

    allowed_count = int(spec["allowed_oxp_standards_errors"])
    allowed = set(spec["allowed_oxp_standards_error_signatures"])
    if evidence["oxp_standards_errors"] != allowed_count:
        raise ScenarioError(
            "evidence.oxp_standards_errors is %d but exactly %d is allowed for this fixture "
            "(bead oo-kcrw: this is a NOMANIF fixture - it predates the manifest format and emits "
            "exactly %d '[oxp-standards.error]' lines). A different count means a NEW problem, "
            "and widening this number to make the run pass is forbidden. Signatures seen: %r"
            % (evidence["oxp_standards_errors"], allowed_count, allowed_count,
               evidence["oxp_standards_error_signatures"]))
    unexpected = [s for s in evidence["oxp_standards_error_signatures"] if s not in allowed]
    if unexpected:
        raise ScenarioError(
            "the run emitted an [oxp-standards.error] line that is NOT the known missing-manifest "
            "message: %r. The allow-list is %r and it is deliberately exact - a third or "
            "different error is a finding, not noise." % (unexpected, sorted(allowed)))


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, stage=True, empty_stage=False,
        spawn=True, seed_override=None, ticks_override=None, probe=False):
    from console import DebugConsole  # noqa: E402  (path valid only after sys.path setup)

    seed = int(spec["seed"] if seed_override is None else seed_override)
    ticks = int(spec["ticks"] if ticks_override is None else ticks_override)
    oxp_basename = os.path.basename(spec["oxp_source"].rstrip("/"))

    os.makedirs(run_root, exist_ok=True)
    port = golden_run.reserve_port(run_root)
    stamp = "%s-p%d-%d" % (time.strftime("%H%M%S", time.gmtime()), port, os.getpid())
    artifact_dir = golden_run._slashes(os.path.join(run_root, "%s-%s" % (SCENARIO, stamp)))
    staged = golden_run._slashes(os.path.join(artifact_dir, "app"))
    config_dir = golden_run._slashes(os.path.join(artifact_dir, "console-config"))
    addons_dir = golden_run._slashes(os.path.join(artifact_dir, "oxp-stage"))

    os.makedirs(artifact_dir, exist_ok=True)
    golden_run.stage_app(app_dir, staged)
    golden_run._write_console_config(config_dir, "127.0.0.1", port)
    # `empty_stage` is the NARROW staging mutant: the staging root exists and is on
    # OO_ADDITIONALADDONSDIRS, but the expansion has been removed from it. oxp_staged stays true,
    # so the run gets past the staging assertion and trips the assertion actually under test - the
    # one about the expansion's content being live. A mutant applied ABOVE the assertion you mean
    # to exercise short-circuits it (bead oo-vwd).
    if empty_stage:
        os.makedirs(addons_dir, exist_ok=True)
        staged_oxp = None
    else:
        staged_oxp = stage_oxp(spec, addons_dir) if stage else None

    roots = [config_dir] + ([addons_dir] if stage or empty_stage else [])
    previous = os.environ.get("OO_ADDITIONALADDONSDIRS")
    os.environ["OO_ADDITIONALADDONSDIRS"] = ",".join(roots + ([previous] if previous else []))
    started = time.time()
    try:
        console = start_with_retry(lambda: DebugConsole(
            staged, port, seed=seed, output_dir=artifact_dir, host="127.0.0.1",
            load_save=spec["load_save"]))
        with console:
            assert_system(console, spec)
            keys, ai_type = read_ship_registry(console, spec)

            suppressed = suppress_populators(console)
            clear_system(console)

            spawned = spawn_overflow_ship(console, spec) if spawn else 0
            # The hinge: block until the ENGINE says the overflow happened, then measure the
            # budget. Everything after this point is evidence the simulation survived it.
            #
            # SKIPPED WHEN NOTHING WAS SPAWNED, deliberately. await_overflow would time out after
            # 180s and the mutant would die on a TIMEOUT rather than on the assertion it exists to
            # exercise. A mutant applied above the assertion under test short-circuits it (bead
            # oo-vwd), so --no-spawn/--no-oxp fall straight through to assert_ran, where
            # `ai_stack_overflow_events < 1` names the real property.
            if spawn:
                await_overflow(console, artifact_dir)
            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            # Pause LAST and CHECK THE RETURN VALUE: GlobalPauseGame (OOJSGlobal.m:831-856)
            # returns NO without pausing on the chart/mission/report/keyboard/save screens, and an
            # unchecked pause turns a deterministic scenario into a stopwatch (bead oo-jor).
            if console.evaluate("pauseGame()").strip().lower() != "true":
                raise ScenarioError(
                    "pauseGame() returned false: the game is NOT paused (guiScreen=%s). The "
                    "simulation would keep integrating through the dump and no two runs could "
                    "agree." % console.evaluate("guiScreen").strip())
            clock_before = float(console.evaluate("clock.absoluteSeconds"))

            # The overflow ship is removed here, not kept: see the module docstring.
            clear_system(console)
            clock_after = float(console.evaluate("clock.absoluteSeconds"))
            if clock_after != clock_before:
                raise ScenarioError(
                    "the game clock advanced %.4fs (%.4f -> %.4f) after pauseGame() returned "
                    "true; the world is NOT frozen, so the dump is a stopwatch reading and no two "
                    "runs can agree" % (clock_after - clock_before, clock_before, clock_after))

            # `magnitude` IS A FUNCTION, NOT A PROPERTY - calling it is what makes this guard able
            # to fail at all (bead oo-jor measured a version that compared a function object with
            # a number and therefore passed on every run).
            moving = console.evaluate(
                "(function(){ var s = system.allShips, bad = [];"
                " for (var i = 0; i < s.length; i++) {"
                "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
                "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
                "              s[i].velocity.magnitude().toFixed(4)); }"
                " return bad.join(', '); })()").strip()
            if moving:
                raise ScenarioError(
                    "the game clock is stopped but %d entity/entities still report motion: %s. "
                    "ShipEntity -velocity is [super velocity] + [self thrustVector] "
                    "(ShipEntity.m:12830-12833), so a ship under thrust reads a non-zero velocity "
                    "that no JS write can clear; its value depends on the frame count and no two "
                    "runs can reproduce it." % (moving.count("=") + 1, moving))

            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        log = read_run_log(artifact_dir, oxp_basename)

        events = len(log["overflows"])
        squashed = len(log["squashes"])
        evidence = {
            "scenario": SCENARIO,
            "oxp_staged": bool(stage or empty_stage),
            "oxp_basename": oxp_basename,
            "oxp_ship_keys": sorted(keys),
            "oxp_ship_ai_type": ai_type,
            "overflow_ships_spawned": spawned,
            "ai_stack_overflow_events": events,
            "ai_stack_overflow_max_stack_depth": log["max_stack_depth"],
            "ai_stack_overflow_signatures": sorted(set(log["overflows"])),
            "ai_stack_overflow_squashed": squashed,
            "ai_stack_overflow_squash_signatures": sorted(set(log["squashes"])),
            "overflow_handled": bool(events >= 1 and squashed == events),
            "oxp_standards_errors": len(log["standards"]),
            "oxp_standards_error_signatures": sorted(set(log["standards"])),
            # The BUDGET is pinned; the measured elapsed time is NOT in the dump on purpose - the
            # overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor). The assertion keeps full strength as a
            # boolean and the raw float is reported on stdout by the CLI.
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
        }
        # `probe` is the MEASUREMENT mode: it reports the evidence WITHOUT asserting on it and
        # WITHOUT writing a dump, because the values assert_ran checks are exactly the values the
        # probe exists to discover. It can never write a golden, so it cannot launder an
        # unasserted run into one.
        if not probe:
            assert_ran(evidence, spec)
        state["evidence"] = evidence
        text = canonical(state)
        if out_path and not probe:
            parent = os.path.dirname(os.path.abspath(out_path))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(out_path, "w", encoding="utf-8", newline="\n") as handle:
                handle.write(text)
        return {"ok": True, "out": out_path, "port": port, "staged_oxp": staged_oxp,
                "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                "log_bytes": log["log_bytes"], "stack_dump_lines": log["stack_dump_lines"],
                "game_seconds_elapsed": round(elapsed, 3), "evidence": evidence}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
            shutil.rmtree(addons_dir, ignore_errors=True)
        golden_run.release_all()


def gate_spec(spec, prov_path=None):
    """Assert every determinism knob is pinned, read, and AGREES WITH THE GOLDEN'S PROVENANCE.

    `prov_path` defaults to the blessed-then-pending search and is injectable so the offline suite
    can drive this gate against a provenance file it has deliberately corrupted, and prove the
    drift comparison still fires. See gate_isolation's note on why that seam exists.

    THE PROVENANCE COMPARISON IS THE POINT, and it is here because of a measured hole: bead
    oo-3ya's gate PRINTED its seed and had no predicate on it, so the seed could be changed with
    the gate staying green - and the fresh-run-vs-golden line cannot catch that either, because
    changing the seed changes BOTH sides of that comparison. Hardcoding the seed in the checker is
    the wrong fix (it makes re-blessing illegal and invites editing the constant). Asserting the
    spec equals the knobs the golden was BLESSED with keeps a deliberate re-bless legal while
    silent drift is fatal.

    Returns a message; raises ScenarioError naming the field and both values on failure.
    """
    required = ("seed", "system_id", "ticks", "tick_seconds", "quant_decimals", "load_save",
                "oxp_source", "overflow_ship_role", "overflow_ship_count",
                "overflow_spawn_distance", "expected_ship_keys", "expected_ship_ai_type",
                "expected_max_stack_depth", "expected_overflow_signatures",
                "expected_squash_signatures", "allowed_oxp_standards_errors",
                "allowed_oxp_standards_error_signatures")
    missing = [k for k in required if k not in spec]
    if missing:
        raise ScenarioError("spec.json does not pin %s; without them the scenario is not "
                            "reproducible" % missing)
    if spec["quant_decimals"] != 3:
        raise ScenarioError("spec quant_decimals=%r but the storage policy is 3"
                            % spec["quant_decimals"])
    if not isinstance(spec["ticks"], int) or spec["ticks"] < 1:
        raise ScenarioError("spec ticks=%r, must be a positive int" % spec["ticks"])
    if spec["allowed_oxp_standards_errors"] != 2:
        raise ScenarioError(
            "spec allows %r oxp-standards errors; bead oo-kcrw records EXACTLY 2 missing-manifest "
            "lines for a NOMANIF fixture and widening it is a suppression"
            % spec["allowed_oxp_standards_errors"])
    if spec["allowed_oxp_standards_error_signatures"] != [
            "OXP AI overflow test.oxp has no manifest.plist"]:
        raise ScenarioError("the allow-list is not exactly the known missing-manifest message: %r"
                            % spec["allowed_oxp_standards_error_signatures"])
    if spec["expected_max_stack_depth"] != 32:
        raise ScenarioError(
            "spec expected_max_stack_depth=%r; AI.m:40 defines kStackLimiter=32 and the engine "
            "dumps one preserved frame per stack entry, so 32 is the structural value"
            % spec["expected_max_stack_depth"])

    with open(os.path.join(HERE, "ai_overflow.py"), encoding="utf-8") as handle:
        src = handle.read()
    unread = [k for k in required if 'spec["%s"]' % k not in src]
    if unread:
        raise ScenarioError("ai_overflow.py never reads spec%r; those knobs are decoration"
                            % unread)

    prov_path = prov_path or _first_existing(
        (os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO, "provenance.json"),
         os.path.join(HERE, "pending", SCENARIO, "provenance.json")),
        "provenance.json for scenario %s" % SCENARIO)
    with open(prov_path, encoding="utf-8") as handle:
        prov = json.load(handle)
    knobs = prov.get("scenario_knobs")
    if not knobs:
        raise ScenarioError(
            "%s records no scenario_knobs; the seed the golden was BLESSED with is unrecorded, so "
            "nothing can detect the spec drifting away from it" % prov_path)
    drift = {k: (knobs[k], spec.get(k)) for k in knobs if spec.get(k) != knobs[k]}
    if drift:
        raise ScenarioError(
            "spec.json disagrees with the knobs this golden was blessed with (%s records "
            "blessed-vs-spec %r). The stored golden no longer corresponds to what the spec would "
            "produce; re-bless deliberately or restore the spec - do NOT edit one side to match."
            % (prov_path, drift))
    return ("PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=3 oxp=%s, overflow role "
            "%r x%d at %dm, %d AI frames pinned, exactly %d tolerated missing-manifest error(s), "
            "all %d knobs read by ai_overflow.py, and all %d knob(s) match the values recorded in "
            "the golden provenance"
            % (spec["seed"], spec["system_id"], spec["ticks"], spec["tick_seconds"],
               spec["oxp_source"], spec["overflow_ship_role"], spec["overflow_ship_count"],
               spec["overflow_spawn_distance"], spec["expected_max_stack_depth"],
               spec["allowed_oxp_standards_errors"], len(required), len(knobs)))


def gate_isolation(src_path=None):
    """Assert the mechanisms that stop a sibling worker's console making this run vacuous.

    `src_path` defaults to this file and exists so the OFFLINE SUITE can drive this gate against a
    deliberately weakened COPY of the source and prove it still says no. Without that seam the
    gate could only ever be run against a correct file, and a gate that is never shown failing is
    not known to work - measured: four checker mutants survived the whole stored block precisely
    because the suite inspected the source's shape instead of driving its gates with bad input.

    Each of these is a measured incident, not a style rule:
      * the seed must actually reach the game (console.py exports OO_RANDOM_SEED);
      * each run must reserve its OWN port and WRITE the debugConfig.plist the game DIALS OUT to
        (bead oo-gla: a --port flag that only rebinds a listener can never work; bead oo-het: on
        the shared 8563 a sibling console captures and quits the game and the run still exits 0);
      * the staging dir must not be called `addons`, which IS `../AddOns` case-insensitively and
        loads the expansion at two roots (bead oo-3ya);
      * no manifest.plist may be named in EXECUTABLE code - checked on the AST, because the file's
        prose explains the tolerance many times and a grep would match the explanation.
    """
    sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))
    import console as console_module  # noqa: E402

    with open(console_module.__file__, encoding="utf-8") as handle:
        if "OO_RANDOM_SEED" not in handle.read():
            raise ScenarioError("console.py does not export OO_RANDOM_SEED; the seed knob cannot "
                                "reach the game")
    path = src_path or os.path.join(HERE, "ai_overflow.py")
    with open(path, encoding="utf-8") as handle:
        src = handle.read()
    for needle, why in (
        ("seed=seed", "ai_overflow.py does not pass seed= to DebugConsole"),
        ("reserve_port", "ai_overflow.py does not reserve a private console port; on the shared "
                         "8563 a sibling worker console can capture and quit the game seconds in "
                         "and the run still exits 0 (bead oo-het)"),
        ("_write_console_config", "ai_overflow.py does not write a debugConfig.plist; the game "
                                  "DIALS OUT to the port named there (bead oo-gla)"),
    ):
        if needle not in src:
            raise ScenarioError(why)
    # THE NEEDLE IS BUILT, NOT WRITTEN OUT. A literal here would appear in this file's own source
    # and match itself, so the guard would report its own text as a violation - measured: it did.
    needle = "os.path.join(artifact_dir, %s%s%s)" % (chr(34), "addons", chr(34))
    if needle in src:
        raise ScenarioError(
            "the OXP staging directory is named addons again; /addons IS /../AddOns "
            "case-insensitively, so the game finds the expansion at TWO roots and logs FOUR "
            "missing-manifest errors instead of the two bead oo-kcrw records")

    import ast
    tree = ast.parse(src)
    # THE CHECK IS ON THE ACT, NOT ON THE MENTION. An earlier version flagged every string
    # constant containing `manifest.plist` outside a docstring - and then matched its OWN failure
    # message and the allow-list signature, i.e. it reported the guard as the violation. What must
    # be forbidden is CREATING that file, so the check is: no path-building or file-opening call
    # may carry `manifest.plist` in any of its arguments. Prose, error messages and the NOMANIF
    # allow-list may name it freely; `open(.../manifest.plist, "w")` may not exist.
    creators = {"open", "os.path.join", "shutil.copy", "shutil.copy2", "shutil.copyfile",
                "plistlib.dump", "plistlib.dumps"}
    bad = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call) or ast.unparse(node.func) not in creators:
            continue
        for arg in node.args:
            for sub in ast.walk(arg):
                if isinstance(sub, ast.Constant) and isinstance(sub.value, str) \
                        and "manifest.plist" in sub.value:
                    bad.append(ast.unparse(node))
    if bad:
        raise ScenarioError(
            "ai_overflow.py builds a path to manifest.plist in executable code %r; this fixture "
            "predates the manifest format and its missing manifest must be TOLERATED exactly, "
            "never fabricated" % bad)

    staging = next(n for n in ast.walk(tree)
                   if isinstance(n, ast.FunctionDef) and n.name == "stage_oxp")
    calls = {ast.unparse(n.func) for n in ast.walk(staging) if isinstance(n, ast.Call)}
    if "open" in calls:
        raise ScenarioError("stage_oxp opens a file; it must only copy the fixture tree verbatim")
    if "shutil.copytree" not in calls:
        raise ScenarioError("stage_oxp no longer copies the fixture tree verbatim")

    fn = next(n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef) and n.name == "run")
    # REACHABILITY, NOT MERE PRESENCE. A mutant that changed `if spawn:` to `if False:` left the
    # await_overflow call sitting in the source, so a presence check and an ordering check both
    # passed while the overflow was never actually waited for. Any call guarded by a constant-
    # false test can never execute, so it is treated as absent.
    dead = set()
    for node in ast.walk(fn):
        if isinstance(node, ast.If):
            test = node.test
            falsy = (isinstance(test, ast.Constant) and not test.value)
            if falsy:
                for sub in ast.walk(ast.Module(body=node.body, type_ignores=[])):
                    if isinstance(sub, ast.Call):
                        dead.add(ast.unparse(sub.func))
    lines = {}
    for node in ast.walk(fn):
        if isinstance(node, ast.Call):
            name = ast.unparse(node.func)
            if name in dead:
                continue
            if name not in lines or node.lineno < lines[name]:
                lines[name] = node.lineno
    if "await_overflow" not in lines or "run_ticks" not in lines:
        raise ScenarioError(
            "run() no longer both awaits the overflow and measures a tick budget (unreachable "
            "under a constant-false guard counts as absent; dead calls seen: %s)"
            % (sorted(dead) or "none"))
    if lines["await_overflow"] >= lines["run_ticks"]:
        raise ScenarioError(
            "run() measures its tick budget at line %d, BEFORE waiting for the engine's overflow "
            "report at line %d, so evidence.tick_budget_met no longer shows the simulation "
            "SURVIVED the overflow - it would show only that the game was once alive"
            % (lines["run_ticks"], lines["await_overflow"]))
    return ("PASS: seed reaches the game via OO_RANDOM_SEED, each run reserves its own port and "
            "writes the debugConfig.plist the game dials out to, the OXP stages to oxp-stage (not "
            "addons), no manifest.plist is fabricated, and the tick budget is measured AFTER the "
            "engine's overflow report (line %d) not before (line %d)"
            % (lines["await_overflow"], lines["run_ticks"]))


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/ai_overflow.py", description=__doc__)
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--empty-stage", action="store_true",
                        help="MUTANT: create the staging directory but REMOVE the expansion from "
                             "it. Narrower than --no-oxp: the run reaches and trips the "
                             "expansion-content evidence assertion rather than the staging one.")
    parser.add_argument("--no-oxp", action="store_true",
                        help="MUTANT: stage no expansion. The run must then FAIL its own evidence "
                             "assertions; used to prove the gate can go red.")
    parser.add_argument("--no-spawn", action="store_true",
                        help="MUTANT: stage the expansion but never spawn its ship. The OXP loads "
                             "and the world is quiet, so this is the 'proves nothing' run the "
                             "overflow assertions exist to reject.")
    parser.add_argument("--probe", action="store_true",
                        help="print the registry read and the run's log findings and exit 0 "
                             "without dumping; used to MEASURE what the spec pins.")
    parser.add_argument("--gate", choices=("spec", "isolation"), default=None,
                        help="offline gate mode used by the stored acceptance block: `spec` "
                             "asserts every knob is pinned, read, and equal to the knobs recorded "
                             "in the golden's provenance; `isolation` asserts the port/plist/"
                             "staging/manifest/ordering mechanisms. Neither launches the game.")
    args = parser.parse_args(argv)

    spec = load_spec()
    if args.gate:
        try:
            print(gate_spec(spec) if args.gate == "spec" else gate_isolation())
        except ScenarioError as exc:
            print("FAIL: %s" % exc, file=sys.stderr)
            return 1
        return 0

    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_dto_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     stage=not (args.no_oxp or args.empty_stage),
                     empty_stage=args.empty_stage,
                     # With nothing staged the role does not exist, so addShips would fail FIRST
                     # and the run would die on the spawn count instead of on the
                     # expansion-content assertion these mutants exist to exercise.
                     spawn=not (args.no_spawn or args.no_oxp or args.empty_stage),
                     probe=args.probe,
                     seed_override=args.seed, ticks_override=args.ticks)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    if args.probe:
        json.dump(result["evidence"], sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
