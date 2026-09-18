"""Offline gate: the 002-witchspace dump PROVES A JUMP HAPPENED - not merely that nothing crashed.

Runs against the stored artifacts only. No game process, no console, no GPU: it is the check that
still works on a machine that cannot launch Oolite, and the check a reviewer can read in one
sitting. The live scenario (`witchspace_jump.py`) asserts the same properties AT RUN TIME against
a running game; this file asserts them against WHAT WAS BLESSED, so a golden edited after the fact
is caught by something that did not run when it was made.

WHY THIS FILE EXISTS AT ALL - THE FAILURE IT IS SHAPED AGAINST
--------------------------------------------------------------
A witchspace scenario is unusually easy to fake green. The jump is the thing under test, so the
tempting assertion is a NEGATIVE one - "the run did not crash", "Latest.log has no ERROR lines" -
and every one of those passes VACUOUSLY on a game that died before it ever jumped: a process that
exits in its first second writes a log with zero ERROR lines. So every check below is a PRESENCE
claim about state the engine itself had to produce, and the first one is a progress precondition.

THE SIX WITNESSES, AND WHAT EACH ONE RULES OUT
----------------------------------------------
  1. PROGRESS.  ticks > 0, the dump is non-trivially sized, and the player exists. Nothing else is
     worth asking of a dump from a game that never ran.
  2. THE SYSTEM CHANGED.  system_id_after != system_id_before, and after == the spec's destination.
     The minimum meaning of "a jump happened".
  3. THE ENGINE SAW IT, NOT US.  >= 1 shipWillEnterWitchspace AND >= 1 shipExitedWitchspace.
     These are dispatched from Universe.m (:1061, :1106) during the jump itself. A test that wrote
     `system.ID` by hand would satisfy (2) and fail here.
  4. THE COUNTDOWN RAN.  STATUS_WITCHSPACE_COUNTDOWN and STATUS_EXITING_WITCHSPACE both observed.
     An instantaneous teleport - which is what a mis-scripted `player.ship.exitSystem()` with no
     countdown would look like - passes (2) and (3) and fails here.
  5. IT COST WHAT A JUMP COSTS.  fuel_consumed_tenths == distance_ly_tenths, and > 0. This is the
     INDEPENDENT witness: it comes through the fuel accounting rather than through system.ID, so an
     engine change that moved the player without performing a jump does not satisfy it. It is also
     the check that distinguishes a standard jump from a misjump or a galactic hyperspace jump.
  6. IT ARRIVED SOMEWHERE SPECIFIC.  The run ends docked at the DESTINATION's own main station,
     named. Lave's main station is a Coriolis and Zaonce's an Icosahedron, so the station name is a
     second witness to WHICH system the run ended in that never consults system.ID.

AND TWO WITNESSES ABOUT THE ARTIFACTS THEMSELVES
------------------------------------------------
  7. THE DUMP IS WITNESSED FROM OUTSIDE.  state.json's sha256 AND byte size are pinned in
     provenance.json, a SEPARATE file. A golden cannot witness itself: any digest stored INSIDE
     state.json moves when state.json is edited, so both sides of the comparison change together
     and nothing goes red.
  8. THE FRAME IS PINNED FOR LIVENESS, NOT FOR BYTES.  The grid must show real contrast (a dead run
     draws an all-black grid), and must NOT be byte-compared - llvmpipe is not bit-reproducible.

EXIT CODES: 0 all witnesses present; 1 a witness failed (named, with what it rules out);
2 a structural/usage error that prevented a verdict.
"""

import hashlib
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SCENARIO = "002-witchspace"

# Guarded location first, staged second: this file keeps working unchanged after a human re-bless
# moves the artifacts into goldens/ (which guardrails.sh forbids this bead from doing itself).
DIR_CANDIDATES = (
    os.path.join(REPO_ROOT, "goldens", "windows-x64", SCENARIO),
    os.path.join(HERE, "pending", SCENARIO),
)

MIN_DUMP_BYTES = 500
COUNTDOWN_STATUS = "STATUS_WITCHSPACE_COUNTDOWN"
EXITING_STATUS = "STATUS_EXITING_WITCHSPACE"
STANDARD_JUMP_CAUSE = "standard jump"


def fail(message):
    sys.stderr.write("FAIL: %s\n" % message)
    raise SystemExit(1)


def refuse(message):
    sys.stderr.write("REFUSED: %s\n" % message)
    raise SystemExit(2)


def resolve_dir():
    for candidate in DIR_CANDIDATES:
        if os.path.isfile(os.path.join(candidate, "state.json")):
            return candidate
    refuse("no state.json in any of %s" % ", ".join(DIR_CANDIDATES))


def load(path):
    if not os.path.isfile(path):
        refuse("missing artifact %s" % path)
    with open(path, "rb") as handle:
        raw = handle.read()
    try:
        return raw, json.loads(raw.decode("utf-8"))
    except ValueError as exc:
        refuse("%s is not valid JSON: %s" % (path, exc))


def check_progress(state, raw, path):
    """WITNESS 1. Everything below is meaningless without this one."""
    if len(raw) < MIN_DUMP_BYTES:
        fail("%s is %d bytes (< %d): too small to be a real dump of a populated system. A dead "
             "launch produces a tiny or empty dump and would otherwise satisfy every "
             "absence-of-badness check below." % (path, len(raw), MIN_DUMP_BYTES))
    evidence = state.get("evidence")
    if not isinstance(evidence, dict):
        fail("%s carries no evidence block; an evidence-free dump compares equal to any other "
             "evidence-free dump and proves nothing about a jump" % path)
    ticks = evidence.get("ticks")
    if not isinstance(ticks, int) or ticks < 1:
        fail("evidence.ticks=%r: the simulation did not advance in the destination system, so "
             "every other claim in this dump is about a game that never ran" % (ticks,))
    player = (state.get("player") or {}).get("ship")
    if not isinstance(player, dict):
        fail("%s has no player.ship; the dump is not of a running game" % path)
    return evidence


def check_jump(evidence, spec):
    """WITNESSES 2-6."""
    before = evidence.get("system_id_before")
    after = evidence.get("system_id_after")
    if not isinstance(before, int) or not isinstance(after, int):
        fail("evidence system_id_before=%r / system_id_after=%r must both be ints" % (before, after))
    if before == after:
        fail("system_id_before == system_id_after == %d: THE SHIP NEVER LEFT. This is the whole "
             "scenario; nothing else in this dump matters if it fails." % before)
    if after != spec["destination_system_id"]:
        fail("the run ended in system %d, but the spec pins destination_system_id=%d. It jumped "
             "SOMEWHERE - a misjump lands in interstellar space, and a galactic jump lands in a "
             "different galaxy entirely - but not where this scenario says."
             % (after, spec["destination_system_id"]))
    if before != spec["origin_system_id"]:
        fail("the run started in system %d, but the spec pins origin_system_id=%d; the save did "
             "not load the state this scenario is written against"
             % (before, spec["origin_system_id"]))

    enters = evidence.get("witchspace_enter_events")
    exits = evidence.get("witchspace_exit_events")
    if not isinstance(enters, int) or enters < 1:
        fail("evidence.witchspace_enter_events=%r: the ENGINE never dispatched "
             "shipWillEnterWitchspace (Universe.m:1061). A dump that changed system.ID without it "
             "records a teleport, not a jump." % (enters,))
    if not isinstance(exits, int) or exits < 1:
        fail("evidence.witchspace_exit_events=%r: the ENGINE never dispatched shipExitedWitchspace "
             "(Universe.m:1106), so the arrival was never completed by the engine" % (exits,))
    if evidence.get("jump_cause") != STANDARD_JUMP_CAUSE:
        fail("evidence.jump_cause=%r, expected %r. The engine names the cause itself; a misjump or "
             "a galactic jump reports a different string and is a different scenario."
             % (evidence.get("jump_cause"), STANDARD_JUMP_CAUSE))
    if evidence.get("jump_failed"):
        fail("the engine dispatched playerJumpFailed(%r); witchJumpChecklist: refused the jump "
             "(PlayerEntity.m:7387-7460)" % evidence["jump_failed"])

    statuses = evidence.get("statuses_seen") or []
    for status, why in ((COUNTDOWN_STATUS, "the countdown never ran: the jump was instantaneous, "
                                           "which is what a scripted teleport looks like"),
                        (EXITING_STATUS, "the exit-from-witchspace state was never observed, so "
                                         "the arrival was not witnessed in progress")):
        if status not in statuses:
            fail("%s missing from evidence.statuses_seen=%r: %s" % (status, statuses, why))

    fuel = evidence.get("fuel_consumed_tenths")
    distance = evidence.get("distance_ly_tenths")
    if not isinstance(fuel, int) or not isinstance(distance, int):
        fail("evidence fuel_consumed_tenths=%r / distance_ly_tenths=%r must both be ints"
             % (fuel, distance))
    if fuel < 1:
        fail("evidence.fuel_consumed_tenths=%d: the jump cost no fuel, so it was not a jump. This "
             "is the INDEPENDENT witness - it comes through the fuel accounting rather than "
             "through system.ID - and it is the one an engine that moved the player without "
             "jumping fails." % fuel)
    if fuel != distance:
        fail("evidence bills %d tenths of fuel for a %d-tenth jump. A standard jump costs exactly "
             "its distance (PlayerEntity.m:7440-7447); a disagreement means the move was not a "
             "standard witchspace jump." % (fuel, distance))

    station = evidence.get("destination_station_name")
    if station != spec["destination_station_name"]:
        fail("the run ended docked at %r, but the destination's own main station is %r. THE "
             "STATION NAME IS A SECOND WITNESS THAT NEVER CONSULTS system.ID: the origin's main "
             "station has a different name, so a run that never left cannot produce this."
             % (station, spec["destination_station_name"]))
    if not evidence.get("docked_at_end"):
        fail("evidence.docked_at_end is false: the run did not finish docked at the destination")
    if (evidence.get("dock_events") or 0) < 1:
        fail("evidence.dock_events=%r: the engine never dispatched shipDockedWithStation "
             "(PlayerEntity.m:7206), so the docking was asserted rather than performed"
             % evidence.get("dock_events"))

    if not evidence.get("world_at_rest"):
        fail("evidence.world_at_rest is false (moving: %r); the dump was taken of a world still in "
             "motion, so its values track the frame count rather than the scenario"
             % (evidence.get("moving_entities"),))


def check_market_projection(state):
    """The one projection this scenario makes, and the reason it cannot hide a dead arrival."""
    projection = state.get("market_projection")
    if not isinstance(projection, dict) or not projection.get("projected"):
        fail("the dump records no market_projection. This scenario DOES project the commodity "
             "market out of the comparison (its per-good prices are randf() draws taken when the "
             "destination market is generated), and a projection that is not declared IN the "
             "artifact is indistinguishable from a field that silently went missing.")
    if not projection.get("reason"):
        fail("market_projection records no reason; an exclusion without a recorded reason is how a "
             "golden quietly stops testing something")
    market = state.get("market") or {}
    count = market.get("good_count")
    if not isinstance(count, int) or count < 1:
        fail("the projected market reports good_count=%r. The market is excluded BY VALUE, not "
             "deleted: arriving in a system rebuilds it (Universe.m:7997-7998), so an EMPTY market "
             "is exactly what a half-completed arrival produces and must still fail." % (count,))
    if len(market.get("goods") or []) != count:
        fail("the projected market lists %d good name(s) but reports good_count=%r"
             % (len(market.get("goods") or []), count))


def check_artifact_witness(golden_dir, raw):
    """WITNESS 7: state.json is pinned from OUTSIDE itself."""
    prov_path = os.path.join(golden_dir, "provenance.json")
    _, provenance = load(prov_path)
    artifacts = provenance.get("artifacts") or {}
    record = artifacts.get("state.json")
    if not isinstance(record, dict):
        fail("%s records no artifacts['state.json']. A GOLDEN CANNOT WITNESS ITSELF: a digest "
             "stored inside state.json moves when state.json is edited, so both sides of the "
             "comparison change together and no line goes red. The witness must live in a "
             "SEPARATE file." % prov_path)
    actual_sha = hashlib.sha256(raw).hexdigest()
    if record.get("sha256") != actual_sha:
        fail("state.json hashes to %s but %s pins %s. The golden has been edited since it was "
             "blessed, or the provenance was not regenerated with it."
             % (actual_sha, prov_path, record.get("sha256")))
    if record.get("bytes") != len(raw):
        fail("state.json is %d bytes but %s pins %r; a truncation or an append is visible here "
             "even to a reader who cannot hash" % (len(raw), prov_path, record.get("bytes")))
    return provenance


def check_frame(golden_dir, provenance):
    """WITNESS 8: liveness asserted, byte digest deliberately refused.

    The grid is the raw `side*side` luminance bytes `frame_hash.frame_grid` produces, not JSON.
    Liveness is measured as the SPREAD (max - min) of those bytes scaled to 0..1: a run that died
    before drawing the scene yields a uniform grid whose spread is ~0, and that is the single frame
    property such a run cannot fake. The blessed grid is NOT byte-compared against anything - see
    the failure message below.
    """
    grid_path = os.path.join(golden_dir, "frame.grid")
    if not os.path.isfile(grid_path):
        refuse("missing %s" % grid_path)
    with open(grid_path, "rb") as handle:
        cells = handle.read()
    if not cells:
        fail("%s is empty" % grid_path)
    side = int(round(len(cells) ** 0.5))
    if side * side != len(cells):
        fail("%s is %d bytes, not a square luminance grid; frame_hash.frame_grid writes side*side "
             "bytes" % (grid_path, len(cells)))
    spread = (max(cells) - min(cells)) / 255.0

    liveness = provenance.get("frame_liveness") or {}
    floor = liveness.get("floor")
    if liveness.get("asserted") is not True or not isinstance(floor, (int, float)) or floor <= 0:
        fail("provenance frame_liveness=%r must assert a positive floor; liveness is the one frame "
             "property a dead run fails (a run that died before drawing yields a uniform grid with "
             "zero spread), and without it the frame artifact is entirely unpinned" % (liveness,))
    if spread < floor:
        fail("the frame grid's luminance spread is %.6f, below the blessed floor %.6f: the frame "
             "is (near-)uniform, which is what a run that never drew the scene produces"
             % (spread, floor))
    if provenance.get("frame_digest_asserted") is not False:
        fail("provenance frame_digest_asserted=%r; the grid must NEVER be byte-compared, because "
             "llvmpipe is not bit-reproducible and the predicate would flake on renderer noise. "
             "The dump is byte-hashed BECAUSE it is quantised and deterministic; the frame is not. "
             "The asymmetry is the point." % provenance.get("frame_digest_asserted"))
    return spread, floor


def main():
    golden_dir = resolve_dir()
    spec_path = os.path.join(golden_dir, "spec.json")
    if not os.path.isfile(spec_path):
        spec_path = os.path.join(HERE, "pending", SCENARIO, "spec.json")
    _, spec = load(spec_path)
    raw, state = load(os.path.join(golden_dir, "state.json"))

    evidence = check_progress(state, raw, os.path.join(golden_dir, "state.json"))
    check_jump(evidence, spec)
    check_market_projection(state)
    provenance = check_artifact_witness(golden_dir, raw)
    spread, floor = check_frame(golden_dir, provenance)

    print("PASS: the blessed 002-witchspace dump proves a jump HAPPENED. System %d (%s) -> %d (%s), "
          "docked at %s; %d enter / %d exit witchspace event(s) from the ENGINE; %s and %s both "
          "observed; %d tenths of fuel billed for a %d-tenth jump (independent of system.ID); %d "
          "ticks run in the destination with the world at rest. Market projected out by value with "
          "%d goods still witnessed by shape. state.json pinned from provenance.json at %d bytes; "
          "frame liveness %.4f >= floor %.4f, byte digest deliberately not asserted."
          % (evidence["system_id_before"], spec["origin_system_name"],
             evidence["system_id_after"], spec["destination_system_name"],
             evidence["destination_station_name"], evidence["witchspace_enter_events"],
             evidence["witchspace_exit_events"], COUNTDOWN_STATUS, EXITING_STATUS,
             evidence["fuel_consumed_tenths"], evidence["distance_ly_tenths"], evidence["ticks"],
             (state.get("market") or {}).get("good_count"), len(raw), spread, floor))
    return 0


if __name__ == "__main__":
    sys.exit(main())
