"""Golden scenario 010-png-test-suite: load the in-tree PNGTestSuite test-OXP, prove its PNG
content was DECODED and PUT ON SCREEN, run a FIXED number of game ticks, and emit a canonical
dump plus a reference frame grid.

WHY THIS SCENARIO IS DIFFERENT FROM 012
---------------------------------------
Scenario 012 (`tests/golden/retro_missions.py`, bead oo-3ya) is the shape this copies: fixed seed,
fixed system, fixed tick count, a canonical dump, and an evidence block the stored golden carries.
But 012 asks "did the expansion's SCRIPTS go live", which is a question about objects in a JS
heap. PNGTestSuite is about TEXTURE DECODING, and a texture that failed to decode leaves the JS
heap looking exactly the same. So this scenario adds a second, GRAPHICAL observable and pins it
with the measured instrument from bead oo-ae9 (`tests/golden/frame_hash.py`).

WHAT PNGTestSuite ACTUALLY CONTAINS, MEASURED
---------------------------------------------
Its own README says the 153 PNG Suite images are NOT SHIPPED ("the licensing terms of the test
suite are unspecified, so the images are not included"). Verified on disk: `Images/` holds exactly
ONE file, `oolite_material_test_suite_backdrop.png`, 1024x512, 8-bit truecolour.

That shapes the scenario, and it is stated rather than worked around. The expansion contributes:

  * a 2930-line `Config/shipdata.plist` defining 153 test-cube ship entries, each naming a
    distinct PNG in `materials["cube-face"].diffuse_map` and repeating it in
    `script_info.oolite_png_test_suite_label`;
  * one world script, `oolite-png-test-suite` version 1.0;
  * one real PNG, the backdrop.

So this scenario does NOT run the suite's 153 rendering tests. It cannot: 153 of the 153 images
are absent, every cube would fail to texture, and a scenario built on 153 guaranteed texture
failures would be asserting on a broken state and would have to tolerate real errors to stay
green. That is the opposite of what a golden is for. What it asserts instead is below.

WHAT THIS RUN ASSERTS, AND WHY A DEAD RUN CANNOT SATISFY IT
-----------------------------------------------------------
Four independent defences, each measuring a different stage of the pipeline:

  1. `evidence.oxp_world_scripts` / `oxp_script_versions`. The name `oolite-png-test-suite` is in
     the running game's `worldScripts` and a property read off it returns "1.0". That requires the
     OXP directory accepted as a resource path, its script found, compiled and INSTANTIATED. The
     stock baseline is not guessed: `stock_world_scripts` in spec.json was MEASURED by the
     `--no-oxp` control, so the difference is attributable to PNGTestSuite alone.

  2. `evidence.png_shipdata_entries`. `Ship.shipDataForKey('oolite_png_test_suite_N')` resolves
     for all 153 N, and `evidence.png_diffuse_map_sample` carries the diffuse_map string read back
     out of the merged registry for a fixed sample of those keys. This proves the 2930-line
     shipdata.plist was PARSED AND MERGED, not merely present on disk. A dead run has 0.

  3. `evidence.png_texture_uploads` - THE TEXTURE-DECODE EVIDENCE, and the reason this scenario
     exists. `[texture.upload]` is emitted by OOConcreteTexture -upload (OOConcreteTexture.m:525)
     with the texture's PIXEL DIMENSIONS, and it is reached only AFTER OOPNGTextureLoader has
     decoded the file: the loader bails at `texture.load.png.setup.failed` /
     `texture.load.png.failed` (OOPNGTextureLoader.m:97,118) long before any upload. The channel is
     off by default (logcontrol.plist:457 `texture.upload = $textureDebug = no`), so the run turns
     it on over the console before rendering anything.

     The recorded width and height are checked against the IHDR READ OUT OF THE FILE ON DISK, not
     against a literal: `png_ihdr_dimensions` is parsed from the first 26 bytes of the staged PNG
     by this module. If the engine decoded a different image, or decoded nothing and something
     else uploaded a same-named texture, the two disagree and the run refuses. This is the
     oo-vwd discipline - derive the constant from the product's own data AND keep a literal in
     spec.json so a broken derivation cannot quietly redefine the test.

  4. THE FRAME. A mission screen is opened whose background IS that OXP PNG, and the rendered
     frame's 64x64 luminance grid is compared with the stored reference grid using the tolerance
     bead oo-ae9 MEASURED (frame_hash.derive_tolerance(), 0.004377 from a noise floor of 0.002541
     and a weakest signal of 0.007541). MEASURED FOR THIS SCENARIO, with the OXP staged vs absent:

         same scene, two separate launches   d = 0.000489   0.11x the tolerance
         OXP staged vs OXP ABSENT            d = 0.140094  32.00x the tolerance

     The absent case renders a BLACK screen: with no OXP there is no such background image, the
     mission screen falls back to empty space, and the frame is 32x the tolerance away. This is
     the control the brief asks for, and it is what makes the frame a texture-decode assertion
     rather than decoration - a run in which the PNG did not decode looks like the black frame,
     not like the stored one. Both numbers sit comfortably inside oo-ae9's measured band (floor
     0.002541, weakest signal 0.007541): this scenario's own floor is FIVE TIMES BELOW the
     measured floor, because a docked mission screen is a far more static stimulus than a
     starfield, and its signal is EIGHTEEN TIMES ABOVE the weakest measured signal. The tolerance
     is used exactly as measured and is not adjusted.

THE FRAME GRID IS NOT IN THE CANONICAL DUMP, DELIBERATELY
----------------------------------------------------------
llvmpipe is not bit-reproducible across runs (oo-ae9: 0 of 3 same-scene pairs were byte-identical),
so putting a frame hash into state.json would make the byte-identical golden comparison fail on
every run. The grid is stored BESIDE the dump as `frame.grid` (4096 raw bytes) and compared with a
TOLERANCE, while state.json stays byte-exact. Two artifacts, two comparison rules, each matched to
what its data can actually support.

THE MISSING manifest.plist IS TOLERATED EXPLICITLY, NOT IGNORED (bead oo-kcrw)
------------------------------------------------------------------------------
PNGTestSuite is one of five in-tree legacy fixtures that predate the manifest format. MEASURED on
this host, verbatim from a real launch's own Latest.log:

    [oxp-standards.error]: OXP <staged>/PNGTestSuite.oxp has no manifest.plist
    [oxp-standards.error]: OXP <staged>/PNGTestSuite.oxp has no manifest.plist
    [searchPaths.dumpAll]: Resource paths:
        <staged>/PNGTestSuite.oxp

Exactly two, matching bead oo-kcrw's NOMANIF class. CHOICE MADE, AND WHY: the two lines are
ALLOW-LISTED by EXACT message and EXACT count; no manifest is staged. Staging one would fabricate
content the fixture does not have, which is both a falsification of the thing under test and a
write into expansion content. The allowance is a pin: a THIRD line, or any different
`[oxp-standards.error]`, fails the run. `--stage-double` exists to prove that predicate fires.

DETERMINISM AND ISOLATION
-------------------------
As 012, for the same measured reasons: a reserved port plus a debugConfig.plist in a private
OO_ADDITIONALADDONSDIRS (the game DIALS OUT to the port named there, OODebugSupport.m:67-80 - a run
on the shared 8563 can be captured and quit by a sibling worker's console while still exiting rc=0,
bead oo-het); the system cleared; the tick budget measured on the GAME clock.

TWO POPULATORS, NOT ONE, AND ORDER MATTERS - THE FINDING THAT COST THIS SCENARIO TWO SWEEPS.
Switching off `system.populatorSettings` the way 001 and 012 do is NOT sufficient here.
StationEntity -update (StationEntity.m:960-995) runs its own launch schedule for shuttles, traders
and patrols, gated on `hasNPCTraffic` (:967, :979, :991) and on nothing the system populator owns.

  Sweep 1, system populator only: 5 of 10 runs dumped, FIVE DIFFERENT dumps, disagreeing on which
  ship the station had just launched ('Mining Transporter', 'Cobra Mark I', 'Worm'); the other 5
  refused with a launched ship or its cargo still under thrust.

  Sweep 2, both suppressions but applied AFTER the 153-key shipdata probe: 2 of 10 runs dumped,
  2 distinct dumps, 8 refusals naming 'Cobra Mark I=232.5000' / 'Mining Transporter=69.3000'. The
  probe makes ~160 console round trips and burns several seconds of game time, and the station
  launched during it.

So THREE things are load-bearing and all three are asserted: both sources are switched off
(`suppress_populators` + `suppress_station_traffic`, recorded as `populators_suppressed` and
`stations_quieted`), the suppression happens FIRST, before any slow probe, and the world is then
cleared to a FIXED POINT rather than once (`quiesce`, recorded as
`world_reached_fixed_point`) - because switching off scheduling does not drain a queue a station
has already built or recall a ship already in flight.

WHY THE WORLD IS NOT pauseGame()d, AND WHAT REPLACES IT. GlobalPauseGame (OOJSGlobal.m:831-856)
returns NO without pausing while `guiScreen == GUI_SCREEN_MISSION`, and this scenario's whole
point is a mission screen carrying the OXP's image. An unchecked pause would be worse than none,
so the guard is the DIRECT one instead: every non-player entity's `velocity.magnitude()` is read
(a FUNCTION call - bead oo-jor measured a version comparing a function object with a number, which
passed on every run) and must be zero, and the player must be docked. The world contains no movers
by construction: the populator is off and every non-station ship is removed. Quiescence is then
demonstrated rather than assumed, by the stability run recorded in provenance.json.
"""

import argparse
import json
import os
import re
import shutil
import struct
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DUMP_DIR = os.path.join(HERE, "dump")

sys.path.insert(0, HERE)
sys.path.insert(0, DUMP_DIR)
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests", "component"))

import frame_hash  # noqa: E402
import golden_run  # noqa: E402
from state_dump import dump_state, ensure_launchable, start_with_retry  # noqa: E402

SCENARIO = "010-png-test-suite"

# The spec and golden live under the guarded goldens/ tree once Jon has approved the protected-path
# addition (tools/rebless-approvals.txt). Until then they are staged under tests/golden/pending/,
# and BOTH locations are searched so landing them is a pure `git mv` with no code change. Exactly
# scenario 012's arrangement; see tests/golden/pending/010-png-test-suite/README.md.
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

TICK_WALL_BUDGET_SECONDS = 300
FRAME_SETTLE_SECONDS = 1.5
SETTLE_TIMEOUT_SECONDS = 120
# How many clear-recount-and-remeasure rounds `quiesce` will spend looking for a clean one. MEASURED: with both populators off, the world converges in 2-4 rounds; 20 is a
# generous ceiling whose only job is to turn 'never settles' into a loud refusal rather than a hang.
CLEAR_ROUNDS = 20

OXP_STANDARDS_RE = re.compile(r"\[oxp-standards\.error\]:\s*(.*)")
# OOConcreteTexture.m:525 -- "Uploaded texture %u (%ux%u pixels, %@)". The GL texture NAME is
# deliberately dropped when normalising (it is an allocation artifact); the KEY and the PIXEL
# DIMENSIONS are what carry the evidence.
TEXTURE_UPLOAD_RE = re.compile(
    r"\[texture\.upload\]:\s*Uploaded texture \d+ \((\d+)x(\d+) pixels, ([^)]*)\)")

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


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
    return _first_existing(FRAME_CANDIDATES, "stored reference frame grid for %s" % SCENARIO)


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


def png_ihdr_dimensions(path):
    """(width, height) read straight out of the file's IHDR chunk.

    THE POINT OF THIS FUNCTION is that the dimensions the gate checks against are not a literal
    somebody typed: they are read from the same bytes the engine decoded. If the engine reports
    uploading a texture of a different size than the file on disk actually is, the run refuses -
    which is what makes `[texture.upload]` evidence OF THIS IMAGE rather than of some texture.
    (bead oo-vwd: derive the constant from the product's own data, and keep a literal in spec.json
    so a broken derivation cannot quietly redefine the test.)
    """
    with open(path, "rb") as handle:
        head = handle.read(26)
    if len(head) < 26 or head[:8] != PNG_SIGNATURE:
        raise ScenarioError(
            "%s is not a PNG (signature %r); the scenario's texture-decode evidence is about a "
            "PNG and there is nothing here to decode" % (path, head[:8]))
    if head[12:16] != b"IHDR":
        raise ScenarioError("%s has no IHDR as its first chunk (%r)" % (path, head[12:16]))
    width, height = struct.unpack(">II", head[16:24])
    return int(width), int(height)


def stage_oxp(spec, addons_dir, twice=False):
    """Copy the expansion into a private addons root and return its staged path.

    A COPY, not a junction: the game writes nothing here, but the staged root is deleted at the
    end of the run and unstage must never follow a link into the tracked tree.

    THE DIRECTORY IS CALLED `oxp-stage`, NOT `addons`, AND THAT IS LOAD-BEARING. The game also
    searches `<app dir>/../AddOns` by default and the staged app lives at `<artifact>/app`, so a
    staging directory named `<artifact>/addons` IS `<artifact>/../AddOns` on a case-insensitive
    filesystem: bead oo-3ya measured the expansion then found at TWO roots, logging FOUR
    missing-manifest errors instead of two. The exact-count guard is what catches that.

    `twice` reproduces that double-root state on purpose (--stage-double), so the exact-count
    predicate can be PROVEN to fire rather than merely asserted to be exact.
    """
    src = oxp_source(spec)
    os.makedirs(addons_dir, exist_ok=True)
    target = os.path.join(addons_dir, os.path.basename(src))
    shutil.copytree(src, target)
    if not os.path.isdir(target):
        raise ScenarioError("staging %s -> %s produced nothing" % (src, target))
    if twice:
        shutil.copytree(src, os.path.join(addons_dir, "PNGTestSuiteCopy.oxp"))
    return golden_run._slashes(target)


def assert_system(console, spec):
    got = console.evaluate_int("system.ID")
    if got != int(spec["system_id"]):
        raise ScenarioError(
            "scenario %s is pinned to system ID %d (%s) but the loaded save is in system ID %d; a "
            "golden taken in a different system is not comparable with the stored one"
            % (SCENARIO, int(spec["system_id"]), spec.get("system_name", "?"), got))
    return got


def world_script_names(console):
    """Names of every live world script, sorted, read from the RUNNING game.

    Returned as JSON rather than as a joined string: the console transport is an XML property list
    and a separator character can be plist-escaped, silently collapsing N names into one (measured
    by bead oo-3ya).
    """
    raw = console.evaluate(
        "(function(){ var n = Object.keys(worldScripts); n.sort();"
        " return JSON.stringify(n); })()").strip()
    try:
        names = json.loads(raw)
    except ValueError as exc:
        raise ScenarioError("worldScripts did not come back as JSON (%s): %r" % (exc, raw[:200]))
    if not isinstance(names, list):
        raise ScenarioError("worldScripts came back as %r, not a list" % (names,))
    return names


def world_script_versions(console, names):
    """Split `names` into scripts resolving to a LIVE JS object and those that are bare keys."""
    live, key_only = {}, []
    for name in names:
        expr = ("(function(){ var s = worldScripts[%s];"
                " if (!s) return 'OOGXP-KEY-ONLY';"
                " return String(s.version); })()" % json.dumps(name))
        value = console.evaluate(expr).strip()
        if value == "OOGXP-KEY-ONLY":
            key_only.append(name)
        else:
            live[name] = value
    return live, sorted(key_only)


def png_shipdata(console, spec):
    """How many of the suite's ship entries the merged registry resolves, and a fixed sample.

    `Ship.shipDataForKey` (OOJSShip.m:578) reads the MERGED ship registry, so a key resolving here
    means PNGTestSuite's 2930-line Config/shipdata.plist was parsed and merged into the game's own
    ship data. The sample re-reads `materials['cube-face'].diffuse_map` and the
    `script_info.oolite_png_test_suite_label` for a FIXED set of indices, so the evidence names
    actual image filenames from inside the running engine rather than counting anonymously.
    """
    count = console.evaluate_int(
        "(function(){ var n = 0;"
        " for (var i = 1; i <= %d; i++) {"
        "   if (Ship.shipDataForKey('%s' + i)) n++; }"
        " return n; })()"
        % (int(spec["png_test_count"]), spec["png_shipdata_key_prefix"]))
    sample = {}
    for index in spec["png_sample_indices"]:
        raw = console.evaluate(
            "(function(){ var d = Ship.shipDataForKey('%s%d');"
            " if (!d) return 'ABSENT';"
            " var m = d.materials && d.materials['cube-face'];"
            " return JSON.stringify([String(m && m.diffuse_map),"
            "   String(d.script_info && d.script_info.oolite_png_test_suite_label)]); })()"
            % (spec["png_shipdata_key_prefix"], int(index))).strip()
        if raw == "ABSENT":
            raise ScenarioError(
                "Ship.shipDataForKey('%s%d') is absent from the merged ship registry: the "
                "expansion's shipdata.plist was not merged, so nothing names a PNG to decode"
                % (spec["png_shipdata_key_prefix"], int(index)))
        try:
            diffuse, label = json.loads(raw)
        except ValueError as exc:
            raise ScenarioError("shipdata sample %d came back unparseable (%s): %r"
                                % (index, exc, raw[:200]))
        if diffuse != label:
            raise ScenarioError(
                "ship entry %s%d names diffuse_map %r but script_info label %r. The fixture "
                "repeats the image name in both places; a disagreement means the plist was merged "
                "wrongly, not that the image is missing."
                % (spec["png_shipdata_key_prefix"], int(index), diffuse, label))
        sample[str(index)] = diffuse
    return count, sample


def enable_texture_logging(console, spec):
    """Turn on the texture channels this scenario's evidence is read from, and PROVE they are on.

    They are off by default: logcontrol.plist:454-457 sets `$textureDebug = no` and
    `texture.upload = $textureDebug`. A run that merely ASKED for them and did not check would
    produce an empty `png_texture_uploads` list indistinguishable from a run where nothing decoded,
    which is exactly the vacuity this scenario exists to close. So the flag is read back.
    """
    channels = list(spec["texture_log_channels"])
    for channel in channels:
        console.perform("debugConsole.setDisplayMessagesInClass(%s, true);" % json.dumps(channel))
    off = []
    for channel in channels:
        state = console.evaluate(
            "String(debugConsole.displayMessagesInClass(%s))" % json.dumps(channel)).strip()
        if state.lower() != "true":
            off.append("%s=%s" % (channel, state))
    if off:
        raise ScenarioError(
            "these log channels did not switch on: %s. The texture-decode evidence is read out of "
            "the run's own Latest.log on those channels, and with them off an empty upload list "
            "would mean 'not logged' rather than 'not decoded' - the two must not be confusable."
            % ", ".join(off))
    return channels


def suppress_populators(console):
    """Switch the system populator off at the source (copied from scenario 001/012).

    `system.setPopulator(key, null)` deletes a populator setting (OOJSSystem.m:1311). The populator
    keeps adding traffic while the scenario runs and every ship it adds consumes RANROT draws, so a
    fixed seed fixes the SEQUENCE but not how far a wall-clock-timed run has got through it.
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


def suppress_station_traffic(console):
    """Switch off EVERY station's own NPC traffic, and prove none is left on.

    MEASURED, AND THIS IS THE SECOND POPULATOR NOBODY EXPECTS. Suppressing
    `system.populatorSettings` is NOT sufficient: StationEntity -update (StationEntity.m:960-995)
    runs its OWN launch schedule for shuttles, traders and patrols, gated on `hasNPCTraffic`
    (:967, :979, :991) and on nothing the system populator owns. With only the system populator
    off, a 10-run stability sweep of this scenario produced FIVE DIFFERENT dumps and two outright
    refusals - the dumps disagreeing on which ship the station had just launched ('Mining
    Transporter', 'Cobra Mark I', 'Worm') and the refusals naming a launched ship or its cargo
    still under thrust ('Worm=83.0800'; six 'Cargo container=144.xxxx'). That is the fixed-point
    problem bead oo-jor recorded, one layer further down: a single clear does not settle a world
    that has a second source still adding to it.

    `hasNPCTraffic` is READWRITE from JS (OOJSStation.m:123, :358-361). Switching it off at the
    source, rather than clearing repeatedly, is what makes this scenario a fixed point instead of
    a race.
    """
    remaining = console.evaluate(
        "(function(){ var e = system.stations, off = 0, on = [];"
        " for (var i = 0; i < e.length; i++) {"
        "   e[i].hasNPCTraffic = false; off++;"
        "   if (e[i].hasNPCTraffic) on.push(e[i].name); }"
        " return JSON.stringify([off, on]); })()").strip()
    try:
        count, still_on = json.loads(remaining)
    except ValueError as exc:
        raise ScenarioError("station traffic suppression came back unparseable (%s): %r"
                            % (exc, remaining[:200]))
    if still_on:
        raise ScenarioError(
            "these station(s) still report hasNPCTraffic after it was written false: %r. "
            "StationEntity -update launches shuttles, traders and patrols on its own schedule "
            "(StationEntity.m:960-995), so the world would keep gaining ships during the run and "
            "no two dumps could agree." % (still_on,))
    if not count:
        raise ScenarioError(
            "no station was found to suppress. The scenario is docked at Lave's main station by "
            "construction, so zero stations means the save did not load the world this scenario "
            "is about.")
    return count


def suppress_repopulator(console, spec):
    """Neuter the `oolite-populator` world script's REPOPULATE handler, and prove it is gone.

    THE THIRD SOURCE, AND THE ONE THAT DEFEATS THE OTHER TWO. `system.setPopulator(k, null)`
    clears the populator SETTINGS that run when a system is first populated; `hasNPCTraffic = false`
    stops StationEntity's own launch schedule. Neither touches `oolite-populator.js`'s
    `systemWillRepopulate` (:1027), which the engine fires periodically for the life of the system
    and which launches freighters, couriers, police patrols and shuttles on its own RNG rolls.

    AND IT IGNORES THE FLAG. Its station picker `_tradeStation` (:2656-2680) tests
    `stat.hasNPCTraffic` inside the loop but ENDS WITH `return system.mainStation;` - an
    unconditional fallback. So switching the main station's traffic off does not stop it launching:
    it only stops it being chosen by the loop, after which the fallback chooses it anyway. MEASURED
    after both earlier suppressions were in place: still 'Cobra Mark I=130.0000' and
    'Mining Transporter=50.0000' arriving mid-run, with 1 of 10 runs dumping.

    A world script's handlers are ordinary JS properties, so the handler is replaced with a no-op
    at the source and the replacement is READ BACK. The names are in spec.json rather than inline,
    because a handler upstream renames is a handler this no longer suppresses, and the read-back
    turns that into a red rather than a flaky golden.
    """
    quieted = []
    for name in spec["repopulator_handlers"]:
        before = console.evaluate(
            "String(typeof worldScripts['oolite-populator'][%s])" % json.dumps(name)).strip()
        if before == "undefined":
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s does not exist. This scenario suppresses that "
                "handler because it launches traffic for the life of the system "
                "(oolite-populator.js:1027); if it has been renamed upstream, the suppression is "
                "silently doing nothing and the scenario is no longer deterministic. Re-derive the "
                "handler names rather than dropping this check." % name)
        console.perform(
            "worldScripts['oolite-populator'][%s] = function(){};" % json.dumps(name))
        after = console.evaluate(
            "String(worldScripts['oolite-populator'][%s].toString().replace(/\\s+/g,''))"
            % json.dumps(name)).strip()
        if "function(){}" not in after:
            raise ScenarioError(
                "worldScripts['oolite-populator'].%s did not become a no-op (it reads %r); the "
                "repopulator is still live and will keep adding ships during the run"
                % (name, after[:120]))
        quieted.append(name)
    return quieted


def clear_system(console):
    """Remove every non-player, non-station ship, and report how many were removed AND how many
    are still there afterwards.

    THIS FUNCTION DOES NOT JUDGE. Deciding whether the world is quiet is `quiesce`'s
    job, because a single round legitimately finds ships: a ship the repopulator launched a moment
    before the suppression landed is still in flight, and removing it is normal, not a failure. An
    earlier version raised here on any survivor, which made the fixed-point loop unreachable - it
    could never get to its second round.
    """
    removed = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) { ships[i].remove(); n++; } }"
        " return n; })()")
    remaining = console.evaluate_int(
        "(function(){ var ships = system.allShips, n = 0;"
        " for (var i = 0; i < ships.length; i++) {"
        "   if (!ships[i].isPlayer && !ships[i].isStation) n++; }"
        " return n; })()")
    return removed, remaining


def quiesce(console, rounds=CLEAR_ROUNDS):
    """Clear AND settle as ONE fixed point, and refuse if the world never reaches it.

    THE ORDER OF THE LAST FEW SECONDS IS THE WHOLE PROBLEM. Clearing to a fixed point and THEN
    switching screens, settling and snapshotting leaves several seconds in which a ship can arrive,
    and MEASURED that is exactly what happened: runs refused with 'Mining Transporter=50.0000',
    'Cobra Mark I=138.0000', 'Worm=50.0000' - ships that did not exist when the clear returned.

    So the two conditions are checked TOGETHER, in one loop, immediately before the measurement:
    a round passes only when it removes nothing, sees nothing, AND every remaining entity reports
    zero motion. Anything less is 'the world was quiet a moment ago', which is not a claim this
    scenario can make.

    Returns the round history. Raises ScenarioError if the world never settles - a stopwatch
    reading is not a golden.
    """
    history = []
    for _ in range(rounds):
        removed, remaining = clear_system(console)
        moving = moving_entities(console)
        history.append([removed, remaining, len(moving)])
        if removed == 0 and remaining == 0 and not moving:
            return history
        time.sleep(0.3)
    raise ScenarioError(
        "the world never went quiet: %d rounds went %r ([removed, remaining, moving] per round) "
        "and none was clean. Something is still adding or accelerating entities. The three known "
        "sources are the system populator (system.populatorSettings), each station's own launch "
        "schedule (StationEntity.m:960-995, hasNPCTraffic) and oolite-populator.js's "
        "systemWillRepopulate (Universe.m:7094-7103, fired on a timer for the life of the "
        "system), and all three are switched off before this runs. A fourth source is a FINDING; "
        "do not widen the round count to paper over it." % (rounds, history))


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


def moving_entities(console):
    """Every non-player ship reporting motion, as 'name=magnitude' strings.

    `magnitude` IS A FUNCTION, NOT A PROPERTY - calling it is what makes this able to fail at all
    (bead oo-jor measured a version that compared a function OBJECT with a number, so the guard
    passed on every run including the ones that should have refused).
    """
    raw = console.evaluate(
        "(function(){ var s = system.allShips, bad = [];"
        " for (var i = 0; i < s.length; i++) {"
        "   if (!s[i].isPlayer && s[i].velocity.magnitude() > 0.0005)"
        "     bad.push((s[i].shipUniqueName || s[i].name) + '=' +"
        "              s[i].velocity.magnitude().toFixed(4)); }"
        " return bad.join(', '); })()").strip()
    return [part for part in raw.split(", ") if part]


def assert_at_rest(console):
    """The world is still, without pauseGame() - which refuses on a mission screen.

    GlobalPauseGame (OOJSGlobal.m:831-856) returns NO while guiScreen is GUI_SCREEN_MISSION, and
    the whole scenario is a mission screen. This is the LAST-INSTANT re-check: `quiesce` already
    drove the world to a fixed point, and this proves it was still at that fixed point when the
    frame and the dump were taken rather than a few seconds earlier.
    """
    moving = moving_entities(console)
    if moving:
        raise ScenarioError(
            "%d entity/entities still report motion: %s. ShipEntity -velocity is [super velocity] "
            "+ [self thrustVector] (ShipEntity.m:12830-12833), so a ship under thrust reads a "
            "non-zero velocity that no JS write can clear; its value depends on the frame count "
            "and no two runs can reproduce it." % (len(moving), ", ".join(moving)))
    if console.evaluate("player.ship.docked").strip().lower() != "true":
        raise ScenarioError(
            "the player is not docked. This scenario's frame is a station mission screen; "
            "undocked, the camera is wherever the ship drifted to and the frame hash is noise.")
    return True


def settle(console, seconds=FRAME_SETTLE_SECONDS, timeout=SETTLE_TIMEOUT_SECONDS):
    """Advance on the GAME's clock, never ours: a fixed sleep snapshots whatever frame was up."""
    start = float(console.evaluate("clock.absoluteSeconds"))
    deadline = time.time() + timeout
    while time.time() < deadline:
        if float(console.evaluate("clock.absoluteSeconds")) - start >= seconds:
            return
        time.sleep(0.25)
    raise ScenarioError("game clock did not advance %ss within %ss" % (seconds, timeout))


def show_backdrop(console, spec, blank=False):
    """Open a mission screen whose background is the OXP's PNG, and prove it opened.

    `blank=True` is the NARROW graphical mutant: the identical screen with NO background image, so
    the run reaches the frame comparison and trips it on the image rather than short-circuiting
    somewhere above.
    """
    config = {"title": "", "message": "\n\n\n"}
    if not blank:
        config["background"] = spec["backdrop_image"]
    opened = console.evaluate(
        "(function(){ try { return String(mission.runScreen(%s)); }"
        " catch (e) { return 'ERR ' + e; } })()" % json.dumps(config)).strip()
    if opened.lower() != "true":
        raise ScenarioError(
            "mission.runScreen did not open the backdrop screen (returned %r). Without it there "
            "is no frame carrying the expansion's image and the graphical evidence is absent."
            % opened)
    screen = console.evaluate("guiScreen").strip()
    if screen != "GUI_SCREEN_MISSION":
        raise ScenarioError(
            "guiScreen is %r, not GUI_SCREEN_MISSION, after runScreen returned true; the frame "
            "would be of some other screen entirely" % screen)
    return screen


def capture_frame(console, artifact_dir, attempts=20):
    """Snapshot the current frame and return (png path, 64x64 luminance grid).

    THE FILE APPEARS BEFORE IT IS FINISHED. `golden_run._await_png` waits for the NAME to show up
    in the directory, which on Windows happens while the game still holds the handle open for
    writing - reading it then fails with `PermissionError: [Errno 13]` (MEASURED: 1 run in 10) or,
    worse, could read a truncated image and hash it as if it were the frame. Both are retried
    here, and a frame that never becomes readable is a REFUSAL rather than a hash of half a file.
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
        "the snapshot at %s never became readable (%s: %s). The game writes the file while still "
        "holding the handle, so this is retried; a frame that stays unreadable means the hash "
        "would be taken on a partial image, which is worse than no frame at all."
        % (png, type(last).__name__, last))


def normalise_oxp_error(message, oxp_basename):
    """Replace the volatile staged path with the OXP's basename.

    The staged addons root carries a timestamp, a port and a pid, so the raw message differs on
    every run by construction. Only the PATH is replaced; the rest of the message is compared
    VERBATIM, so a different error at the same path does not match the allow-list.
    """
    return re.sub(r"\S*%s" % re.escape(oxp_basename), oxp_basename, message).strip()


def normalise_texture_key(key, oxp_basename):
    """`Images/x.png:0x2017/0/0` -> `Images/x.png`.

    The trailing fields are the texture OPTIONS mask and the anisotropy/lod settings, which are
    rendering configuration rather than evidence about the image. The leading path is normalised
    the same way the error signatures are, for the same reason.
    """
    key = normalise_oxp_error(key, oxp_basename)
    return key.split(":")[0].strip()


def read_log_evidence(artifact_dir, oxp_basename):
    """Collect the oxp-standards and texture-upload evidence from THIS run's own Latest.log."""
    log = os.path.join(artifact_dir, "Latest.log")
    if not os.path.isfile(log):
        raise ScenarioError(
            "no Latest.log at %s: the run wrote no log, so neither the missing-manifest allowance "
            "nor the texture-upload evidence can be checked at all" % log)
    with open(log, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()
    standards = [normalise_oxp_error(m.group(1), oxp_basename)
                 for m in OXP_STANDARDS_RE.finditer(text)]
    uploads = []
    for match in TEXTURE_UPLOAD_RE.finditer(text):
        width, height, key = int(match.group(1)), int(match.group(2)), match.group(3)
        uploads.append({"key": normalise_texture_key(key, oxp_basename),
                        "width": width, "height": height})
    png_failures = [line.strip() for line in text.splitlines()
                    if "[texture.load.png." in line]
    return standards, uploads, png_failures, len(text)


def assert_ran(evidence, spec):
    """The anti-vacuity gate, applied before anything is written.

    Every clause names a field the dump CARRIES, so the same property is re-checked by every future
    diff against the stored golden rather than only at capture time.
    """
    if not evidence["oxp_staged"]:
        raise ScenarioError("evidence.oxp_staged is false: nothing was staged, so this run says "
                            "nothing about the expansion")

    # --- DEFENCE 1: the expansion's world script is live --------------------------------------
    expected_names = sorted(spec["expected_oxp_world_scripts"])
    if not evidence["oxp_world_scripts"]:
        raise ScenarioError(
            "evidence.oxp_world_scripts is empty: the running game has no world script a stock "
            "game lacks, so PNGTestSuite's script was never instantiated. The OXP being on the "
            "search path is not the same as its content being live.")
    if sorted(evidence["oxp_world_scripts"]) != expected_names:
        raise ScenarioError(
            "evidence.oxp_world_scripts is %r but the spec pins %r. A golden taken against a "
            "different set of expansion scripts is not comparable with the stored one."
            % (sorted(evidence["oxp_world_scripts"]), expected_names))
    if evidence["oxp_script_versions"] != spec["expected_live_script_versions"]:
        raise ScenarioError(
            "evidence.oxp_script_versions is %r but the spec pins %r. This is the read that "
            "proves a script FILE was found, compiled and instantiated - a name in "
            "oxp_world_scripts only proves the world-scripts list was merged."
            % (evidence["oxp_script_versions"], spec["expected_live_script_versions"]))

    # --- DEFENCE 2: the 153-entry shipdata registry was merged ---------------------------------
    if evidence["png_shipdata_entries"] != int(spec["png_test_count"]):
        raise ScenarioError(
            "evidence.png_shipdata_entries is %r but PNGTestSuite defines exactly %d test-cube "
            "ship entries in Config/shipdata.plist. Fewer means the plist was not merged (or was "
            "merged partially); more means something else is contributing keys with this prefix."
            % (evidence["png_shipdata_entries"], int(spec["png_test_count"])))
    if evidence["png_diffuse_map_sample"] != spec["expected_diffuse_map_sample"]:
        raise ScenarioError(
            "evidence.png_diffuse_map_sample is %r but the spec pins %r. These strings are read "
            "back out of the RUNNING engine's merged ship registry and each names a PNG the "
            "fixture asks it to decode; a mismatch means the merged registry is not this fixture's."
            % (evidence["png_diffuse_map_sample"], spec["expected_diffuse_map_sample"]))

    # --- DEFENCE 3: a PNG was actually DECODED and UPLOADED ------------------------------------
    uploads = evidence["png_texture_uploads"]
    if not uploads:
        raise ScenarioError(
            "evidence.png_texture_uploads is EMPTY: not one [texture.upload] line named the "
            "expansion's image. OOConcreteTexture -upload (OOConcreteTexture.m:525) is reached "
            "only after OOPNGTextureLoader has decoded the file - the loader bails at "
            "texture.load.png.failed long before any upload - so an empty list means NO PNG FROM "
            "THIS EXPANSION WAS DECODED. This is exactly the silent failure a clean log and a "
            "quiet dump cannot distinguish from success.")
    want_key = spec["expected_texture_key"]
    matching = [u for u in uploads if u["key"] == want_key]
    if not matching:
        raise ScenarioError(
            "no [texture.upload] line named %r; the uploads seen were %r. The scenario's texture "
            "evidence is about THAT image and no other." % (want_key, uploads))
    ihdr = evidence["png_ihdr_dimensions"]
    for upload in matching:
        if [upload["width"], upload["height"]] != ihdr:
            raise ScenarioError(
                "the engine reports uploading %r at %dx%d pixels, but the IHDR chunk of the file "
                "on disk says %dx%d. The dimensions are read from the same bytes the engine "
                "decoded, so a disagreement means the upload is not of this image and the "
                "texture-decode evidence does not apply to it."
                % (want_key, upload["width"], upload["height"], ihdr[0], ihdr[1]))
    if ihdr != list(spec["expected_ihdr_dimensions"]):
        raise ScenarioError(
            "the staged PNG's IHDR says %dx%d but the spec pins %r. Both are kept on purpose: the "
            "derivation keeps the gate honest if the fixture is ever replaced, and the literal "
            "keeps the derivation honest if the IHDR parse silently reads the wrong bytes "
            "(bead oo-vwd)." % (ihdr[0], ihdr[1], list(spec["expected_ihdr_dimensions"])))
    if evidence["png_load_failures"]:
        raise ScenarioError(
            "the run emitted PNG loader diagnostics: %r. These come from OOPNGTextureLoader's "
            "error/warning callbacks (OOPNGTextureLoader.m:223,236) and mean an image did not "
            "decode cleanly. A texture-decoding scenario must not tolerate them."
            % (evidence["png_load_failures"],))

    # --- DEFENCE 4: the run really ran ---------------------------------------------------------
    if not evidence["tick_budget_met"]:
        raise ScenarioError(
            "evidence.tick_budget_met is false: the game clock advanced less than the scenario's "
            "budget of %.3f game seconds (%d ticks), so the simulation did not run"
            % (evidence["game_seconds_budget"], evidence["ticks"]))
    if not evidence["world_at_rest"]:
        raise ScenarioError("evidence.world_at_rest is false: the world was still integrating")
    if not evidence["world_reached_fixed_point"]:
        raise ScenarioError(
            "evidence.world_reached_fixed_point is false: the clearing loop never saw a round that "
            "both removed nothing and left nothing, so something was still adding entities when "
            "the dump was taken and no two runs can agree")
    if not evidence["populators_suppressed"]:
        raise ScenarioError(
            "evidence.populators_suppressed is 0: the system populator was never switched off, so "
            "the world kept gaining traffic during the run and no two dumps can agree")
    if not evidence["stations_quieted"]:
        raise ScenarioError(
            "evidence.stations_quieted is 0: no station had hasNPCTraffic written false. "
            "StationEntity -update (StationEntity.m:960-995) runs its OWN launch schedule for "
            "shuttles, traders and patrols independently of the system populator - MEASURED, it "
            "produced five different dumps in ten runs of this scenario.")
    if sorted(evidence["repopulator_handlers_quieted"]) != sorted(spec["repopulator_handlers"]):
        raise ScenarioError(
            "evidence.repopulator_handlers_quieted is %r but the spec pins %r. "
            "oolite-populator.js's systemWillRepopulate (:1027) keeps launching traffic for the "
            "life of the system, and its station picker _tradeStation (:2656-2680) ENDS WITH an "
            "unconditional `return system.mainStation`, so hasNPCTraffic does not stop it - "
            "MEASURED, it kept adding ships with both other suppressions in place."
            % (sorted(evidence["repopulator_handlers_quieted"]),
               sorted(spec["repopulator_handlers"])))
    if evidence["gui_screen"] != "GUI_SCREEN_MISSION":
        raise ScenarioError(
            "evidence.gui_screen is %r: the frame was not taken on the mission screen that "
            "carries the expansion's image" % (evidence["gui_screen"],))

    # --- DEFENCE 5: the NOMANIF allowance, held EXACTLY ----------------------------------------
    allowed_count = int(spec["allowed_oxp_standards_errors"])
    allowed = set(spec["allowed_oxp_standards_error_signatures"])
    if evidence["oxp_standards_errors"] != allowed_count:
        raise ScenarioError(
            "evidence.oxp_standards_errors is %d but exactly %d is allowed for this fixture "
            "(bead oo-kcrw: PNGTestSuite is NOMANIF - it predates the manifest format and emits "
            "exactly %d '[oxp-standards.error]' lines). A different count means a NEW problem, "
            "and widening this number to make the run pass is forbidden. Signatures seen: %r"
            % (evidence["oxp_standards_errors"], allowed_count, allowed_count,
               evidence["oxp_standards_error_signatures"]))
    unexpected = [s for s in evidence["oxp_standards_error_signatures"] if s not in allowed]
    if unexpected:
        raise ScenarioError(
            "the run emitted an [oxp-standards.error] line that is NOT the known missing-manifest "
            "message: %r. The allow-list is %r and it is deliberately exact - a third or different "
            "error is a finding, not noise." % (unexpected, sorted(allowed)))


def canonical(obj):
    """The one serialisation used for the golden, for a fresh run, and for the hash."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def run(app_dir, out_path, spec, run_root, keep=False, stage=True, empty_stage=False,
        stage_double=False, blank_screen=False, seed_override=None, ticks_override=None,
        frame_out=None):
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

    # `empty_stage` is the NARROW mutant: the staging root exists and is on
    # OO_ADDITIONALADDONSDIRS, but the expansion has been removed from it. Narrower than --no-oxp
    # on purpose - oxp_staged stays true, so the run gets past the staging assertion and trips the
    # assertion that is actually under test. A mutant applied ABOVE the assertion you mean to
    # exercise short-circuits it (bead oo-vwd).
    if empty_stage:
        os.makedirs(addons_dir, exist_ok=True)
        staged_oxp = None
    else:
        staged_oxp = stage_oxp(spec, addons_dir, twice=stage_double) if stage else None

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

            # SUPPRESSION FIRST, BEFORE ANY SLOW PROBE. The shipdata probe below makes ~160 console
            # round trips and takes several seconds of GAME time, during which a station with
            # hasNPCTraffic still on launches traders and miners. MEASURED: with the suppression
            # after the probe, eight of ten runs refused with a launched ship still under thrust
            # ('Cobra Mark I=232.5000', 'Mining Transporter=69.3000') and the two that dumped
            # disagreed. Order is load-bearing, not tidiness.
            channels = enable_texture_logging(console, spec)
            suppressed = suppress_populators(console)
            stations_quieted = suppress_station_traffic(console)
            repopulator_handlers = suppress_repopulator(console, spec)
            quiesce(console)

            names = world_script_names(console)
            stock = set(spec["stock_world_scripts"])
            oxp_names = sorted(n for n in names if n not in stock)
            versions, key_only = world_script_versions(console, oxp_names)
            shipdata_entries, diffuse_sample = (0, {})
            if oxp_names:
                shipdata_entries, diffuse_sample = png_shipdata(console, spec)

            elapsed = run_ticks(console, ticks, float(spec["tick_seconds"]))

            # SCREEN FIRST, THEN QUIESCE, THEN MEASURE - the order is load-bearing.
            # Clearing to a fixed point and THEN switching screens and settling leaves several
            # seconds in which the repopulator can land another ship, and MEASURED it did:
            # 'Mining Transporter=50.0000', 'Cobra Mark I=138.0000', 'Worm=50.0000' all arrived
            # AFTER a clean clear returned. So the mission screen is opened and settled first, and
            # the world is driven to its fixed point LAST, immediately before the frame and the
            # dump, with nothing in between that can burn game time.
            gui_screen = show_backdrop(console, spec, blank=blank_screen)
            settle(console)
            clear_rounds = quiesce(console)
            at_rest = assert_at_rest(console)
            png, grid = capture_frame(console, artifact_dir)
            state = json.loads(dump_state(console))

        # AFTER the game has exited, so the log is complete and flushed.
        standards, uploads, png_failures, log_bytes = read_log_evidence(
            artifact_dir, oxp_basename)

        ihdr = [0, 0]
        if staged_oxp:
            ihdr = list(png_ihdr_dimensions(
                os.path.join(staged_oxp, *spec["backdrop_image_relpath"].split("/"))))

        evidence = {
            "scenario": SCENARIO,
            "oxp_staged": bool(stage or empty_stage),
            "oxp_basename": oxp_basename,
            "oxp_world_scripts": oxp_names,
            "oxp_script_versions": versions,
            "oxp_key_only_scripts": key_only,
            "png_shipdata_entries": shipdata_entries,
            "png_diffuse_map_sample": diffuse_sample,
            "png_texture_uploads": sorted(
                uploads, key=lambda u: (u["key"], u["width"], u["height"])),
            "png_ihdr_dimensions": ihdr,
            "png_load_failures": png_failures,
            "texture_log_channels": sorted(channels),
            "oxp_standards_errors": len(standards),
            "oxp_standards_error_signatures": sorted(set(standards)),
            "gui_screen": gui_screen,
            "world_at_rest": bool(at_rest),
            # The BUDGET is pinned; the MEASURED elapsed time is deliberately not in the dump - the
            # overshoot past the 100 ms poll is a property of how fast this box rendered that
            # interval, not of the engine (bead oo-jor). The assertion keeps full strength as a
            # boolean and the raw float is reported on stdout by the CLI.
            "tick_budget_met": bool(elapsed >= ticks * float(spec["tick_seconds"])),
            "game_seconds_budget": round(ticks * float(spec["tick_seconds"]), 3),
            "ticks": ticks,
            "seed": seed,
            "system_id": int(spec["system_id"]),
            "populators_suppressed": len(suppressed),
            "stations_quieted": stations_quieted,
            "repopulator_handlers_quieted": sorted(repopulator_handlers),
            # The NUMBER of rounds is deliberately NOT in the dump - it depends on how far the
            # station's launch queue had drained when this run got there, which is a stopwatch
            # reading. What IS recorded is that the world reached a fixed point at all.
            "world_reached_fixed_point": bool(clear_rounds) and clear_rounds[-1] == [0, 0, 0],
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
        if frame_out:
            parent = os.path.dirname(os.path.abspath(frame_out))
            if parent:
                os.makedirs(parent, exist_ok=True)
            with open(frame_out, "wb") as handle:
                handle.write(bytes(grid))
        return {"ok": True, "out": out_path, "frame_out": frame_out, "port": port,
                "staged_oxp": staged_oxp, "png": golden_run._slashes(png),
                "frame_hash": frame_hash.hex_digest(grid),
                "wall_seconds": round(time.time() - started, 1), "bytes": len(text),
                "log_bytes": log_bytes, "game_seconds_elapsed": round(elapsed, 3),
                "evidence": evidence}
    finally:
        if previous is None:
            os.environ.pop("OO_ADDITIONALADDONSDIRS", None)
        else:
            os.environ["OO_ADDITIONALADDONSDIRS"] = previous
        if not keep:
            golden_run.unstage_app(staged)
            shutil.rmtree(addons_dir, ignore_errors=True)
        golden_run.release_all()


def default_app_dir():
    for candidate in (os.environ.get("OO_APP_DIR"),
                      os.path.join(REPO_ROOT, "upstream", "oolite", "build", "meson_test",
                                   "oolite.app"),
                      "C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app"):
        if candidate and os.path.isdir(candidate):
            return golden_run._slashes(os.path.abspath(candidate))
    return None


def compare_frame(grid_path, reference_path, tol=None):
    """Compare a captured grid with the stored reference under the MEASURED tolerance."""
    tol = frame_hash.derive_tolerance() if tol is None else tol
    with open(grid_path, "rb") as handle:
        got = handle.read()
    with open(reference_path, "rb") as handle:
        want = handle.read()
    if len(got) != frame_hash.GRID_CELLS or len(want) != frame_hash.GRID_CELLS:
        raise ScenarioError(
            "a frame grid is not %d bytes (%s=%d, %s=%d); the comparison would be meaningless"
            % (frame_hash.GRID_CELLS, grid_path, len(got), reference_path, len(want)))
    d = frame_hash.distance(got, want)
    return {"distance": d, "tolerance": tol, "within": d <= tol,
            "ratio": d / tol if tol else float("inf"),
            "hash_got": frame_hash.hex_digest(got), "hash_want": frame_hash.hex_digest(want)}


def main(argv=None):
    parser = argparse.ArgumentParser(prog="tests/golden/png_test_suite.py", description=__doc__)
    parser.add_argument("--app-dir", default=None)
    parser.add_argument("--out", default=None, help="write the canonical dump here")
    parser.add_argument("--frame-out", default=None, help="write the 64x64 luminance grid here")
    parser.add_argument("--run-root", default=None, help="scratch root for staged apps/artifacts")
    parser.add_argument("--keep", action="store_true")
    parser.add_argument("--seed", type=int, default=None, help="override the spec's seed")
    parser.add_argument("--ticks", type=int, default=None, help="override the spec's tick count")
    parser.add_argument("--empty-stage", action="store_true",
                        help="MUTANT: create the staging directory but REMOVE the expansion from "
                             "it. Narrower than --no-oxp: the run reaches and trips the "
                             "expansion-content evidence assertion rather than the staging one.")
    parser.add_argument("--stage-double", action="store_true",
                        help="MUTANT: stage the expansion at TWO paths, reproducing the "
                             "case-insensitive double-root state bead oo-3ya measured. Must trip "
                             "the EXACT missing-manifest count, proving that count is a pin.")
    parser.add_argument("--blank-screen", action="store_true",
                        help="MUTANT: open the identical mission screen with NO background image. "
                             "The dump's evidence still passes; the FRAME must go red.")
    parser.add_argument("--no-oxp", action="store_true",
                        help="MUTANT: stage no expansion. The run must then FAIL its own evidence "
                             "assertions; used to prove the gate can go red, and to MEASURE the "
                             "stock world-script baseline pinned in spec.json.")
    parser.add_argument("--compare-frame", nargs=2, metavar=("GRID", "REFERENCE"),
                        help="offline: compare two stored grids and exit 0/1")
    args = parser.parse_args(argv)

    if args.compare_frame:
        try:
            result = compare_frame(*args.compare_frame)
        except Exception as exc:  # noqa: BLE001
            print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
            return 2
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
        return 0 if result["within"] else 1

    spec = load_spec()
    app_dir = args.app_dir or default_app_dir()
    if not app_dir or not os.path.isdir(app_dir):
        print("[!] no Oolite build; pass --app-dir or set OO_APP_DIR", file=sys.stderr)
        return 1
    ensure_launchable(app_dir)

    run_root = args.run_root or os.path.join(
        os.environ.get("LOCALAPPDATA", os.path.expanduser("~")), "Temp", "oo_gxp_runs")
    run_root = golden_run._slashes(os.path.abspath(run_root))

    try:
        result = run(app_dir, args.out, spec, run_root, keep=args.keep,
                     stage=not (args.no_oxp or args.empty_stage),
                     empty_stage=args.empty_stage, stage_double=args.stage_double,
                     blank_screen=args.blank_screen,
                     seed_override=args.seed, ticks_override=args.ticks,
                     frame_out=args.frame_out)
    except Exception as exc:  # noqa: BLE001 - the CLI reports; the library raises
        print("[!] %s: %s" % (type(exc).__name__, exc), file=sys.stderr)
        return 1
    json.dump(result, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
